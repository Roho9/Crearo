import Foundation

// Builds the totally-personalized final boss from the player's hidden profile (GDD §50–51).
// The boss is the "Sameness" wearing the mask of the player's specific creative weaknesses.

public struct BossPhase: Codable, Equatable, Sendable {
    public let targetsDimension: CreativeDimension
    public let name: String          // the diegetic phase name (e.g., "The Echo Choir")
    public let winCondition: String  // what the player must DO to clear it
    public init(targetsDimension: CreativeDimension, name: String, winCondition: String) {
        self.targetsDimension = targetsDimension
        self.name = name
        self.winCondition = winCondition
    }
}

public struct PersonalizedBoss: Codable, Equatable, Sendable {
    public let phases: [BossPhase]
    public let mirroredModality: Modality?  // the boss reflects the player's most-overused input
    public let taunt: String                // personalized, references named creations
    public init(phases: [BossPhase], mirroredModality: Modality?, taunt: String) {
        self.phases = phases
        self.mirroredModality = mirroredModality
        self.taunt = taunt
    }
}

public struct BossComposer: Sendable {
    public init() {}

    public func compose(from profile: CreativeProfile, namedCreations: [String]) -> PersonalizedBoss {
        let weak = profile.weakestDimensions(3)
        let phases = weak.map { d in
            BossPhase(targetsDimension: d, name: Self.phaseName(d), winCondition: Self.winCondition(d))
        }
        return PersonalizedBoss(
            phases: phases,
            mirroredModality: profile.dominantModality,
            taunt: Self.taunt(namedCreations: namedCreations)
        )
    }

    // Mapping mirrors GDD §51.
    static func phaseName(_ d: CreativeDimension) -> String {
        switch d {
        case .originality: return "The Echo Choir"
        case .elaboration: return "The Unfinished"
        case .flexibility: return "The Single Road"
        case .riskTaking: return "The Sealed Door"
        case .usefulness: return "The Beautiful Wreck"
        case .emotionalExpression: return "The Cold Mirror"
        case .symbolicThinking: return "The Mute Glyph"
        case .fluency: return "The Drought"
        }
    }

    static func winCondition(_ d: CreativeDimension) -> String {
        switch d {
        case .originality: return "Present something it has never catalogued. Predictability deals zero."
        case .elaboration: return "Wound it only with richly detailed, multi-layered creations."
        case .flexibility: return "Solve the same obstacle three distinct ways in sequence."
        case .riskTaking: return "It opens only to a bold, unhedged leap. Safe actions do not register."
        case .usefulness: return "Only creations that are original AND actually function can pass its traps."
        case .emotionalExpression: return "Logic and force pass through it; only genuine feeling lands."
        case .symbolicThinking: return "Answer it in metaphor and symbol, not literal terms."
        case .fluency: return "Flood it with many varied ideas faster than it can drink them."
        }
    }

    static func taunt(namedCreations: [String]) -> String {
        guard let last = namedCreations.last else {
            return "You made so little of yourself that I had to imagine the rest. Let me show you what you avoided."
        }
        let repeated = namedCreations.suffix(3).joined(separator: ", the ")
        return "You made the \(last), and the \(repeated) again. I am every idea you were too afraid to have."
    }
}
