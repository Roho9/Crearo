import Foundation

/// Authored neighborhoods of Prism. Region identity is independent of a player's calendar day.
public enum ChallengeRegion: String, CaseIterable, Codable, Sendable {
    case prism, pocketPark, ribbonMarket, paperHarbor

    public var title: String {
        switch self {
        case .prism: return "Prism"
        case .pocketPark: return "Pocket Park"
        case .ribbonMarket: return "Ribbon Market"
        case .paperHarbor: return "Paper Harbor"
        }
    }

    public var subtitle: String {
        switch self {
        case .prism: return "Help a still world remember how to play."
        case .pocketPark: return "Little visitors. Wonderfully big possibilities."
        case .ribbonMarket: return "A lively market with room for another way."
        case .paperHarbor: return "Fold new possibilities into a welcoming shore."
        }
    }

    public var challengeCount: Int { self == .prism ? 12 : 4 }

    public var firstLevel: Int {
        switch self {
        case .prism: return 1
        case .pocketPark: return 13
        case .ribbonMarket: return 17
        case .paperHarbor: return 21
        }
    }
}

/// An authored obstacle, rather than a guess extracted from a chapter's title.
public enum ChallengeObstacle: String, CaseIterable, Codable, Sendable {
    case pedestal, gap, creature, door, tree, vines, cave, pond, giant, statue
    case picnic, gate, parade, shade, stall, deliveries, balloons, queue
    case boat, map, lighthouse, visitor

    /// A readable exact target shared by the scene director and Paper Theatre renderer.
    public var sceneTarget: String {
        switch self {
        case .pedestal: return "the still world"
        case .gap: return "the wide canyon"
        case .creature: return "the Grumble"
        case .door: return "the handleless doors"
        case .tree: return "the lantern tree"
        case .vines: return "the tangled vines"
        case .cave: return "the echo cave"
        case .pond: return "the riddle pond"
        case .giant: return "the sleepy giant"
        case .statue: return "the grey statue"
        case .picnic: return "the sliding picnic blanket"
        case .gate: return "the tiny park gate"
        case .parade: return "the quiet park parade"
        case .shade: return "the sunlit picnic benches"
        case .stall: return "the bakery stall without a sign"
        case .deliveries: return "the tangled market deliveries"
        case .balloons: return "the balloon animals at the low arch"
        case .queue: return "the market waiting line"
        case .boat: return "the folding paper boat"
        case .map: return "the harbor map with holes"
        case .lighthouse: return "the inward-looking lighthouse"
        case .visitor: return "the floating harbor visitor"
        }
    }
}

/// A challenge's day ID is retained for save compatibility. `contentID` identifies the authored
/// puzzle across days, so future comparisons can match people on the same actual problem.
public struct DailyChallenge: Identifiable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
    public let setup: String
    public let goal: String
    public let question: String
    public let placeholder: String
    public let focusDimension: CreativeDimension?
    public let contentID: String
    public let region: ChallengeRegion
    public let obstacle: ChallengeObstacle
    public let constraint: String
    public let hint: String
    public let revisionPrompt: String
    public let practiceContext: PracticeChallengeContext
    public let regionIndex: Int
    public let sceneTarget: String

    public var regionTitle: String { region.title }
    public var regionCount: Int { region.challengeCount }

    public init(id: String, level: Int, title: String, setup: String, goal: String,
                question: String, placeholder: String, focusDimension: CreativeDimension?,
                contentID: String = "", region: ChallengeRegion = .prism,
                obstacle: ChallengeObstacle = .pedestal, constraint: String = "",
                hint: String = "", revisionPrompt: String = "",
                practiceContext: PracticeChallengeContext? = nil, regionIndex: Int = 1,
                sceneTarget: String? = nil) {
        self.id = id
        self.level = level
        self.title = title
        self.setup = setup
        self.goal = goal
        self.question = question
        self.placeholder = placeholder
        self.focusDimension = focusDimension
        self.contentID = contentID.isEmpty
            ? title.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: "-")
            : contentID
        self.region = region
        self.obstacle = obstacle
        self.constraint = constraint.isEmpty ? goal : constraint
        self.hint = hint.isEmpty ? "What could you change about the situation, instead of your first solution?" : hint
        self.revisionPrompt = revisionPrompt.isEmpty ? "Explain how your idea gets from its first step to the goal." : revisionPrompt
        self.practiceContext = practiceContext ?? PracticeChallengeContext(goal: goal, goalTerms: [], mechanismTerms: [])
        self.regionIndex = regionIndex
        self.sceneTarget = sceneTarget ?? obstacle.sceneTarget
    }

    public var focus: DimensionScores {
        var weights = DimensionScores.uniform
        if let dimension = focusDimension { weights[dimension] = 2 }
        return weights
    }

    public var passMark: Int { LevelGate.passMark(forLevel: level) }
}
