import Foundation

/// Authored clues for a local, English-language practice check. Terms describe the goal and broad
/// ways an answer can explain an effect; they are not a list of approved solutions. Required groups
/// are for explicit prompt constraints only. Each group accepts any of its terms or phrases.
public struct PracticeChallengeContext: Equatable, Sendable {
    public var goal: String
    public var goalTerms: [String]
    public var mechanismTerms: [String]
    public var requiredTermGroups: [[String]]
    public var minimumDistinctIdeas: Int

    public init(goal: String, goalTerms: [String], mechanismTerms: [String],
                requiredTermGroups: [[String]] = [], minimumDistinctIdeas: Int = 1) {
        self.goal = goal
        self.goalTerms = goalTerms
        self.mechanismTerms = mechanismTerms
        self.requiredTermGroups = requiredTermGroups
        self.minimumDistinctIdeas = max(1, minimumDistinctIdeas)
    }
}

/// The raw values fit the existing rubric for consistent rewards. They are observable writing
/// proxies, not validated measurements of originality, emotion, or whether a mechanism would work.
public struct PracticeEvaluation: Equatable, Sendable {
    public let raw: RubricScores
    public let coaching: String
    public let evidence: [String]

    public init(raw: RubricScores, coaching: String, evidence: [String]) {
        self.raw = raw
        self.coaching = coaching
        self.evidence = evidence
    }
}

/// A deterministic fallback that checks a response against the actual challenge, rather than
/// rewarding vocabulary in isolation. It accepts concise explanations and has no fixed score
/// ceiling below the level gates. Because it uses bounded lexical clues, it can miss valid unusual
/// solutions or accept a well-written implausible one. Keep its result labeled a practice estimate.
public struct PracticeChallengeEvaluator: Sendable {
    public init() {}

