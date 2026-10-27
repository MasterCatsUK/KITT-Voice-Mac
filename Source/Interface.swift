import SwiftUI
import AppKit

private struct PanelControlRegions: PreferenceKey {
    static var defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

// A native drag surface with holes over actual SwiftUI control bounds. This
// avoids swallowing button clicks, and keeps dragging correct when resized.
struct PanelDragSurface: NSViewRepresentable {
    let excludedRects: [CGRect]
    let kit: KITTController
    func makeNSView(context: Context) -> PanelDragView { PanelDragView() }
    func updateNSView(_ view: PanelDragView, context: Context) {
        view.excludedRects = excludedRects
        view.kit = kit
        view.toolTip = "Drag to move KITT. AIR pauses or resumes listening. P3 opens Settings."
    }
}

final class PanelDragView: NSView {
    var excludedRects: [CGRect] = []
    weak var kit: KITTController?
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard bounds.contains(local), !excludedRects.contains(where: { $0.contains(local) }) else { return nil }
        return self
    }
    override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        add(to: menu, title: kit?.handsFreeEnabled == true ? "Pause listening" : "Resume hands-free listening", action: #selector(toggleListening))
        add(to: menu, title: "Settings…", action: #selector(settings))
        add(to: menu, title: "KITT sayings", action: #selector(sayings))
        add(to: menu, title: "Show full interface", action: #selector(fullInterface))
        menu.addItem(.separator())
        add(to: menu, title: "Quit KITT Voice", action: #selector(quit))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    private func add(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }
    @objc private func toggleListening() { kit?.toggleHandsFree() }
    @objc private func settings() { kit?.showSettings = true }
    @objc private func sayings() { kit?.showSayings = true }
    @objc private func fullInterface() { kit?.compactMode = false }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

private let red = Color(red: 1, green: 0.16, blue: 0.12)
private let amber = Color(red: 1, green: 0.58, blue: 0.15)
private let subdued = Color(red: 0.55, green: 0.57, blue: 0.59)

struct VoiceBox: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 23) {
                    Button { kit.toggleHandsFree() } label: {
                        lamp("AIR", color: amber, active: kit.activity == .listening)
                    }.buttonStyle(.plain)
                        .accessibilityLabel(kit.handsFreeEnabled ? "Pause hands-free listening" : "Resume hands-free listening")
                        .help("\(kit.status). Click to \(kit.handsFreeEnabled ? "pause" : "resume") hands-free listening.")
                        .anchorPreference(key: PanelControlRegions.self, value: .bounds) { [$0] }
                    lamp("OIL", color: amber, active: kit.connected)
                    panelButton("P1", help: "Play voice demo", action: kit.demo)
                    panelButton("P2", help: "Stop speech and pause hands-free listening", action: kit.stop)
                }.padding(.top, 30)
                VStack(spacing: 22) {
                    HStack(spacing: 9) {
                        LEDStack(level: kit.levels.left)
                        LEDStack(level: kit.levels.center)
                        LEDStack(level: kit.levels.right)
                    }
                    .frame(width: 112, height: 218)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("KITT red voice box")
                    .accessibilityValue(kit.activity == .speaking ? "Reacting to speech" : "Silent")
                    VStack(spacing: 8) {
                        modeButton("AUTO CRUISE", color: Color(red: 0.64, green: 0.17, blue: 0.08))
                        modeButton("NORMAL CRUISE", color: Color(red: 0.68, green: 0.7, blue: 0.24))
                        modeButton("PURSUIT", color: Color(red: 0.43, green: 0.3, blue: 1))
                    }
                }
                VStack(spacing: 23) {
                    lamp("S1", color: amber, active: kit.activity == .speaking)
                    lamp("S2", color: amber, active: kit.activity == .thinking)
                    panelButton("P3", help: "Voice and AI settings") { kit.showSettings = true }
                    panelButton("P4", help: "Replay last answer", action: kit.replay)
                }.padding(.top, 30)
            }
            .padding(.horizontal, 27).padding(.top, 24).padding(.bottom, 28)
        }
        .background(LinearGradient(colors: [Color(white: 0.105), Color(white: 0.065)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(.black.opacity(0.85), lineWidth: 3))
        .padding(9)
        .background(LinearGradient(colors: [Color(white: 0.9), Color(white: 0.43), Color(white: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 41))
        .overlay(RoundedRectangle(cornerRadius: 41).stroke(Color(white: 0.85).opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.65), radius: 22, y: 12)
        .overlayPreferenceValue(PanelControlRegions.self) { controls in
            if kit.compactMode {
                GeometryReader { geometry in
                    PanelDragSurface(excludedRects: controls.map { geometry[$0] }, kit: kit)
                }
            }
        }
    }

    private func lamp(_ title: String, color: Color, active: Bool) -> some View {
        Text(title).font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(.black.opacity(0.87))
            .frame(width: 65, height: 43)
            .background(color.opacity(active ? 1 : 0.47))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.black.opacity(0.8), lineWidth: 2))
            .shadow(color: color.opacity(active ? 0.45 : 0), radius: 9)
            .help(["AIR": "Microphone active", "OIL": "Local AI connected", "S1": "Voice output active", "S2": "AI is thinking"][title] ?? "")
    }

    private func panelButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.9))
                .frame(width: 65, height: 43)
                .background(LinearGradient(colors: [red, Color(red: 0.73, green: 0.07, blue: 0.04)], startPoint: .top, endPoint: .bottom))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.black.opacity(0.75), lineWidth: 2))
        }.buttonStyle(.plain).help(help).accessibilityLabel(help)
            .anchorPreference(key: PanelControlRegions.self, value: .bounds) { [$0] }
    }

    private func modeButton(_ title: String, color: Color) -> some View {
        let selected = kit.mode == title
        return Button { kit.mode = title } label: {
            Text(title.replacingOccurrences(of: " ", with: "\n"))
                .font(.system(size: title == "PURSUIT" ? 16 : 12, weight: .heavy, design: .rounded))
                .lineSpacing(-1).multilineTextAlignment(.center)
                .foregroundStyle(Color.black.opacity(selected ? 0.95 : 0.75))
                .frame(width: 126, height: 39)
                .background(color.opacity(selected ? 1 : 0.25))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.8), lineWidth: 2))
                .shadow(color: color.opacity(selected ? 0.28 : 0), radius: 8)
        }.buttonStyle(.plain).help("\(title): change KITT's conversational style")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .anchorPreference(key: PanelControlRegions.self, value: .bounds) { [$0] }
    }
}

