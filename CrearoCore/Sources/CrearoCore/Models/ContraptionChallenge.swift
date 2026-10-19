import Foundation

/// Shared, stable art IDs for the eight modular objects in the surreal workshop.
public enum ContraptionPart: String, CaseIterable, Codable, Identifiable, Sendable {
    case fan, bell, spring, mirror, sail, magnet, wheel, seed

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbolName: String {
        switch self {
        case .fan: return "fan"
        case .bell: return "bell.fill"
        case .spring: return "arrow.up.and.down"
        case .mirror: return "sparkle"
        case .sail: return "sailboat.fill"
        case .magnet: return "link"
        case .wheel: return "circle.hexagongrid.fill"
        case .seed: return "leaf.fill"
        }
    }
    public var detail: String {
        switch self {
        case .fan: return "A gust with somewhere to be. Strong lift and movement."
        case .bell: return "A noise you can hold. Strong signal; a little care."
        case .spring: return "A compressed tomorrow. Strong lift and movement."
        case .mirror: return "A window looking back. Strong reach and signal."
        case .sail: return "A pocket for the sky. Reach, lift, and a gentle touch."
        case .magnet: return "An invisible handshake. Strong movement."
        case .wheel: return "A circle that refuses to sit still. Movement, reach, and care."
        case .seed: return "A very small future. Strong care; a little reach and lift."
        }
    }
    public var capabilities: ContraptionCapabilities {
        switch self {
        case .fan: return .init(lift: 3, reach: 1, signal: 0, motion: 2, care: 0)
        case .bell: return .init(lift: 0, reach: 1, signal: 3, motion: 0, care: 1)
        case .spring: return .init(lift: 3, reach: 1, signal: 0, motion: 3, care: 0)
        case .mirror: return .init(lift: 0, reach: 3, signal: 3, motion: 0, care: 0)
        case .sail: return .init(lift: 2, reach: 3, signal: 0, motion: 1, care: 1)
        case .magnet: return .init(lift: 1, reach: 1, signal: 1, motion: 3, care: 0)
        case .wheel: return .init(lift: 0, reach: 2, signal: 1, motion: 3, care: 1)
        case .seed: return .init(lift: 1, reach: 2, signal: 0, motion: 0, care: 3)
        }
    }
    /// An authored mechanical family, used only for the visible part-range bonus.
    public var primaryCapability: ContraptionCapability {
        switch self {
        case .fan: return .lift
        case .bell: return .signal
        case .spring, .magnet, .wheel: return .motion
        case .mirror, .sail: return .reach
        case .seed: return .care
        }
    }
    public func contribution(in slot: ContraptionSlot) -> ContraptionCapabilities {
        var values = capabilities
        for capability in ContraptionCapability.allCases {
            values[capability] *= slot.multiplier(for: capability)
        }
        return values
    }
}

public enum ContraptionCapability: String, CaseIterable, Codable, Identifiable, Sendable {
    case lift, reach, signal, motion, care
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var meaning: String {
        switch self {
        case .lift: return "Raise or support a load."
        case .reach: return "Bridge distance or guide an effect."
        case .signal: return "Carry light, sound, or a message."
        case .motion: return "Move or drive the mechanism."
        case .care: return "Protect what is fragile."
        }
    }
}

public struct ContraptionCapabilities: Codable, Equatable, Sendable {
    public var lift: Int
    public var reach: Int
    public var signal: Int
    public var motion: Int
    public var care: Int

    public init(lift: Int = 0, reach: Int = 0, signal: Int = 0, motion: Int = 0, care: Int = 0) {
        self.lift = lift; self.reach = reach; self.signal = signal; self.motion = motion; self.care = care
    }
    public subscript(_ capability: ContraptionCapability) -> Int {
        get {
            switch capability {
            case .lift: return lift
            case .reach: return reach
            case .signal: return signal
            case .motion: return motion
            case .care: return care
            }
        }
        set {
            switch capability {
            case .lift: lift = newValue
            case .reach: reach = newValue
            case .signal: signal = newValue
            case .motion: motion = newValue
            case .care: care = newValue
            }
        }
    }
    public func adding(_ other: Self) -> Self {
        .init(lift: lift + other.lift, reach: reach + other.reach, signal: signal + other.signal,
              motion: motion + other.motion, care: care + other.care)
    }
}

public enum ContraptionSlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case anchor, engine, twist
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var purpose: String {
        switch self {
        case .anchor: return "Doubles reach + care."
        case .engine: return "Doubles lift + motion."
        case .twist: return "Doubles signal."
        }
    }
    public func multiplier(for capability: ContraptionCapability) -> Int {
        switch (self, capability) {
        case (.anchor, .reach), (.anchor, .care), (.engine, .lift), (.engine, .motion), (.twist, .signal): return 2
        default: return 1
        }
    }
}