    public func evaluate(answer: String, context: PracticeChallengeContext) -> PracticeEvaluation {
        let text = String(answer.prefix(12_000)).trimmingCharacters(in: .whitespacesAndNewlines)
        let words = Self.tokens(text)
        let content = words.filter { $0.count > 2 && !Self.filler.contains($0) }
        let unique = Set(content)
        let units = Self.ideaUnits(text)
        let distinctUnits = Self.distinctUnits(units)
        let goalHits = Self.matches(context.goalTerms, in: words)
        let mechanismHits = Self.matches(context.mechanismTerms, in: words)
        let missingGroups = context.requiredTermGroups.filter { Self.matches($0, in: words).isEmpty }.count
        let neededIdeas = max(1, context.minimumDistinctIdeas)
        let enoughIdeas = distinctUnits.count >= neededIdeas
        let functionCount = words.filter { Self.structureWords.contains($0) }.count
        let structureVariety = Set(words.filter { Self.structureWords.contains($0) }).count
        let connectiveCount = Set(words.filter { Self.linkWords.contains($0) }).count
        let actionCount = Self.matches(Self.actions, in: words).count
        let gibberishCount = content.filter { token in
            token.count > 3 && !token.contains(where: { "aeiouy".contains($0) })
        }.count
        let gibberish = !content.isEmpty && Double(gibberishCount) / Double(content.count) > 0.45
        let genericCount = content.filter { Self.generic.contains($0) }.count
        let generic = unique.count < 3 || (!content.isEmpty && Double(genericCount) / Double(content.count) >= 0.45)
        let keywordList = words.count >= 8 && (functionCount < 2 || structureVariety < 2 ||
            Double(functionCount) / Double(words.count) < 0.18)
        // Repeating whole sentences or a small vocabulary cannot manufacture detail or ideas.
        let repeatedUnits = units.count >= 3 && distinctUnits.count * 2 <= units.count
        let repeatedWords = content.count >= 16 && Double(unique.count) / Double(content.count) < 0.36
        let repeated = repeatedUnits || repeatedWords
        let hasStructure = functionCount >= 2 && words.count >= 6
        let lowInformation = text.isEmpty || generic || gibberish || keywordList || repeated || !hasStructure

        let hasGoal = !goalHits.isEmpty
        let hasMechanism = !mechanismHits.isEmpty && (actionCount > 0 || connectiveCount > 0)
        let requirementsMet = missingGroups == 0 && enoughIdeas

        var evidence: [String] = []
        if hasGoal { evidence.append("Goal wording found in this idea") }
        if hasMechanism { evidence.append("Action or effect wording found in this idea") }
        if neededIdeas > 1 { evidence.append("\(distinctUnits.count) distinct idea sections found; \(neededIdeas) requested") }
        if !context.requiredTermGroups.isEmpty {
            evidence.append("\(context.requiredTermGroups.count - missingGroups) of \(context.requiredTermGroups.count) explicit constraint clues found")
        }

        let coaching: String
        if text.isEmpty || generic || gibberish {
            coaching = "Name one thing you would make, then explain what it does to help: \(Self.lowercasedGoal(context.goal))"
        } else if repeated {
            coaching = "Keep your strongest version and remove the repeated lines. Add one new step that shows how it helps: \(Self.lowercasedGoal(context.goal))"
        } else if keywordList || !hasStructure {
            coaching = "Turn the list into a small explanation: what acts on what, and what changes? Show how it helps: \(Self.lowercasedGoal(context.goal))"
        } else if !hasGoal {
            coaching = "I couldn't find the goal connection in this local check. Say directly how your idea helps: \(Self.lowercasedGoal(context.goal))"
        } else if !hasMechanism {
            coaching = "You connected your idea to the goal. Add one action and its effect so we can picture how it works."
        } else if !enoughIdeas {
            coaching = "I found \(distinctUnits.count) distinct idea sections. Give \(neededIdeas) different approaches on separate lines, with a different action or purpose in each."
        } else if missingGroups > 0 {
            coaching = "Your idea has an action and a goal. Revisit the prompt's explicit constraints and say how your idea meets each one."
        } else if unique.count < 8 {
            coaching = "Your action connects to the goal. Add one concrete detail, such as a material, sound, movement, or what your companion does next."
        } else {
            coaching = "Your explanation connects an action to the goal. Try one surprising change to the material, scale, or point of view, while keeping that connection clear."
        }

        guard !lowInformation else {
            return PracticeEvaluation(raw: RubricScores(originality: 0.12, elaboration: 0.12,
                fit: text.isEmpty ? 0 : 0.12, boldness: 0.1, depth: 0.1, delight: 0.1),
                coaching: coaching, evidence: evidence)
        }

        // Unique concrete language saturates quickly, so a short clear mechanism can score well.
        // Additional length beyond this point earns nothing. Unrelated prose is limited by fit.
        let specificity = min(1, Double(unique.count) / 14)
        let linking = min(1, Double(connectiveCount) / 2)
        let actionVariety = min(1, Double(max(actionCount, mechanismHits.count)) / 2)
        let mechanism = hasMechanism ? 0.65 + 0.2 * linking + 0.15 * actionVariety : 0.15
        let sensory = min(1, Double(Self.matches(Self.detailTerms, in: words).count) / 2)
        let transformation = min(1, Double(Self.matches(Self.transformationTerms, in: words).count) / 2)
        let perspective = min(1, Double(Self.matches(Self.perspectiveTerms, in: words).count) / 2)
        let variety = neededIdeas > 1 ? min(1, Double(distinctUnits.count) / Double(neededIdeas)) : max(transformation, actionVariety)

        var fit = hasGoal ? 0.55 + 0.35 * mechanism + 0.1 * specificity : 0.15
        if !hasMechanism { fit = min(fit, 0.5) }
        if !requirementsMet { fit = min(fit, 0.45) }

        let raw = RubricScores(
            originality: 0.25 + 0.30 * specificity + 0.20 * variety + 0.15 * mechanism,
            elaboration: 0.20 + 0.45 * specificity + 0.25 * mechanism + 0.10 * sensory,
            fit: fit,
            boldness: 0.25 + 0.30 * specificity + 0.20 * variety + 0.15 * mechanism,
            depth: 0.20 + 0.25 * specificity + 0.30 * mechanism + 0.20 * max(linking, perspective),
            delight: 0.25 + 0.30 * specificity + 0.20 * mechanism + 0.15 * max(sensory, perspective)
        )
        return PracticeEvaluation(raw: raw, coaching: coaching, evidence: evidence)
    }

    private static func lowercasedGoal(_ goal: String) -> String {
        guard let first = goal.first else { return "solve this challenge." }
        return first.lowercased() + goal.dropFirst()
    }

