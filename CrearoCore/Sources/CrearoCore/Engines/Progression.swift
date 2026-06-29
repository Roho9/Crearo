import Foundation

// Glue systems that translate the profile into world change: class emergence (§14),
// region unlocks (§46), badges (§43), and absence decay/corruption (§32, §38, §48).

// MARK: - Class emergence (discovered from behavior, never chosen)

public struct ClassEmergence: Sendable {
    public var recognitionThreshold: Double
    public init(recognitionThreshold: Double = 0.4) { self.recognitionThreshold = recognitionThreshold }

    /// Infer class affinities (0...1) from how the player tends to create.
    public func affinities(from profile: CreativeProfile) -> [String: Double] {
        let total = max(1, profile.modalityCounts.values.reduce(0, +))
        var result: [String: Double] = [:]
        for cls in EmergentClass.allCases {
            let modalityShare = Double(profile.modalityCounts[cls.signalModality.rawValue] ?? 0) / Double(total)
            // Blend modality preference with the dimension the class leans on.
            let dimensionBoost: Double
            switch cls {
            case .forger: dimensionBoost = profile.value(.usefulness)
            case .mythweaver: dimensionBoost = profile.value(.symbolicThinking)
            case .wyrdmage: dimensionBoost = profile.value(.flexibility)
            case .rootspeaker: dimensionBoost = profile.value(.emotionalExpression)
            case .inkbinder: dimensionBoost = profile.value(.elaboration)
            case .hollowSpark: dimensionBoost = profile.value(.riskTaking)
            case .wardmaker: dimensionBoost = profile.value(.usefulness)
            case .relicseer: dimensionBoost = profile.value(.originality)
            }
            result[cls.rawValue] = clamp01(0.6 * modalityShare + 0.4 * dimensionBoost)
        }
        return result
    }

    /// The class the world should "recognize" now, if any has crossed threshold.
    public func recognizedClass(from profile: CreativeProfile) -> EmergentClass? {
        let aff = affinities(from: profile)
        guard let best = aff.max(by: { $0.value < $1.value }), best.value >= recognitionThreshold else { return nil }
        return EmergentClass(rawValue: best.key)
    }
}

// MARK: - Region unlocks (gated by demonstrated creative range, not grind; GDD §46)

public enum RegionGates {
    /// Which regions the player has now earned, given their profile.
    public static func unlockedRegions(for profile: CreativeProfile) -> Set<RegionID> {
        var unlocked: Set<RegionID> = [.lastlight, .mirrorwood]
        if profile.value(.flexibility) >= 0.35 { unlocked.insert(.hushMire) }      // ≥2 distinct approaches
        if profile.value(.riskTaking) >= 0.40 { unlocked.insert(.greymarch) }       // a real risk that paid off
        if profile.value(.usefulness) >= 0.45 { unlocked.insert(.emberreach) }
        if profile.value(.emotionalExpression) >= 0.45 { unlocked.insert(.theLull) }
        // The Unwritten opens only when most dimensions are exercised (endgame readiness).
        let exercised = CreativeDimension.allCases.filter { profile.value($0) >= 0.4 }.count
        if exercised >= 6 { unlocked.insert(.theUnwritten) }
        return unlocked
    }
}

// MARK: - Badges / Marks (GDD §43)

public struct BadgeGranter: Sendable {
    public init() {}

    /// Marks newly earned by this act, excluding ones already held.
    public func newBadges(score: CreativityScore, profile: CreativeProfile, existing: [Badge]) -> [Badge] {
        let held = Set(existing.map { $0.id })
        var earned: [Badge] = []
        func grant(_ id: String, _ name: String, _ dim: CreativeDimension, _ condition: Bool) {
            if condition && !held.contains(id) { earned.append(Badge(id: id, markName: name, dimension: dim)) }
        }
        grant("mark.unrepeating", "Mark of the Unrepeating", .flexibility,
              profile.value(.flexibility) >= 0.7 && profile.repetitionRatio < 0.3)
        grant("mark.aching", "Mark of the Aching Light", .emotionalExpression,
              score.dimensions.emotionalExpression >= 0.8)
        grant("mark.firstleap", "Mark of the First Leap", .riskTaking,
              score.dimensions.riskTaking >= 0.8 && score.gate >= 0.6)
        grant("mark.patient", "Mark of the Patient Hand", .elaboration,
              score.dimensions.elaboration >= 0.8)
        grant("mark.commonholy", "Mark of Common Things Made Holy", .originality,
              score.dimensions.originality >= 0.75)
        return earned
    }
}

// MARK: - Decay & corruption (absence + neglected dimensions; GDD §32, §38, §48)

public struct DecayService: Sendable {
    public var graceDays: Double
    public var fullCorruptionDays: Double
    public init(graceDays: Double = 4, fullCorruptionDays: Double = 30) {
        self.graceDays = graceDays
        self.fullCorruptionDays = fullCorruptionDays
    }

    /// Absence severity 0...1 from elapsed time (0 inside the grace period).
    public func absenceSeverity(elapsed: TimeInterval) -> Double {
        let days = elapsed / 86_400
        guard days > graceDays else { return 0 }
        return clamp01((days - graceDays) / (fullCorruptionDays - graceDays))
    }

    /// Compute decay for a creation given absence severity + the player's weakest dimension.
    /// Distortion concentrates on the dimension the maker most neglects (GDD §38).
    public func decay(severity: Double, weakest: CreativeDimension?) -> CreationDecay {
        var distortion = DimensionScores()
        if let w = weakest { distortion[w] = clamp01(severity * 0.8) }
        return CreationDecay(distortion: distortion, dust: severity, glowLoss: clamp01(severity * 0.7))
    }

    /// Apply absence to a whole world-state (reversible; never deletes — GDD §32).
    public func applyAbsence(to state: WorldState, now: Date) -> WorldState {
        var s = state
        let elapsed = now.timeIntervalSince(s.home.lastMeaningfulActivity)
        let severity = absenceSeverity(elapsed: elapsed)
        guard severity > 0 else { return s }

        let weakest = s.profile.weakestDimensions(1).first
        s.home.corruptionLevel = severity
        for i in s.home.rooms.indices { s.home.rooms[i].corruption = max(s.home.rooms[i].corruption, severity * 0.9) }
        s.companion.brightness = clamp01(1 - severity * 0.7)
        let d = decay(severity: severity, weakest: weakest)
        for i in s.creations.indices {
            s.creations[i].decay = d   // reversible via creative restoration quests
        }
        return s
    }

    /// Restoration is a creative act, not a purchase: a good creative act on a creation heals it.
    public func restore(_ creation: Creation, with score: CreativityScore) -> Creation {
        guard score.gate >= 0.4 else { return creation }   // a weak act doesn't restore
        var c = creation
        c.decay = .pristine
        return c
    }
}
