import Foundation
import CrearoCore

// Dependency-injection container. Swap any implementation here without touching feature code
// (docs/TECH_ARCHITECTURE.md §3). Defaults run fully offline so the app is demonstrable with no backend.

struct AppServices {
    var auth: AuthService
    var persistence: PersistenceStore
    var api: APIClient
    var ai: AIInterpretationService
    var rarity: RarityService

    /// Production-ish wiring. TODOs mark the backends to connect (see SETUP_GUIDE.md).
    static func live() -> AppServices {
        let api = LiveAPIClient(baseURL: AppConfig.apiBaseURL)
        return AppServices(
            auth: InMemoryAuthService(),                 // TODO: SupabaseAuthService (Sign in with Apple)
            persistence: FilePersistenceStore(),         // real local JSON store (add CloudKit sync later)
            api: api,
            ai: Self.aiService(api: api),
            rarity: InMemoryRarityService()              // TODO: SupabaseRarityService (pgvector / HNSW)
        )
    }

    /// Pick the Forge interpreter: real Claude when a key is present (local testing), else the
    /// remote Edge Function if configured, else the deterministic offline stub.
    private static func aiService(api: APIClient) -> AIInterpretationService {
        if !Secrets.anthropicAPIKey.isEmpty {
            return ClaudeAIInterpretationService(apiKey: Secrets.anthropicAPIKey)
        }
        return AppConfig.useRemoteAI ? RemoteAIInterpretationService(api: api) : StubAIInterpretationService()
    }

    /// Fully in-memory wiring for SwiftUI previews & tests.
    static func preview() -> AppServices {
        AppServices(
            auth: InMemoryAuthService(user: UserAccount(id: "preview", displayName: "Maker")),
            persistence: InMemoryPersistenceStore(.previewWorld),
            api: LiveAPIClient(baseURL: AppConfig.apiBaseURL),
            ai: StubAIInterpretationService(),
            rarity: InMemoryRarityService()
        )
    }
}

extension WorldState {
    /// A small populated world for previews.
    static var previewWorld: WorldState {
        var ws = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        ws.wallet.earn([ResourceAmount(.embers, 40), ResourceAmount(.musefire, 6), ResourceAmount(.essence, 4)])
        ws.creations = [
            Creation(name: "Honeyfang", type: .weapon,
                     traditional: TraditionalStats(damage: 22, durability: 30, weight: 3),
                     creative: CreativeStats(originality: 55, strangeness: 40, usefulness: 60),
                     effect: UniqueEffect(kind: .slow, magnitude: 0.3, durationSec: 3, cooldownSec: 4),
                     artDescriptor: "amber resin blade", regionMade: .mirrorwood)
        ]
        ws.companion.remember("Honeyfang")
        return ws
    }
}
