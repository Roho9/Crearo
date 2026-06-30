import Foundation
import CrearoCore

// Real Forge AI: turns a player's freeform creation into a balanced game item by calling the
// Anthropic Claude API. Swift has no official Anthropic SDK, so this uses raw HTTPS via URLSession.
//
// It uses STRUCTURED OUTPUTS (output_config.format with a JSON schema) so Claude returns JSON that
// decodes directly into InterpretedIdea — the schema's enums are pinned to the game's ItemType /
// EffectKind so the model can only pick real, balanceable values. Creative stats are NOT requested
// from the model (they come authoritatively from the hidden score; see Creation.assemble).
//
// LOCAL-TESTING ONLY: the key comes from the gitignored Secrets.swift. Don't ship a key in a build.
struct ClaudeAIInterpretationService: AIInterpretationService {
    let apiKey: String
    var model = "claude-opus-4-8"   // default per current Anthropic guidance; swap to a cheaper model if desired

    func interpret(_ idea: IdeaInput, context: CreationContext) async throws -> InterpretedIdea {
        let prompt = """
        A player in a cozy dark-fantasy creativity game just described something to forge into the \
        world. Turn their idea into a single balanced game item.

        Rules:
        - Keep numbers modest; this is early game (player level \(context.level), region \(context.region.rawValue)).
        - traditional stats are roughly 0–40 (damage/defense), weight 1–6, cooldown 0–8 seconds.
        - effect.magnitude is 0.0–0.6, durationSec 0–6, cooldownSec 2–8, range 0–6 (0 = melee/self).
        - Pick the single closest effect kind. Use "none" if nothing fits.
        - suggestedName: a short, evocative proper name. artDescriptor: one vivid clay/dark-fantasy visual line.

        The player's idea: "\(idea.text ?? "")"
        """

        let schema: [String: Any] = [
            "type": "object",
            "additionalProperties": false,
            "required": ["itemType", "suggestedName", "artDescriptor", "traditional", "effect"],
            "properties": [
                "itemType": ["type": "string", "enum": ItemType.allCases.map { $0.rawValue }],
                "suggestedName": ["type": "string"],
                "artDescriptor": ["type": "string"],
                "traditional": [
                    "type": "object", "additionalProperties": false,
                    "required": ["damage", "defense", "speed", "durability", "resistance", "weight", "cooldown"],
                    "properties": [
                        "damage": ["type": "number"], "defense": ["type": "number"], "speed": ["type": "number"],
                        "durability": ["type": "number"], "resistance": ["type": "number"],
                        "weight": ["type": "number"], "cooldown": ["type": "number"],
                    ],
                ],
                "effect": [
                    "type": "object", "additionalProperties": false,
                    "required": ["kind", "magnitude", "durationSec", "cooldownSec", "range"],
                    "properties": [
                        "kind": ["type": "string", "enum": EffectKind.allCases.map { $0.rawValue }],
                        "magnitude": ["type": "number"], "durationSec": ["type": "number"],
                        "cooldownSec": ["type": "number"], "range": ["type": "number"],
                    ],
                ],
            ],
        ]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": "You convert player ideas into balanced dark-fantasy game items. Be evocative but concise, and always respect the numeric ranges given.",
            "output_config": ["format": ["type": "json_schema", "schema": schema]],
            "messages": [["role": "user", "content": prompt]],
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.transport("no response") }
        guard (200..<300).contains(http.statusCode) else {
            throw http.statusCode == 401 ? APIError.unauthorized : APIError.http(status: http.statusCode)
        }

        // Response: { "content": [ { "type": "text", "text": "<schema-valid JSON>" }, ... ] }
        struct MessageResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        let message = try JSONDecoder().decode(MessageResponse.self, from: data)
        guard let jsonText = message.content.first(where: { $0.type == "text" })?.text,
              let jsonData = jsonText.data(using: .utf8) else {
            throw APIError.decoding("no text block in Claude response")
        }
        return try JSONDecoder().decode(InterpretedIdea.self, from: jsonData)
    }
}
