import AppKit
import SwiftUI
import AVFoundation
import Combine

final class KITTWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class KITTSettingsWindow: NSWindow {
    var closeAction: (() -> Void)?
    override func cancelOperation(_ sender: Any?) { closeAction?() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var controller: KITTController?
    private var layoutSubscription: AnyCancellable?
    private var settingsSubscription: AnyCancellable?
    private var settingsWindow: KITTSettingsWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let kit = KITTController()
        controller = kit
        let window = KITTWindow(contentRect: NSRect(x: 0, y: 0, width: 384, height: 443),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "KITT Voice"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(white: 0.07, alpha: 1)
        window.contentView = NSHostingView(rootView: AppRoot(kit: kit))
        configure(window, compact: kit.compactMode)
        layoutSubscription = kit.$compactMode.removeDuplicates().dropFirst().sink { [weak self, weak window] compact in
            DispatchQueue.main.async {
                guard let self, let window else { return }
                self.configure(window, compact: compact)
            }
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        settingsSubscription = kit.$showSettings.removeDuplicates().sink { [weak self] visible in
            DispatchQueue.main.async { self?.setSettingsVisible(visible) }
        }
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About KITT Voice", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(withTitle: "Settings…", action: #selector(settings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide KITT Voice", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit KITT Voice", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let editItem = NSMenuItem()
        editItem.title = "Edit"
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        menu.addItem(editItem)
        let viewItem = NSMenuItem()
        viewItem.title = "View"
        let view = NSMenu(title: "View")
        view.addItem(withTitle: "Voice Box Only", action: #selector(compactView), keyEquivalent: "1")
        view.addItem(withTitle: "Full Interface", action: #selector(fullView), keyEquivalent: "2")
        view.addItem(.separator())
        view.addItem(withTitle: "Pause / Resume Hands-Free Listening", action: #selector(toggleListening), keyEquivalent: "l")
        view.addItem(withTitle: "KITT Sayings…", action: #selector(sayings), keyEquivalent: "")
        viewItem.submenu = view
        menu.addItem(viewItem)
        NSApp.mainMenu = menu
        NSApp.activate(ignoringOtherApps: true)
    }
    private func setSettingsVisible(_ visible: Bool) {
        guard let kit = controller else { return }
        if !visible {
            settingsWindow?.orderOut(nil)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        if settingsWindow == nil {
            let preferences = KITTSettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 565, height: 705),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            preferences.title = "KITT Settings"
            preferences.isReleasedWhenClosed = false
            preferences.delegate = self
            preferences.closeAction = { [weak kit] in kit?.closeSettings() }
            preferences.contentView = NSHostingView(rootView: SettingsView(kit: kit))
            preferences.center()
            settingsWindow = preferences
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        if let closed = notification.object as? NSWindow, closed === settingsWindow,
           controller?.showSettings == true { controller?.closeSettings() }
    }
    private func configure(_ window: NSWindow, compact: Bool) {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        window.minSize = .zero
        window.contentMinSize = .zero
        window.contentMaxSize = NSSize(width: 10000, height: 10000)
        window.contentAspectRatio = .zero
        window.styleMask = compact ? [.borderless, .resizable] : [.titled, .closable, .miniaturizable, .resizable]
        window.isOpaque = !compact
        window.backgroundColor = compact ? .clear : NSColor(white: 0.07, alpha: 1)
        window.hasShadow = true
        window.isMovableByWindowBackground = compact
        window.titlebarAppearsTransparent = true
        window.titleVisibility = compact ? .hidden : .visible
        let size = compact ? NSSize(width: 384, height: 443) : NSSize(width: 920, height: 795)
        window.setContentSize(size)
        window.contentMinSize = compact ? size : NSSize(width: 860, height: 795)
        if compact { window.contentAspectRatio = NSSize(width: 384, height: 443) }
        window.setFrameOrigin(NSPoint(x: center.x - window.frame.width / 2, y: center.y - window.frame.height / 2))
    }
    @objc func settings() { controller?.showSettings = true }
    @objc func compactView() { controller?.compactMode = true }
    @objc func fullView() { controller?.compactMode = false }
    @objc func toggleListening() { controller?.toggleHandsFree() }
    @objc func sayings() { controller?.showSayings = true }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "KITT Voice", .applicationVersion: "1.0",
            .credits: NSAttributedString(string: "A personal KITT-inspired voice companion.\nFree local AI with Ollama and macOS speech.\nUnofficial fan project; not affiliated with Knight Rider.")])
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { controller?.shutdown() }
}

// Run integration checks without launching the interface or requesting a microphone.
if CommandLine.arguments.contains("--check-local-ai") {
    Task { @MainActor in
        do {
            let models = try await LocalAI.models()
            guard let model = models.first(where: { $0.name == LocalAI.recommended }) ?? models.first else {
                throw AppFailure.message("No local AI model is installed.")
            }
            print("PASS: local model discovered: \(model.name)")
            let answer = try await LocalAI.answer(model: model.name,
                messages: [ChatLine(role: "user", content: "Say hello in one short sentence.")], mode: "NORMAL CRUISE")
            print("PASS: local AI reply: \(answer)")
            exit(0)
        } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
    dispatchMain()
} else if CommandLine.arguments.contains("--check-audio"), let path = CommandLine.arguments.last {
    do {
        let envelope = try VoiceEnvelope(url: URL(fileURLWithPath: path))
        guard !envelope.frames.isEmpty,
              envelope.frames.contains(where: { $0.center > 0.1 }),
              envelope.frames.allSatisfy({ (0...1).contains($0.left) && (0...1).contains($0.center) && (0...1).contains($0.right) && $0.left == $0.right && $0.center >= $0.left }) else {
            throw AppFailure.message("Speech envelopes are empty or out of range.")
        }
        let silence = envelope.at(10000)
        guard silence.center == 0, silence.left == 0, silence.right == 0 else {
            throw AppFailure.message("LEDs should be silent after playback.")
        }
        print("PASS: \(envelope.frames.count) frames; left and right match, centre is taller, LEDs return to silence.")
    } catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
} else if CommandLine.arguments.contains("--check-panel-drag") {
    MainActor.assumeIsolated {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 550))
        let drag = PanelDragView(frame: NSRect(x: 40, y: 50, width: 384, height: 443))
        parent.addSubview(drag)
        let button = NSRect(x: 35, y: 60, width: 65, height: 43)
        drag.excludedRects = [button]
        let bezel = drag.convert(NSPoint(x: 8, y: 8), to: parent)
        let control = drag.convert(NSPoint(x: 60, y: 80), to: parent)
        let empty = drag.convert(NSPoint(x: 190, y: 300), to: parent)
        guard drag.hitTest(bezel) === drag, drag.hitTest(empty) === drag,
              drag.hitTest(control) == nil, drag.mouseDownCanMoveWindow else {
            fputs("FAIL: drag must work on the bezel/background and pass through controls.\n", stderr); exit(1)
        }
        print("PASS: bezel and background accept dragging; control regions pass clicks through, including an offset view.")
    }
} else if CommandLine.arguments.contains("--check-settings-close") {
    MainActor.assumeIsolated {
        let kit = KITTController(preview: true)
        kit.connected = true
        kit.voice = FishVoice.name
        kit.fishKey = ""
        kit.showSettings = true
        kit.setHandsFree(true)
        kit.closeSettings()
        guard !kit.showSettings else { fputs("FAIL: settings reopened immediately with a missing Fish key.\n", stderr); exit(1) }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        guard !kit.showSettings, kit.activity == .idle, kit.notice != nil else {
            fputs("FAIL: settings must stay closed, keep the microphone idle, and explain the missing key.\n", stderr); exit(1)
        }
        kit.showSettings = true
        kit.setHandsFree(false)
        kit.closeSettings()
        guard !kit.showSettings else { fputs("FAIL: settings did not close with hands-free paused.\n", stderr); exit(1) }
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let preferences = KITTSettingsWindow(contentRect: NSRect(x: 0, y: 0, width: 565, height: 705),
            styleMask: [.titled, .closable], backing: .buffered, defer: true)
        preferences.closeAction = { kit.closeSettings() }
        kit.showSettings = true
        preferences.cancelOperation(nil)
        guard !kit.showSettings, preferences.styleMask.contains(.closable) else {
            fputs("FAIL: native Settings must support Escape and a standard close button.\n", stderr); exit(1)
        }
        kit.shutdown()
        print("PASS: Done stays closed with a missing Fish key; native Settings supports Escape and the standard close button. No microphone or API call needed.")
        exit(0)
    }
} else if CommandLine.arguments.contains("--render-panel"), let path = CommandLine.arguments.last {
    MainActor.assumeIsolated {
        // Offscreen rendering of this app's own SwiftUI, without screen capture,
        // microphone permission, network requests, or a visible test window.
        let kit = KITTController(preview: true)
        kit.connected = true
        kit.levels = VoiceLevels(left: 0.55, center: 0.75, right: 0.55)
        let renderer = ImageRenderer(content: CompactView(kit: kit).frame(width: 384, height: 443))
        renderer.scale = 2
        guard let cgImage = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            fputs("FAIL: could not render the compact voice box.\n", stderr); exit(1)
        }
        do { try png.write(to: URL(fileURLWithPath: path)); print("PASS: compact panel rendered at 768 × 886.") }
        catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
