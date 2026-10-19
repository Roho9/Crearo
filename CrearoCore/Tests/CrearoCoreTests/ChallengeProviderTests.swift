import XCTest
@testable import CrearoCore

final class ChallengeProviderTests: XCTestCase {
    func testExistingSaveLevelsKeepTheirOriginalChapterOrder() {
        let originalTitles = ["The Spark", "The Wide Gap", "The Grumble", "Three Doors",
                              "The Lantern Tree", "The Tangle", "The Echo", "The Long List",
                              "The Riddle Pond", "The Sleepy Giant", "The Color Thief", "The Last Bright"]
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        for (offset, title) in originalTitles.enumerated() {
            let chapter = ChallengeProvider.challenge(level: offset + 1, date: date)
            XCTAssertEqual(chapter.title, title)
            XCTAssertEqual(chapter.level, offset + 1)
            XCTAssertEqual(chapter.id, ChallengeProvider.dayKey(date))
            XCTAssertEqual(chapter.region, .prism)
        }
    }

    func testExpansionAddsNewContentBeforeAnyChapterRepeats() {
        XCTAssertEqual(ChallengeProvider.catalogCount, 24)
        let chapters = ChallengeProvider.allContent
        XCTAssertEqual(chapters.map(\.level), Array(1...24))
        XCTAssertEqual(Set(chapters.map(\.contentID)).count, 24)
        XCTAssertEqual(Set(chapters.map(\.title)).count, 24)
        XCTAssertEqual(chapters[12].title, "The Picnic That Slides")
        XCTAssertEqual(chapters[16].title, "The Shop Without a Sign")
        XCTAssertEqual(chapters[20].title, "The Folding Boat")

        let repeated = ChallengeProvider.challenge(level: 25)
        XCTAssertEqual(repeated.level, 25)
        XCTAssertEqual(repeated.contentID, chapters[0].contentID)
        XCTAssertEqual(repeated.title, chapters[0].title)
        XCTAssertEqual(repeated.passMark, LevelGate.passMark(forLevel: 25))
    }

    func testEveryRegionHasAContiguousCompleteSetOfChapters() {
        let chapters = ChallengeProvider.allContent
        for region in ChallengeRegion.allCases {
            let regional = chapters.filter { $0.region == region }
            XCTAssertEqual(regional.count, region.challengeCount)
            XCTAssertEqual(regional.map(\.regionIndex), Array(1...region.challengeCount))
            XCTAssertEqual(regional.first?.level, region.firstLevel)
            XCTAssertFalse(region.title.isEmpty)
            XCTAssertFalse(region.subtitle.isEmpty)
        }
    }

    func testEveryChapterSuppliesActionableContextForCoachingAndScenes() {
        for chapter in ChallengeProvider.allContent {
            let fields = [chapter.contentID, chapter.title, chapter.setup, chapter.goal, chapter.question,
                          chapter.placeholder, chapter.constraint, chapter.hint, chapter.revisionPrompt,
                          chapter.sceneTarget]
            XCTAssertTrue(fields.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                          chapter.contentID)
            XCTAssertEqual(chapter.practiceContext.goal, chapter.goal)
            XCTAssertFalse(chapter.practiceContext.goalTerms.isEmpty, chapter.contentID)
            XCTAssertFalse(chapter.practiceContext.mechanismTerms.isEmpty, chapter.contentID)
            XCTAssertTrue(chapter.contentID.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
            XCTAssertNotNil(chapter.focusDimension)
        }
    }

    func testMultiIdeaChallengesKeepTheirDifferentPracticeExpectations() {
        let chapters = ChallengeProvider.allContent
        XCTAssertEqual(chapters.first { $0.title == "Three Doors" }?.practiceContext.minimumDistinctIdeas, 3)
        XCTAssertEqual(chapters.first { $0.title == "The Long List" }?.practiceContext.minimumDistinctIdeas, 4)
        XCTAssertEqual(chapters.first { $0.title == "The Tangle of Deliveries" }?.practiceContext.minimumDistinctIdeas, 3)
        XCTAssertEqual(chapters.first { $0.title == "The Folding Boat" }?.practiceContext.minimumDistinctIdeas, 1)
    }

    func testDayIDsUseLocalCalendarDayAndStableGregorianDigits() throws {
        let formatter = ISO8601DateFormatter()
        let boundary = try XCTUnwrap(formatter.date(from: "2026-10-19T01:30:00Z"))
        let utc = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let chicago = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        XCTAssertEqual(ChallengeProvider.dayKey(boundary, timeZone: utc), "2026-10-19")
        XCTAssertEqual(ChallengeProvider.dayKey(boundary, timeZone: chicago), "2026-10-18")
        XCTAssertEqual(ChallengeProvider.dayKey(boundary, timeZone: tokyo), "2026-10-19")

        // Foundation Date has no locale. The same instant expressed through a Buddhist calendar
        // must still produce the Gregorian, ASCII save key used by streak and attempt records.
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = utc
        let buddhistDate = try XCTUnwrap(buddhist.date(from: DateComponents(year: 2569, month: 10, day: 19)))
        XCTAssertEqual(ChallengeProvider.dayKey(buddhistDate, timeZone: utc), "2026-10-19")
    }

    func testContentIdentityIsStableAcrossDaysAndInvalidLevelsClampSafely() {
        let yesterday = Date(timeIntervalSince1970: 1_790_000_000)
        let tomorrow = yesterday.addingTimeInterval(2 * 86_400)
        let first = ChallengeProvider.challenge(level: 13, date: yesterday)
        let later = ChallengeProvider.challenge(level: 13, date: tomorrow)
        XCTAssertEqual(first.contentID, later.contentID)
        XCTAssertEqual(first.title, later.title)
        XCTAssertNotEqual(first.id, later.id)
        XCTAssertEqual(ChallengeProvider.challenge(level: 0).level, 1)
        XCTAssertEqual(ChallengeProvider.challenge(level: Int.min).contentID, ChallengeProvider.allContent[0].contentID)
        XCTAssertEqual(ChallengeProvider.challenge(level: Int.max).level, Int.max)
    }
}
