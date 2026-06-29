import Foundation

// MARK: - The nine creative resources (GDD §28–30)

public enum Resource: String, CaseIterable, Codable, Sendable {
    case embers, musefire, dreamsteel, ink, essence, willpower, memoryShards, moonThread, hollowSparks

    public var displayName: String {
        switch self {
        case .embers: return "Embers"
        case .musefire: return "Musefire"
        case .dreamsteel: return "Dreamsteel"
        case .ink: return "Ink"
        case .essence: return "Essence"
        case .willpower: return "Willpower"
        case .memoryShards: return "Memory Shards"
        case .moonThread: return "Moon Thread"
        case .hollowSparks: return "Hollow Sparks"
        }
    }

    /// Soft mapping of a resource to the creative dimension it most expresses (GDD §29).
    /// Used so a missing dimension surfaces as a resource shortage the companion can nudge.
    public var tiedDimension: CreativeDimension? {
        switch self {
        case .embers: return nil               // baseline energy, untied
        case .musefire: return .originality
        case .dreamsteel: return .symbolicThinking
        case .ink: return .elaboration         // visual detail
        case .essence: return .emotionalExpression
        case .willpower: return .riskTaking
        case .memoryShards: return .symbolicThinking
        case .moonThread: return .usefulness   // elegance / refinement
        case .hollowSparks: return .originality // strangeness
        }
    }
}

/// A typed (resource, amount) pair. Used for costs so Codable stays an explicit array
/// (avoids enum-keyed-dictionary JSON quirks).
public struct ResourceAmount: Codable, Equatable, Sendable {
    public let resource: Resource
    public let amount: Int
    public init(_ resource: Resource, _ amount: Int) {
        self.resource = resource
        self.amount = amount
    }
}

public enum EconomyError: Error, Equatable, Sendable {
    case insufficientResources([ResourceAmount]) // the shortfall
}

/// The player's visible wallet (GDD §28). Amounts never go negative.
public struct ResourceWallet: Equatable, Sendable {
    private var amounts: [Resource: Int]

    public init(_ amounts: [Resource: Int] = [:]) {
        var a: [Resource: Int] = [:]
        for r in Resource.allCases { a[r] = max(0, amounts[r] ?? 0) }
        self.amounts = a
    }

    public subscript(_ r: Resource) -> Int {
        get { amounts[r] ?? 0 }
        set { amounts[r] = max(0, newValue) }
    }

    public func canAfford(_ cost: [ResourceAmount]) -> Bool {
        cost.allSatisfy { self[$0.resource] >= $0.amount }
    }

    public mutating func earn(_ resource: Resource, _ n: Int) {
        self[resource] = self[resource] + max(0, n)
    }

    public mutating func earn(_ bundle: [ResourceAmount]) {
        for item in bundle { earn(item.resource, item.amount) }
    }

    /// Spend a cost atomically. Throws (and changes nothing) if unaffordable.
    public mutating func spend(_ cost: [ResourceAmount]) throws {
        guard canAfford(cost) else {
            let shortfall = cost.compactMap { item -> ResourceAmount? in
                let missing = item.amount - self[item.resource]
                return missing > 0 ? ResourceAmount(item.resource, missing) : nil
            }
            throw EconomyError.insufficientResources(shortfall)
        }
        for item in cost { self[item.resource] = self[item.resource] - item.amount }
    }
}

// Codable mapping to a [String:Int] object keyed by raw values (clean JSON).
extension ResourceWallet: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode([String: Int].self)
        var a: [Resource: Int] = [:]
        for (k, v) in raw { if let r = Resource(rawValue: k) { a[r] = max(0, v) } }
        self.init(a)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        var raw: [String: Int] = [:]
        for r in Resource.allCases { raw[r.rawValue] = self[r] }
        try container.encode(raw)
    }
}

// MARK: - Cost model

/// Pure cost calculation. Costs scale with power, rarity, and complexity so that more
/// powerful / unusual / world-changing ideas cost more (creativity under constraint, GDD §28/§34).
public enum Economy {
    public static func cost(power: Double, rarity: Double, complexity: Double, level: Int) -> [ResourceAmount] {
        let p = max(0, power), r = clamp01(rarity), c = clamp01(complexity)
        var out: [ResourceAmount] = []

        let embers = max(1, Int((4 + p * 8).rounded()))
        out.append(ResourceAmount(.embers, embers))

        if r > 0.45 { out.append(ResourceAmount(.musefire, max(1, Int((r * 6).rounded())))) }
        if c > 0.45 { out.append(ResourceAmount(.dreamsteel, max(1, Int((c * 4).rounded())))) }
        if r > 0.80 { out.append(ResourceAmount(.hollowSparks, 1)) }   // rare/strange ideas cost the scarce stuff

        return out
    }
}
