import Foundation
import Observation
import CrearoCore

// The single source of truth for the running app. Holds session + world-state + services and
// exposes high-level intents to the SwiftUI feature views. @MainActor so UI mutations are safe.

/// The cut-scene the companion acts out, derived from the player's answer.
struct SceneSpec {
    let item: String
    let colorName: String
    let action: SceneAction
    let target: String
    let outcomeCaption: String
}

/// Result of attempting a level: the graded score, whether it passed the gate, the cut-scene, the
/// story beat, coaching, sparks, and streak. The score is now shown to the player (out of 100).
struct ChallengeOutcome: Identifiable {
    let id = UUID()
    let rubric: RubricResult        // total 0...100 + per-criterion breakdown + band
    let passed: Bool                // did it clear this level's rising pass mark
    let passMark: Int
    let level: Int                  // the level number that was attempted
    let levelTitle: String
    let earned: [ResourceAmount]
    let coaching: String
    let storyBeat: String
    let scene: SceneSpec
    let streak: Int
    let advanced: Bool              // moved on to the next level
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

    // MARK: The level loop (the core game)

    /// The level you face right now. It only advances when you clear the current one, so it holds
    /// steady all day and moves forward the moment an idea passes the gate.
    var todaysChallenge: DailyChallenge {
        ChallengeProvider.challenge(level: worldState?.level ?? 1)
    }

    /// Whether you have already cleared a level today (one level a day; come back tomorrow).
    var hasDoneToday: Bool { worldState?.lastChallengeDay == ChallengeProvider.dayKey() }

    /// Score the answer against the hard rubric, stage the cut-scene, and advance ONLY if it clears
    /// this level's rising pass mark. Failing does not consume the day: you can refine and try again.
    @discardableResult
    func submitChallenge(_ level: DailyChallenge, answer: String) async -> ChallengeOutcome? {
        // The offline engine still runs: it updates the private profile and pays baseline sparks.
        guard let result = await completeDailyQuest(responseText: answer, modality: .writing, focus: level.focus) else { return nil }
        let companion = worldState?.companion.name ?? "your companion"

        // Claude grades + directs when a key is present; otherwise fall back to the offline engine.
        let ai = await StoryDirector.direct(level: level, answer: answer, companion: companion,
                                            apiKey: Secrets.anthropicAPIKey)
        let raw = ai?.scores ?? RubricScores.from(dimensions: result.score.dimensions, gate: result.score.gate)
        let graded = CreativityRubric.default.evaluate(raw)
        let passed = LevelGate.passes(score: graded.total, level: level.level)

        let scene = ai ?? StoryDirector.offlineScene(answer: answer, companion: companion, level: level)

        var advanced = false
        if var ws = worldState {
            ws.bestScore = max(ws.bestScore, graded.total)
            // Advance at most once per day, and only when the idea is creative enough.
            if passed, ws.lastChallengeDay != level.id {
                ws.streak = Self.isConsecutive(ws.lastChallengeDay, before: level.id) ? ws.streak + 1 : 1
                ws.lastChallengeDay = level.id
                ws.level += 1
                ws.totalPoints += graded.total
                ws.storyLog.append(scene.storyBeat)
                advanced = true
            }
            worldState = ws
            await persist()
        }

        let coaching = scene.coaching.isEmpty ? (result.prophecy ?? result.companionLine) : scene.coaching
        let spec = SceneSpec(item: scene.item, colorName: scene.color,
                             action: SceneAction.from(scene.action), target: scene.target,
                             outcomeCaption: scene.outcome)
        return ChallengeOutcome(rubric: graded, passed: passed, passMark: level.passMark,
                                level: level.level, levelTitle: level.title, earned: result.earned,
                                coaching: coaching, storyBeat: scene.storyBeat, scene: spec,
                                streak: worldState?.streak ?? 0, advanced: advanced)
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
