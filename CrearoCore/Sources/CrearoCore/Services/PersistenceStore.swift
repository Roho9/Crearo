import Foundation

// Persistence contract for the player's world-state (local-first, cloud-synced; GDD §36, §61).
// Production impls: SwiftDataStore (local) + SupabasePersistence (cloud) in the app layer.
// Here: the protocol + an in-memory impl for previews/tests.

public protocol PersistenceStore: Sendable {
    func loadWorldState() async throws -> WorldState?
    func save(_ state: WorldState) async throws
    func deleteAll() async throws
}

public final class InMemoryPersistenceStore: PersistenceStore, @unchecked Sendable {
    private var state: WorldState?
    private let lock = NSLock()

    public init(_ initial: WorldState? = nil) { self.state = initial }

    public func loadWorldState() async throws -> WorldState? {
        lock.lock(); defer { lock.unlock() }
        return state
    }

    public func save(_ state: WorldState) async throws {
        lock.lock(); defer { lock.unlock() }
        var s = state
        s.updatedAt = Date()
        self.state = s
    }

    public func deleteAll() async throws {
        lock.lock(); defer { lock.unlock() }
        state = nil
    }
}

// MARK: - JSON codec helpers (shared by file/cloud stores)

public enum WorldStateCodec {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
    public static func data(from state: WorldState) throws -> Data { try encoder().encode(state) }
    public static func state(from data: Data) throws -> WorldState { try decoder().decode(WorldState.self, from: data) }
}
