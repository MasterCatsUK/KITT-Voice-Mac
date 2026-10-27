import Foundation

// Uses both recognised words and microphone energy. Background noise alone
// cannot submit a turn, and a pause inside a spoken phrase keeps the turn open.
struct ConversationTurn {
    private(set) var transcript = ""
    private var lastWords: TimeInterval?
    private var lastVoice: TimeInterval?
    private var noiseFloor = 0.002
    var pause: TimeInterval = 1.5

    mutating func heard(_ text: String, at time: TimeInterval) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text != transcript else { return }
        transcript = text
        lastWords = time
    }

    mutating func observe(rms: Double, at time: TimeInterval) {
        guard rms.isFinite else { return }
        if transcript.isEmpty {
            noiseFloor = min(0.02, max(0.0005, noiseFloor * 0.94 + rms * 0.06))
        }
        if rms > max(0.005, noiseFloor * 3) { lastVoice = time }
    }

    func isFinished(at time: TimeInterval) -> Bool {
        guard let words = lastWords, !transcript.isEmpty else { return false }
        return time - max(words, lastVoice ?? words) >= pause
    }
}
