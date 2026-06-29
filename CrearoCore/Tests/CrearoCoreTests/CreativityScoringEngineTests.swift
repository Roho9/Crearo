import XCTest
@testable import CrearoCore

final class CreativityScoringEngineTests: XCTestCase {
    let engine = CreativityScoringEngine()

    /// Anti-nonsense: a highly "novel" but irrelevant/incoherent response must score ~0.
    /// (Defends against the DAT failure mode where randomness scores as creative — CREATIVITY_SCORING §5.)
    func testGateCollapsesOnIrrelevantNonsense() {
        let nonsense = ScoringInput(
            promptID: "p1", modality: .writing,
            relevance: 0.05, functionalValidity: 0.1, coherence: 0.1,
            semanticDistance: 1.0, ideaCount: 12, distinctCategoryCount: 9, detail: 1.0, effort: 1.0
        )
        let score = engine.score(nonsense)
        XCTAssertLessThan(score.gate, 0.2, "gate should collapse on irrelevant input")
        XCTAssertLessThan(score.dimensions.originality, 0.15, "novelty must not be credited without fit")
    }

    /// A novel AND apt response scores high originality.
    func testNovelAndAptScoresHigh() {
        let good = ScoringInput(
            promptID: "p1", modality: .writing,
            relevance: 0.9, functionalValidity: 1.0, coherence: 1.0,
            semanticDistance: 0.9, ideaCount: 5, distinctCategoryCount: 3, detail: 0.8, effort: 1.0
        )
        let score = engine.score(good)
        XCTAssertGreaterThan(score.gate, 0.85)
        XCTAssertGreaterThan(score.dimensions.originality, 0.7)
    }

    /// Population rarity (when available) overrides the semantic-distance fallback.
    func testRarityPercentileDrivesOriginality() {
        let input = ScoringInput(
            promptID: "p1", modality: .drawing,
            relevance: 1.0, functionalValidity: 1.0, coherence: 1.0,
            semanticDistance: 0.1,            // low fallback...
            rarityPercentile: 0.95,           // ...but rare in the population
            detail: 0.5, effort: 1.0
        )
        let score = engine.score(input)
        XCTAssertGreaterThan(score.dimensions.originality, 0.9)
    }

    /// The profile moves toward an observed high-originality act (trajectory update, §7).
    func testProfileMovesTowardObserved() {
        let input = ScoringInput(
            promptID: "p1", modality: .writing, relevance: 0.9,
            semanticDistance: 0.9, ideaCount: 5, distinctCategoryCount: 3, detail: 0.8, effort: 1.0
        )
        let score = engine.score(input)
        let before = CreativeProfile()
        let after = engine.updatedProfile(before, with: score, input: input)
        XCTAssertGreaterThan(after.value(.originality), before.value(.originality))
        XCTAssertEqual(after.totalActs, 1)
        XCTAssertEqual(after.modalityCounts[Modality.writing.rawValue], 1)
    }

    /// Reward scales with quality (GDD §35: lazy ideas earn less).
    func testRewardScalesWithQuality() {
        let hi = engine.score(ScoringInput(promptID: "p", modality: .writing, relevance: 0.9,
                                           semanticDistance: 0.9, ideaCount: 6, distinctCategoryCount: 4,
                                           detail: 0.9, emotionalCharge: 0.8, effort: 1.0))
        let lo = engine.score(ScoringInput(promptID: "p", modality: .writing, relevance: 0.9,
                                           semanticDistance: 0.1, ideaCount: 1, distinctCategoryCount: 1,
                                           detail: 0.1, effort: 0.3))
        XCTAssertGreaterThan(engine.rewardMultiplier(for: hi), engine.rewardMultiplier(for: lo))
    }

    /// Reframing boosts symbolic + flexible thinking.
    func testReframingBonus() {
        let base = ScoringInput(promptID: "p", modality: .writing, relevance: 0.9, symbolism: 0.4)
        let reframed = ScoringInput(promptID: "p", modality: .writing, relevance: 0.9, symbolism: 0.4,
                                    reframingDetected: true)
        XCTAssertGreaterThan(engine.score(reframed).dimensions.symbolicThinking,
                             engine.score(base).dimensions.symbolicThinking)
    }

    /// In-memory rarity: a point far from the corpus is rarer than one near it.
    func testInMemoryRarity() async throws {
        let svc = InMemoryRarityService(k: 5)
        for _ in 0..<20 { svc.add(promptID: "p", embedding: [1, 0, 0]) }  // dense cluster near [1,0,0]
        let near = try await svc.rarity(promptID: "p", embedding: [0.99, 0.01, 0])
        let far = try await svc.rarity(promptID: "p", embedding: [0, 0, 1])
        XCTAssertGreaterThan(far.percentile, near.percentile)
    }
}
