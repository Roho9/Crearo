import XCTest
@testable import CrearoCore

final class ChallengeProgressionTests: XCTestCase {
    private let today = "2026-09-30"

    func testFailedAttemptPreservesRewardsGrowthAndDailyOpportunity() {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        let original = world
        let disposition = ChallengeProgression.record(into: &world, level: 1, day: today,
                                                      currentDay: today, score: 40, storyBeat: "Not yet")
        XCTAssertEqual(disposition, .retry)
        XCTAssertEqual(world.wallet, original.wallet)
        XCTAssertEqual(world.profile, original.profile)
        XCTAssertEqual(world.home, original.home)
        XCTAssertEqual(world.companion, original.companion)
        XCTAssertEqual(world.level, 1)
        XCTAssertEqual(world.totalPoints, 0)
        XCTAssertNil(world.lastChallengeDay)
        XCTAssertTrue(world.storyLog.isEmpty)
        XCTAssertEqual(world.bestScore, 40)
        XCTAssertTrue(ChallengeProgression.canAttempt(world, level: 1, day: today, currentDay: today))
    }

    func testClearIsAcceptedOnlyOnceAndRepeatedAttemptCannotMutateSave() {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 1, day: today,
                                                  currentDay: today, score: 85, storyBeat: "The bridge opens"), .cleared)
        XCTAssertEqual(world.level, 2)
        XCTAssertEqual(world.totalPoints, 85)
        XCTAssertEqual(world.streak, 1)
        XCTAssertEqual(world.storyLog, ["The bridge opens"])
        let cleared = world
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 1, day: today,
                                                  currentDay: today, score: 100, storyBeat: "Duplicate"), .unavailable)
        XCTAssertEqual(world, cleared)
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 2, day: today,
                                                  currentDay: today, score: 100, storyBeat: "Second today"), .unavailable)
        XCTAssertEqual(world, cleared)
    }

    func testStaleDayAndLevelCannotMutateSave() {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        let original = world
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 2, day: today,
                                                  currentDay: today, score: 100, storyBeat: "Wrong level"), .unavailable)
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 1, day: "2026-09-29",
                                                  currentDay: today, score: 100, storyBeat: "Yesterday"), .unavailable)
        XCTAssertEqual(world, original)
    }

    func testNextDayClearExtendsStreakAndGapRestartsIt() {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        world.lastChallengeDay = "2026-09-29"
        world.streak = 3
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 1, day: today,
                                                  currentDay: today, score: 80, storyBeat: "New day"), .cleared)
        XCTAssertEqual(world.streak, 4)
        XCTAssertEqual(ChallengeProgression.record(into: &world, level: 2, day: "2026-10-02",
                                                  currentDay: "2026-10-02", score: 80, storyBeat: "Return"), .cleared)
        XCTAssertEqual(world.streak, 1)
    }

    func testRewardProfileAdapterUsesFinalJudgmentAndItsFitGate() {
        let raw = RubricScores(originality: 0.9, elaboration: 0.6, fit: 0.8,
                               boldness: 0.7, depth: 0.5, delight: 0.4)
        let score = ChallengeAssessment.worldScore(from: raw)
        XCTAssertEqual(score.gate, 0.8)
        XCTAssertEqual(score.dimensions.originality, 0.72, accuracy: 0.0001)
        XCTAssertEqual(score.dimensions.elaboration, 0.48, accuracy: 0.0001)
        XCTAssertEqual(score.dimensions.usefulness, 0.8)
        XCTAssertEqual(score.dimensions.riskTaking, 0.56, accuracy: 0.0001)
        XCTAssertEqual(score.dimensions.symbolicThinking, 0.4, accuracy: 0.0001)
        XCTAssertEqual(score.dimensions.emotionalExpression, 0.32, accuracy: 0.0001)
        XCTAssertEqual(score.effort, 0.6)

        let rejected = ChallengeAssessment.worldScore(from: RubricScores(
            originality: 1, elaboration: 1, fit: 0, boldness: 1, depth: 1, delight: 1))
        XCTAssertEqual(rejected.dimensions, .zero)
        XCTAssertFalse(rejected.constraintSatisfied)
    }
}
