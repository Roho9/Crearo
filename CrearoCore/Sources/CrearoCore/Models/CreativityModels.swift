import Foundation

// MARK: - Creative dimensions (docs/CREATIVITY_SCORING.md §2)

/// The eight research-grounded creativity dimensions the engine scores.
public enum CreativeDimension: String, CaseIterable, Codable, Sendable {
    case originality          // statistical rarity + semantic distance (Torrance; DAT/Olson 2021)
    case fluency              // number of relevant ideas (Torrance)
    case flexibility          // number of distinct solution categories (Torrance)
    case elaboration          // amount of meaningful detail (Torrance)
    case usefulness           // fit / constraint satisfaction (convergent thinking, Guilford)
    case riskTaking           // boldness / acceptance of instability
    case emotionalExpression  // genuine affective charge
    case symbolicThinking     // metaphor / symbol / reframing
}

/// The input methods a player can respond with (GDD §27, §52).
public enum Modality: String, CaseIterable, Codable, Sendable {
    case drawing, writing, voice, photo, arrangement, building, sound, gesture, mixed
}

// MARK: - Fixed-shape score containers
// We use a struct with named fields rather than [CreativeDimension: Double] so Codable
// produces a clean JSON object (Swift encodes enum-keyed dictionaries as arrays).

/// Per-dimension values in 0...1.
public struct DimensionScores: Codable, Equatable, Sendable {
    public var originality: Double
    public var fluency: Double
    public var flexibility: Double
    public var elaboration: Double
    public var usefulness: Double
    public var riskTaking: Double
    public var emotionalExpression: Double
    public var symbolicThinking: Double

    public init(originality: Double = 0, fluency: Double = 0, flexibility: Double = 0,
                elaboration: Double = 0, usefulness: Double = 0, riskTaking: Double = 0,
                emotionalExpression: Double = 0, symbolicThinking: Double = 0) {
        self.originality = originality
        self.fluency = fluency
        self.flexibility = flexibility
        self.elaboration = elaboration
        self.usefulness = usefulness
        self.riskTaking = riskTaking
        self.emotionalExpression = emotionalExpression
        self.symbolicThinking = symbolicThinking
    }

    public static let zero = DimensionScores()
    public static let uniform = DimensionScores(originality: 1, fluency: 1, flexibility: 1,
                                                elaboration: 1, usefulness: 1, riskTaking: 1,
                                                emotionalExpression: 1, symbolicThinking: 1)

    public subscript(_ d: CreativeDimension) -> Double {
        get {
            switch d {
            case .originality: return originality
            case .fluency: return fluency
            case .flexibility: return flexibility
            case .elaboration: return elaboration
            case .usefulness: return usefulness
            case .riskTaking: return riskTaking
            case .emotionalExpression: return emotionalExpression
            case .symbolicThinking: return symbolicThinking
            }
        }
        set {
            switch d {
            case .originality: originality = newValue
            case .fluency: fluency = newValue
            case .flexibility: flexibility = newValue
            case .elaboration: elaboration = newValue
            case .usefulness: usefulness = newValue
            case .riskTaking: riskTaking = newValue
            case .emotionalExpression: emotionalExpression = newValue
            case .symbolicThinking: symbolicThinking = newValue
            }
        }
    }

    public var average: Double {
        let all = CreativeDimension.allCases
        return all.map { self[$0] }.reduce(0, +) / Double(all.count)
    }
}

// MARK: - A single scored creative act

/// The hidden result of scoring one creative act. The player NEVER sees these numbers;
/// they are translated into world state (color, loot, dialogue, prophecy). GDD §39.
public struct CreativityScore: Codable, Equatable, Sendable {
    /// Relevance/usefulness gate in 0...1. Gates all novelty dimensions (anti-nonsense, §5).
    public let gate: Double
    /// Per-dimension scores in 0...1 (novelty dims already gate-applied).
    public let dimensions: DimensionScores
    public let reframingDetected: Bool
    public let constraintSatisfied: Bool
    /// Effort 0...1, used to weight the trajectory update.
    public let effort: Double

    public init(gate: Double, dimensions: DimensionScores, reframingDetected: Bool = false,
                constraintSatisfied: Bool = false, effort: Double = 0.5) {
        self.gate = gate
        self.dimensions = dimensions
        self.reframingDetected = reframingDetected
        self.constraintSatisfied = constraintSatisfied
        self.effort = effort
    }

    /// A single 0...1 "creative magnitude" for convenience (loot tiering, glow intensity).
    public var magnitude: Double { gate * dimensions.average }
}

// MARK: - Scoring input (pre-extracted signals)
// Heavy NLP/vision/embeddings happen on-device or in Edge Functions; the pure engine
// consumes already-extracted numeric signals so it stays deterministic & testable.

public struct ScoringInput: Codable, Equatable, Sendable {
    public let promptID: String
    public let modality: Modality

