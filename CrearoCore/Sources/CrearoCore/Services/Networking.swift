import Foundation

// The networking CONTRACT only. The concrete URLSession/Supabase client lives in the app layer
// (CrearoApp/Services) so CrearoCore stays Foundation-pure and Linux-testable
// (see docs/TECH_ARCHITECTURE.md §3, §9).

public struct Endpoint: Sendable {
    public enum Method: String, Sendable { case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE" }

    public var path: String
    public var method: Method
    public var body: Data?
    public var headers: [String: String]
    public var query: [String: String]

    public init(path: String, method: Method = .get, body: Data? = nil,
                headers: [String: String] = [:], query: [String: String] = [:]) {
        self.path = path
        self.method = method
        self.body = body
        self.headers = headers
        self.query = query
    }
}

public enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case transport(String)
    case http(status: Int)
    case decoding(String)
    case unauthorized
}

public protocol APIClient: Sendable {
    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func send(_ endpoint: Endpoint) async throws            // fire-and-forget (no decodable body)
}

public extension APIClient {
    func send(_ endpoint: Endpoint) async throws {
        _ = try await send(endpoint, as: EmptyResponse.self)
    }
}

public struct EmptyResponse: Decodable, Sendable { public init() {} }