struct AppRoot: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        Group {
            if kit.compactMode { CompactView(kit: kit) }
            else { MainView(kit: kit) }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $kit.showSayings) { SayingsView(kit: kit) }
    }
}

struct CompactView: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 384, geometry.size.height / 443)
            VoiceBox(kit: kit)
                .frame(width: 384, height: 443)
                .scaleEffect(scale)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .frame(minWidth: 384, minHeight: 443)
        .help([kit.status, kit.notice].compactMap { $0 }.joined(separator: " · "))
        .contextMenu {
            Button(kit.handsFreeEnabled ? "Pause listening" : "Resume hands-free listening") { kit.toggleHandsFree() }
            Button("Settings…") { kit.showSettings = true }
            Button("KITT sayings") { kit.showSayings = true }
            Button("Show full interface") { kit.compactMode = false }
            Divider()
            Button("Quit KITT Voice") { NSApplication.shared.terminate(nil) }
        }
    }
}

struct LEDStack: View {
    let level: Double
    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<24, id: \.self) { row in
                let distance = abs(Double(row) - 11.5) / 12
                let lit = level > 0.025 && distance < level
                RoundedRectangle(cornerRadius: 0.6)
                    .fill(lit ? Color(red: 1, green: 0.19, blue: 0.13) : Color(red: 0.19, green: 0.035, blue: 0.025))
                    .overlay(alignment: .top) { if lit { Rectangle().fill(Color(red: 1, green: 0.52, blue: 0.34).opacity(0.65)).frame(height: 1) } }
                    .shadow(color: lit ? red.opacity(0.8) : .clear, radius: 5)
                    .frame(width: 25, height: 6)
            }
        }
    }
}

