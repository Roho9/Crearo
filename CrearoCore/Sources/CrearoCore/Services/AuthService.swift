import Foundation

// Auth contract. Production impl is SupabaseAuthService (Sign in with Apple) in the app layer;
// here we provide the protocol + an in-memory impl for previews/tests (GDD §61).

public struct UserAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var displayName: String?
    public init(id: String, displayName: String? = nil) {
        self.id = id
        self.displayName = displayName
    }
}

public enum AuthError: Error, Equatable, Sendable {
    case notSignedIn
    case appleTokenInvalid
    case backend(String)
}

public protocol AuthService: Sendable {
    var currentUser: UserAccount? { get }
    func signInWithApple(identityToken: String, nonce: String) async throws -> UserAccount
    func restoreSession() async throws -> UserAccount?
    func signOut() async throws
}

/// In-memory auth for previews/tests/offline. Never ships to production.
public final class InMemoryAuthService: AuthService, @unchecked Sendable {
    public private(set) var currentUser: UserAccount?
    private let lock = NSLock()

    public init(user: UserAccount? = nil) { self.currentUser = user }

    public func signInWithApple(identityToken: String, nonce: String) async throws -> UserAccount {
        guard !identityToken.isEmpty else { throw AuthError.appleTokenInvalid }
        let user = UserAccount(id: UUID().uuidString, displayName: "Maker")
        lock.lock(); currentUser = user; lock.unlock()
        return user
    }

    public func restoreSession() async throws -> UserAccount? { currentUser }

    public func signOut() async throws {
        lock.lock(); currentUser = nil; lock.unlock()
    }
}
