import Foundation
import Observation
import CrearoCore

// The single source of truth for the running app. Holds session + world-state + services and
// exposes high-level intents to the SwiftUI feature views. @MainActor so UI mutations are safe.

/// Result of a daily challenge: the hidden creativity score, sparks earned, coaching, and streak.
struct ChallengeOutcome: Identifiable {
    let id = UUID()
    let score: CreativityScore
    let earned: [ResourceAmount]
    let coaching: String
    let streak: Int
    let advancedStreak: Bool
}

@MainActor
@Observable
final class AppState {
    var services: AppServices
    var worldState: WorldState?
    var didBootstrap = false   // false until the saved world has loaded, so we show a splash (not the start page) during launch
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
        // Load the local world first (fast) and mark ready, so the UI never stalls on a splash.
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
        didBootstrap = true
        // Session restore is non-essential to entering the world; do it after.
        user = try? await services.auth.restoreSession()
    }

    /// Gather CreaCash from a world action (chop/fight). Brightens the world a touch (GDD §28).
    func gather(creaCash n: Int) async {
        guard var ws = worldState, n > 0 else { return }
        ws.wallet.earn(.embers, n)
        ws.companion.brightness = min(1, ws.companion.brightness + 0.04)
        ws.home.lastMeaningfulActivity = Date()
        worldState = ws
        await persist()
    }

    /// Wipe the saved world and return to the opening sequence (the "New Game" path).
    func resetGame() async {
        try? await services.persistence.deleteAll()
        worldState = nil
        latestProphecy = nil
        latestCompanionLine = nil
        lastForged = nil
        toast = nil
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

    // MARK: Daily creativity challenge (the new core loop)

    /// Today's challenge — biased toward the player's weakest creative dimension.
    var todaysChallenge: DailyChallenge {
        ChallengeProvider.challenge(for: Date(), weakest: worldState?.profile.weakestDimensions(1).first)
    }

    /// Whether the player has already completed a challenge today (streak already advanced).
    var hasDoneToday: Bool { worldState?.lastChallengeDay == ChallengeProvider.dayKey() }

    /// Score the answer (offline engine), advance the streak once/day, and fetch coaching.
    @discardableResult
    func submitChallenge(_ challenge: DailyChallenge, answer: String) async -> ChallengeOutcome? {
        guard let result = await completeDailyQuest(responseText: answer, modality: .writing, focus: challenge.focus) else { return nil }

        var advanced = false
        if var ws = worldState, ws.lastChallengeDay != challenge.id {
            ws.streak = Self.isConsecutive(ws.lastChallengeDay, before: challenge.id) ? ws.streak + 1 : 1
            ws.lastChallengeDay = challenge.id
            worldState = ws
            advanced = true
            await persist()
        }

        let coaching = await CreativityCoach.coach(prompt: challenge.prompt, answer: answer,
                                                   dimensions: result.score.dimensions,
                                                   apiKey: Secrets.anthropicAPIKey)
            ?? result.prophecy ?? result.companionLine

        return ChallengeOutcome(score: result.score, earned: result.earned, coaching: coaching,
                                streak: worldState?.streak ?? 0, advancedStreak: advanced)
    }

    private static func isConsecutive(_ prev: String?, before today: String) -> Bool {
        guard let prev else { return false }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let p = f.date(from: prev), let t = f.date(from: today) else { return false }
        return Calendar.current.dateComponents([.day], from: p, to: t).day == 1
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
