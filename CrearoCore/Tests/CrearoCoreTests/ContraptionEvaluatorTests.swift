import XCTest
@testable import CrearoCore

final class ContraptionEvaluatorTests: XCTestCase {
    private let evaluator = ContraptionEvaluator()
    private let explanation = "The objects work together to carry our little invention forward."
    // Different object sets, not merely the same objects reordered.
    private var examples: [(Int, ContraptionRecipe, String)] { [
        (1, .init(anchor: .sail, engine: .fan, twist: .bell), "The sail reaches across the gap while the fan carries the bell's hello."),
        (1, .init(anchor: .wheel, engine: .spring, twist: .mirror), "The wheel rolls the spring forward while the mirror flashes a distant hello."),
        (2, .init(anchor: .seed, engine: .spring, twist: .sail), "The seed cradles the sleeping moon as the spring raises its soft sail."),
        (2, .init(anchor: .sail, engine: .fan, twist: .seed), "The fan lifts the sail and its seed cushion gently under the moon."),
        (3, .init(anchor: .seed, engine: .fan, twist: .sail), "The fan sways the sail softly while the seed protects the dancing flowers."),
        (3, .init(anchor: .sail, engine: .wheel, twist: .seed), "The wheel turns a sail slowly and the seed carries flowers around it."),
        (4, .init(anchor: .mirror, engine: .sail, twist: .seed), "The mirror guides raindrops into the sail while the seed cushions their landing."),
        (4, .init(anchor: .seed, engine: .sail, twist: .wheel), "The seed holds the rain in a sail that the wheel guides upward."),
        (5, .init(anchor: .magnet, engine: .fan, twist: .bell), "The fan lifts the magnet's spark while the bell announces its cloudy stop."),
        (5, .init(anchor: .mirror, engine: .fan, twist: .magnet), "The magnet carries a spark upward on the fan's gust toward the mirror."),
        (6, .init(anchor: .sail, engine: .spring, twist: .wheel), "The sail cradles each wave as the spring lifts the wheel's next step."),
        (6, .init(anchor: .sail, engine: .magnet, twist: .wheel), "The magnet draws the wheel up while the sail carries each careful wave.")
    ] }

