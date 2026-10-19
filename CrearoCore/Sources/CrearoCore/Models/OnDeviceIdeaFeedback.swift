import Foundation

/// Optional wording and stage cues from the device's language model. Deliberately contains no
/// grade, pass state, rewards or progression: those remain the deterministic game's decision.
public struct OnDeviceIdeaFeedback: Equatable, Sendable {
    public let strength: String
    public let nextStep: String
    public let evidenceQuote: String
    public let item: String
    public let color: String
    public let action: String

    /// Model output is untrusted. Reject unsupported cues and fabricated evidence rather than
    /// showing them as if they came from the player's invention. A rejected response uses the
    /// existing local coaching and scene composer, without affecting the submitted score.
    public init?(strength: String, nextStep: String, evidenceQuote: String,
                 item: String, color: String, action: String, answer: String) {
        let strength = Self.normalized(strength)
        let nextStep = Self.normalized(nextStep)
        let evidence = Self.normalized(evidenceQuote)
        let item = Self.normalized(item)
        let color = Self.normalized(color).lowercased()
        let action = Self.normalized(action).lowercased()
        guard (8...240).contains(strength.count), (8...240).contains(nextStep.count),
              (4...160).contains(evidence.count), (2...60).contains(item.count),
              Self.actions.contains(action), Self.colors.contains(color),
              Self.containsPhrase(evidence, in: answer), Self.containsPhrase(item, in: answer),
              !Self.claimsAGrade(strength), !Self.claimsAGrade(nextStep) else { return nil }
        self.strength = strength
        self.nextStep = nextStep
        self.evidenceQuote = evidence
        self.item = item
        self.color = color
        self.action = action
    }

    private static let actions: Set<String> = [
        "strike", "build", "transform", "summon", "fly", "grow", "give", "solve", "explore"
    ]
    private static let colors: Set<String> = [
        "red", "orange", "yellow", "gold", "green", "blue", "teal", "purple", "pink", "rainbow", "silver"
    ]

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func containsPhrase(_ phrase: String, in answer: String) -> Bool {
        let answer = normalized(answer)
        var searchStart = answer.startIndex
        while let range = answer.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive],
                                       range: searchStart..<answer.endIndex) {
            // A tiny substring such as "rope" in "Europe" is not evidence of a rope invention,
            // but a later occurrence of "a rope" is. Examine all occurrences, not just the first.
            let before = range.lowerBound == answer.startIndex ? nil : answer[answer.index(before: range.lowerBound)]
            let after = range.upperBound == answer.endIndex ? nil : answer[range.upperBound]
            if !(before?.isLetter ?? false) && !(before?.isNumber ?? false)
                && !(after?.isLetter ?? false) && !(after?.isNumber ?? false) { return true }
            searchStart = range.upperBound
        }
        return false
    }

    private static func claimsAGrade(_ text: String) -> Bool {
        let orderedWords = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let words = Set(orderedWords)
        if !words.isDisjoint(with: ["score", "scores", "scored", "points", "passed", "unlocked", "unlock", "unlocks",
                                  "reward", "rewards", "earned", "100"]) { return true }
        // Reject common success claims while allowing useful wording such as "make it clear how
        // the rope works" or "let water pass through" in an actual revision suggestion.
        let sentence = " " + orderedWords.joined(separator: " ") + " "
        return ["you pass", "you clear", "you cleared", "you have cleared", "you ve cleared",
                "chapter is cleared", "level is cleared", "chapter complete", "level complete"]
            .contains { sentence.contains(" " + $0 + " ") }
    }
}
