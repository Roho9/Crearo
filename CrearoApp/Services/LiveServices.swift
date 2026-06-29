import Foundation
import CrearoCore

// Concrete service implementations for the running app. These live in the app target (not in
// CrearoCore) so the core stays Foundation-pure & Linux-testable. Backends are swappable because
// everything conforms to the CrearoCore protocols (docs/TECH_ARCHITECTURE.md §3, §5).

// MARK: - Config (values injected via Config.xcconfig → Info.plist; see SETUP_GUIDE §5–6)

enum AppConfig {
    static let apiBaseURL: URL = {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String) ?? "https://YOUR-PROJECT.supabase.co"
        return URL(string: raw) ?? URL(string: "https://YOUR-PROJECT.supabase.co")!
    }()
    static let supabaseAnonKey = (Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String) ?? ""
    /// Flip on once the Edge Functions are deployed; otherwise the deterministic stub runs offline.
    static let useRemoteAI = (Bundle.main.object(forInfoDictionaryKey: "USE_REMOTE_AI") as? String) == "YES"
}

// MARK: - Networking (URLSession)

struct LiveAPIClient: APIClient {
    let baseURL: URL
    let session: URLSession
    let defaultHeaders: [String: String]

    init(baseURL: URL, session: URLSession = .shared, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
    }

    func send<T: Decodable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                        resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        if !endpoint.query.isEmpty {
            comps.queryItems = endpoint.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.httpBody = endpoint.body
        for (k, v) in defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }
        for (k, v) in endpoint.headers { req.setValue(v, forHTTPHeaderField: k) }
        if endpoint.body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        do {
            let (data, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw http.statusCode == 401 ? APIError.unauthorized : APIError.http(status: http.statusCode)
            }
            if T.self == EmptyResponse.self { return EmptyResponse() as! T }
            do { return try JSONDecoder().decode(T.self, from: data) }
            catch { throw APIError.decoding(String(describing: error)) }
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(String(describing: error))
        }
    }
}

// MARK: - Remote AI interpretation (calls the `interpret-idea` Edge Function; GDD §33)

struct RemoteAIInterpretationService: AIInterpretationService {
    let api: APIClient

    private struct RequestBody: Encodable { let idea: IdeaInput; let context: CreationContext }

    func interpret(_ idea: IdeaInput, context: CreationContext) async throws -> InterpretedIdea {
        let body = try JSONEncoder().encode(RequestBody(idea: idea, context: context))
        var headers: [String: String] = [:]
        if !AppConfig.supabaseAnonKey.isEmpty {
            headers["Authorization"] = "Bearer \(AppConfig.supabaseAnonKey)"
            headers["apikey"] = AppConfig.supabaseAnonKey
        }
        let endpoint = Endpoint(path: "functions/v1/interpret-idea", method: .post, body: body, headers: headers)
        return try await api.send(endpoint, as: InterpretedIdea.self)
    }
}

// MARK: - Local persistence (JSON file in Application Support; real, offline-first; GDD §61)

final class FilePersistenceStore: PersistenceStore, @unchecked Sendable {
    private let url: URL
    private let queue = DispatchQueue(label: "crearo.persistence")

    init(filename: String = "world_state.json") {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        self.url = dir.appendingPathComponent(filename)
    }

    func loadWorldState() async throws -> WorldState? {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            let data = try Data(contentsOf: url)
            return try WorldStateCodec.state(from: data)
        }
    }

    func save(_ state: WorldState) async throws {
        try queue.sync {
            var s = state; s.updatedAt = Date()
            let data = try WorldStateCodec.data(from: s)
            try data.write(to: url, options: [.atomic])
        }
    }

    func deleteAll() async throws {
        try queue.sync {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }
}
