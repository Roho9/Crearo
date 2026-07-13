import XCTest
@testable import CrearoCore

final class CreativityRubricTests: XCTestCase {
    let rubric = CreativityRubric.default

    // MARK: The rubric must be HARD

    func testMediocreAnswerFailsEarlyLevels() {
        // A relevant but ordinary idea (all criteria 0.6) should land well under the level-1 pass mark.
        let r = RubricScores(originality: 0.6, elaboration: 0.6, fit: 0.6,
                             boldness: 0.6, depth: 0.6, delight: 0.6)
        let result = rubric.evaluate(r)
        XCTAssertLessThan(result.total, LevelGate.passMark(forLevel: 1),
                          "A middling 0.6-across answer should not clear level 1 (got \(result.total)).")
        XCTAssertEqual(result.band, .spark)
    }

    func testClicheRelevantAnswerScoresLow() {
        // On-topic but unoriginal (fit fine, everything else weak) must score poorly.
        let r = RubricScores(originality: 0.2, elaboration: 0.3, fit: 0.8,
                             boldness: 0.15, depth: 0.2, delight: 0.2)
        let result = rubric.evaluate(r)
        XCTAssertLessThan(result.total, 40)
    }

    func testGoodAnswerReachesBright() {
        let r = RubricScores(originality: 0.85, elaboration: 0.85, fit: 0.85,
                             boldness: 0.85, depth: 0.85, delight: 0.85)
        let result = rubric.evaluate(r)
        XCTAssertGreaterThanOrEqual(result.total, 60)
        XCTAssertLessThan(result.total, 90, "0.85-across should be Bright, not yet Luminous.")
    }

    func testExceptionalAnswerIsLuminous() {
        let r = RubricScores(originality: 0.96, elaboration: 0.95, fit: 0.95,
                             boldness: 0.96, depth: 0.95, delight: 0.95)
        let result = rubric.evaluate(r)
        XCTAssertGreaterThanOrEqual(result.total, 90)
        XCTAssertEqual(result.band, .luminous)
    }

    // MARK: Anti-nonsense gate

    func testOffTopicAnswerCollapses() {
        // High imagination scores but near-zero fit: the gate must crush the total.
        let r = RubricScores(originality: 0.9, elaboration: 0.9, fit: 0.05,
                             boldness: 0.9, depth: 0.9, delight: 0.9)
        let result = rubric.evaluate(r)
        XCTAssertLessThan(result.total, 20, "Off-topic brilliance should still fail (got \(result.total)).")
    }

    func testEmptySignalsScoreZero() {
        let result = rubric.evaluate(RubricScores())
        XCTAssertEqual(result.total, 0)
        XCTAssertEqual(result.band, .spark)
    }

    // MARK: Structure

    func testPointsRoughlySumToTotal() {
        let r = RubricScores(originality: 0.7, elaboration: 0.7, fit: 0.7,
                             boldness: 0.7, depth: 0.7, delight: 0.7)
        let result = rubric.evaluate(r)
        let summed = RubricCriterion.allCases.reduce(0) { $0 + (result.points[$1] ?? 0) }
        XCTAssertLessThanOrEqual(abs(summed - result.total), RubricCriterion.allCases.count,
                                 "Per-criterion points should sum to the total within rounding.")
    }

    func testWeightsSumTo100() {
        XCTAssertEqual(RubricCriterion.allCases.reduce(0) { $0 + $1.weight }, 100)
    }

    func testWeakestCriterionIsLowestRatio() {
        let r = RubricScores(originality: 0.9, elaboration: 0.9, fit: 0.9,
                             boldness: 0.1, depth: 0.9, delight: 0.9)
        let result = rubric.evaluate(r)
        XCTAssertEqual(result.weakestCriterion, .boldness)
    }

    // MARK: Rising level gate

    func testPassMarkRisesThenCaps() {
        XCTAssertEqual(LevelGate.passMark(forLevel: 1), 55)
        XCTAssertLessThan(LevelGate.passMark(forLevel: 1), LevelGate.passMark(forLevel: 5))
        XCTAssertLessThan(LevelGate.passMark(forLevel: 5), LevelGate.passMark(forLevel: 10))
        XCTAssertEqual(LevelGate.passMark(forLevel: 50), 78, "Pass mark should cap at 78.")
    }

    func testOfflineMappingFromDimensions() {
        var d = DimensionScores.zero
        d.originality = 0.8; d.elaboration = 0.7; d.usefulness = 0.6
        d.riskTaking = 0.5; d.symbolicThinking = 0.4; d.emotionalExpression = 0.3
        let raw = RubricScores.from(dimensions: d, gate: 0.8)
        XCTAssertEqual(raw.originality, 0.8, accuracy: 0.0001)
        XCTAssertEqual(raw.boldness, 0.5, accuracy: 0.0001)
        XCTAssertEqual(raw.fit, (0.8 + 0.6) / 2, accuracy: 0.0001)
    }
}