    // Gate inputs (0...1)
    public let relevance: Double           // semantic relatedness to the prompt
    public let functionalValidity: Double  // sim-check pass (1 if not applicable)
    public let coherence: Double           // media coherence (drawing has structure, text on-topic)

    // Dimension signals
    public let semanticDistance: Double    // originality fallback when rarity is unknown (0...1)
    public let rarityPercentile: Double?   // population rarity from RarityService (0...1), nil at cold-start
    public let ideaCount: Int              // fluency
    public let distinctCategoryCount: Int  // flexibility
    public let detail: Double              // elaboration (meaningful detail, NOT length) 0...1
    public let emotionalCharge: Double     // 0...1
    public let symbolism: Double           // 0...1
    public let riskSignal: Double          // 0...1 (distance from the safe default)

    public let reframingDetected: Bool
    public let constraintSatisfied: Bool
    public let effort: Double              // 0...1

    public init(promptID: String, modality: Modality, relevance: Double, functionalValidity: Double = 1,
                coherence: Double = 1, semanticDistance: Double = 0, rarityPercentile: Double? = nil,
                ideaCount: Int = 1, distinctCategoryCount: Int = 1, detail: Double = 0,
                emotionalCharge: Double = 0, symbolism: Double = 0, riskSignal: Double = 0,
                reframingDetected: Bool = false, constraintSatisfied: Bool = false, effort: Double = 0.5) {
        self.promptID = promptID
        self.modality = modality
        self.relevance = relevance
        self.functionalValidity = functionalValidity
        self.coherence = coherence
        self.semanticDistance = semanticDistance
        self.rarityPercentile = rarityPercentile
        self.ideaCount = ideaCount
        self.distinctCategoryCount = distinctCategoryCount
        self.detail = detail
        self.emotionalCharge = emotionalCharge
        self.symbolism = symbolism
        self.riskSignal = riskSignal
        self.reframingDetected = reframingDetected
        self.constraintSatisfied = constraintSatisfied
        self.effort = effort
    }
}

// MARK: - The private creative profile (trajectory over verdict, §7)

public struct DimensionEstimate: Codable, Equatable, Sendable {
    public var value: Double       // EWMA estimate 0...1
    public var uncertainty: Double // 0...1, shrinks with samples
    public var trend: Double       // most recent delta
    public var samples: Int

    public init(value: Double = 0.0, uncertainty: Double = 1.0, trend: Double = 0, samples: Int = 0) {
        self.value = value
        self.uncertainty = uncertainty
        self.trend = trend
        self.samples = samples
    }
}

/// The brain that personalizes classes, regions, companion, NPCs, rewards, decay, and the final boss.
/// Stored privately per user, never shown raw (GDD §44, §62).
public struct CreativeProfile: Codable, Equatable, Sendable {
    // Keyed by CreativeDimension.rawValue / Modality.rawValue to keep Codable output a clean object.
    public var estimates: [String: DimensionEstimate]
    public var modalityCounts: [String: Int]
    public var recentSolutionSignatures: [String]  // for repetition detection (§35)
    public var combatReliance: Double              // 0...1 (too-much-combat signal)
    public var returnConsistency: Double           // 0...1 (consistency of return)
    public var totalActs: Int

    public init() {
        var est: [String: DimensionEstimate] = [:]
        for d in CreativeDimension.allCases { est[d.rawValue] = DimensionEstimate() }
        self.estimates = est
        self.modalityCounts = [:]
        self.recentSolutionSignatures = []
        self.combatReliance = 0
        self.returnConsistency = 0.5
        self.totalActs = 0
    }

    public func estimate(_ d: CreativeDimension) -> DimensionEstimate {
        estimates[d.rawValue] ?? DimensionEstimate()
    }
    public func value(_ d: CreativeDimension) -> Double { estimate(d).value }

    /// Current per-dimension snapshot (used as AI context and for reward focus).
    public var snapshot: DimensionScores {
        var s = DimensionScores()
        for d in CreativeDimension.allCases { s[d] = value(d) }
        return s
    }

    /// The n weakest / most-stagnant dimensions — seeds the personalized final boss (§9, GDD §50).
    public func weakestDimensions(_ n: Int) -> [CreativeDimension] {
        CreativeDimension.allCases.sorted { lhs, rhs in
            let l = estimate(lhs), r = estimate(rhs)
            if l.value != r.value { return l.value < r.value }
            return l.trend < r.trend
        }
        .prefix(max(0, n))
        .map { $0 }
    }

    /// The player's most-used input method — the shadow boss mirrors it (GDD §50).
    public var dominantModality: Modality? {
        modalityCounts.max(by: { $0.value < $1.value }).flatMap { Modality(rawValue: $0.key) }
    }

    /// How repetitive the player has been recently (0 = varied, 1 = same thing every time).
    public var repetitionRatio: Double {
        guard !recentSolutionSignatures.isEmpty else { return 0 }
        let distinct = Set(recentSolutionSignatures).count
        return 1 - (Double(distinct) / Double(recentSolutionSignatures.count))
    }
}
