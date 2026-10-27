import AppKit
import AVFoundation
import SwiftUI

@MainActor
final class KITTController: ObservableObject {
    enum Activity { case idle, preparingMic, listening, finishing, thinking, speaking }
    @Published var activity: Activity = .idle
    @Published var levels = VoiceLevels.silent
    @Published var draft = ""
    @Published var messages: [ChatLine] = []
    @Published var notice: String?
    @Published var models: [String] = []
    @Published var connected = false
    @Published var checking = false
    @Published var settingUp = false
    @Published var showSettings = false {
        didSet { if showSettings { suspendCapture() } else { scheduleListening() } }
    }
    @Published var showSayings = false {
        didSet { if showSayings { suspendCapture() } else { scheduleListening() } }
    }
    @Published private(set) var handsFreeEnabled = UserDefaults.standard.object(forKey: "handsFree") as? Bool ?? true
    @Published var compactMode = UserDefaults.standard.object(forKey: "compactMode") as? Bool ?? true {
        didSet { UserDefaults.standard.set(compactMode, forKey: "compactMode") }
    }
    @Published var replyPause = UserDefaults.standard.object(forKey: "replyPause") as? Double ?? 1.5 {
        didSet { turn.pause = replyPause; UserDefaults.standard.set(replyPause, forKey: "replyPause") }
    }
    @Published var fishKey = ""
    @Published var keyNotice: String?
    @Published var mode = "NORMAL CRUISE"
    @Published var model: String = UserDefaults.standard.string(forKey: "model") ?? LocalAI.recommended
    @Published var voice: String = UserDefaults.standard.string(forKey: "voice") ?? (LocalVoices.available ? LocalVoices.names[0] : "Reed (English (US))")
    @Published var rate: Double = UserDefaults.standard.object(forKey: "rate") as? Double ?? 170
    @Published var volume: Double = UserDefaults.standard.object(forKey: "volume") as? Double ?? 0.8 {
        didSet { output.volume = Float(volume); UserDefaults.standard.set(volume, forKey: "volume") }
    }
    let output = VoiceOutput()
    let input = VoiceInput()
    private var pending: Task<Void, Never>?
    private var service: Process?
    private var operation = UUID()
    private var silenceTimer: Timer?
    private var resumeTask: Task<Void, Never>?
    private var turn = ConversationTurn()
    private var listeningSince: TimeInterval = 0
    private var failedInputSessions = 0
    private var shuttingDown = false
    private let savesPreferences: Bool
    let demoText = "Hello. I am KITT, your personal AI companion. My voice systems are operational. I must say, this Mac is rather more comfortable than a dashboard."

