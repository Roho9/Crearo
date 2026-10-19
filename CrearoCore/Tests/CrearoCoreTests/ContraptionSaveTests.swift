import XCTest
@testable import CrearoCore

final class ContraptionSaveTests: XCTestCase {
    private let evaluator = ContraptionEvaluator()
    private let text = "The objects work together to carry our little invention forward."
    private var recipes: [ContraptionRecipe] { [
        .init(anchor: .sail, engine: .fan, twist: .bell), .init(anchor: .seed, engine: .spring, twist: .sail),
        .init(anchor: .seed, engine: .fan, twist: .sail), .init(anchor: .mirror, engine: .sail, twist: .seed),
        .init(anchor: .magnet, engine: .fan, twist: .bell), .init(anchor: .sail, engine: .spring, twist: .wheel)
    ] }
    func testFullDraftAndClearedContraptionSurviveRoundTrip() throws {
        var save = ContraptionSave()
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1)); let recipe = recipes[0]
        let oversizedDraft = String(repeating: text, count: 20)
        save.setDraft(recipe: recipe, explanation: oversizedDraft, for: challenge)
        let draft = try JSONDecoder().decode(ContraptionSave.self, from: JSONEncoder().encode(save))
        XCTAssertEqual(draft.textDrafts[challenge.id], oversizedDraft)
        let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: text)
        let recorded = save.record(evaluation: result, challenge: challenge, recipe: recipe, explanation: text, date: Date(timeIntervalSince1970: 100))
        XCTAssertTrue(recorded.recorded); XCTAssertTrue(recorded.wasFirstClear); XCTAssertTrue(recorded.didUnlockNextLevel)
        XCTAssertEqual(save.currentLevel, 2); XCTAssertEqual(save.bestScores[challenge.id], result.score)
        XCTAssertEqual(save.journal.first?.recipe, recipe); XCTAssertEqual(save.journal.first?.explanation, text)
        XCTAssertEqual(try JSONDecoder().decode(ContraptionSave.self, from: JSONEncoder().encode(save)), save)
    }
    func testFailedLockedAndMismatchedResultsCannotAdvanceOrEnterJournal() throws {
        var save = ContraptionSave()
        let first = try XCTUnwrap(ContraptionChallenge.level(1)); let second = try XCTUnwrap(ContraptionChallenge.level(2))
        let fail = evaluator.evaluate(challenge: first, recipe: .init(), explanation: text)
        XCTAssertFalse(save.record(evaluation: fail, challenge: first, recipe: .init(), explanation: text).recorded)
        let locked = evaluator.evaluate(challenge: second, recipe: recipes[1], explanation: text)
        XCTAssertTrue(locked.passed); XCTAssertFalse(save.record(evaluation: locked, challenge: second, recipe: recipes[1], explanation: text).recorded)
        let pass = evaluator.evaluate(challenge: first, recipe: recipes[0], explanation: text)
        XCTAssertFalse(save.record(evaluation: pass, challenge: first, recipe: .init(), explanation: text).recorded)
        XCTAssertEqual(save.currentLevel, 1); XCTAssertTrue(save.bestScores.isEmpty); XCTAssertTrue(save.journal.isEmpty)
    }
    func testReplayMayImproveBestButNeverReunlockProgressOrDuplicateJournal() throws {
        var save = ContraptionSave(); let first = try XCTUnwrap(ContraptionChallenge.level(1))
        let lower = ContraptionRecipe(anchor: .wheel, engine: .spring, twist: .mirror)
        let initial = evaluator.evaluate(challenge: first, recipe: lower, explanation: text)
        let higher = evaluator.evaluate(challenge: first, recipe: recipes[0], explanation: text)
        XCTAssertTrue(initial.passed); XCTAssertGreaterThan(higher.score, initial.score)
        save.record(evaluation: initial, challenge: first, recipe: lower, explanation: text)
        let replay = save.record(evaluation: higher, challenge: first, recipe: recipes[0], explanation: text)
        XCTAssertTrue(replay.isNewBest); XCTAssertFalse(replay.wasFirstClear); XCTAssertFalse(replay.didUnlockNextLevel)
        XCTAssertEqual(save.currentLevel, 2); XCTAssertEqual(save.bestScores[first.id], higher.score); XCTAssertEqual(save.journal.count, 2)
        let existingID = save.journal.last?.id
        for _ in 0..<100 { save.record(evaluation: higher, challenge: first, recipe: recipes[0], explanation: text) }
        XCTAssertEqual(save.currentLevel, 2); XCTAssertEqual(save.journal.count, 2); XCTAssertEqual(save.journal.last?.id, existingID)
        let revised = "The fan sends a tiny hello across the gap as the sail steadies the bell."
        let revision = evaluator.evaluate(challenge: first, recipe: recipes[0], explanation: revised)
        save.record(evaluation: revision, challenge: first, recipe: recipes[0], explanation: revised)
        XCTAssertEqual(save.journal.count, 2); XCTAssertEqual(save.journal.last?.explanation, revised); XCTAssertEqual(save.journal.last?.id, existingID)
    }
    func testCampaignFinishesAtSixAndAllEarlierStationsRemainReplayable() throws {
        var save = ContraptionSave()
        for challenge in ContraptionChallenge.catalog {
            XCTAssertEqual(save.currentLevel, challenge.level)
            let recipe = recipes[challenge.level - 1]
            let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: text)
            XCTAssertTrue(result.passed)
            let record = save.record(evaluation: result, challenge: challenge, recipe: recipe, explanation: text)
            XCTAssertTrue(record.wasFirstClear); XCTAssertEqual(record.didUnlockNextLevel, challenge.level < 6)
        }
        XCTAssertTrue(save.isCampaignComplete); XCTAssertEqual(save.currentLevel, 6)
        let first = ContraptionChallenge.catalog[0]
        let result = evaluator.evaluate(challenge: first, recipe: recipes[0], explanation: text)
        XCTAssertTrue(save.record(evaluation: result, challenge: first, recipe: recipes[0], explanation: text).recorded)
        XCTAssertEqual(save.currentLevel, 6); XCTAssertEqual(save.journal.count, 6)
    }
    func testUnknownVersionIsRejectedAndUnlockedIndexIsRebuiltFromClears() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ContraptionSave())) as? [String: Any])
        object["version"] = 2
        XCTAssertThrowsError(try JSONDecoder().decode(ContraptionSave.self, from: JSONSerialization.data(withJSONObject: object)))
        object["version"] = 1; object["currentLevel"] = 500
        object["bestScores"] = ["noise-post": 100, "unknown-level": 100, "sleeping-moon": 1000]
        let loaded = try JSONDecoder().decode(ContraptionSave.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(loaded.currentLevel, 2); XCTAssertEqual(loaded.bestScores, ["noise-post": 100]); XCTAssertFalse(loaded.isCampaignComplete)
    }
    func testJournalIsBoundedAcrossManyDifferentSuccessfulConstructions() throws {
        var save = ContraptionSave()
        for challenge in ContraptionChallenge.catalog {
            let recipe = recipes[challenge.level - 1]
            save.record(evaluation: evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: text), challenge: challenge, recipe: recipe, explanation: text)
        }
        for challenge in ContraptionChallenge.catalog {
            for anchor in ContraptionPart.allCases {
                for engine in ContraptionPart.allCases where engine != anchor {
                    for twist in ContraptionPart.allCases where twist != anchor && twist != engine {
                        let recipe = ContraptionRecipe(anchor: anchor, engine: engine, twist: twist)
                        let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: text)
                        if result.passed { save.record(evaluation: result, challenge: challenge, recipe: recipe, explanation: text) }
                    }
                }
            }
        }
        XCTAssertEqual(save.journal.count, ContraptionSave.journalLimit)
        XCTAssertEqual(Set(save.journal.map(\.id)).count, ContraptionSave.journalLimit); XCTAssertEqual(save.currentLevel, 6)
        let loaded = try JSONDecoder().decode(ContraptionSave.self, from: JSONEncoder().encode(save))
        XCTAssertEqual(loaded.journal.count, ContraptionSave.journalLimit); XCTAssertTrue(loaded.isCampaignComplete)
    }
}
