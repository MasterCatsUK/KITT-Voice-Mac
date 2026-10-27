import Foundation
import AVFoundation
import Speech

struct VoiceLevels {
    var left: Double = 0
    var center: Double = 0
    var right: Double = 0
    static let silent = VoiceLevels()
}

// Measure the sound that is actually being played. The outside stacks move
// together at the same height; the centre stack is taller, as on KITT's voice box.
struct VoiceEnvelope {
    let frames: [VoiceLevels]
    let step: Double = 1.0 / 30.0

    init(url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let count = AVAudioFrameCount(file.length)
        guard count > 0 else { throw AppFailure.message("macOS did not produce any speech audio. Try another voice in Settings.") }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else {
            throw AppFailure.message("Could not read the speech audio.")
        }
        try file.read(into: buffer)
        guard let samples = buffer.floatChannelData?[0] else {
            throw AppFailure.message("The speech audio has an unsupported format.")
        }
        let rate = format.sampleRate
        let window = max(1, Int(rate / 30))
        var result: [VoiceLevels] = []
        for start in stride(from: 0, to: Int(buffer.frameLength), by: window) {
            var power = 0.0
            let end = min(start + window, Int(buffer.frameLength))
            for i in start..<end {
                let sample = Double(samples[i])
                power += sample * sample
            }
            let n = Double(end - start)
            func level(_ power: Double, gain: Double) -> Double {
                let rms = sqrt(power / n) * gain
                if rms < 0.002 { return 0 }
                return min(1, max(0, (20 * log10(rms) + 48) / 43))
            }
            let center = level(power, gain: 1.2)
            let side = center * 0.8
            result.append(VoiceLevels(left: side, center: center, right: side))
        }
        frames = result
    }

    func at(_ time: Double) -> VoiceLevels {
        let index = Int(max(0, time) / step)
        return index < frames.count ? frames[index] : .silent
    }
}

@MainActor
final class VoiceOutput: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var envelope: VoiceEnvelope?
    private var timer: Timer?
    private var process: Process?
    private var cloudTask: Task<Void, Never>?
    private var generation = UUID()
    private var temporaryURL: URL?
    var onLevels: ((VoiceLevels) -> Void)?
    var onFinished: (() -> Void)?
    var onError: ((String) -> Void)?
    var fishKey = ""
    var volume: Float = 0.8 { didSet { player?.volume = volume } }

    func speak(_ text: String, voice: String, rate: Int) {
        stop()
        let token = generation
        let neuralID = LocalVoices.id(for: voice)
        let isFish = voice == FishVoice.name
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("KITT-\(UUID().uuidString).\(neuralID != nil || isFish ? "wav" : "aiff")")
        temporaryURL = url
        if isFish {
            let key = fishKey
            cloudTask = Task {
                do {
                    let data = try await FishVoice.render(text, key: key, speed: Double(rate) / 170)
                    guard !Task.isCancelled, self.generation == token else { return }
                    try data.write(to: url)
                    try self.play(url)
                } catch {
                    guard !Task.isCancelled, self.generation == token else { return }
                    self.cleanup()
                    self.onError?(error.localizedDescription)
                }
            }
            return
        }
        let task = Process()
        let stdin = Pipe()
        task.standardInput = stdin
        var payload: Data
        if let neuralID {
            guard LocalVoices.available else { cleanup(); onError?("Keep VoiceEngine beside the app, or choose a Mac voice."); return }
            task.executableURL = LocalVoices.python
            task.arguments = [LocalVoices.root.appendingPathComponent("speak.py").path]
            payload = (try? JSONSerialization.data(withJSONObject: ["text": text, "voice": neuralID,
                "speed": Double(rate) / 170, "output": url.path] as [String: Any])) ?? Data()
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            task.arguments = ["-v", voice, "-r", String(rate), "-o", url.path, "-f", "-"]
            payload = Data(text.utf8)
        }
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.terminationHandler = { [weak self] task in
            Task { @MainActor in
                guard let self, self.generation == token else {
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                self.process = nil
                guard task.terminationStatus == 0 else {
                    self.cleanup()
                    self.onError?("The selected voice could not speak. Check the voice engine folder or choose another voice.")
                    return
                }
                do { try self.play(url) }
                catch { self.cleanup(); self.onError?(error.localizedDescription) }
            }
        }
        process = task
        do {
            try task.run()
            try stdin.fileHandleForWriting.write(contentsOf: payload)
            try stdin.fileHandleForWriting.close()
        }
        catch { process = nil; cleanup(); onError?(error.localizedDescription) }
    }

    private func play(_ url: URL) throws {
        envelope = try VoiceEnvelope(url: url)
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.volume = volume
        guard player?.play() == true else { throw AppFailure.message("The audio output could not start.") }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.onLevels?(self.envelope?.at(player.currentTime) ?? .silent)
            }
        }
    }

    func stop() {
        generation = UUID()
        cloudTask?.cancel(); cloudTask = nil
        process?.terminationHandler = nil
        if process?.isRunning == true { process?.terminate() }
        process = nil
        player?.stop()
        player = nil
        cleanup()
    }

    private func cleanup() {
        timer?.invalidate(); timer = nil
        envelope = nil
        onLevels?(.silent)
        if let url = temporaryURL { try? FileManager.default.removeItem(at: url) }
        temporaryURL = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.player = nil
            self.cleanup()
            if flag { self.onFinished?() }
            else { self.onError?("Audio playback was interrupted.") }
        }
    }
}

