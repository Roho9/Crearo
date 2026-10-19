import Foundation
import XCTest
@testable import CrearoCore

final class ChallengeSaveTests: XCTestCase {
    func testOldSaveWithoutDraftsOrArchiveKeepsItsProgressAndStory() throws {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        world.level = 13
        world.totalPoints = 842
        world.bestScore = 89
        world.streak = 4
        world.lastChallengeDay = "2026-10-18"
        world.storyLog = ["The old bridge opened.", "The paper lantern glowed."]
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: WorldStateCodec.data(from: world)) as? [String: Any])
        json.removeValue(forKey: "challengeDrafts")
        json.removeValue(forKey: "challengeHistory")
        let restored = try WorldStateCodec.state(from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.character, world.character)
        XCTAssertEqual(restored.wallet, world.wallet)
        XCTAssertEqual(restored.profile, world.profile)
        XCTAssertEqual(restored.level, 13)
        XCTAssertEqual(restored.totalPoints, 842)
        XCTAssertEqual(restored.bestScore, 89)
        XCTAssertEqual(restored.streak, 4)
        XCTAssertEqual(restored.lastChallengeDay, "2026-10-18")
        XCTAssertEqual(restored.storyLog, world.storyLog)
        XCTAssertTrue(restored.challengeDrafts.isEmpty)
        XCTAssertTrue(restored.challengeHistory.isEmpty)
    }

    func testDraftsAndExactInventionsSurviveSaveRoundTrip() throws {
        var world = WorldState.newGame(characterName: "Wren", companionName: "Kindle")
        world.challengeDrafts = ["14": "A picnic blanket becomes a wing.\nIt carries the shade."]
        let entry = ChallengeJournalEntry(level: 13, contentID: "park.picnic", title: "The Travelling Picnic",
            answer: "A folding leaf boat 🌿 carries the picnic without leaving a trace.", score: 83,
            isPracticeEstimate: true, storyBeat: "Kindle unfolds the leaf boat.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        world.challengeHistory = [entry]
        let restored = try WorldStateCodec.state(from: WorldStateCodec.data(from: world))
        XCTAssertEqual(restored.challengeDrafts, world.challengeDrafts)
        XCTAssertEqual(restored.challengeHistory, [entry])
        XCTAssertTrue(restored.challengeHistory[0].isPracticeEstimate)
    }
}
