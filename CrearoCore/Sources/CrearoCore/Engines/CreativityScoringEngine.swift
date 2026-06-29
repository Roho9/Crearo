import Foundation

// The hidden creativity engine. Pure & deterministic given its inputs, so it is fully
// unit-testable. See docs/CREATIVITY_SCORING.md for the research and the math.

public struct ScoringConfig: Sendable {
    /// Below this relevance, the gate collapses regardless of novelty (anti-nonsense, §5).
    public var relevanceFloor: Double = 0.25
    public var fluencySoftCap: Int = 6
    public var flexibilitySoftCap: Int = 4
    public var reframingBonus: Double = 0.15
    /// EWMA learning rate for the profile (small ⇒ stable, hard to swing on one input, §7).
    public var learningRate: Double = 0.18
    public var uncertaintyDecay: Double = 0.12
    public var signatureWindow: Int = 12
    public var baseReward: Double = 10
    public var minMultiplier: Double = 0.2

    public static let `default` = ScoringConfig()
    public init() {}
}

public struct CreativityScoringEngine: Sendable {
    public var config: ScoringConfig
    public init(config: ScoringConfig = .default) { self.config = config }

    // MARK: Stage 1 + 2 — gate then dimensional scoring

    public func score(_ input: ScoringInput) -> CreativityScore {
        let gate = computeGate(input)

        var dims = DimensionScores()

        // Novelty-type dimensions are GATE-MULTIPLIED so novelty without fit ≈ 0 (anti-nonsense).
        let originalitySignal = input.rarityPercentile ?? input.semanticDistance
        dims.originality = gate * clamp01(originalitySignal)
        dims.fluency = gate * normalizeCount(input.ideaCount, soft: config.fluencySoftCap)
        dims.flexibility = gate * normalizeCount(input.distinctCategoryCount, soft: config.flexibilitySoftCap)
        dims.elaboration = gate * clamp01(input.detail)
        dims.emotionalExpression = gate * clamp01(input.emotionalCharge)
        dims.symbolicThinking = gate * clamp01(input.symbolism)
        dims.riskTaking = gate * clamp01(input.riskSignal)

        // Usefulness is the convergent "landing" — it IS the fit, so it is not gate-multiplied
        // (it would double-count). It reflects relevance + functional validity directly.
        dims.usefulness = clamp01((input.functionalValidity + input.relevance) / 2)

        // Reframing is a strong creativity marker → boosts symbolic + flexible thinking.
        if input.reframingDetected {
            dims.symbolicThinking = clamp01(dims.symbolicThinking + config.reframingBonus)
            dims.flexibility = clamp01(dims.flexibility + config.reframingBonus)
        }

        return CreativityScore(
            gate: gate,
            dimensions: dims,
            reframingDetected: input.reframingDetected,
            constraintSatisfied: input.constraintSatisfied,
            effort: clamp01(input.effort)
        )
    }

    /// The relevance/usefulness gate (0...1). Geometric mean emphasizes the WEAKEST of
    /// {relevance, functional validity, coherence}, so a single failing check tanks the gate.
    func computeGate(_ input: ScoringInput) -> Double {
        let r = clamp01(input.relevance)
        let f = clamp01(input.functionalValidity)
        let c = clamp01(input.coherence)
        let eps = 1e-6
        let g = pow(max(r, eps) * max(f, eps) * max(c, eps), 1.0 / 3.0)
        // Hard floor: irrelevant responses can't be rescued by validity/coherence.
        return r < config.relevanceFloor ? min(g, r) : g
    }

    // MARK: Stage 3 — trajectory update (§7)

    public func updatedProfile(_ profile: CreativeProfile, with score: CreativityScore, input: ScoringInput) -> CreativeProfile {
        var p = profile
        // Effort-weighted learning rate: trivial inputs barely move the estimate.
        let w = config.learningRate * (0.5 + 0.5 * score.effort)

        for d in CreativeDimension.allCases {
            var e = p.estimate(d)
            let observed = score.dimensions[d]
            let newValue = clamp01((1 - w) * e.value + w * observed)
            e.trend = newValue - e.value
            e.value = newValue
            e.uncertainty = max(0, e.uncertainty * (1 - config.uncertaintyDecay))
            e.samples += 1
            p.estimates[d.rawValue] = e
        }

        p.modalityCounts[input.modality.rawValue, default: 0] += 1
        p.totalActs += 1

        // Repetition signature for the §35 "are you doing the same thing?" pressure.
        let signature = "\(input.modality.rawValue):\(input.distinctCategoryCount):\(Int((score.dimensions.originality * 10).rounded()))"
        p.recentSolutionSignatures.append(signature)
        if p.recentSolutionSignatures.count > config.signatureWindow {
            p.recentSolutionSignatures.removeFirst(p.recentSolutionSignatures.count - config.signatureWindow)
        }
        return p
    }

    // MARK: Rewards — quality scales payouts (GDD §30, §35)

    /// Per-act reward magnitude. `focus` weights dimensions toward the current quest's intent
    /// (e.g., a flexibility daily weights flexibility). Defaults to uniform weighting.
    public func rewardMultiplier(for score: CreativityScore, focus: DimensionScores = .uniform) -> Double {
        var weighted = 0.0, wsum = 0.0
        for d in CreativeDimension.allCases {
            let weight = focus[d]
            weighted += weight * score.dimensions[d]
            wsum += weight
        }
        let base = wsum > 0 ? weighted / wsum : score.dimensions.average
        return config.baseReward * score.gate * (config.minMultiplier + (1 - config.minMultiplier) * base)
    }

    /// Translate a reward magnitude + the act's character into actual earned resources.
    /// Higher originality pays the rarer resources; emotion pays Essence; etc. (GDD §29).
    public func resourceReward(for score: CreativityScore, focus: DimensionScores = .uniform) -> [ResourceAmount] {
        let magnitude = rewardMultiplier(for: score, focus: focus)
        var out: [ResourceAmount] = [ResourceAmount(.embers, max(1, Int(magnitude.rounded())))]
        let d = score.dimensions
        if d.originality > 0.5 { out.append(ResourceAmount(.musefire, max(1, Int((d.originality * 5).rounded())))) }
        if d.emotionalExpression > 0.5 { out.append(ResourceAmount(.essence, max(1, Int((d.emotionalExpression * 4).rounded())))) }
        if d.riskTaking > 0.6 { out.append(ResourceAmount(.willpower, max(1, Int((d.riskTaking * 3).rounded())))) }
        if d.originality > 0.85 { out.append(ResourceAmount(.hollowSparks, 1)) }
        return out
    }
}
