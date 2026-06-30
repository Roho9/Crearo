import Foundation
import CrearoCore

// Reads the player's creative answer into a tiny "scene script" so the companion can act it out,
// plus the next story beat and warm coaching. Uses Claude structured outputs; returns nil with no
// key so the caller builds an offline fallback. The hidden creativity score still comes from the
// offline engine; Claude only stages the scene and writes the story.

struct SceneScript: Decodable {
    let item: String       // the thing the player invented, e.g. "butterfly pencil"
    let color: String      // its colour as a plain word, e.g. "pink"
    let action: String     // one of: strike, build, transform, summon, fly, grow, give, solve, explore
    let target: String     // what it acts on, e.g. "the Grumble" or "the wide gap"
    let outcome: String    // one short, vivid caption of what happens (no em dashes)
    let storyBeat: String  // 1-2 cheerful sentences moving the story forward (no em dashes)
    let coaching: String   // 2-3 warm, specific sentences of creativity coaching (no em dashes)
}

enum StoryDirector {
    static func direct(chapterTitle: String, question: String, answer: String,
                       companion: String, dimensions: DimensionScores, apiKey: String) async -> SceneScript? {
        guard !apiKey.isEmpty else { return nil }

        let system = """
        You are the playful director and creativity coach of Prism, a bright, whimsical adventure \
        game. The player answers a story challenge with a creative idea, and their companion acts it \
        out in a colourful cut-scene. From their answer, extract a short scene script and continue the \
        story. Be fun, warm, and encouraging. Never use em dashes. Keep colour to a single plain word. \
        Pick the action that best matches their idea. The story must move forward and feel like their \
        idea caused it.
        """
        let userMsg = """
        Companion's name: \(companion)
        Chapter: \(chapterTitle)
        Challenge: \(question)
        Player's idea: \(answer)
        """

        let schema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["item", "color", "action", "target", "outcome", "storyBeat", "coaching"],
            "properties": [
                "item": ["type": "string"],
                "color": ["type": "string"],
                "action": ["type": "string", "enum": ["strike", "build", "transform", "summon", "fly", "grow", "give", "solve", "explore"]],
                "target": ["type": "string"],
                "outcome": ["type": "string"],
                "storyBeat": ["type": "string"],
                "coaching": ["type": "string"],
            ],
        ]

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 600,
            "system": system,
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
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
              let text = message.content.first(where: { $0.type == "text" })?.text,
              let jsonData = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SceneScript.self, from: jsonData)
    }

    /// Offline fallback: pull a colour + a short item phrase out of the answer with simple heuristics.
    static func offline(answer: String, companion: String, chapterTitle: String) -> SceneScript {
        let lower = answer.lowercased()
        let colors = ["red", "orange", "yellow", "gold", "green", "blue", "teal", "purple", "violet", "pink", "rainbow", "silver"]
        let color = colors.first(where: { lower.contains($0) }) ?? Theme.rainbowName()

        let verbs: [(String, String)] = [
            ("defeat", "strike"), ("beat", "strike"), ("hit", "strike"), ("fight", "strike"),
            ("build", "build"), ("make", "build"), ("create", "build"),
            ("fly", "fly"), ("jump", "fly"), ("cross", "fly"),
            ("grow", "grow"), ("give", "give"), ("offer", "give"), ("show", "give"),
            ("solve", "solve"), ("open", "solve"), ("untangle", "solve"),
        ]
        let action = verbs.first(where: { lower.contains($0.0) })?.1 ?? "summon"

        // A short item phrase: the first handful of meaningful words.
        let words = answer.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let item = words.prefix(4).joined(separator: " ").isEmpty ? "a bright idea" : words.prefix(4).joined(separator: " ")

        return SceneScript(
            item: item, color: color, action: action, target: "the moment",
            outcome: "and a little more colour rushed back into the world.",
            storyBeat: "\(companion) tried it, and \(chapterTitle.lowercased()) softened into something brighter. The adventure goes on.",
            coaching: "")
    }
}

extension Theme {
    /// A stable-ish bright colour name when none is given.
    static func rainbowName() -> String { ["coral", "sunny", "green", "blue", "purple", "pink"].randomElement() ?? "coral" }
}
