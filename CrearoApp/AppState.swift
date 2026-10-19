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
    var isPracticeEstimate: Bool = true
    var answer: String = ""
    var feedbackEvidence: [String] = []
    var region: ChallengeRegion = .prism
    var usesOnDeviceCoaching: Bool = false
}

@MainActor
@Observable
final class AppState {
    static let maximumChallengeLength = 12_000
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
    @ObservationIgnored private let ideaCoach: OnDeviceIdeaCoach?
    @ObservationIgnored private var draftSaveTask: Task<Void, Never>?

    init(services: AppServices = .live(), ideaCoach: OnDeviceIdeaCoach? = .shared) {
        self.services = services
        self.ideaCoach = ideaCoach
    }

    var hasGame: Bool { worldState != nil }
    var isLocalPractice: Bool { Secrets.anthropicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func challengeDraft(forLevel level: Int) -> String {
        worldState?.challengeDrafts[String(level)] ?? ""
    }

    /// Save immediately in memory, then coalesce typing into a single disk write. A late editor
    /// callback from a cleared chapter must not restore that chapter's discarded draft.
    func saveChallengeDraft(_ text: String, forLevel level: Int) {
        guard var world = worldState, world.level == level else { return }
        let key = String(level)
        guard world.challengeDrafts[key] != text else { return }
        if text.isEmpty { world.challengeDrafts.removeValue(forKey: key) }
        else { world.challengeDrafts[key] = text }
        worldState = world
        let worldID = world.character.id
        draftSaveTask?.cancel()
        draftSaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard let self, !Task.isCancelled, self.worldState?.character.id == worldID else { return }
            await self.persist()
        }
    }

    func clearChallengeDraft(forLevel level: Int) {
        guard var world = worldState else { return }
        world.challengeDrafts.removeValue(forKey: String(level))
        worldState = world
        Task { await persist() }
    }

    /// Backgrounding flushes the latest text without waiting for the typing debounce.
    func flushChallengeDrafts() async {
        draftSaveTask?.cancel()
        await ideaCoach?.suspend()
        await persist()
    }

