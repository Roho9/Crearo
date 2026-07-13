import Foundation
import CrearoCore

// Reads the player's answer into a "scene script" so the companion can act it out, continues the
// story, AND grades the idea against Crearo's hard creativity rubric. Uses Claude structured outputs;
// returns nil with no key so the caller falls back to the offline engine for both scene and score.

/// One flat object from Claude: the scene to animate, the story beat, coaching, and the rubric grades.
struct AIDirection: Decodable {
    let item: String       // the thing the player invented, e.g. "butterfly pencil"
    let color: String      // its colour as a plain word, e.g. "pink"
    let action: String     // one of the SceneAction cases
    let target: String     // what it acts on, e.g. "the Grumble" or "the wide gap"
    let outcome: String    // one short, vivid caption of what happens (no em dashes)
    let storyBeat: String  // 1-2 cheerful sentences moving the story forward (no em dashes)
    let coaching: String   // 2-3 warm, specific, honest sentences of coaching (no em dashes)
    let scores: RubricScores  // 0...1 per criterion, graded strictly
}

enum StoryDirector {
    static func direct(level: DailyChallenge, answer: String, companion: String, apiKey: String) async -> AIDirection? {
        guard !apiKey.isEmpty else { return nil }

        let system = """
        You are the director and creativity judge of Prism, a bright, whimsical puzzle game in the \
        spirit of Scribblenauts. The player is given a level with a goal and solves it by inventing \
        the thing that gets them through. You do two jobs.

        1) STAGE THE SCENE. From the player's idea, extract a short scene script so their companion \
        can act it out in a colourful pixel cut-scene, then write one or two cheerful sentences that \
        move the story forward (the story must feel caused by their idea), then two or three sentences \
        of warm but honest coaching. Keep colour to a single plain word. Pick the action that best \
        matches their idea.

        2) GRADE IT, STRICTLY. Score the idea from 0 to 1 on each rubric criterion. Be a demanding \
        judge: this game is meant to stretch adults, so ordinary or cliche answers must score low. \
        originality: how surprising and non-obvious it is (an obvious answer is 0.2 or less). \
        elaboration: how concrete and vivid the specifics are (vague ideas score low). \
        fit: how cleverly it actually solves THIS level's goal (off-topic or nonsense is near 0). \
        boldness: how far it dares to break convention. depth: metaphor, meaning, reframing. \
        delight: the spark of wonder or joy. Reserve scores above 0.85 for genuinely inventive work.

        Never use em dashes anywhere in your output.
        """
        let userMsg = """
        Companion's name: \(companion)
        Level: \(level.title)
        The scene: \(level.setup)
        The goal: \(level.goal)
        The ask: \(level.question)
        Player's idea: \(answer)
        """

        let unit: [String: Any] = ["type": "number", "minimum": 0, "maximum": 1]
        let schema: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "required": ["item", "color", "action", "target", "outcome", "storyBeat", "coaching", "scores"],
            "properties": [
                "item": ["type": "string"],
                "color": ["type": "string"],
                "action": ["type": "string", "enum": ["strike", "build", "transform", "summon", "fly", "grow", "give", "solve", "explore"]],
                "target": ["type": "string"],
                "outcome": ["type": "string"],
                "storyBeat": ["type": "string"],
                "coaching": ["type": "string"],
                "scores": [
                    "type": "object", "additionalProperties": false,
                    "required": ["originality", "elaboration", "fit", "boldness", "depth", "delight"],
                    "properties": [
                        "originality": unit, "elaboration": unit, "fit": unit,
                        "boldness": unit, "depth": unit, "delight": unit,
                    ],
                ],
            ],
        ]

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 700,
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
        return try? JSONDecoder().decode(AIDirection.self, from: jsonData)
    }

    /// Offline fallback scene: pull a colour + a short item phrase out of the answer with heuristics.
    /// The score comes from the offline engine (see AppState), not from here.
    static func offlineScene(answer: String, companion: String, level: DailyChallenge) -> AIDirection {
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

        let words = answer.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let item = words.prefix(4).joined(separator: " ").isEmpty ? "a bright idea" : words.prefix(4).joined(separator: " ")

        return AIDirection(
            item: item, color: color, action: action, target: level.goal.lowercased(),
            outcome: "and a little more colour rushed back into the world.",
            storyBeat: "\(companion) tried it, and \(level.title.lowercased()) softened into something brighter. The adventure goes on.",
            coaching: "", scores: RubricScores())
    }
}

extension Theme {
    /// A stable-ish bright colour name when none is given.
    static func rainbowName() -> String { ["coral", "sunny", "green", "blue", "purple", "pink"].randomElement() ?? "coral" }
}
