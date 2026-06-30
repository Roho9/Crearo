import Foundation
import Observation
import CrearoCore

// The single source of truth for the running app. Holds session + world-state + services and
// exposes high-level intents to the SwiftUI feature views. @MainActor so UI mutations are safe.

@MainActor
@Observable
final class AppState {
    var services: AppServices
    var worldState: WorldState?
    var user: UserAccount?
    var selectedRegion: RegionID = .mirrorwood

    // Surfaced to the UI as fiction (never raw numbers, GDD §39).
    var latestProphecy: String?
    var latestCompanionLine: String?
    var lastForged: Creation?
    var isWorking = false
    var toast: String?

    private let engine = GameEngine()

    init(services: AppServices = .live()) {
        self.services = services
    }

    var hasGame: Bool { worldState != nil }

    // MARK: Lifecycle

    /// Restore session + load world, then apply graceful absence decay (GDD §32).
    func bootstrap() async {
        user = try? await services.auth.restoreSession()
        if let loaded = try? await services.persistence.loadWorldState() {
            let decayed = engine.decay.applyAbsence(to: loaded, now: Date())
            worldState = decayed
            if decayed.home.corruptionLevel > 0 {
                latestCompanionLine = engine.companionDir.line(
                    for: .returnedAfterAbsence, companion: decayed.companion,
                    lastCreation: decayed.companion.rememberedCreations.last)
            }
            if decayed != loaded { await persist() }
        }
    }

    func signInWithApple(identityToken: String, nonce: String) async {
        user = try? await services.auth.signInWithApple(identityToken: identityToken, nonce: nonce)
    }

    /// Demo sign-in for the offline build (real build uses Sign in with Apple).
    func signInOffline() async {
        user = try? await services.auth.signInWithApple(identityToken: "offline-demo", nonce: "n")
    }

    func startNewGame(characterName: String, companionName: String) async {
        let ws = WorldState.newGame(characterName: characterName, companionName: companionName)
        worldState = ws
        latestCompanionLine = engine.companionDir.line(for: .firstMaking, companion: ws.companion, lastCreation: nil)
        await persist()
    }

    // MARK: Forge a creation (GDD §23)

    @discardableResult
    func forge(ideaText: String, modality: Modality) async -> ForgeOutcome? {
        guard var ws = worldState, !ideaText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        isWorking = true
        defer { isWorking = false }

        let promptID = "forge.\(selectedRegion.rawValue)"
        let context = CreationContext(
            level: ws.character.level, region: selectedRegion,
            walletSnapshot: Resource.allCases.map { ResourceAmount($0, ws.wallet[$0]) },
            dominantClass: ws.character.dominantClass(), constraint: nil,
            profileSummary: ws.profile.snapshot)
        let idea = IdeaInput(promptID: promptID, modality: modality, text: ideaText)

        let interpreted = (try? await services.ai.interpret(idea, context: context))
            ?? GameEngine.fallbackInterpreted(text: ideaText)
        let rarity = try? await services.rarity.rarity(promptID: promptID,
                                                       embedding: GameEngine.pseudoEmbedding(ideaText))

        let outcome = engine.forge(into: &ws, ideaText: ideaText, modality: modality,
                                   region: selectedRegion, interpreted: interpreted, rarity: rarity)
        worldState = ws
        lastForged = outcome.creation
        latestProphecy = outcome.act.prophecy
        latestCompanionLine = outcome.act.companionLine
        toast = outcome.affordable ? "Forged “\(outcome.creation.name)”." :
            "“\(outcome.creation.name)” entered the world, but faint; you lacked the resources to fully fund it."
        if let cls = outcome.act.recognizedClass, ws.character.title == "a Maker" {
            ws.character.title = "the \(cls.title)"
            worldState = ws
            toast = "The world has named you: \(cls.title)."
        }
        await persist()
        return outcome
    }

    // MARK: Daily creative quest (GDD §31)

    @discardableResult
    func completeDailyQuest(responseText: String, modality: Modality, focus: DimensionScores = .uniform) async -> ScoredActResult? {
        guard var ws = worldState, !responseText.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        isWorking = true
        defer { isWorking = false }

        let promptID = "daily.\(todayKey())"
        let rarity = try? await services.rarity.rarity(promptID: promptID,
                                                       embedding: GameEngine.pseudoEmbedding(responseText))
        let result = engine.respondToQuest(into: &ws, text: responseText, modality: modality,
                                           promptID: promptID, focus: focus, rarity: rarity)
        worldState = ws
        latestProphecy = result.prophecy
        latestCompanionLine = result.companionLine
        toast = "The world brightened. You gained " + result.earned.map { "\($0.amount) \($0.resource.displayName)" }.joined(separator: ", ") + "."
        await persist()
        return result
    }

    /// The personalized final boss preview, generated from the current profile (GDD §50).
    func previewFinalBoss() -> PersonalizedBoss? {
        guard let ws = worldState else { return nil }
        return BossComposer().compose(from: ws.profile, namedCreations: ws.companion.rememberedCreations)
    }

    // MARK: Helpers

    private func persist() async {
        if let ws = worldState { try? await services.persistence.save(ws) }
    }

    private func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }
}