struct MainView: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 11) {
                    Circle().fill(red).frame(width: 7, height: 7).shadow(color: red.opacity(0.6), radius: 5)
                    Text("KNIGHT INDUSTRIES").font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2.8)
                }
                Spacer()
                Text(kit.voice == FishVoice.name ? "LOCAL AI  /  FISH VOICE" : "LOCAL AI  /  LOCAL VOICE").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5).foregroundStyle(subdued)
                Button { kit.showSettings = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 16)) }
                    .buttonStyle(.plain).padding(.leading, 16).help("Settings").accessibilityLabel("Settings")
            }.padding(.horizontal, 30).padding(.top, 28)

            HStack(alignment: .top, spacing: 36) {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Text("K.I.T.T.").font(.system(size: 39, weight: .semibold, design: .rounded)).tracking(9)
                        Text("KNIGHT INDUSTRIES TWO THOUSAND").font(.system(size: 8, design: .monospaced)).tracking(1.6).foregroundStyle(subdued)
                    }
                    VoiceBox(kit: kit)
                    VStack(spacing: 9) {
                        Text(kit.status).font(.system(size: 10, weight: .medium, design: .monospaced)).tracking(2).foregroundStyle(kit.busy ? red : subdued)
                        Text(kit.voice == FishVoice.name ? "AI-generated KITT character voice" : "AI-generated voice · KITT-inspired").font(.system(size: 10)).foregroundStyle(subdued.opacity(0.8))
                    }
                    HStack(spacing: 16) {
                        Button { kit.demo() } label: { Label("Voice demo", systemImage: "waveform") }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color(white: 0.78))
                        Rectangle().fill(Color(white: 0.25)).frame(width: 1, height: 12)
                        Button { kit.replay() } label: { Label("Replay", systemImage: "arrow.counterclockwise") }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color(white: 0.78))
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "person.wave.2").foregroundStyle(subdued)
                        Picker("Voice", selection: $kit.voice) {
                            ForEach(kit.voices, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().frame(width: 215)
                        Button("Test") { kit.persist(); kit.demo() }.font(.system(size: 11))
                    }.font(.system(size: 11))
                        .onChange(of: kit.voice) { kit.persist() }
                    Button { kit.showSayings = true } label: { Label("KITT sayings", systemImage: "quote.bubble") }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(amber)
                }.frame(width: 382)

                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your co-pilot.").font(.system(size: 26, weight: .medium))
                        Spacer()
                        Button { kit.clear() } label: { Image(systemName: "square.and.pencil") }
                            .buttonStyle(.plain).foregroundStyle(subdued).help("New conversation").accessibilityLabel("New conversation")
                    }
                    Text("A familiar presence. A new conversation.").font(.system(size: 12)).foregroundStyle(subdued)
                    conversation
                    if let notice = kit.notice {
                        Text(notice).font(.system(size: 11)).foregroundStyle(amber).fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    if !kit.connected {
                        Button { kit.setup() } label: {
                            HStack { if kit.settingUp || kit.checking { ProgressView().controlSize(.small) }; Text(kit.settingUp ? "Setting up local AI…" : "Set up free AI"); Spacer(); Image(systemName: "arrow.right") }
                                .font(.system(size: 12, weight: .medium)).padding(12)
                                .background(amber.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 8)).foregroundStyle(amber)
                        }.buttonStyle(.plain).disabled(kit.settingUp)
                    }
                    HStack(spacing: 10) {
                        TextField("Type a message to KITT…", text: $kit.draft)
                            .textFieldStyle(.plain).font(.system(size: 13)).onSubmit { kit.send() }
                            .disabled(kit.activity != .idle)
                        Button { kit.send() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 25)) }
                            .buttonStyle(.plain).foregroundStyle(kit.canSend ? red : Color(white: 0.28)).disabled(!kit.canSend).help("Send message").accessibilityLabel("Send message")
                    }.padding(13).background(Color(white: 0.095)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.22), lineWidth: 1))
                    HStack(spacing: 12) {
                        Button { kit.talk() } label: {
                            HStack(spacing: 9) {
                                Image(systemName: kit.activity == .listening ? "stop.fill" : "mic.fill")
                                Text(kit.activity == .listening ? "Finish & send" : "Talk to KITT")
                            }.font(.system(size: 13, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(red.opacity(kit.activity == .listening ? 0.65 : 1)).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).disabled((kit.busy && kit.activity != .listening) || !kit.connected)
                        Button { kit.stop() } label: { Image(systemName: "stop.fill").font(.system(size: 13)).frame(width: 44, height: 42).background(Color(white: 0.14)).clipShape(RoundedRectangle(cornerRadius: 8)) }
                            .buttonStyle(.plain).disabled(!kit.busy).help("Stop · Escape").accessibilityLabel("Stop").keyboardShortcut(.cancelAction)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(kit.connected ? Color.green.opacity(0.75) : amber).frame(width: 5, height: 5)
                        Text(kit.connected ? "\(kit.model) · on this Mac" : "Local AI needs setup")
                            .font(.system(size: 9, design: .monospaced)).foregroundStyle(subdued)
                        Spacer()
                    }
                }.frame(maxWidth: .infinity).padding(.top, 7)
            }.padding(.horizontal, 30).padding(.top, 30).padding(.bottom, 28)
        }
        .frame(minWidth: 860, idealWidth: 920, maxWidth: .infinity, minHeight: 795, idealHeight: 795, maxHeight: .infinity)
        .background(LinearGradient(colors: [Color(white: 0.075), Color(white: 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(Color(white: 0.9)).preferredColorScheme(.dark)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if kit.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Image(systemName: "waveform").font(.system(size: 24, weight: .light)).foregroundStyle(red)
                            Text("Hello. My voice systems\nare at your disposal.").font(.system(size: 21, weight: .regular)).lineSpacing(5)
                            Text("Just speak. KITT replies after you pause, then listens again. AIR pauses or resumes hands-free conversation.")
                                .font(.system(size: 12)).foregroundStyle(subdued).lineSpacing(4)
                            Text("Try the voice demo to see the red voice box respond to speech.")
                                .font(.system(size: 11)).foregroundStyle(subdued).lineSpacing(3)
                        }.padding(.top, 37).padding(.horizontal, 18)
                    }
                    ForEach(kit.messages) { line in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(line.role == "user" ? "YOU" : "K.I.T.T.")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.8)
                                .foregroundStyle(line.role == "user" ? subdued : red)
                            Text(line.content).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                    }
                    if kit.activity == .thinking {
                        HStack(spacing: 8) { ProgressView().controlSize(.small); Text("One moment…").font(.system(size: 12)).foregroundStyle(subdued) }.padding(.horizontal, 16)
                    }
                    Color.clear.frame(height: 1).id("end")
                }.padding(.vertical, 14)
            }
            .onChange(of: kit.messages.count) { proxy.scrollTo("end", anchor: .bottom) }
            .onChange(of: kit.activity) { proxy.scrollTo("end", anchor: .bottom) }
        }
        .frame(minHeight: 245, maxHeight: .infinity)
        .background(Color.black.opacity(0.16)).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.15), lineWidth: 1))
    }
}

