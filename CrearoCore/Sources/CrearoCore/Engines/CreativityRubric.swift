import Foundation

// The scoring rubric for Crearo, the creativity game. Every answer is graded out of 100 against
// six weighted criteria, then a level gate decides whether the idea was creative enough to advance.
//
// This rubric is deliberately HARD. A relevant but ordinary answer lands in the 30s. A genuinely
// good, specific idea reaches the 60s. Only a bold, surprising, richly imagined idea crosses into
// the 80s and 90s. Two forces make it demanding:
//   1. A gamma curve on every criterion, so "pretty good" (0.6) earns far less than its share.
//   2. A relevance/fit gate raised to a power, so an answer that does not truly solve the level's
//      problem has its whole score collapsed (anti-nonsense, anti-cliche).
//
// Pure and deterministic given its inputs, so it is fully unit-testable and reusable by the widget.

// MARK: - Criteria

/// The six things a creative answer is graded on. Weights sum to 100.
public enum RubricCriterion: String, CaseIterable, Codable, Sendable {
    case originality   // how surprising / non-obvious the idea is (clichés score near zero)
    case elaboration   // concrete, vivid, specific detail (not vague hand-waving)
    case fit           // does it actually, cleverly solve the level's problem (also the gate)
    case boldness      // willingness to break convention and take an imaginative risk
    case depth         // metaphor, symbol, reframing, conceptual meaning
    case delight       // emotional spark, wonder, joy

    /// Share of the 100 points this criterion is worth.
    public var weight: Int {
        switch self {
        case .originality: return 25
        case .elaboration: return 20
        case .fit:         return 15
        case .boldness:    return 15
        case .depth:       return 15
        case .delight:     return 10
        }
    }

    public var title: String {
        switch self {
        case .originality: return "Originality"
        case .elaboration: return "Vivid Detail"
        case .fit:         return "Clever Fit"
        case .boldness:    return "Boldness"
        case .depth:       return "Depth"
        case .delight:     return "Delight"
        }
    }

    /// One line describing what earns points here (shown in the score breakdown).
    public var blurb: String {
        switch self {
        case .originality: return "How surprising and unlike the obvious answer it is."
        case .elaboration: return "How concrete and vivid the details are."
        case .fit:         return "How cleverly it actually solves the problem."
        case .boldness:    return "How far it dares to break convention."
        case .depth:       return "Metaphor, meaning, and clever reframing."
        case .delight:     return "The spark of wonder and joy it carries."
        }
    }
}

/// Raw 0...1 judgements per criterion, before the rubric's curve and gate are applied.
public struct RubricScores: Codable, Equatable, Sendable {
    public var originality: Double
    public var elaboration: Double
    public var fit: Double
    public var boldness: Double
    public var depth: Double
    public var delight: Double

    public init(originality: Double = 0, elaboration: Double = 0, fit: Double = 0,
                boldness: Double = 0, depth: Double = 0, delight: Double = 0) {
        self.originality = originality
        self.elaboration = elaboration
        self.fit = fit
        self.boldness = boldness
        self.depth = depth
        self.delight = delight
    }

    public subscript(_ c: RubricCriterion) -> Double {
        switch c {
        case .originality: return originality
        case .elaboration: return elaboration
        case .fit:         return fit
        case .boldness:    return boldness
        case .depth:       return depth
        case .delight:     return delight
        }
    }

    /// Build raw criteria from the offline engine's dimension scores + its relevance gate.
    /// Used when there is no API key, so the game still grades without a model.
    public static func from(dimensions d: DimensionScores, gate: Double) -> RubricScores {
        RubricScores(
            originality: d.originality,
            elaboration: d.elaboration,
            fit: (clamp01(gate) + d.usefulness) / 2,
            boldness: d.riskTaking,
            depth: max(d.symbolicThinking, d.flexibility * 0.8),
            delight: max(d.emotionalExpression, d.fluency * 0.5)
        )
    }
}

// MARK: - Bands

/// A friendly name for a score range, used to colour and caption the result.
public enum ScoreBand: String, Codable, Sendable, CaseIterable {
    case spark      // 0...39   didn't catch
    case glimmer    // 40...59
    case bright     // 60...74
    case brilliant  // 75...89
    case luminous   // 90...100

    public static func of(_ total: Int) -> ScoreBand {
        switch total {
        case ..<40:  return .spark
        case ..<60:  return .glimmer
        case ..<75:  return .bright
        case ..<90:  return .brilliant
        default:     return .luminous
        }
    }

    public var label: String {
        switch self {
        case .spark:     return "A Spark"
        case .glimmer:   return "A Glimmer"
        case .bright:    return "Bright"
        case .brilliant: return "Brilliant"
        case .luminous:  return "Luminous"
        }
    }

    /// A short, warm reaction (never uses em dashes).
    public var reaction: String {
        switch self {
        case .spark:     return "A flicker of an idea. Push it somewhere stranger."
        case .glimmer:   return "There is something here. Make it bolder and more your own."
        case .bright:    return "That genuinely lit up. Nicely done."
        case .brilliant: return "That is a real leap of imagination."
        case .luminous:  return "Wonderfully inventive. The whole world felt that one."
        }
    }
}

// MARK: - Result

/// The full graded outcome of one answer.
public struct RubricResult: Equatable, Sendable {
    public let total: Int                        // 0...100
    public let points: [RubricCriterion: Int]    // points earned per criterion (out of its weight)
    public let band: ScoreBand
    public let raw: RubricScores

    /// The single criterion that cost the most points versus its weight (the best thing to improve).
    public var weakestCriterion: RubricCriterion {
        RubricCriterion.allCases.min { lhs, rhs in
            let l = Double(points[lhs] ?? 0) / Double(lhs.weight)
            let r = Double(points[rhs] ?? 0) / Double(rhs.weight)
            return l < r
        } ?? .originality
    }
}

// MARK: - The rubric

public struct CreativityRubric: Sendable {
    /// Curve exponent. > 1 means middling answers earn less than their linear share (harder).
    public var gamma: Double
    /// How sharply a weak fit gate collapses the whole score. Higher = more punishing to off-topic.
    public var gatePower: Double

    public init(gamma: Double = 1.45, gatePower: Double = 0.7) {
        self.gamma = gamma
        self.gatePower = gatePower
    }

    public static let `default` = CreativityRubric()

    /// Grade raw 0...1 criteria into a 0...100 result with a per-criterion breakdown.
    public func evaluate(_ r: RubricScores) -> RubricResult {
        let gate = pow(clamp01(r.fit), gatePower)   // off-topic answers collapse toward zero
        var points: [RubricCriterion: Int] = [:]
        var subtotal = 0.0
        for c in RubricCriterion.allCases {
            let curved = pow(clamp01(r[c]), gamma)
            let earned = gate * Double(c.weight) * curved
            points[c] = Int(earned.rounded())
            subtotal += earned
        }
        let total = min(100, max(0, Int(subtotal.rounded())))
        return RubricResult(total: total, points: points, band: .of(total), raw: r)
    }
}

// MARK: - Level gate (rising difficulty)

/// Decides how creative an answer must be to advance, and it gets harder as levels climb.
public enum LevelGate {
    /// The score (0...100) needed to clear a given 1-based level. Starts forgiving, rises, then caps.
    public static func passMark(forLevel level: Int) -> Int {
        let raised = 53.0 + 2.2 * Double(max(1, level))
        return min(78, Int(raised.rounded()))
    }

    public static func passes(score: Int, level: Int) -> Bool {
        score >= passMark(forLevel: level)
    }
}
