import Foundation

// Right-sizes player ideas into the game's balance without ever rejecting them (GDD §33–34).
// "Conservation of identity": clamping moves magnitudes/ranges/cooldowns, never the effect's
// flavor — the player always feels their idea became real, just appropriately sized.

public struct BalanceConfig: Sendable {
    public var baseBudget: Double = 120
    public var budgetPerLevel: Double = 18
    public var maxEffectMagnitude: Double = 0.6   // e.g., 60% slow cap early-game
    public var maxDurationSec: Double = 6
    public var maxRangeBase: Double = 4

    public func maxRange(level: Int) -> Double { maxRangeBase + Double(max(0, level)) * 0.5 }
    public func minCooldownSec(for effect: UniqueEffect) -> Double { effect.magnitude > 0.3 ? 4 : 2 }

    public static let `default` = BalanceConfig()
    public init() {}
}

public struct BalanceEngine: Sendable {
    public var config: BalanceConfig
    public init(config: BalanceConfig = .default) { self.config = config }

    /// Total power budget available to a creation at a given level/region.
    public func statBudget(level: Int, region: RegionID) -> Double {
        config.baseBudget + Double(max(0, level)) * config.budgetPerLevel
    }

    /// A simple scalar proxy for how "strong" a creation is, for budgeting.
    public func power(of c: Creation) -> Double {
        c.traditional.damage + c.traditional.defense + c.effect.magnitude * 100
    }

    /// Clamp a creation into budget, preserving its identity (effect KIND is never changed).
    public func clamp(_ proposed: Creation, level: Int) -> Creation {
        var c = proposed
        let budget = statBudget(level: level, region: c.regionMade)

        // Clamp the effect envelope first.
        // Module-qualified so these resolve to the global clamp(_:_:_:) in Math.swift,
        // not this struct's own clamp(_:level:) instance method.
        c.effect.magnitude = CrearoCore.clamp(c.effect.magnitude, 0, config.maxEffectMagnitude)
        c.effect.durationSec = CrearoCore.clamp(c.effect.durationSec, 0, config.maxDurationSec)
        c.effect.cooldownSec = max(c.effect.cooldownSec, config.minCooldownSec(for: c.effect))
        c.effect.range = CrearoCore.clamp(c.effect.range, 0, config.maxRange(level: level))

        // If still over budget, scale the raw stats down proportionally (identity preserved).
        let p = power(of: c)
        if p > budget, p > 0 {
            let scale = budget / p
            c.traditional.damage *= scale
            c.traditional.defense *= scale
            c.effect.magnitude = min(c.effect.magnitude, config.maxEffectMagnitude) * scale
        }

        // Risk tax: very original/strange creations carry instability (bigger upside, can backfire).
        c.creative.instability = CrearoCore.clamp(c.creative.originality * 0.4 + c.creative.strangeness * 0.6, 0, 100)

        return c
    }

    /// Resource cost for a (clamped) creation, scaling with power, rarity, complexity (GDD §34).
    public func cost(for c: Creation, score: CreativityScore, level: Int) -> [ResourceAmount] {
        let powerNorm = (c.traditional.damage + c.traditional.defense) / 100 + c.effect.magnitude
        return Economy.cost(power: powerNorm,
                            rarity: score.dimensions.originality,
                            complexity: score.dimensions.elaboration,
                            level: level)
    }

    /// Guarantees a player can never soft-lock: a minimal viable creation that always fits budget
    /// and is affordable from a near-empty wallet (a non-combat path always exists, GDD §25).
    public func fallbackCreation(region: RegionID) -> Creation {
        Creation(
            name: "Spark of Beginning",
            type: .tool,
            traditional: TraditionalStats(damage: 6, durability: 10, weight: 1),
            creative: CreativeStats(originality: 10, usefulness: 40),
            effect: UniqueEffect(kind: .light, magnitude: 0.2, durationSec: 4, cooldownSec: 2, range: 0),
            artDescriptor: "a small, honest light",
            cost: [ResourceAmount(.embers, 1)],
            regionMade: region
        )
    }
}