    var busy: Bool { activity != .idle }
    var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && activity == .idle && connected }
    var status: String {
        switch activity {
        case .preparingMic: return "OPENING MICROPHONE"
        case .listening: return "LISTENING TO YOU"
        case .finishing: return "FINISHING YOUR MESSAGE"
        case .thinking: return "PROCESSING"
        case .speaking: return "VOICE SYSTEM ACTIVE"
        case .idle: return handsFreeEnabled && connected ? "HANDS-FREE STANDBY" : connected ? "LISTENING PAUSED" : "VOICE SYSTEM STANDBY"
        }
    }

    lazy var voices: [String] = {
        let names = NSSpeechSynthesizer.availableVoices.compactMap { id -> String? in
            let attributes = NSSpeechSynthesizer.attributes(forVoice: id)
            let locale = attributes[.localeIdentifier] as? String ?? ""
            guard locale.hasPrefix("en") else { return nil }
            return attributes[.name] as? String
        }
        return (LocalVoices.available ? LocalVoices.names : []) + [FishVoice.name] + Array(Set(names + (LocalVoices.id(for: voice) == nil && voice != FishVoice.name ? [voice] : []))).sorted()
    }()

    init(preview: Bool = false) {
        savesPreferences = !preview
        // Carry the current conversation through this update once, without
        // adding ongoing chat storage. The temporary handoff is then removed.
        let handoff = FileManager.default.temporaryDirectory.appendingPathComponent("KITT-Voice-Update-Session.json")
        if !preview, let data = try? Data(contentsOf: handoff),
           let restored = try? JSONDecoder().decode([ChatLine].self, from: data) {
            messages = restored
            try? FileManager.default.removeItem(at: handoff)
        }
        output.volume = Float(volume)
        fishKey = preview ? "" : FishCredentials.read()
        output.onLevels = { [weak self] in self?.levels = $0 }
        output.onFinished = { [weak self] in
            self?.activity = .idle
            self?.scheduleListening()
        }
        output.onError = { [weak self] in self?.pauseForError($0) }
        input.onText = { [weak self] text in
            guard let self else { return }
            self.draft = text
            self.turn.heard(text, at: ProcessInfo.processInfo.systemUptime)
            if !text.isEmpty { self.failedInputSessions = 0 }
        }
        input.onAudioLevel = { [weak self] rms, time in
            guard let self, self.activity == .listening else { return }
            self.turn.observe(rms: rms, at: time)
        }
        input.onEnded = { [weak self] text in
            guard let self, self.activity == .listening || self.activity == .preparingMic else { return }
            self.silenceTimer?.invalidate(); self.silenceTimer = nil
            self.activity = .idle
            self.draft = text
            if self.handsFreeEnabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.send() }
            else { self.scheduleListening() }
        }
        input.onError = { [weak self] in
            guard let self else { return }
            self.silenceTimer?.invalidate(); self.silenceTimer = nil
            self.activity = .idle
            self.failedInputSessions += 1
            if self.handsFreeEnabled, self.failedInputSessions < 3 {
                self.scheduleListening()
            } else { self.pauseForError($0) }
        }
        if !preview {
            Task {
                await refresh()
                if !connected { setup() }
            }
        }
    }

    func persist() {
        guard savesPreferences else { return }
        UserDefaults.standard.set(model, forKey: "model")
        UserDefaults.standard.set(voice, forKey: "voice")
        UserDefaults.standard.set(rate, forKey: "rate")
        UserDefaults.standard.set(handsFreeEnabled, forKey: "handsFree")
        UserDefaults.standard.set(compactMode, forKey: "compactMode")
    }

    func setHandsFree(_ enabled: Bool) {
        handsFreeEnabled = enabled
        failedInputSessions = 0
        persist()
        if enabled { notice = nil; scheduleListening() }
        else { resumeTask?.cancel(); resumeTask = nil; suspendCapture() }
    }

    func toggleHandsFree() { setHandsFree(!handsFreeEnabled) }

    func closeSettings() {
        persist()
        showSettings = false
    }

    private func suspendCapture() {
        guard activity == .listening || activity == .preparingMic || activity == .finishing else { return }
        operation = UUID()
        pending?.cancel(); pending = nil
        input.cancel()
        silenceTimer?.invalidate(); silenceTimer = nil
        activity = .idle
    }

    private func scheduleListening() {
        resumeTask?.cancel(); resumeTask = nil
        guard handsFreeEnabled, connected, !settingUp, !shuttingDown,
              !showSettings, !showSayings, activity == .idle else { return }
        if voice == FishVoice.name, fishKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notice = "Add your Fish Audio key to resume hands-free replies, or select a local voice."
            return
        }
        resumeTask = Task { @MainActor [weak self] in
            // Leave time for the loudspeaker's last sound to decay before listening.
            do { try await Task.sleep(nanoseconds: 800_000_000) } catch { return }
            guard let self, self.handsFreeEnabled, !self.showSettings, !self.showSayings,
                  !self.shuttingDown, self.activity == .idle else { return }
            self.talk()
        }
    }

    private func pauseForError(_ message: String) {
        cancelCurrent()
        handsFreeEnabled = false
        persist()
        notice = message
        if compactMode, !showSayings { showSettings = true }
    }

    func saveFishKey() {
        do { try FishCredentials.save(fishKey); keyNotice = "Saved in this Mac's Keychain." }
        catch { keyNotice = error.localizedDescription }
    }

    func removeFishKey() {
        do { try FishCredentials.remove(); fishKey = ""; keyNotice = "Key removed." }
        catch { keyNotice = error.localizedDescription }
    }

    private func speak(_ text: String) {
        resumeTask?.cancel(); resumeTask = nil
        input.cancel()
        silenceTimer?.invalidate(); silenceTimer = nil
        if voice == FishVoice.name, fishKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activity = .idle
            notice = "Add your Fish Audio API key in Settings, or select a local Kokoro voice."
            showSettings = true
            return
        }
        activity = .speaking
        output.fishKey = fishKey.trimmingCharacters(in: .whitespacesAndNewlines)
        output.speak(text, voice: voice, rate: Int(rate))
    }

    func say(_ saying: KITTSaying) {
        cancelCurrent()
        notice = saying.classic ? "Classic short phrase · AI-generated voice" : "Original KITT-inspired phrase · AI-generated voice"
        speak(saying.text)
    }

    func refresh() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        do {
            let available = try await LocalAI.models()
            models = available.map(\.name).sorted()
            connected = !models.isEmpty
            if !models.contains(model), let first = models.first { model = first; persist() }
            if models.isEmpty { notice = "Ollama is running. Set up a local model to enable AI replies." }
            else if !busy { notice = nil }
            scheduleListening()
        } catch {
            connected = false
            notice = "Local AI is offline. Click Set up free AI to start Ollama. The voice demo works now."
        }
    }

    private var ollamaBinary: String? {
        ["/opt/homebrew/bin/ollama", "/usr/local/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"].first {
            FileManager.default.isExecutableFile(atPath: $0)
        }
    }

    func setup() {
        guard !settingUp else { return }
        settingUp = true
        notice = "Connecting to local AI…"
        Task {
            defer { settingUp = false; scheduleListening() }
            do {
                var available: [InstalledModel]
                do { available = try await LocalAI.models() }
                catch {
                    guard let binary = ollamaBinary else {
                        throw AppFailure.message("Install Ollama from ollama.com, then click Set up free AI. No API key or subscription is needed.")
                    }
                    if service?.isRunning != true {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: binary)
                        process.arguments = ["serve"]
                        process.standardOutput = FileHandle.nullDevice
                        process.standardError = FileHandle.nullDevice
                        try process.run()
                        service = process
                    }
                    var found: [InstalledModel]?
                    for _ in 0..<15 {
                        try await Task.sleep(nanoseconds: 500_000_000)
                        if let list = try? await LocalAI.models() { found = list; break }
                    }
                    guard let found else { throw AppFailure.message("Ollama did not start. Open Ollama, then try again.") }
                    available = found
                }
                if available.isEmpty {
                    notice = "Downloading a free local model (about 2 GB). This is needed only once…"
                    var request = URLRequest(url: LocalAI.base.appendingPathComponent("api/pull"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 3600
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["name": LocalAI.recommended, "stream": false] as [String: Any])
                    let (data, response) = try await URLSession.shared.data(for: request)
                    try LocalAI.validate(data, response)
                }
                await refresh()
            } catch { notice = error.localizedDescription; if compactMode { showSettings = true } }
        }
    }

    func send() {
        guard canSend else { return }
        resumeTask?.cancel(); resumeTask = nil
        input.cancel()
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        notice = nil
        messages.append(ChatLine(role: "user", content: text))
        activity = .thinking
        let token = UUID(); operation = token
        let history = messages
        pending = Task { [self] in
            do {
                let reply = try await LocalAI.answer(model: model, messages: history, mode: mode)
                guard !Task.isCancelled, operation == token else { return }
                messages.append(ChatLine(role: "assistant", content: reply))
                speak(reply)
            } catch {
                guard !Task.isCancelled, operation == token else { return }
                activity = .idle
                draft = text
                if messages.last?.role == "user" { messages.removeLast() }
                pauseForError("Could not get a reply: \(error.localizedDescription)")
            }
        }
    }

    func talk() {
        if activity == .listening { finishTalking(); return }
        guard activity == .idle else { return }
        guard connected else { notice = "Set up free AI first, or try Voice demo."; return }
        notice = nil
        draft = ""
        turn = ConversationTurn()
        turn.pause = replyPause
        activity = .preparingMic
        let token = UUID(); operation = token
        pending = Task { [self] in
            do {
                try await input.start()
                guard !Task.isCancelled, operation == token else { input.cancel(); return }
                activity = .listening
                listeningSince = ProcessInfo.processInfo.systemUptime
                // Rotate recognition sessions, and automatically submit after a
                // spoken turn goes quiet. Empty rooms never create AI requests.
                silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, self.activity == .listening else { return }
                        let now = ProcessInfo.processInfo.systemUptime
                        if self.handsFreeEnabled, self.turn.isFinished(at: now) {
                            self.finishTalking()
                        } else if now - self.listeningSince >= 50 {
                            if !self.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.finishTalking() }
                            else {
                                self.input.cancel()
                                self.silenceTimer?.invalidate(); self.silenceTimer = nil
                                self.activity = .idle
                                self.scheduleListening()
                            }
                        }
                    }
                }
            } catch {
                guard operation == token, !Task.isCancelled else { return }
                input.cancel()
                pauseForError(error.localizedDescription)
            }
        }
    }

    func finishTalking() {
        guard activity == .listening else { return }
        silenceTimer?.invalidate(); silenceTimer = nil
        activity = .finishing
        input.finish { [weak self] text in
            guard let self else { return }
            self.activity = .idle
            self.draft = text
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if self.handsFreeEnabled { self.scheduleListening() }
                else { self.notice = "I did not catch that. Try again, or type your message." }
            } else { self.send() }
        }
    }

    func demo() {
        cancelCurrent()
        notice = "Voice demo · generated with the selected voice"
        speak(demoText)
    }

    func replay() {
        guard let text = messages.last(where: { $0.role == "assistant" })?.content else { demo(); return }
        cancelCurrent()
        speak(text)
    }

    func stop() {
        handsFreeEnabled = false
        persist()
        cancelCurrent()
    }

    private func cancelCurrent() {
        operation = UUID()
        resumeTask?.cancel(); resumeTask = nil
        pending?.cancel(); pending = nil
        silenceTimer?.invalidate(); silenceTimer = nil
        input.cancel(); output.stop()
        levels = .silent
        activity = .idle
    }

    func clear() { cancelCurrent(); messages.removeAll(); draft = ""; notice = nil; scheduleListening() }
    func shutdown() { shuttingDown = true; cancelCurrent(); if service?.isRunning == true { service?.terminate() } }
}
