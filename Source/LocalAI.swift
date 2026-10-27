import Foundation

enum AppFailure: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

struct ChatLine: Identifiable, Codable {
    var id = UUID()
    let role: String
    var content: String
    enum CodingKeys: String, CodingKey { case role, content }
}

struct InstalledModel: Decodable {
    let name: String
    let size: Int64?
    // A cloud alias must never be silently selected for the local-only app.
    var isLocal: Bool { !name.lowercased().contains(":cloud") && !name.lowercased().hasSuffix("-cloud") }
}

struct LocalAI {
    static let base = URL(string: "http://127.0.0.1:11434")!
    static let recommended = "llama3.2:3b"

    static func models() async throws -> [InstalledModel] {
        var request = URLRequest(url: base.appendingPathComponent("api/tags"))
        request.timeoutInterval = 4
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(data, response)
        struct List: Decodable { let models: [InstalledModel] }
        return try JSONDecoder().decode(List.self, from: data).models.filter(\.isLocal)
    }

    static func answer(model: String, messages: [ChatLine], mode: String) async throws -> String {
        guard !model.isEmpty, InstalledModel(name: model, size: nil).isLocal else {
            throw AppFailure.message("Select a downloaded local model in Settings.")
        }
        let style = mode == "PURSUIT" ? "Be energetic, decisive, and concise." : mode == "AUTO CRUISE" ? "Be gentle and relaxed." : "Be composed and precise."
        let clock = DateFormatter()
        clock.locale = Locale(identifier: "en_GB")
        clock.dateFormat = "EEEE, d MMMM yyyy, HH:mm:ss zzz"
        let system = """
        You are KITT, a friendly fictional talking-car-inspired AI companion running on the user's Mac.
        Your chosen name is KITT. When introducing yourself, say 'I am KITT, your personal AI companion.'
        Introduce yourself only when asked, not at the start of every reply.
        The user's Mac clock for this turn is \(clock.string(from: Date())). Use this value for time and date questions; do not invent another time.
        Speak in a calm, intelligent, polite style with occasional dry wit. \(style)
        Occasionally use brief expressions such as 'Of course' or 'I must protest' when natural.
        Be warmly confident, with restrained humour, rather than giving generic AI disclaimers.
        Answer the user's actual question helpfully in one to four short sentences, unless they request detail.
        You are an AI, not the original television character or actor. Never claim to control a real car,
        files, apps, or devices. You have no tools, live internet access, or knowledge of the user's surroundings.
        Do not claim to have performed actions. Use plain spoken English with no markdown or stage directions.
        """
        let history = messages.suffix(16).map { ["role": $0.role, "content": $0.content] }
        let body: [String: Any] = ["model": model,
            "messages": [["role": "system", "content": system]] + history,
            "stream": false, "keep_alive": "10m",
            "options": ["temperature": 0.7, "num_predict": 350, "num_ctx": 4096]]
        var request = URLRequest(url: base.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 180
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Task.checkCancellation()
        try validate(data, response)
        struct Reply: Decodable { struct Message: Decodable { let content: String }; let message: Message }
        let reply = try JSONDecoder().decode(Reply.self, from: data).message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reply.isEmpty else { throw AppFailure.message("The model returned an empty reply. Try another local model.") }
        return reply
    }

    static func validate(_ data: Data, _ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw AppFailure.message("No response from local AI.") }
        guard (200..<300).contains(http.statusCode) else {
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            throw AppFailure.message(object?["error"] as? String ?? "Local AI returned error \(http.statusCode).")
        }
    }
}