public struct ContraptionRecipe: Codable, Equatable, Sendable {
    public var anchor: ContraptionPart?
    public var engine: ContraptionPart?
    public var twist: ContraptionPart?
    public init(anchor: ContraptionPart? = nil, engine: ContraptionPart? = nil, twist: ContraptionPart? = nil) {
        self.anchor = anchor; self.engine = engine; self.twist = twist
    }
    public subscript(_ slot: ContraptionSlot) -> ContraptionPart? {
        get {
            switch slot {
            case .anchor: return anchor
            case .engine: return engine
            case .twist: return twist
            }
        }
        set {
            switch slot {
            case .anchor: anchor = newValue
            case .engine: engine = newValue
            case .twist: twist = newValue
            }
        }
    }
    public var parts: [ContraptionPart] { ContraptionSlot.allCases.compactMap { self[$0] } }
    public var isComplete: Bool { parts.count == ContraptionSlot.allCases.count }
    public var hasDistinctParts: Bool { Set(parts).count == parts.count }
    public var signature: String { ContraptionSlot.allCases.map { self[$0]?.rawValue ?? "_" }.joined(separator: ":") }
    public var capabilities: ContraptionCapabilities {
        ContraptionSlot.allCases.reduce(.init()) { total, slot in
            total.adding(self[slot]?.contribution(in: slot) ?? .init())
        }
    }
    /// Selecting an object already in another slot swaps it with this slot's object.
    /// Moving it into an empty slot leaves its previous slot empty. There is only one of each object.
    public mutating func place(_ part: ContraptionPart?, in slot: ContraptionSlot) {
        if let part, let previous = ContraptionSlot.allCases.first(where: { $0 != slot && self[$0] == part }) {
            self[previous] = self[slot]
        }
        self[slot] = part
    }
    public func placing(_ part: ContraptionPart?, in slot: ContraptionSlot) -> Self {
        var copy = self; copy.place(part, in: slot); return copy
    }
}

public struct ContraptionRequirement: Codable, Equatable, Sendable {
    public let capability: ContraptionCapability
    public let minimum: Int
    public init(_ capability: ContraptionCapability, atLeast minimum: Int) {
        self.capability = capability; self.minimum = max(1, minimum)
    }
    public var text: String { "\(capability.title) \(minimum)+" }
}

public enum ContraptionConstraint: Codable, Equatable, Sendable {
    case excludedPart(ContraptionPart, reason: String)
    case maximum(ContraptionCapability, value: Int, reason: String)
    case excludedSlot(ContraptionPart, ContraptionSlot, reason: String)
    public var text: String {
        switch self {
        case let .excludedPart(part, reason): return "No \(part.title.lowercased()). \(reason)"
        case let .maximum(capability, value, reason): return "\(capability.title) at most \(value). \(reason)"
        case let .excludedSlot(part, slot, reason): return "No \(part.title.lowercased()) in \(slot.title.lowercased()). \(reason)"
        }
    }
}

