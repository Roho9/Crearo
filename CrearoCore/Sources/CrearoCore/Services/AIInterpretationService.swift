import Foundation

// Turns a player's free creative expression into a balanced, art-styled, named in-world object.
// The REAL implementation calls the `interpret-idea` Supabase Edge Function (keys off-device);
// this file defines the contract + DTOs + a deterministic offline stub for previews/tests.
// See docs/TECH_ARCHITECTURE.md §6 and GDD §33.

/// Raw idea captured from the player (text / transcript / media reference).
public struct IdeaInput: Codable, Equatable, Sendable {
    public let promptID: String
    public let modality: Modality
    public let text: String?       // typed text or speech-to-text transcript
    public let mediaRef: String?   // storage id/URL for a drawing or photo

    public init(promptID: String, modality: Modality, text: String? = nil, mediaRef: String? = nil) {
        self.promptID = promptID
        self.modality = modality
        self.text = text
        self.mediaRef = mediaRef
    }
}

/// Context the interpreter needs to fit an idea to the current game (level, region, resources, class, profile).
public struct CreationContext: Codable, Equatable, Sendable {
    public let level: Int
    public let region: RegionID
    public let walletSnapshot: [ResourceAmount]
    public let dominantClass: EmergentClass?
    public let constraint: String?
    public let profileSummary: DimensionScores

    public init(level: Int, region: RegionID, walletSnapshot: [ResourceAmount] = [],
                dominantClass: EmergentClass? = nil, constraint: String? = nil,
                profileSummary: DimensionScores = .zero) {
        self.level = level
        self.region = region
        self.walletSnapshot = walletSnapshot
        self.dominantClass = dominantClass
        self.constraint = constraint
        self.profileSummary = profileSummary
    }
}

/// The LLM's proposal (pre-balance). Mirrors the Edge Function JSON schema EXCEPT creative stats,
/// which are derived authoritatively from the hidden score (see Creation.assemble / CreativeStats).
public struct InterpretedIdea: Codable, Equatable, Sendable {
    public var itemType: ItemType
    public var traditional: TraditionalStats
    public var effect: UniqueEffect
    public var artDescriptor: String
    public var suggestedName: String

    public init(itemType: ItemType, traditional: TraditionalStats, effect: UniqueEffect,
                artDescriptor: String, suggestedName: String) {
        self.itemType = itemType
        self.traditional = traditional
        self.effect = effect
        self.artDescriptor = artDescriptor
        self.suggestedName = suggestedName
    }
}

public protocol AIInterpretationService: Sendable {
    func interpret(_ idea: IdeaInput, context: CreationContext) async throws -> InterpretedIdea
}

/// Deterministic, offline interpreter so the app runs with no backend (and tests are stable).
/// Naive keyword→effect mapping; the production service replaces this with the Edge Function.
public struct StubAIInterpretationService: AIInterpretationService {
    public init() {}

    public func interpret(_ idea: IdeaInput, context: CreationContext) async throws -> InterpretedIdea {
        let text = (idea.text ?? "").lowercased()

        let effect: UniqueEffect
        let type: ItemType
        let art: String

        if text.contains("honey") || text.contains("slow") || text.contains("resin") {
            effect = UniqueEffect(kind: .slow, magnitude: 0.3, durationSec: 3, cooldownSec: 4, range: 0)
            type = .weapon
            art = "dark-fantasy blade wrapped in beeswax, dripping amber resin"
        } else if text.contains("fear") || text.contains("scare") || text.contains("nightmare") {
            effect = UniqueEffect(kind: .fear, magnitude: 0.25, durationSec: 2.5, cooldownSec: 5, range: 3)
            type = .spell
            art = "a guttering violet light that shows enemies their own shadow"
        } else if text.contains("shield") || text.contains("protect") || text.contains("ward") {
            effect = UniqueEffect(kind: .shield, magnitude: 0.4, durationSec: 5, cooldownSec: 6, range: 0)
            type = .armor
            art = "a lantern-shield of warm, stubborn glass"
        } else if text.contains("light") || text.contains("lantern") || text.contains("lamp") {
            effect = UniqueEffect(kind: .light, magnitude: 0.5, durationSec: 6, cooldownSec: 2, range: 4)
            type = .tool
            art = "a small lantern that the fog cannot drink"
        } else {
            effect = .none
            type = .tool
            art = "a curious dark-fantasy implement of uncertain purpose"
        }

        let name = Self.titleCase(idea.text) ?? "Nameless Making"
        return InterpretedIdea(
            itemType: type,
            traditional: TraditionalStats(damage: type == .weapon ? 22 : 6,
                                          defense: type == .armor ? 18 : 2,
                                          speed: 10, durability: 30, weight: 3),
            effect: effect,
            artDescriptor: art,
            suggestedName: name
        )
    }

    static func titleCase(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let words = s.split(separator: " ").prefix(4)
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
