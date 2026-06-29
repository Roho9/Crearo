import Foundation

// MARK: - Item taxonomy

public enum ItemType: String, CaseIterable, Codable, Sendable {
    case weapon, armor, spell, structure, relic, ritual, decoration, tool, trap, consumable, companionForm
}

// MARK: - Traditional stats (GDD §24)

public struct TraditionalStats: Codable, Equatable, Sendable {
    public var damage: Double
    public var defense: Double
    public var speed: Double
    public var durability: Double
    public var resistance: Double
    public var weight: Double
    public var cooldown: Double

    public init(damage: Double = 0, defense: Double = 0, speed: Double = 0, durability: Double = 0,
                resistance: Double = 0, weight: Double = 0, cooldown: Double = 0) {
        self.damage = damage
        self.defense = defense
        self.speed = speed
        self.durability = durability
        self.resistance = resistance
        self.weight = weight
        self.cooldown = cooldown
    }
}

// MARK: - Creative stats (GDD §24) — 0...100, derived from the hidden CreativityScore

public struct CreativeStats: Codable, Equatable, Sendable {
    public var originality: Double
    public var symbolism: Double
    public var adaptability: Double
    public var emotionalCharge: Double
    public var strangeness: Double
    public var elegance: Double
    public var usefulness: Double
    public var instability: Double  // the risk stat: bigger upside, chance of backfire

    public init(originality: Double = 0, symbolism: Double = 0, adaptability: Double = 0,
                emotionalCharge: Double = 0, strangeness: Double = 0, elegance: Double = 0,
                usefulness: Double = 0, instability: Double = 0) {
        self.originality = originality
        self.symbolism = symbolism
        self.adaptability = adaptability
        self.emotionalCharge = emotionalCharge
        self.strangeness = strangeness
        self.elegance = elegance
        self.usefulness = usefulness
        self.instability = instability
    }

    /// Creative stats are AUTHORITATIVELY derived from the hidden score (not from the LLM),
    /// so a player can't talk an item into being more "original" than it was. (CREATIVITY_SCORING §3.)
    public init(from score: CreativityScore) {
        let d = score.dimensions
        self.init(
            originality: d.originality * 100,
            symbolism: d.symbolicThinking * 100,
            adaptability: d.flexibility * 100,
            emotionalCharge: d.emotionalExpression * 100,
            strangeness: ((d.originality + d.riskTaking) / 2) * 100,
            elegance: ((d.elaboration + d.usefulness) / 2) * 100,
            usefulness: d.usefulness * 100,
            instability: d.riskTaking * 100
        )
    }
}

// MARK: - Unique effect (drawn from an allowlist so balance can clamp it; GDD §33–34)

public enum EffectKind: String, CaseIterable, Codable, Sendable {
    case slow, burn, fear, charm, confuse, shield, light, heal, stealth, summon, reframe, none
}

public struct UniqueEffect: Codable, Equatable, Sendable {
    public var kind: EffectKind
    public var magnitude: Double   // 0...1 (e.g., slow 0.3 = 30%)
    public var durationSec: Double
    public var cooldownSec: Double
    public var range: Double       // meters; 0 = melee/self

    public init(kind: EffectKind, magnitude: Double = 0, durationSec: Double = 0,
                cooldownSec: Double = 0, range: Double = 0) {
        self.kind = kind
        self.magnitude = magnitude
        self.durationSec = durationSec
        self.cooldownSec = cooldownSec
        self.range = range
    }

    public static let none = UniqueEffect(kind: .none)
}

// MARK: - Decay (GDD §32, §38) — distortion along neglected dimensions, plus absence wear

public struct CreationDecay: Codable, Equatable, Sendable {
    /// Per-dimension distortion 0...1 (1 = fully distorted in that dimension). GDD §38.
    public var distortion: DimensionScores
    public var dust: Double      // absence wear 0...1 (GDD §32)
    public var glowLoss: Double  // 0...1

    public init(distortion: DimensionScores = .zero, dust: Double = 0, glowLoss: Double = 0) {
        self.distortion = distortion
        self.dust = dust
        self.glowLoss = glowLoss
    }

    public static let pristine = CreationDecay()

    /// Overall "health" of a creation for display/feel (1 = pristine).
    public var health: Double {
        let worstDistortion = CreativeDimension.allCases.map { distortion[$0] }.max() ?? 0
        return clamp01(1 - max(worstDistortion, max(dust, glowLoss)))
    }
}

// MARK: - A permanent player creation (GDD §36)

public struct Creation: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String            // player-named (GDD §37)
    public var type: ItemType
    public var traditional: TraditionalStats
    public var creative: CreativeStats
    public var effect: UniqueEffect
    public var artDescriptor: String   // drives the restyle pipeline (GDD §52)
    public var cost: [ResourceAmount]
    public var createdAt: Date
    public var regionMade: RegionID
    public var classAffinity: EmergentClass?
    public var decay: CreationDecay

    public init(id: UUID = UUID(), name: String, type: ItemType, traditional: TraditionalStats,
                creative: CreativeStats, effect: UniqueEffect = .none, artDescriptor: String = "",
                cost: [ResourceAmount] = [], createdAt: Date = Date(), regionMade: RegionID,
                classAffinity: EmergentClass? = nil, decay: CreationDecay = .pristine) {
        self.id = id
        self.name = name
        self.type = type
        self.traditional = traditional
        self.creative = creative
        self.effect = effect
        self.artDescriptor = artDescriptor
        self.cost = cost
        self.createdAt = createdAt
        self.regionMade = regionMade
        self.classAffinity = classAffinity
        self.decay = decay
    }

    /// Build a final, permanent Creation from the AI's proposal + the authoritative hidden score.
    /// Creative stats come from the score, NOT the LLM (see CreativeStats.init(from:)).
    public static func assemble(idea: InterpretedIdea, score: CreativityScore, cost: [ResourceAmount],
                                region: RegionID, classAffinity: EmergentClass? = nil,
                                name: String? = nil) -> Creation {
        Creation(
            name: name ?? idea.suggestedName,
            type: idea.itemType,
            traditional: idea.traditional,
            creative: CreativeStats(from: score),
            effect: idea.effect,
            artDescriptor: idea.artDescriptor,
            cost: cost,
            regionMade: region,
            classAffinity: classAffinity
        )
    }
}