/// Six finite authored stations. IDs also identify the corresponding surreal scene composition.
public struct ContraptionChallenge: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
    public let subtitle: String
    public let brief: String
    public let goal: String
    public let writingPrompt: String
    public let hint: String
    public let requirements: [ContraptionRequirement]
    public let constraints: [ContraptionConstraint]
    public var constraintText: String { constraints.map(\.text).joined(separator: " ") }
    public var ruleText: String { requirements.map(\.text).joined(separator: " · ") }

    public static let catalog: [Self] = [
        .init(id: "noise-post", level: 1, title: "Mail a noise", subtitle: "The Unheard Post Office",
              brief: "A very long gap. A very small hello. The postmaster has misplaced the concept of letters.",
              goal: "Send a signal across the gap with a moving contraption.",
              writingPrompt: "In one short sentence, tell us what travels and how your three objects send it.",
              hint: "The anchor doubles reach. A bell or mirror in the twist doubles signal. Try more than one kind of messenger.",
              requirements: [.init(.reach, atLeast: 8), .init(.signal, atLeast: 6), .init(.motion, atLeast: 4)], constraints: []),
        .init(id: "sleeping-moon", level: 2, title: "Lift a sleeping moon", subtitle: "Department of Night Weight",
              brief: "The moon fell asleep on the pavement. Morning would like its street back.",
              goal: "Lift the moon gently without ringing a bell.",
              writingPrompt: "Explain how your contraption lifts the moon and keeps it comfortable.",
              hint: "A seed in the anchor gives six care. Another route puts a sail there and lets the seed add care elsewhere.",
              requirements: [.init(.lift, atLeast: 9), .init(.care, atLeast: 5), .init(.reach, atLeast: 5)],
              constraints: [.excludedPart(.bell, reason: "The moon must stay asleep.")]),
        .init(id: "silent-garden", level: 3, title: "Wake the quiet garden", subtitle: "The Almost Botanical Society",
              brief: "These flowers only open for a dance. Their neighbor is a sleeping volcano.",
              goal: "Make a gentle moving garden with almost no signal.",
              writingPrompt: "Describe the little dance your objects make and how the flowers stay safe.",
              hint: "Keep signal at two or less. Use the anchor's care bonus, then give something a reason to move.",
              requirements: [.init(.care, atLeast: 6), .init(.motion, atLeast: 4), .init(.reach, atLeast: 8)],
              constraints: [.maximum(.signal, value: 2, reason: "The volcano is a very light sleeper.")]),
        .init(id: "rain-redirect", level: 4, title: "Bend the rain", subtitle: "Office of Unscheduled Weather",
              brief: "Rain is falling into an upside-down teacup. A thirsty cloud waits just beyond its rim.",
              goal: "Reach the cloud, raise the rain, and carry it without a wild ride.",
              writingPrompt: "Tell us the route each raindrop takes through your invention.",
              hint: "A sail reaches far. A seed can protect the rain. Too much engine movement will spill it.",
              requirements: [.init(.reach, atLeast: 9), .init(.care, atLeast: 4), .init(.lift, atLeast: 4)],
              constraints: [.maximum(.motion, value: 6, reason: "Faster movement spills the rain.")]),
        .init(id: "cloud-spark", level: 5, title: "Deliver a spark", subtitle: "Bureau of Small Emergencies",
              brief: "A cloud has forgotten how to glow. Its last spark is waiting at a bus stop below.",
              goal: "Move a visible spark up to the cloud without using the spring.",
              writingPrompt: "Explain how the spark gets aboard and how the cloud spots its arrival.",
              hint: "The fan supplies lift. The magnet can move the delivery; a bell or mirror can announce it.",
              requirements: [.init(.lift, atLeast: 7), .init(.signal, atLeast: 5), .init(.motion, atLeast: 6)],
              constraints: [.excludedPart(.spring, reason: "The spark cannot survive a sudden launch.")]),
        .init(id: "tide-stairs", level: 6, title: "Teach the tide to climb", subtitle: "Institute of Impossible Departures",
              brief: "The sea is late for a meeting upstairs. No one has had the heart to explain stairs.",
              goal: "Build a far-reaching, careful moving stairway while keeping the air still.",
              writingPrompt: "Describe how one wave reaches the next step, then what happens to the step behind it.",
              hint: "A sail in the anchor reaches six. A spring, wheel, or magnet can provide movement without a fan.",
              requirements: [.init(.reach, atLeast: 9), .init(.motion, atLeast: 8), .init(.care, atLeast: 3)],
              constraints: [.excludedPart(.fan, reason: "A breeze would flatten the tide's carefully stacked waves.")])
    ]
    public static var catalogCount: Int { catalog.count }
    public static func level(_ number: Int) -> Self? { catalog.first { $0.level == number } }
    public static func challenge(id: String) -> Self? { catalog.first { $0.id == id } }
}

public struct ContraptionJournalEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let challengeID: String
    public let level: Int
    public let title: String
    public let recipe: ContraptionRecipe
    public let explanation: String
    public let score: Int
    public let createdAt: Date
    public init(id: UUID = UUID(), challengeID: String, level: Int, title: String, recipe: ContraptionRecipe,
                explanation: String, score: Int, createdAt: Date = Date()) {
        self.id = id; self.challengeID = challengeID; self.level = level; self.title = title
        self.recipe = recipe; self.explanation = explanation; self.score = min(100, max(0, score)); self.createdAt = createdAt
    }
    public var scoreLabel: String { "Local puzzle score" }
}

public struct ContraptionRecordResult: Equatable, Sendable {
    public let recorded: Bool
    public let wasFirstClear: Bool
    public let isNewBest: Bool
    public let didUnlockNextLevel: Bool
}

