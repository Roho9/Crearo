import Foundation

// MARK: - Emergent classes (discovered, never selected — GDD §14)

public enum EmergentClass: String, CaseIterable, Codable, Sendable {
    case forger, mythweaver, wyrdmage, rootspeaker, inkbinder, hollowSpark, wardmaker, relicseer

    public var title: String {
        switch self {
        case .forger: return "Forger"
        case .mythweaver: return "Mythweaver"
        case .wyrdmage: return "Wyrdmage"
        case .rootspeaker: return "Rootspeaker"
        case .inkbinder: return "Inkbinder"
        case .hollowSpark: return "Hollow Spark"
        case .wardmaker: return "Wardmaker"
        case .relicseer: return "Relicseer"
        }
    }

    /// The modality that most signals this class lean (used for emergence inference, GDD §14).
    public var signalModality: Modality {
        switch self {
        case .forger: return .building
        case .mythweaver: return .writing
        case .wyrdmage: return .gesture
        case .rootspeaker: return .sound
        case .inkbinder: return .drawing
        case .hollowSpark: return .mixed
        case .wardmaker: return .building
        case .relicseer: return .photo
        }
    }
}

// MARK: - Regions (GDD §9)

public enum RegionID: String, CaseIterable, Codable, Sendable {
    case lastlight, mirrorwood, hushMire, greymarch, emberreach, theLull, theUnwritten

    public var displayName: String {
        switch self {
        case .lastlight: return "Lastlight"
        case .mirrorwood: return "The Mirrorwood"
        case .hushMire: return "The Hush Mire"
        case .greymarch: return "The Leaden Court / Greymarch"
        case .emberreach: return "The Emberreach Highlands"
        case .theLull: return "The Lull"
        case .theUnwritten: return "The Unwritten"
        }
    }

    /// The creative dimension the region pressures / teaches (GDD §9).
    public var dominantDimension: CreativeDimension? {
        switch self {
        case .lastlight: return .elaboration
        case .mirrorwood: return .originality
        case .hushMire: return .flexibility
        case .greymarch: return .riskTaking
        case .emberreach: return .usefulness
        case .theLull: return .emotionalExpression
        case .theUnwritten: return nil  // tests the player's weakest, personalized
        }
    }
}

// MARK: - Player character (begins blank; GDD §12)

public struct PlayerCharacter: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var title: String
    public var level: Int
    public var classAffinities: [String: Double]   // EmergentClass.rawValue -> 0...1
    public var symbolicObjectName: String?
    public var sigilDescriptor: String?
    public var backstory: String?

    public init(id: UUID = UUID(), name: String, title: String = "a Maker", level: Int = 1,
                classAffinities: [String: Double] = [:], symbolicObjectName: String? = nil,
                sigilDescriptor: String? = nil, backstory: String? = nil) {
        self.id = id
        self.name = name
        self.title = title
        self.level = level
        self.classAffinities = classAffinities
        self.symbolicObjectName = symbolicObjectName
        self.sigilDescriptor = sigilDescriptor
        self.backstory = backstory
    }

    /// The class that has emerged most strongly, if any has crossed the recognition threshold.
    public func dominantClass(threshold: Double = 0.4) -> EmergentClass? {
        guard let best = classAffinities.max(by: { $0.value < $1.value }),
              best.value >= threshold else { return nil }
        return EmergentClass(rawValue: best.key)
    }
}

// MARK: - Companion (GDD §18–19, §55)

/// Companion tone axes 0...1, assembled from the player's creative style.
public struct ToneVector: Codable, Equatable, Sendable {
    public var playfulness: Double
    public var somberness: Double
    public var warmth: Double
    public var strangeness: Double

    public init(playfulness: Double = 0.5, somberness: Double = 0.5, warmth: Double = 0.5, strangeness: Double = 0.5) {
        self.playfulness = playfulness
        self.somberness = somberness
        self.warmth = warmth
        self.strangeness = strangeness
    }
}