    private static func tokens(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    /// Full token/phrase boundaries avoid accidental matches such as "unlit" matching "lit".
    /// Common English inflections are accepted; this deliberately does not claim language parsing.
    private static func wordMatches(_ word: String, _ term: String) -> Bool {
        if word == term { return true }
        guard term.count >= 3 else { return false }
        if word == term + "s" || word == term + "es" || word == term + "ed" || word == term + "ing" { return true }
        if term.hasSuffix("e"), word == term.dropLast() + "ing" || word == term + "d" { return true }
        if term.hasSuffix("y"), word == term.dropLast() + "ies" || word == term.dropLast() + "ied" { return true }
        return false
    }

    private static func matches(_ terms: [String], in words: [String]) -> [String] {
        terms.filter { term in
            let phrase = tokens(term)
            guard !phrase.isEmpty, words.count >= phrase.count else { return false }
            return (0...(words.count - phrase.count)).contains { start in
                phrase.indices.allSatisfy { wordMatches(words[start + $0], phrase[$0]) }
            }
        }
    }

    private static func ideaUnits(_ text: String) -> [Set<String>] {
        text.split { ".!?;\n".contains($0) }.compactMap { fragment in
            let words = tokens(String(fragment))
            let meaningful = Set(words.filter { $0.count > 2 && !filler.contains($0) && !$0.allSatisfy(\.isNumber) })
            return meaningful.count >= 3 && words.count >= 4 ? meaningful : nil
        }
    }

    private static func distinctUnits(_ units: [Set<String>]) -> [Set<String>] {
        var accepted: [Set<String>] = []
        for unit in units {
            // Matching words in a reordered sentence do not turn it into a different idea.
            let duplicate = accepted.contains { prior in
                let smaller = min(prior.count, unit.count)
                return smaller > 0 && Double(prior.intersection(unit).count) / Double(smaller) >= 0.72
            }
            if !duplicate { accepted.append(unit) }
        }
        return accepted
    }

    private static let filler: Set<String> = [
        "the", "and", "but", "for", "with", "that", "this", "they", "them", "then", "than", "are", "was", "were", "will",
        "would", "could", "should", "can", "have", "has", "had", "our", "your", "its", "into", "from", "some", "very",
        "first", "second", "third", "fourth", "fifth", "one", "two", "three", "use", "make", "made", "because"
    ]
    private static let generic: Set<String> = ["thing", "things", "stuff", "something", "anything", "idk", "dunno", "whatever", "blah", "asdf", "nice", "good", "cool", "test", "testing"]
    private static let structureWords: Set<String> = ["a", "an", "the", "i", "we", "it", "its", "our", "my", "you", "your", "they", "their", "to", "by", "with", "when", "as", "and", "so", "if", "that", "because", "which", "is", "are", "would", "will", "can", "in", "on", "at", "of", "for", "from", "into", "over", "under", "each", "then", "until", "through", "while", "without"]
    private static let linkWords: Set<String> = ["to", "by", "when", "because", "so", "then", "until", "while", "using", "through", "instead"]
    private static let actions = ["build", "make", "turn", "carry", "hold", "lift", "float", "fly", "pull", "push", "roll", "fold", "open", "grow", "plant", "sing", "play", "trade", "offer", "give", "shine", "glow", "light", "wake", "tap", "stretch", "spin", "weave", "catch", "guide", "send", "cross", "tie", "draw", "tell", "dance", "transform", "convert", "collect", "attach", "release", "fill", "pour", "touch", "speak", "whisper", "listen", "connect", "share", "warm", "bounce", "laugh", "sneeze", "unfold", "move", "reflect"]
    private static let detailTerms = ["paper", "silk", "wood", "metal", "glass", "thread", "seed", "leaf", "leaves", "moss", "petal", "bell", "honey", "copper", "tin", "cloth", "sand", "water", "ribbon", "soft", "warm", "tiny", "rough", "smooth", "bright", "glow", "hum", "ring", "rustle", "rattle", "silver", "gold", "blue", "green", "orange", "crimson", "sound", "scent", "smell"]
    private static let transformationTerms = ["turn", "become", "instead", "transform", "convert", "fold", "unfold", "grow", "swap", "trade", "stretch", "weave", "reflect", "reverse", "tiny", "giant", "upside down", "inside out"]
    private static let perspectiveTerms = ["companion", "friend", "together", "share", "kind", "gentle", "smile", "laugh", "joy", "remember", "memory", "hope", "courage", "afraid", "comfort", "welcome", "play", "delight", "listen", "help"]
}