/// A separate v1 save for the new workshop. Old story saves are deliberately not overwritten.
public struct ContraptionSave: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let journalLimit = 60
    public let version: Int
    /// Furthest unlocked station; selecting an earlier replay is a separate UI concern.
    public private(set) var currentLevel: Int
    public var partDrafts: [String: ContraptionRecipe]
    public var textDrafts: [String: String]
    public private(set) var bestScores: [String: Int]
    public private(set) var journal: [ContraptionJournalEntry]
    public var isCampaignComplete: Bool { ContraptionChallenge.catalog.allSatisfy { bestScores[$0.id] != nil } }

    public init(partDrafts: [String: ContraptionRecipe] = [:], textDrafts: [String: String] = [:],
                bestScores: [String: Int] = [:], journal: [ContraptionJournalEntry] = []) {
        self.version = Self.currentVersion
        let known = Set(ContraptionChallenge.catalog.map(\.id))
        self.partDrafts = partDrafts.filter { known.contains($0.key) }
        self.textDrafts = textDrafts.filter { known.contains($0.key) }
        self.bestScores = bestScores.filter { known.contains($0.key) && (0...100).contains($0.value) }
        self.journal = Array(journal.filter { entry in
            known.contains(entry.challengeID) && entry.explanation.count <= ContraptionEvaluator.maximumCharacters
                && entry.recipe.isComplete && entry.recipe.hasDistinctParts
        }.suffix(Self.journalLimit))
        self.currentLevel = 1
        while self.currentLevel < ContraptionChallenge.catalogCount,
              let challenge = ContraptionChallenge.level(self.currentLevel), self.bestScores[challenge.id] != nil {
            self.currentLevel += 1
        }
    }

    public mutating func setDraft(recipe: ContraptionRecipe, explanation: String, for challenge: ContraptionChallenge) {
        guard challenge.level <= currentLevel, ContraptionChallenge.challenge(id: challenge.id) == challenge else { return }
        partDrafts[challenge.id] = recipe
        textDrafts[challenge.id] = explanation // Preserve the entire draft; submission enforces the length boundary.
    }

    /// Records only a canonical passing result. Replays may improve a best score or revise a
    /// recipe's journal entry, but a cleared station cannot unlock another station a second time.
    @discardableResult
    public mutating func record(evaluation: ContraptionEvaluation, challenge: ContraptionChallenge,
                                recipe: ContraptionRecipe, explanation: String, date: Date = Date()) -> ContraptionRecordResult {
        let rejected = ContraptionRecordResult(recorded: false, wasFirstClear: false, isNewBest: false, didUnlockNextLevel: false)
        guard challenge.level <= currentLevel, ContraptionChallenge.challenge(id: challenge.id) == challenge,
              evaluation == ContraptionEvaluator().evaluate(challenge: challenge, recipe: recipe, explanation: explanation),
              evaluation.passed else { return rejected }
        let first = bestScores[challenge.id] == nil
        let improved = evaluation.score > (bestScores[challenge.id] ?? -1)
        bestScores[challenge.id] = max(bestScores[challenge.id] ?? 0, evaluation.score)
        let entry = ContraptionJournalEntry(challengeID: challenge.id, level: challenge.level, title: challenge.title,
                                           recipe: recipe, explanation: explanation, score: evaluation.score, createdAt: date)
        if let existing = journal.firstIndex(where: { $0.challengeID == challenge.id && $0.recipe == recipe }) {
            let previous = journal[existing]
            if previous.explanation != explanation || previous.score != evaluation.score {
                journal[existing] = .init(id: previous.id, challengeID: challenge.id, level: challenge.level,
                                         title: challenge.title, recipe: recipe, explanation: explanation,
                                         score: evaluation.score, createdAt: date)
            }
        } else {
            journal.append(entry)
            if journal.count > Self.journalLimit { journal.removeFirst(journal.count - Self.journalLimit) }
        }
        let advances = first && challenge.level == currentLevel && currentLevel < ContraptionChallenge.catalogCount
        if advances { currentLevel += 1 }
        return .init(recorded: true, wasFirstClear: first, isNewBest: improved, didUnlockNextLevel: advances)
    }

    private enum CodingKeys: String, CodingKey { case version, currentLevel, partDrafts, textDrafts, bestScores, journal }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: container, debugDescription: "Unsupported contraption save version: \(version).")
        }
        // Recompute the unlocked station from contiguous clears instead of trusting a stale index.
        self.init(partDrafts: try container.decode([String: ContraptionRecipe].self, forKey: .partDrafts),
                  textDrafts: try container.decode([String: String].self, forKey: .textDrafts),
                  bestScores: try container.decode([String: Int].self, forKey: .bestScores),
                  journal: try container.decode([ContraptionJournalEntry].self, forKey: .journal))
    }
}