    func testSixFiniteStationsAndStableObjectIDs() {
        XCTAssertEqual(ContraptionChallenge.catalogCount, 6)
        XCTAssertEqual(ContraptionChallenge.catalog.map(\.level), Array(1...6))
        XCTAssertEqual(Set(ContraptionChallenge.catalog.map(\.id)).count, 6)
        XCTAssertEqual(Set(ContraptionPart.allCases.map(\.rawValue)), ["fan", "bell", "spring", "mirror", "sail", "magnet", "wheel", "seed"])
        XCTAssertNil(ContraptionChallenge.level(0)); XCTAssertNil(ContraptionChallenge.level(7))
        for challenge in ContraptionChallenge.catalog {
            XCTAssertFalse(challenge.goal.isEmpty); XCTAssertFalse(challenge.writingPrompt.isEmpty)
            XCTAssertEqual(challenge.requirements.count, 3); XCTAssertFalse(challenge.hint.isEmpty)
        }
    }
    func testTwoExplainedDifferentObjectSetsCanClearEveryStation() throws {
        for (level, recipe, text) in examples {
            let challenge = try XCTUnwrap(ContraptionChallenge.level(level))
            let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: text)
            XCTAssertTrue(result.passed, "Station \(level), \(recipe.signature): \(result.feedback)")
            XCTAssertTrue(result.checks.allSatisfy(\.isSatisfied)); XCTAssertEqual(result.breakdown.mechanicalFit, 70)
            XCTAssertEqual(result.breakdown.explanationCompletion, 10); XCTAssertEqual(result.score, result.breakdown.total)
            XCTAssertTrue((80...100).contains(result.score)); XCTAssertEqual(result.scoreLabel, "Local puzzle score")
        }
        for level in 1...6 {
            let sets = examples.filter { $0.0 == level }.map { Set($0.1.parts) }
            XCTAssertEqual(sets.count, 2); XCTAssertNotEqual(sets[0], sets[1])
        }
    }
    func testEveryStationHasMultipleWorkingRecipesAndMeaningfulFailures() {
        for challenge in ContraptionChallenge.catalog {
            let evaluations = allRecipes.map { ($0, evaluator.evaluate(challenge: challenge, recipe: $0, explanation: explanation)) }
            let valid = evaluations.filter { $0.1.passed }
            let sets = Set(valid.map { $0.0.parts.map(\.rawValue).sorted().joined(separator: ":") })
            XCTAssertGreaterThanOrEqual(sets.count, 2, "Station \(challenge.level) needs different constructions.")
            XCTAssertTrue(evaluations.contains { !$0.1.passed }); XCTAssertLessThan(valid.count, allRecipes.count / 2)
            for (_, result) in evaluations {
                XCTAssertTrue((0...100).contains(result.score)); XCTAssertFalse(result.feedback.isEmpty); XCTAssertFalse(result.nextStep.isEmpty)
            }
        }
    }
    func testSwappingRolesChangesTheMechanicalOutcome() throws {
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1))
        let original = ContraptionRecipe(anchor: .sail, engine: .fan, twist: .bell)
        let swapped = ContraptionRecipe(anchor: .fan, engine: .sail, twist: .bell)
        let pass = evaluator.evaluate(challenge: challenge, recipe: original, explanation: explanation)
        let fail = evaluator.evaluate(challenge: challenge, recipe: swapped, explanation: explanation)
        XCTAssertTrue(pass.passed); XCTAssertFalse(fail.passed)
        XCTAssertEqual(pass.capabilities.reach, 8); XCTAssertEqual(fail.capabilities.reach, 6)
        XCTAssertTrue(fail.nextStep.contains("anchor")); XCTAssertNotEqual(original.capabilities, swapped.capabilities)
    }
    func testPlacementSwapsAnExistingObjectAndMovesItIntoAnEmptySlot() {
        var recipe = ContraptionRecipe(anchor: .sail, engine: .fan)
        recipe.place(.sail, in: .engine)
        XCTAssertEqual(recipe.anchor, .fan); XCTAssertEqual(recipe.engine, .sail)
        recipe.place(.fan, in: .twist)
        XCTAssertNil(recipe.anchor); XCTAssertEqual(recipe.twist, .fan); XCTAssertTrue(recipe.hasDistinctParts)
        recipe.place(nil, in: .engine); XCTAssertNil(recipe.engine)
    }
    func testIncompleteAndDuplicatedObjectsCannotClear() throws {
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1))
        for recipe in [ContraptionRecipe(), .init(anchor: .sail, engine: .fan), .init(anchor: .mirror, engine: .spring, twist: .mirror)] {
            let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: explanation)
            XCTAssertFalse(result.passed); XCTAssertEqual(result.breakdown.mechanicalFit, 0); XCTAssertEqual(result.breakdown.partRange, 0)
        }
    }
    func testForbiddenObjectAndMaximumCapabilityConstraintsAreRealRules() throws {
        let moon = try XCTUnwrap(ContraptionChallenge.level(2))
        let bell = evaluator.evaluate(challenge: moon, recipe: .init(anchor: .seed, engine: .spring, twist: .bell), explanation: explanation)
        XCTAssertFalse(bell.passed); XCTAssertFalse(bell.constraintChecks[0].isSatisfied); XCTAssertTrue(bell.nextStep.contains("Replace the bell"))
        let garden = try XCTUnwrap(ContraptionChallenge.level(3))
        let noisy = evaluator.evaluate(challenge: garden, recipe: .init(anchor: .seed, engine: .fan, twist: .mirror), explanation: explanation)
        XCTAssertTrue(noisy.capabilityChecks.allSatisfy(\.isSatisfied)); XCTAssertFalse(noisy.passed)
        XCTAssertEqual(noisy.constraintChecks[0].actual, 6); XCTAssertEqual(noisy.constraintChecks[0].required, 2)
        let rain = try XCTUnwrap(ContraptionChallenge.level(4))
        let wild = evaluator.evaluate(challenge: rain, recipe: .init(anchor: .sail, engine: .spring, twist: .seed), explanation: explanation)
        XCTAssertTrue(wild.capabilityChecks.allSatisfy(\.isSatisfied)); XCTAssertFalse(wild.constraintChecks[0].isSatisfied); XCTAssertFalse(wild.passed)
    }
    func testWritingBoundaryRejectsOversizeWithoutTruncatingAndDoesNotRewardPadding() throws {
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1))
        let recipe = ContraptionRecipe(anchor: .sail, engine: .fan, twist: .bell)
        let short = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: "Seven little words do not complete this")
        XCTAssertEqual(short.writingStatus.wordCount, 7); XCTAssertEqual(short.writingStatus.state, .tooShort); XCTAssertFalse(short.passed)
        let exact = explanation + String(repeating: " ", count: 600 - explanation.count)
        let atLimit = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: exact)
        let above = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: exact + "x")
        XCTAssertTrue(atLimit.passed); XCTAssertEqual(atLimit.writingStatus.characterCount, 600)
        XCTAssertFalse(above.passed); XCTAssertEqual(above.writingStatus.state, .tooLong); XCTAssertEqual(above.writingStatus.characterCount, 601)
        XCTAssertTrue(above.nextStep.contains("kept in full"))
        XCTAssertEqual(atLimit.score, evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: explanation).score)
        XCTAssertEqual(evaluator.writingStatus(for: " \n ").state, .empty)
        XCTAssertEqual(evaluator.writingStatus(for: "a b c d e f g h").state, .tooShort)
    }
    func testCompletionCheckHonestlyDoesNotClaimToJudgeWritingMeaning() throws {
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1))
        let result = evaluator.evaluate(challenge: challenge, recipe: .init(anchor: .sail, engine: .fan, twist: .bell),
                                        explanation: "Yesterday I baked a loaf of bread for our neighbors.")
        XCTAssertTrue(result.passed, "Writing is a completion check, not a fake semantic judge.")
        XCTAssertTrue(result.writingStatus.message.contains("not automatically judged"))
        XCTAssertTrue(result.scoreExplanation.contains("not a validated creativity rating"))
    }
    func testEvaluationAndRecipesRoundTripAndInvalidPartIDsAreRejected() throws {
        let challenge = try XCTUnwrap(ContraptionChallenge.level(1))
        let recipe = ContraptionRecipe(anchor: .sail, engine: .fan, twist: .bell)
        let result = evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: explanation)
        XCTAssertEqual(result, evaluator.evaluate(challenge: challenge, recipe: recipe, explanation: explanation))
        XCTAssertEqual(try JSONDecoder().decode(ContraptionEvaluation.self, from: JSONEncoder().encode(result)), result)
        XCTAssertEqual(try JSONDecoder().decode(ContraptionRecipe.self, from: JSONEncoder().encode(recipe)), recipe)
        XCTAssertThrowsError(try JSONDecoder().decode(ContraptionRecipe.self, from: Data("{\"anchor\":\"unknown-model\"}".utf8)))
    }
    private var allRecipes: [ContraptionRecipe] {
        ContraptionPart.allCases.flatMap { anchor in
            ContraptionPart.allCases.filter { $0 != anchor }.flatMap { engine in
                ContraptionPart.allCases.filter { $0 != anchor && $0 != engine }.map {
                    ContraptionRecipe(anchor: anchor, engine: engine, twist: $0)
                }
            }
        }
    }
}
