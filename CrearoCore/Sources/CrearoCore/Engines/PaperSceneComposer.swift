import Foundation

public struct PaperSceneScript: Equatable, Sendable {
    public let item: String
    public let color: String
    public let action: String
    public let target: String
}

/// A bounded local stage direction, not an interpretation of arbitrary inventions. Match whole
/// words so "heartbeat" cannot accidentally direct an attack, and keep repeat attempts stable.
public enum PaperSceneComposer {
    public static func compose(answer: String, target: String) -> PaperSceneScript {
        let words = answer.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let lower = words.map { $0.lowercased() }
        let colorAliases = ["golden": "gold", "azure": "blue", "scarlet": "red", "violet": "purple"]
        let colors: Set<String> = ["red", "orange", "yellow", "gold", "green", "blue", "teal", "purple", "pink", "rainbow", "silver"]
        let color = lower.compactMap { colors.contains($0) ? $0 : colorAliases[$0] }.first
            ?? ["blue", "green", "gold", "pink", "purple", "red"][answer.utf8.reduce(0) { ($0 + Int($1)) % 6 }]

        let actions: [String: String] = [
            "build": "build", "make": "build", "create": "build", "fold": "build", "assemble": "build",
            "transform": "transform", "convert": "transform", "reshape": "transform",
            "fly": "fly", "glide": "fly", "float": "fly", "jump": "fly",
            "grow": "grow", "plant": "grow", "bloom": "grow",
            "give": "give", "offer": "give", "trade": "give", "share": "give",
            "solve": "solve", "open": "solve", "unlock": "solve", "untangle": "solve",
            "explore": "explore", "walk": "explore", "cross": "explore", "deliver": "explore",
            "strike": "strike", "fight": "strike", "hit": "strike", "defeat": "strike"
        ]
        let action = lower.compactMap { actions[$0] }.first ?? "summon"

        let heading = answer.split(separator: ":", maxSplits: 1).first.map(String.init) ?? answer
        var itemWords = heading.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let introductory: Set<String> = ["i", "we", "my", "our", "would", "will", "can", "could", "a", "an", "the", "make", "build", "create", "invent", "use"]
        while let first = itemWords.first, introductory.contains(first.lowercased()) { itemWords.removeFirst() }
        let item = itemWords.prefix(6).joined(separator: " ")
        return PaperSceneScript(item: item.isEmpty ? "a new paper idea" : item,
                                color: color, action: action, target: target)
    }
}