struct SettingsView: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack { Text("Voice & local intelligence").font(.system(size: 22, weight: .medium)); Spacer(); Button("Done") { kit.closeSettings() }.keyboardShortcut(.defaultAction) }
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
            Text("Local AI and local voices are free. Fish KITT voice is optional.").font(.system(size: 12)).foregroundStyle(.secondary)
            GroupBox("Hands-free conversation") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Listen and reply automatically", isOn: Binding(get: { kit.handsFreeEnabled }, set: { kit.setHandsFree($0) }))
                    HStack {
                        Text("Reply after a pause")
                        Slider(value: $kit.replyPause, in: 0.9...3, step: 0.1)
                        Text(String(format: "%.1f s", kit.replyPause)).monospacedDigit().frame(width: 45)
                    }
                    Text("The microphone pauses during KITT's replies and while these settings are open. AIR toggles listening; P2 stops speech and pauses listening.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Text(kit.status).font(.system(size: 10, design: .monospaced)).foregroundStyle(amber)
                    Toggle("Show only the voice box", isOn: $kit.compactMode)
                    HStack { Button("KITT sayings") { kit.showSettings = false; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { kit.showSayings = true } }; Button("New conversation") { kit.clear() } }
                }.padding(10)
            }
            GroupBox("Intelligence") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Local model"); Spacer(); if kit.models.isEmpty { Text("No downloaded model").foregroundStyle(.secondary) } else { Picker("Local model", selection: $kit.model) { ForEach(kit.models, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 235) } }
                    HStack { Button(kit.checking ? "Checking…" : "Refresh connection") { Task { await kit.refresh() } }.disabled(kit.checking); Button("Set up free AI") { kit.setup() }.disabled(kit.settingUp); Link("Get Ollama", destination: URL(string: "https://ollama.com/download/mac")!) }
                    Text("Setup starts installed Ollama and, if needed, downloads a model of about 2 GB. AI conversation uses only 127.0.0.1 on this Mac; cloud models are excluded.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(10)
            }
            GroupBox("Speech") {
                VStack(spacing: 15) {
                    HStack { Text("Voice"); Spacer(); Picker("Voice", selection: $kit.voice) { ForEach(kit.voices, id: \.self) { Text($0).tag($0) } }.labelsHidden().frame(width: 280) }
                    HStack { Text("Speed").frame(width: 60, alignment: .leading); Slider(value: $kit.rate, in: 120...230, step: 5); Text("\(Int(kit.rate)) wpm").monospacedDigit().frame(width: 65) }
                    HStack { Text("Volume").frame(width: 60, alignment: .leading); Slider(value: $kit.volume, in: 0...1); Text("\(Int(kit.volume * 100))%").monospacedDigit().frame(width: 65) }
                    HStack { Button("Test voice & LEDs") { kit.persist(); kit.demo() }; Spacer() }
                }.padding(10)
            }
            GroupBox("Fish Audio · linked KITT voice") {
                VStack(alignment: .leading, spacing: 10) {
                    SecureField("Fish Audio API key", text: $kit.fishKey).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Fish Audio API key")
                    HStack {
                        Button("Save in Keychain") { kit.saveFishKey() }.disabled(kit.fishKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Remove saved key") { kit.removeFishKey() }
                        Spacer()
                        Link("Get API key", destination: URL(string: "https://fish.audio/app/api-keys")!)
                    }
                    Button("Use & test Fish KITT voice") { kit.voice = FishVoice.name; kit.persist(); kit.demo() }
                        .disabled(kit.fishKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Text("Only s2.1-pro-free is used. Fish currently offers it free through 30 Nov 2026, subject to fair use. Reply text goes to Fish Audio and may be used to improve its models. Local Kokoro and Mac voices stay on this Mac. Keys remain in memory unless you choose Save in Keychain.")
                        .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if let status = kit.keyNotice { Text(status).font(.system(size: 10)).foregroundStyle(.secondary) }
                }.padding(10)
            }
            Text("Kokoro provides natural local voices; Mac voices are also available. Fish uses the KITT character model you linked. All speech is AI-generated. Voice input requires on-device Apple speech recognition and microphone permission; you can always type.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
            Text("AIR Pause/resume listening · P1 Demo · P2 Stop\nP3 Settings · P4 Replay\nCruise/Pursuit buttons change the conversation style. OIL = local AI, S1 = speech, S2 = thinking.")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineSpacing(5)
            if let notice = kit.notice { Text(notice).font(.system(size: 11)).foregroundStyle(amber).fixedSize(horizontal: false, vertical: true) }
            }.padding(.trailing, 5)
            }
        }.padding(24).frame(width: 565, height: 705).preferredColorScheme(.dark)
            .onExitCommand { kit.closeSettings() }
            .onDisappear { kit.persist() }
    }
}

