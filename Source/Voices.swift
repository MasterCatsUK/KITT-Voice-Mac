import Foundation
import Security

enum LocalVoices {
    static let names = ["Kokoro · Michael (US)", "Kokoro · Fenrir (US)", "Kokoro · Puck (US)",
                        "Kokoro · Onyx (US)", "Kokoro · George (UK)", "Kokoro · Heart (US)"]
    static let ids = ["am_michael", "am_fenrir", "am_puck", "am_onyx", "bm_george", "af_heart"]
    static let root = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("VoiceEngine")
    static var python: URL { root.appendingPathComponent(".venv/bin/python") }
    static var available: Bool {
        FileManager.default.isExecutableFile(atPath: python.path) &&
        FileManager.default.fileExists(atPath: root.appendingPathComponent("models/kokoro-v1.0.onnx").path) &&
        FileManager.default.fileExists(atPath: root.appendingPathComponent("models/voices-v1.0.bin").path)
    }
    static func id(for name: String) -> String? {
        guard let index = names.firstIndex(of: name) else { return nil }
        return ids[index]
    }
}

enum FishVoice {
    static let name = "Fish Audio · KITT (online)"
    static let referenceID = "eaa8a416bfcd4a38b3e3fa94ad934225"
    static let model = "s2.1-pro-free"
    static let freeUntil = DateComponents(calendar: Calendar(identifier: .gregorian),
        timeZone: TimeZone(secondsFromGMT: 0), year: 2026, month: 12, day: 1).date!

    static func render(_ text: String, key: String, speed: Double) async throws -> Data {
        guard Date() < freeUntil else {
            throw AppFailure.message("Fish's announced free period ended on 30 November 2026. Select a local voice; this app will not switch to a paid model.")
        }
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppFailure.message("Add your Fish Audio API key in Settings, or select a free local voice.")
        }
        var request = URLRequest(url: URL(string: "https://api.fish.audio/v1/tts")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(model, forHTTPHeaderField: "model")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "text": text, "reference_id": referenceID, "format": "wav",
            "sample_rate": 24000, "prosody": ["speed": speed],
            "temperature": 0.6, "top_p": 0.7] as [String: Any])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw AppFailure.message("No response from Fish Audio.") }
        guard (200..<300).contains(http.statusCode) else {
            switch http.statusCode {
            case 401, 403: throw AppFailure.message("Fish Audio rejected the key or voice access. Check your API key in Settings.")
            case 402: throw AppFailure.message("Fish Audio did not allow free generation for this account. Select a local voice to keep using KITT for free.")
            case 429: throw AppFailure.message("Fish Audio is limiting free requests. Try again later or select a local voice.")
            default: throw AppFailure.message("Fish Audio returned error \(http.statusCode). Select a local voice or try again later.")
            }
        }
        guard data.count > 44, String(data: data.prefix(4), encoding: .ascii) == "RIFF" else {
            throw AppFailure.message("Fish Audio returned an unexpected audio format.")
        }
        return data
    }
}

enum FishCredentials {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "local.kitt.voice.fish-audio",
         kSecAttrAccount as String: "api-key"]
    }
    static func read() -> String {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ key: String) throws {
        let data = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AppFailure.message("The key could not be saved in Keychain (\(status)). You can still use it for this session.") }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppFailure.message("The saved key could not be removed (\(status)).")
        }
    }
}

struct KITTSaying: Identifiable {
    let id: Int
    let title: String
    let text: String
    let classic: Bool
    static let all: [KITTSaying] = [
        .init(id: 0, title: "Of course", text: "But of course.", classic: true),
        .init(id: 1, title: "Pardon?", text: "I beg your pardon?", classic: true),
        .init(id: 2, title: "Concerned", text: "Michael, what are you doing?", classic: true),
        .init(id: 3, title: "Oh, dear", text: "Oh, dear.", classic: true),
        .init(id: 4, title: "Hello", text: "Hello. I am Kitt, your personal AI companion. How may I assist you?", classic: false),
        .init(id: 5, title: "A little caution", text: "A little caution would be an excellent addition to that plan.", classic: false),
        .init(id: 6, title: "Dry humour", text: "I admire your confidence. I would admire a backup plan even more.", classic: false),
        .init(id: 7, title: "Ready", text: "My conversational systems are ready. Your next brilliant idea is the only thing missing.", classic: false),
        .init(id: 8, title: "Reassurance", text: "Let us take this one step at a time. Even a complicated problem deserves a calm approach.", classic: false),
        .init(id: 9, title: "Mac life", text: "I must admit, living in a Mac has its advantages. The parking is considerably easier.", classic: false)
    ]
}
