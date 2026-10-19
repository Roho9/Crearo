import Foundation
import Observation
import CrearoCore

actor AtelierSaveStore {
    private let url: URL
    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Crearo", isDirectory: true).appendingPathComponent("oddworks-v1.json")
    }
    func load() throws -> ContraptionSave {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        return try JSONDecoder().decode(ContraptionSave.self, from: Data(contentsOf: url))
    }
    func write(_ save: ContraptionSave) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(save).write(to: url, options: .atomic)
    }
}

/// The new construction game has its own versioned save. Previous written adventures stay intact.
@MainActor @Observable
final class AtelierGameModel {
    private(set) var save = ContraptionSave()
    private(set) var hasLoaded = false
    private(set) var selectedLevel = 1
    var selectedSlot: ContraptionSlot = .anchor
    private(set) var recipe = ContraptionRecipe()
    private(set) var explanation = ""
    private(set) var isTesting = false
    private(set) var attemptID: UUID?
    private(set) var testResult: ContraptionEvaluation?
    private(set) var result: ContraptionEvaluation?
    var showingResult = false
    private(set) var storageNotice: String?
    @ObservationIgnored private let store: AtelierSaveStore
    @ObservationIgnored private var writeTask: Task<Void, Never>?
    @ObservationIgnored private var loading = false
    @ObservationIgnored private var preserveUnreadableSave = false

    init(store: AtelierSaveStore = AtelierSaveStore()) { self.store = store }
    var challenge: ContraptionChallenge { ContraptionChallenge.level(selectedLevel)! }
    var assessment: ContraptionEvaluation {
        ContraptionEvaluator().evaluate(challenge: challenge, recipe: recipe, explanation: explanation)
    }
    var canTest: Bool { hasLoaded && recipe.isComplete && recipe.hasDistinctParts && assessment.writingStatus.isComplete && !isTesting }
    var completedCount: Int { save.bestScores.count }
    var orderedParts: [String] { ContraptionSlot.allCases.map { recipe[$0]?.rawValue ?? "" } }

    func load() async {
        guard !hasLoaded, !loading else { return }
        loading = true
        defer { loading = false; hasLoaded = true }
        do {
            save = try await store.load()
            selectedLevel = save.currentLevel
            restoreDraft()
        } catch {
            // Do not overwrite an unreadable or newer save with a fresh empty game.
            preserveUnreadableSave = true
            storageNotice = "Your saved workshop could not be opened. It has been kept safe; this session is temporary."
        }
    }

    func choose(_ part: ContraptionPart) {
        guard hasLoaded, !isTesting else { return }
        recipe.place(recipe[selectedSlot] == part ? nil : part, in: selectedSlot)
        keepDraft()
    }
    func setExplanation(_ value: String) {
        guard hasLoaded, !isTesting else { return }
        explanation = value
        keepDraft()
    }
    func select(_ level: Int) {
        guard hasLoaded, !isTesting, level <= save.currentLevel, ContraptionChallenge.level(level) != nil else { return }
        keepDraft()
        selectedLevel = level
        selectedSlot = .anchor
        result = nil
        showingResult = false
        restoreDraft()
    }
    func test() {
        guard canTest else { return }
        testResult = assessment
        attemptID = UUID()
        isTesting = true
    }
    func finishTest() {
        guard isTesting, let evaluated = testResult else { return }
        isTesting = false
        result = evaluated
        save.record(evaluation: evaluated, challenge: challenge, recipe: recipe, explanation: explanation)
        showingResult = true
        scheduleWrite()
    }
    func nextStation() {
        showingResult = false
        if selectedLevel < save.currentLevel { select(selectedLevel + 1) }
    }
    func flush() async {
        writeTask?.cancel()
        guard hasLoaded, !preserveUnreadableSave else { return }
        do { try await store.write(save); storageNotice = nil }
        catch { storageNotice = "This session could not be saved. Keep the app open and try again." }
    }
    private func restoreDraft() {
        recipe = save.partDrafts[challenge.id] ?? .init()
        explanation = save.textDrafts[challenge.id] ?? ""
    }
    private func keepDraft() {
        save.setDraft(recipe: recipe, explanation: explanation, for: challenge)
        result = nil
        testResult = nil
        attemptID = nil
        scheduleWrite()
    }
    private func scheduleWrite() {
        writeTask?.cancel()
        writeTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            await self.flush()
        }
    }
    var shareText: String {
        Self.share(challenge: challenge, recipe: recipe, explanation: explanation, score: result?.score ?? 0)
    }
    static func share(challenge: ContraptionChallenge, recipe: ContraptionRecipe, explanation: String, score: Int) -> String {
        """
        CREARO / ODDWORKS
        \(challenge.title)
        Local puzzle score: \(score)/100
        \(ContraptionSlot.allCases.map { "\($0.title): \(recipe[$0]?.title ?? "—")" }.joined(separator: " · "))

        \(explanation)

        Scored against the station's visible construction rules, not a global creativity ranking.
        """
    }
}
