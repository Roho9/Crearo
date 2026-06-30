import Foundation
import CrearoCore

// Turns a daily answer + its hidden creativity score into warm, specific coaching via Claude.
// Returns nil if no API key is set, so the caller can fall back to the offline growth note.
// The hidden score still comes from the offline engine — Claude only writes the encouragement.
enum CreativityCoach {
    static func coach(prompt: String, answer: String, dimensions: DimensionScores, apiKey: String) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        // A compact read of the answer's creative shape, so the coach can be specific.
        func pct(_ x: Double) -> Int { Int((x * 100).rounded()) }
        let shape = """
        originality \(pct(dimensions.originality)), usefulness \(pct(dimensions.usefulness)), \
        elaboration \(pct(dimensions.elaboration)), flexibility \(pct(dimensions.flexibility)), \
        emotional \(pct(dimensions.emotionalExpression)), risk \(pct(dimensions.riskTaking))
        """

        let system = """
        You are a warm, sharp creativity coach in a daily self-improvement app. Given a creative \
        prompt, a person's answer, and a hidden creativity read, write 2-3 sentences of feedback: \
        first name one specific, genuine strength in what they wrote, then give ONE concrete nudge \
        to grow tomorrow. Be encouraging and concrete, never generic. No scores, no numbers, no \
        markdown, no preamble. Just the feedback.
        """
        let userMsg = """
        Prompt: \(prompt)

        Their answer: \(answer)

        Hidden creativity read (do not mention numbers): \(shape)
        """

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 400,
            "system": system,
            "messages": [["role": "user", "content": userMsg]],
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        req.httpBody = data

        guard let (respData, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }

        struct MessageResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        guard let message = try? JSONDecoder().decode(MessageResponse.self, from: respData),
              let text = message.content.first(where: { $0.type == "text" })?.text else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