public struct Companion: Codable, Equatable, Sendable {
    public var name: String
    public var tone: ToneVector
    public var brightness: Double          // dims with neglect 0...1 (GDD §32)
    public var rememberedCreations: [String]
    public var formTraits: [String]        // accreted features from creations (color/horns/texture)

    public init(name: String = "", tone: ToneVector = ToneVector(), brightness: Double = 1.0,
                rememberedCreations: [String] = [], formTraits: [String] = []) {
        self.name = name
        self.tone = tone
        self.brightness = brightness
        self.rememberedCreations = rememberedCreations
        self.formTraits = formTraits
    }

    public mutating func remember(_ creationName: String, max: Int = 8) {
        rememberedCreations.append(creationName)
        if rememberedCreations.count > max { rememberedCreations.removeFirst(rememberedCreations.count - max) }
    }
}

// MARK: - Home base (GDD §47–48)

public struct HomeRoom: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: String       // "hearth", "library", "forge", "greenhouse", "gallery"...
    public var corruption: Double // 0...1

    public init(id: UUID = UUID(), name: String, kind: String, corruption: Double = 0) {
        self.id = id
        self.name = name
        self.kind = kind
        self.corruption = corruption
    }
}

public struct HomeBase: Codable, Equatable, Sendable {
    public var rooms: [HomeRoom]
    public var corruptionLevel: Double          // aggregate 0...1
    public var lastMeaningfulActivity: Date

    public init(rooms: [HomeRoom] = [], corruptionLevel: Double = 0, lastMeaningfulActivity: Date = Date()) {
        self.rooms = rooms
        self.corruptionLevel = corruptionLevel
        self.lastMeaningfulActivity = lastMeaningfulActivity
    }
}

// MARK: - Badges / Marks (GDD §43)

public struct Badge: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var markName: String          // e.g. "Mark of the Unrepeating"
    public var dimension: CreativeDimension
    public var earnedAt: Date

    public init(id: String = UUID().uuidString, markName: String, dimension: CreativeDimension, earnedAt: Date = Date()) {
        self.id = id
        self.markName = markName
        self.dimension = dimension
        self.earnedAt = earnedAt
    }
}

// MARK: - Aggregate world state (persisted local + cloud; GDD §36, §61)

public struct WorldState: Codable, Equatable, Sendable {
    public var character: PlayerCharacter
    public var companion: Companion
    public var profile: CreativeProfile
    public var wallet: ResourceWallet
    public var creations: [Creation]
    public var home: HomeBase
    public var badges: [Badge]
    public var unlockedRegions: [RegionID]
    public var updatedAt: Date

    public init(character: PlayerCharacter, companion: Companion, profile: CreativeProfile = CreativeProfile(),
                wallet: ResourceWallet = ResourceWallet(), creations: [Creation] = [],
                home: HomeBase = HomeBase(), badges: [Badge] = [],
                unlockedRegions: [RegionID] = [.lastlight, .mirrorwood], updatedAt: Date = Date()) {
        self.character = character
        self.companion = companion
        self.profile = profile
        self.wallet = wallet
        self.creations = creations
        self.home = home
        self.badges = badges
        self.unlockedRegions = unlockedRegions
        self.updatedAt = updatedAt
    }

    /// Bootstrap a fresh game after the opening sequence (GDD §10).
    public static func newGame(characterName: String, companionName: String) -> WorldState {
        let character = PlayerCharacter(name: characterName)
        let companion = Companion(name: companionName, brightness: 0.4) // wakes dim, brightens with making
        let hearth = HomeRoom(name: "The Hearth Room", kind: "hearth")
        let home = HomeBase(rooms: [hearth])
        var wallet = ResourceWallet()
        wallet.earn(.embers, 12)  // a small starting spark
        return WorldState(character: character, companion: companion, wallet: wallet, home: home)
    }
}
