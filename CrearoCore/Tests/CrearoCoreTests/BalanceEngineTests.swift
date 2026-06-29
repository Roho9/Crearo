import XCTest
@testable import CrearoCore

final class BalanceEngineTests: XCTestCase {
    let engine = BalanceEngine()

    /// An absurdly overpowered idea is scaled into budget but keeps its identity (GDD §34).
    func testClampReducesOverpoweredButPreservesIdentity() {
        let doom = Creation(
            name: "Worldender", type: .weapon,
            traditional: TraditionalStats(damage: 10_000, defense: 0, speed: 10, durability: 30, weight: 3),
            creative: CreativeStats(originality: 90, strangeness: 80),
            effect: UniqueEffect(kind: .slow, magnitude: 1.0, durationSec: 99, cooldownSec: 0, range: 999),
            regionMade: .mirrorwood
        )
        let clamped = engine.clamp(doom, level: 1)
        let budget = engine.statBudget(level: 1, region: .mirrorwood)

        XCTAssertEqual(clamped.effect.kind, .slow, "effect identity must be preserved")
        XCTAssertLessThanOrEqual(engine.power(of: clamped), budget + 0.001, "must fit power budget")
        XCTAssertLessThanOrEqual(clamped.effect.magnitude, engine.config.maxEffectMagnitude)
        XCTAssertLessThanOrEqual(clamped.effect.durationSec, engine.config.maxDurationSec)
        XCTAssertGreaterThan(clamped.effect.cooldownSec, 0, "a slow effect must have a cooldown")
    }

    /// Instability is taxed from originality + strangeness (risk has a cost; GDD §24/§34).
    func testInstabilityTax() {
        let c = Creation(name: "Strange", type: .spell,
                         traditional: TraditionalStats(damage: 5),
                         creative: CreativeStats(originality: 90, strangeness: 80),
                         regionMade: .mirrorwood)
        let clamped = engine.clamp(c, level: 1)
        XCTAssertEqual(clamped.creative.instability, 90 * 0.4 + 80 * 0.6, accuracy: 0.001)
    }

    /// Cost rises with power.
    func testCostIncreasesWithPower() {
        let low = Economy.cost(power: 0.1, rarity: 0.1, complexity: 0.1, level: 1)
        let high = Economy.cost(power: 3.0, rarity: 0.1, complexity: 0.1, level: 1)
        let lowEmbers = low.first { $0.resource == .embers }?.amount ?? 0
        let highEmbers = high.first { $0.resource == .embers }?.amount ?? 0
        XCTAssertGreaterThan(highEmbers, lowEmbers)
    }

    /// Rare/strange ideas pull in the scarce resources.
    func testRareIdeasCostScarceResources() {
        let rare = Economy.cost(power: 1.0, rarity: 0.9, complexity: 0.9, level: 1)
        XCTAssertTrue(rare.contains { $0.resource == .musefire })
        XCTAssertTrue(rare.contains { $0.resource == .hollowSparks })
    }

    /// The anti-soft-lock fallback is always cheap.
    func testFallbackIsAffordable() {
        let fb = engine.fallbackCreation(region: .mirrorwood)
        let embers = fb.cost.first { $0.resource == .embers }?.amount ?? Int.max
        XCTAssertLessThanOrEqual(embers, 2)
    }

    /// The full forge pipeline: interpret → score → clamp → assemble produces a sane, named item.
    func testForgePipelineProducesHoneyfang() async throws {
        let ai = StubAIInterpretationService()
        let idea = IdeaInput(promptID: "forge", modality: .writing, text: "a sword that shoots honey to slow enemies")
        let ctx = CreationContext(level: 1, region: .mirrorwood)
        let interpreted = try await ai.interpret(idea, context: ctx)

        let scoring = CreativityScoringEngine()
        let score = scoring.score(ScoringInput(promptID: "forge", modality: .writing, relevance: 0.9,
                                               semanticDistance: 0.6, detail: 0.5, effort: 0.8))
        let cost = engine.cost(for: Creation.assemble(idea: interpreted, score: score, cost: [],
                                                      region: .mirrorwood), score: score, level: 1)
        let creation = engine.clamp(Creation.assemble(idea: interpreted, score: score, cost: cost,
                                                       region: .mirrorwood), level: 1)

        XCTAssertEqual(creation.effect.kind, .slow)
        XCTAssertLessThanOrEqual(creation.effect.magnitude, 0.6)
        XCTAssertFalse(creation.name.isEmpty)
        XCTAssertFalse(creation.cost.isEmpty)
    }
}
