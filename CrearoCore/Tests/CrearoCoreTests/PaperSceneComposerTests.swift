import XCTest
@testable import CrearoCore

final class PaperSceneComposerTests: XCTestCase {
    func testHeartbeatAndGlitterDoNotBecomeAnAttackOrAnEmbeddedColor() {
        let scene = PaperSceneComposer.compose(answer: "Heartbeat lantern: its glitter holds a tired tune.", target: "the still world")
        XCTAssertEqual(scene.item, "Heartbeat lantern")
        XCTAssertEqual(scene.action, "summon")
        XCTAssertEqual(scene.target, "the still world")
    }

    func testNamedHeadingAndFirstExplicitColorAreKept() {
        let scene = PaperSceneComposer.compose(
            answer: "Blue paper song lantern: we build it from a golden spring and folded leaves.", target: "the lantern tree")
        XCTAssertEqual(scene.item, "Blue paper song lantern")
        XCTAssertEqual(scene.color, "blue")
        XCTAssertEqual(scene.action, "build")
    }

    func testRepeatedAttemptHasStableDirectionAndSkipsIntroductoryWords() {
        let answer = "We build a shadow bridge for the canyon."
        let scene = PaperSceneComposer.compose(answer: answer, target: "the wide canyon")
        XCTAssertTrue(scene.item.hasPrefix("shadow bridge"))
        XCTAssertEqual(scene, PaperSceneComposer.compose(answer: answer, target: "the wide canyon"))
        XCTAssertEqual(scene.action, "build")
    }
}