@MainActor
final class VoiceInput {
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var hasTap = false
    private var finishing: ((String) -> Void)?
    private var token = UUID()
    private var text = ""
    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onEnded: ((String) -> Void)?
    var onAudioLevel: ((Double, TimeInterval) -> Void)?

    func start() async throws {
        cancel()
        let generation = token
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        guard generation == token else { throw CancellationError() }
        guard microphone else { throw AppFailure.message("Allow KITT Voice microphone access in System Settings → Privacy & Security → Microphone. You can also type a message.") }
        let permission = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard generation == token else { throw CancellationError() }
        guard permission == .authorized else {
            throw AppFailure.message("Allow speech recognition in System Settings → Privacy & Security → Speech Recognition, or type a message.")
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB")),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw AppFailure.message("On-device speech recognition is unavailable on this Mac. Type your message instead; replies still speak aloud.")
        }
        self.recognizer = recognizer
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        self.request = request
        text = ""
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self, self.token == generation else { return }
                if let result {
                    self.text = result.bestTranscription.formattedString
                    self.onText?(self.text)
                }
                if result?.isFinal == true {
                    self.finishRecognition()
                } else if let error {
                    if self.finishing != nil { self.finishRecognition() }
                    else if !self.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { self.finishRecognition() }
                    else { self.cancel(); self.onError?(error.localizedDescription) }
                }
            }
        }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            cancel(); throw AppFailure.message("No microphone is available. Connect one or type your message.")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
                var sum = 0.0
                for index in 0..<Int(buffer.frameLength) { let value = Double(samples[index]); sum += value * value }
                let rms = sqrt(sum / Double(buffer.frameLength))
                let time = ProcessInfo.processInfo.systemUptime
                Task { @MainActor in
                    guard let self, self.token == generation else { return }
                    self.onAudioLevel?(rms, time)
                }
            }
        }
        hasTap = true
        engine.prepare()
        do { try engine.start() } catch { cancel(); throw error }
    }

    func finish(_ completion: @escaping (String) -> Void) {
        finishing = completion
        endCapture()
        request?.endAudio()
        let generation = token
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard self.token == generation, self.finishing != nil else { return }
            self.finishRecognition()
        }
    }

    private func finishRecognition() {
        let callback = finishing
        let finalText = text
        cancel()
        if let callback { callback(finalText) }
        else { onEnded?(finalText) }
    }

    private func endCapture() {
        engine.stop()
        if hasTap { engine.inputNode.removeTap(onBus: 0); hasTap = false }
    }

    func cancel() {
        token = UUID()
        finishing = nil
        endCapture()
        request?.endAudio(); request = nil
        task?.cancel(); task = nil
        recognizer = nil
    }
}