struct SayingsView: View {
    @ObservedObject var kit: KITTController
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Text("KITT sayings").font(.system(size: 24, weight: .medium)); Spacer(); Button("Done") { kit.showSayings = false }.keyboardShortcut(.defaultAction) }
            Text("Tap a line to hear it through the selected voice and red voice box.").font(.system(size: 12)).foregroundStyle(.secondary)
            ForEach([true, false], id: \.self) { classic in
                Text(classic ? "CLASSIC SHORT PHRASES" : "ORIGINAL KITT-INSPIRED QUIPS")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.6).foregroundStyle(amber).padding(.top, 7)
                ForEach(KITTSaying.all.filter { $0.classic == classic }) { saying in
                    Button { kit.say(saying) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.circle.fill").foregroundStyle(red)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(saying.title).font(.system(size: 12, weight: .medium))
                                Text(saying.text).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                            }
                            Spacer()
                        }.padding(10).background(Color.white.opacity(0.04)).clipShape(RoundedRectangle(cornerRadius: 7))
                    }.buttonStyle(.plain)
                }
            }
            HStack { Text(kit.voice).font(.system(size: 10)).foregroundStyle(.secondary); Spacer(); Button("Stop") { kit.stop() }.keyboardShortcut(.cancelAction) }
            if let notice = kit.notice { Text(notice).font(.system(size: 10)).foregroundStyle(amber) }
        }.padding(25).frame(width: 575).preferredColorScheme(.dark)
    }
}