    func prepareIdeaCoach() async { await ideaCoach?.prewarm() }

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
        guard !isWorking, var ws = worldState, n > 0 else { return }
        ws.wallet.earn(.embers, n)
        ws.companion.brightness = min(1, ws.companion.brightness + 0.04)
        ws.home.lastMeaningfulActivity = Date()
        worldState = ws
        await persist()
    }

    /// Wipe the saved world and return to the opening sequence (the "New Game" path).
    func resetGame() async {
        draftSaveTask?.cancel()
        // Invalidate pending judgments before awaiting storage, so they cannot restore this world.
        worldState = nil
        await ideaCoach?.suspend()
        latestProphecy = nil
        latestCompanionLine = nil
        lastForged = nil
        toast = nil
        try? await services.persistence.deleteAll()
    }

    func signInWithApple(identityToken: String, nonce: String) async {
        user = try? await services.auth.signInWithApple(identityToken: identityToken, nonce: nonce)
    }

    /// Demo sign-in for the offline build (real build uses Sign in with Apple).
    func signInOffline() async {
        user = try? await services.auth.signInWithApple(identityToken: "offline-demo", nonce: "n")
    }

    func startNewGame(characterName: String, companionName: String) async {
        draftSaveTask?.cancel()
        let maker = characterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let friend = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ws = WorldState.newGame(characterName: maker.isEmpty ? "Wren" : maker,
                                   companionName: friend.isEmpty ? "Kindle" : friend)
        worldState = ws
        latestCompanionLine = engine.companionDir.line(for: .firstMaking, companion: ws.companion, lastCreation: nil)
        await persist()
    }

    // MARK: Forge a creation (GDD §23)

    @discardableResult
    func forge(ideaText: String, modality: Modality) async -> ForgeOutcome? {
        guard !isWorking, let initialWorld = worldState,
              !ideaText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        isWorking = true
        defer { isWorking = false }

        let region = selectedRegion
        let promptID = "forge.\(region.rawValue)"
        let context = CreationContext(
            level: initialWorld.character.level, region: region,
            walletSnapshot: Resource.allCases.map { ResourceAmount($0, initialWorld.wallet[$0]) },
            dominantClass: initialWorld.character.dominantClass(), constraint: nil,
            profileSummary: initialWorld.profile.snapshot)
        let idea = IdeaInput(promptID: promptID, modality: modality, text: ideaText)

        let interpreted = (try? await services.ai.interpret(idea, context: context))
            ?? GameEngine.fallbackInterpreted(text: ideaText)
        let rarity = try? await services.rarity.rarity(promptID: promptID,
                                                       embedding: GameEngine.pseudoEmbedding(ideaText))

        guard !Task.isCancelled, var ws = worldState,
              ws.character.id == initialWorld.character.id else { return nil }
        let outcome = engine.forge(into: &ws, ideaText: ideaText, modality: modality,
                                   region: region, interpreted: interpreted, rarity: rarity)
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
        guard !isWorking, let initialWorld = worldState,
              !responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        isWorking = true
        defer { isWorking = false }

        let promptID = "daily.\(todayKey())"
        let rarity = try? await services.rarity.rarity(promptID: promptID,
                                                       embedding: GameEngine.pseudoEmbedding(responseText))
        guard !Task.isCancelled, var ws = worldState,
              ws.character.id == initialWorld.character.id else { return nil }
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

    /// The next uncleared chapter. A clear opens the next one immediately.
    var todaysChallenge: DailyChallenge {
        ChallengeProvider.challenge(level: worldState?.level ?? 1)
    }

    /// Whether today has contributed to the streak; this does not lock further chapters.
    var hasDoneToday: Bool { worldState?.lastChallengeDay == ChallengeProvider.dayKey() }

    /// Score the answer against the hard rubric, stage the cut-scene, and advance ONLY if it clears
    /// this level's rising pass mark. Failing does not consume the day: you can refine and try again.
    @discardableResult
    func submitChallenge(_ level: DailyChallenge, answer: String) async -> ChallengeOutcome? {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isWorking, !trimmed.isEmpty, trimmed.count <= Self.maximumChallengeLength, let initialWorld = worldState,
              ChallengeProgression.canAttempt(initialWorld, level: level.level,
                                               day: level.id, currentDay: ChallengeProvider.dayKey()) else {
            return nil
        }
        isWorking = true
        defer { isWorking = false }
        let companion = initialWorld.companion.name
        // Retain the exact submitted draft even if the process closes while evaluation is running.
        saveChallengeDraft(trimmed, forLevel: level.level)

        // Claude grades + directs when a key is present; otherwise fall back to the offline engine.
        // Neither evaluation path mutates the save. Only an accepted result earns rewards below.
        let ai = await StoryDirector.direct(level: level, answer: trimmed, companion: companion,
                                            previousStory: Array(initialWorld.storyLog.suffix(3)),
                                            apiKey: Secrets.anthropicAPIKey)
        guard !Task.isCancelled, worldState?.character.id == initialWorld.character.id else { return nil }
        // Device-local wording and scene cues are optional. Their response has no grade or reward
        // authority, and is never sent to the existing explicitly configured remote judge.
        let deviceFeedback: OnDeviceIdeaFeedback?
        if ai == nil, let ideaCoach {
            deviceFeedback = await ideaCoach.feedback(level: level, answer: trimmed)
        } else {
            deviceFeedback = nil
        }
        guard !Task.isCancelled, var ws = worldState,
              ws.character.id == initialWorld.character.id,
              ChallengeProgression.canAttempt(ws, level: level.level, day: level.id,
                                               currentDay: ChallengeProvider.dayKey()) else { return nil }

        let raw: RubricScores
        let practice: PracticeEvaluation?
        if let ai {
            raw = ai.scores
            practice = nil
        } else {
            // Challenge-specific evidence improves coaching, but remains a local estimate.
            let estimate = PracticeChallengeEvaluator().evaluate(answer: trimmed, context: level.practiceContext)
            practice = estimate
            raw = estimate.raw
        }
        let graded = CreativityRubric.default.evaluate(raw)
        let passed = LevelGate.passes(score: graded.total, level: level.level)

        let scene: AIDirection
        if let ai {
            scene = ai
        } else if let feedback = deviceFeedback {
            scene = AIDirection(item: feedback.item, color: feedback.color, action: feedback.action,
                target: level.sceneTarget,
                outcome: "\(companion) tests \(feedback.item) at \(level.sceneTarget).",
                storyBeat: "In \(level.region.title), \(companion) puts \(feedback.item) to work at \(level.sceneTarget). The invention joins your journal.",
                coaching: feedback.strength + "\n\n" + feedback.nextStep, scores: raw)
        } else {
            scene = StoryDirector.offlineScene(answer: trimmed, companion: companion, level: level)
        }
        let disposition = ChallengeProgression.record(
            into: &ws, level: level.level, day: level.id,
            currentDay: ChallengeProvider.dayKey(), score: graded.total, storyBeat: scene.storyBeat)
        guard disposition != .unavailable else { return nil }
        let advanced = disposition == .cleared
        var earned: [ResourceAmount] = []
        if advanced {
            let result = engine.commitAssessedChallenge(into: &ws, raw: raw,
                promptID: "challenge.\(level.level).\(level.id)", focus: level.focus)
            earned = result.earned
            latestProphecy = result.prophecy
            latestCompanionLine = result.companionLine
            ws.challengeDrafts.removeValue(forKey: String(level.level))
            ws.challengeHistory.append(ChallengeJournalEntry(
                level: level.level, contentID: level.contentID, title: level.title,
                answer: trimmed, score: graded.total, isPracticeEstimate: ai == nil,
                storyBeat: scene.storyBeat))
            if ws.challengeHistory.count > 120 {
                ws.challengeHistory.removeFirst(ws.challengeHistory.count - 120)
            }
        }
        worldState = ws
        await persist()
        guard !Task.isCancelled, worldState?.character.id == initialWorld.character.id else { return nil }

        let coaching = deviceFeedback != nil ? scene.coaching
            : practice?.coaching ?? (scene.coaching.isEmpty ? level.revisionPrompt : scene.coaching)
        var evidence = practice?.evidence ?? []
        if let feedback = deviceFeedback { evidence.append("From your idea: “\(feedback.evidenceQuote)”") }
        let spec = SceneSpec(item: scene.item, colorName: scene.color,
                             action: SceneAction.from(scene.action), target: scene.target,
                             outcomeCaption: passed ? scene.outcome : "An idea to refine. The challenge is still open.")
        return ChallengeOutcome(rubric: graded, passed: passed, passMark: level.passMark,
                                level: level.level, levelTitle: level.title, earned: earned,
                                coaching: coaching,
                                storyBeat: passed ? scene.storyBeat : "The challenge is still open. Revise this idea and try it again.",
                                scene: spec,
                                streak: ws.streak, advanced: advanced, isPracticeEstimate: ai == nil,
                                answer: trimmed, feedbackEvidence: evidence, region: level.region,
                                usesOnDeviceCoaching: deviceFeedback != nil)
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
