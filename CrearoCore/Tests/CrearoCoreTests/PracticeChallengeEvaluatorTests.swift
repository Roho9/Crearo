import XCTest
@testable import CrearoCore

final class PracticeChallengeEvaluatorTests: XCTestCase {
    private let evaluator = PracticeChallengeEvaluator()
    private let gap = PracticeChallengeContext(
        goal: "Get across the gap.",
        goalTerms: ["gap", "canyon", "across", "far bank"],
        mechanismTerms: ["bridge", "float", "carry", "stretch", "fly", "cross", "rope", "lift"])
    private let tree = PracticeChallengeContext(
        goal: "Light the lantern tree.",
        goalTerms: ["lantern", "tree", "branches"],
        mechanismTerms: ["light", "glow", "shine", "reflect", "firefly", "sun", "bright"])

    private let inventiveCrossing = """
    We weave a ribbon from folded paper leaves and stretch it across the canyon.
    Tiny copper bells guide our companion over the gap, because each step unfolds another bridge panel.
    """

    private func total(_ answer: String, _ context: PracticeChallengeContext) -> Int {
        CreativityRubric.default.evaluate(evaluator.evaluate(answer: answer, context: context).raw).total
    }

    func testExplainedGoalRelevantIdeaCanClearTheHighestLevelGate() {
        let result = evaluator.evaluate(answer: inventiveCrossing, context: gap)
        let grade = CreativityRubric.default.evaluate(result.raw)
        XCTAssertGreaterThanOrEqual(grade.total, LevelGate.passMark(forLevel: 50),
                                  "The local practice path must not strand players at the late level gate.")
        XCTAssertFalse(result.evidence.isEmpty)
        XCTAssertGreaterThan(result.raw.fit, 0.8)
    }

    func testTheSameWritingIsNotAutomaticallyRelevantToAnotherChallenge() {
        XCTAssertGreaterThan(total(inventiveCrossing, gap), total(inventiveCrossing, tree) + 40)
        let result = evaluator.evaluate(answer: inventiveCrossing, context: tree)
        XCTAssertLessThan(total(inventiveCrossing, tree), LevelGate.passMark(forLevel: 1))
        XCTAssertTrue(result.coaching.contains("light the lantern tree"))
    }

    func testConciseMechanismDoesNotNeedPaddingToPassAnEarlyLevel() {
        let answer = "We float a folded paper boat across the gap, using its tiny leaf sail to carry our companion."
        XCTAssertGreaterThanOrEqual(total(answer, gap), LevelGate.passMark(forLevel: 1))
        let padded = answer + " " + Array(repeating: "very", count: 80).joined(separator: " ")
        XCTAssertLessThanOrEqual(total(padded, gap), total(answer, gap), "Filler must not inflate the estimate.")
    }

    func testBareKeywordListCannotManufactureAHighScore() {
        let words = "gap canyon across bridge float carry stretch fly cross rope lift paper copper bell hope glow transform delight"
        let result = evaluator.evaluate(answer: words, context: gap)
        XCTAssertLessThan(total(words, gap), 20)
        XCTAssertTrue(result.coaching.contains("explanation"))
        let joined = "gap and canyon and across and bridge and float and carry and stretch and fly and paper and copper and bell"
        XCTAssertLessThan(total(joined, gap), 20, "Joining every clue with 'and' is still a word list.")
        let disguised = "I gap canyon across bridge float carry stretch fly cross rope lift paper copper bell hope glow transform because so"
        XCTAssertLessThan(total(disguised, gap), 20, "A few structure words do not make a dictionary dump an explanation.")
    }

    func testRepeatedSentencesDoNotCreateDetailOrDifferentIdeas() {
        let line = "We build a tiny bridge across the gap with paper panels."
        let repeated = Array(repeating: line, count: 8).joined(separator: " ")
        let result = evaluator.evaluate(answer: repeated, context: gap)
        XCTAssertLessThan(total(repeated, gap), 20)
        XCTAssertTrue(result.coaching.contains("repeated"))
    }

    func testUnrelatedWellWrittenProseDoesNotClearTheGoal() {
        let answer = "We bake tiny cinnamon cakes in copper cups because our companion loves sharing warm food. Then we fold paper hats and sing a gentle song together."
        XCTAssertLessThan(total(answer, gap), LevelGate.passMark(forLevel: 1))
        let catalogGap = ChallengeProvider.allContent.first { $0.contentID == "prism-wide-gap" }!
        XCTAssertLessThan(total(answer, catalogGap.practiceContext), catalogGap.passMark,
                          "The real catalog must not mistake any mention of the companion for crossing the gap.")
    }

    func testAuthoredLateChallengesInEveryRegionHaveAttainablePracticeScores() {
        let examples: [(String, String)] = [
            ("prism-last-bright", "We fill the grey statue with folded paper birds, then release them because each remembered idea becomes a wing. Our companion sings until the statue stretches its copper fingers and steps into life."),
            ("park-sliding-picnic", "We fold tiny pockets into the picnic blanket so sliding snacks land in soft leaf cups. A ribbon pulley carries food uphill to the snail, while the sparrow reaches copper trays at the top."),
            ("market-signless-shop", "We shape a giant loaf from warm paper ribbons above the bakery. Tiny copper fans carry the bread scent down the lane so visitors follow their noses, while a moving picture shows dough rising."),
            ("harbor-handless-visitor", "We welcome the floating visitor with a curtain of soft light that responds when it moves. Its gentle touch leaves a glowing pattern on the water, so the harbor can remember its visit without asking it to hold a gift.")
        ]
        for (id, answer) in examples {
            let challenge = ChallengeProvider.allContent.first { $0.contentID == id }!
            XCTAssertGreaterThanOrEqual(total(answer, challenge.practiceContext), LevelGate.passMark(forLevel: 50),
                                      "A concrete explained solution should clear even the capped gate in \(challenge.regionTitle): \(id).")
        }
    }

    func testHumanPlausibleSolutionsCanProgressThroughTheAuthoredCampaign() {
        // Hand-written solutions describe the actual situation. This corpus checks that authored
        // clue coverage does not recreate an unreachable chapter, rather than injecting each
        // profile's terms into a template. Multi-approach prompts receive distinct listed plans.
        let solutions: [(String, String)] = [
            ("prism-spark", "We plant tiny paper bells so the still world rings when our companion steps. Each warm note unfolds a flower and invites nearby people to dance together."),
            ("prism-wide-gap", "We float a folded paper boat across the gap, using its tiny leaf sail to carry our companion."),
            ("prism-grumble", "We show the Grumble a tiny copper hat that dances on a giant pair of paper boots. When it bows, soft petals sneeze from its nose and tickle the creature into a laugh."),
            ("prism-three-doors", """
            We fold the first door into a tiny paper boat so it floats gently out of our way.
            I sing a warm note to the next doorway until copper hinges turn into dancing legs.
            Our companion plants a seed by the last entrance and its roots lift the wooden panel overhead.
            """),
            ("prism-lantern-tree", "We catch the reflections of tiny stars in dew-filled paper cups. Our companion hangs them on the tree so each lantern glows softly, while copper leaves reflect the light onto neighboring branches."),
            ("prism-tangle", "Our comb has soft copper teeth that roll along each vine to separate its knots. The handle weaves the freed strands into tiny hammocks, so the cleared meadow becomes a resting place for tired visitors."),
            ("prism-echo", "I tell the cave: a tiny moon folds its silver pajamas into paper boats, then sails them through a sleeping teacup so tomorrow can find its warm socks."),
            ("prism-long-list", """
            I thread the button onto a ribbon so it holds a tiny curtain closed.
            We roll it through soft sand to mark a winding trail for lost ants.
            Our companion trades it as a pretend coin in a miniature paper market.
            I attach it to a copper spoon and spin it to make a gentle rattling instrument.
            """),
            ("prism-riddle-pond", "Courage is a tiny cracked seed in my hand. Its rough shell opens when I feel afraid, because a warm copper root reminds me that growing means stepping into unknown soil."),
            ("prism-sleepy-giant", "We bake tiny cinnamon rolls in a paper oven so the warm scent drifts toward the giant. Our companion sings softly as it wakes, then offers breakfast and a gentle smile."),
            ("prism-color-thief", "We offer the Fizzle a ribbon maze that changes shape whenever a breeze spins through it. Tiny copper bells turn each gust into a playful song, so it trades the hidden colours for endless new music."),
            ("prism-last-bright", "We fill the statue with paper birds. Each remembered idea unfolds a wing, then our companion sings so the grey fingers stretch and the statue steps into life."),
            ("park-sliding-picnic", "We fold tiny pockets into the picnic blanket so sliding snacks land in soft leaf cups. A ribbon pulley carries food uphill to the snail, while the sparrow reaches copper trays at the top."),
            ("park-tiny-gate", "We turn the gate into a soft copper arch that lifts when a tall guest approaches. A tiny leaf tunnel remains open underneath, so the snail rolls straight through while the sparrow walks comfortably above."),
            ("park-quiet-parade", "Our silent parade follows tiny glowing flags that change color when dancers lift their feet. Paper shadows ripple across the grass so neighbors can join the rhythm while the sleeping gardener hears nothing."),
            ("park-misplaced-shade", "We hang a ribbon of folded paper leaves from a floating hoop above the fixed benches. Tiny copper fins tilt the canopy toward the sun, so its cool shadow follows the picnic without moving a seat."),
            ("market-signless-shop", "We shape a giant loaf from warm paper ribbons above the bakery. Tiny copper fans carry the bread scent down the lane so visitors follow their noses, while a moving picture shows dough rising."),
            ("market-delivery-tangle", """
            We lift the parcels above the carts with tiny copper pulleys so ribbons carry them to each stall.
            Our companion starts a hand-to-hand relay that passes soft packages along the crowded lane.
            I send folded paper delivery birds through the market windows so each shop receives its own bundle.
            """),
            ("market-balloon-arch", "We lay the balloon animals sideways in soft leaf cradles. Tiny copper wheels slide each cradle through the low arch while paper cushions protect the long ears, then ribbons lift the animals upright again."),
            ("market-borrowed-minute", "Each customer takes a tiny paper leaf and joins a branch-shaped queue. When a sale finishes, the shopkeeper passes a copper bird to the next leaf, so everyone sees whose turn is ready without a clock."),
            ("harbor-folding-boat", "We seal the paper boat with a thin layer of leaf wax and brace its folds with tiny copper ribs. Splashes roll into soft drainage channels, so the cargo stays dry while the original paper body keeps its shape."),
            ("harbor-map-holes", "We tell a tiny story: the striped buoy plants a seed, the crooked willow grows from it, then its branch points to the red-roofed shed. Three folded paper charms help the visitor remember that order while following the route."),
            ("harbor-lighthouse-inward", "We hang a copper mirror beside the lighthouse lamp so it reflects the existing light through a tiny window. Folded paper fins guide the beam toward the water, where arriving boats can follow its soft glow without a brighter lamp."),
            ("harbor-handless-visitor", "We welcome the floating visitor with a curtain of soft light that responds when it moves. Its gentle touch leaves a glowing pattern on the water, so the harbor can remember its visit without asking it to hold a gift.")
        ]
        XCTAssertEqual(solutions.count, ChallengeProvider.catalogCount)
        for (id, answer) in solutions {
            let challenge = ChallengeProvider.allContent.first { $0.contentID == id }!
            let score = total(answer, challenge.practiceContext)
            XCTAssertGreaterThanOrEqual(score, challenge.passMark,
                                      "Practice corpus blocked at \(id): \(score)/\(challenge.passMark).")
        }
    }

    func testWordBoundariesDoNotMistakeGlitterForLitOrLight() {
        let context = PracticeChallengeContext(goal: "Make it lit.", goalTerms: ["lit"], mechanismTerms: ["glow"])
        let answer = "We spread glitter over a smooth paper lantern so our companion can carry the tiny bowl."
        XCTAssertLessThan(evaluator.evaluate(answer: answer, context: context).raw.fit, 0.25)
    }

    func testSimpleInflectionsAndMultiwordGoalPhrasesAreRecognized() {
        let context = PracticeChallengeContext(goal: "Reach the far bank.", goalTerms: ["far bank"], mechanismTerms: ["carry"])
        let answer = "A folded paper crane carries our companion to the far bank while tiny bells guide its wings."
        XCTAssertGreaterThan(evaluator.evaluate(answer: answer, context: context).raw.fit, 0.8)
    }

    func testExplicitConstraintMustBeAddressed() {
        let context = PracticeChallengeContext(goal: "Light the lantern tree using water.",
            goalTerms: tree.goalTerms, mechanismTerms: tree.mechanismTerms,
            requiredTermGroups: [["water", "rain", "dew"]])
        let missing = "We fold tiny copper mirrors around the tree so each lantern can reflect a bright beam of sunlight."
        let satisfied = missing + " Dew fills each paper cup and turns the water into a lens."
        XCTAssertLessThan(total(missing, context), LevelGate.passMark(forLevel: 1))
        XCTAssertGreaterThanOrEqual(total(satisfied, context), LevelGate.passMark(forLevel: 1))
        XCTAssertTrue(evaluator.evaluate(answer: missing, context: context).coaching.contains("constraints"))
    }

    func testMultipleApproachesRequireDistinctSectionsRatherThanRepeatingOne() {
        let context = PracticeChallengeContext(goal: "Open a handleless door three different ways.",
            goalTerms: ["door", "open"], mechanismTerms: ["fold", "tap", "sing", "turn", "grow"], minimumDistinctIdeas: 3)
        let one = "We fold the door into a tiny paper boat so it floats gently out of our way."
        let three = """
        We fold the door into a tiny paper boat so it floats gently out of our way.
        I tap a rhythm on the wall until copper hinges turn into dancing legs.
        Our companion sings a warm song and the wooden panels grow into flowering branches.
        """
        XCTAssertLessThan(total(one, context), LevelGate.passMark(forLevel: 1))
        XCTAssertGreaterThanOrEqual(total(three, context), LevelGate.passMark(forLevel: 50))
        XCTAssertTrue(evaluator.evaluate(answer: one, context: context).coaching.contains("3 different approaches"))
    }

    func testEmptyGenericAndKeyboardMashRemainLow() {
        for answer in ["", "nice cool good stuff whatever", "bzzzk zzzzzz qwrttp plkjhg"] {
            XCTAssertLessThan(total(answer, gap), 10)
        }
    }

    func testEvaluationIsDeterministicAndBoundedForLargeInput() {
        let answer = String(repeating: inventiveCrossing, count: 300)
        let first = evaluator.evaluate(answer: answer, context: gap)
        XCTAssertEqual(first, evaluator.evaluate(answer: answer, context: gap))
        for criterion in RubricCriterion.allCases {
            XCTAssertTrue(first.raw[criterion].isFinite)
            XCTAssertTrue((0...1).contains(first.raw[criterion]))
        }
    }
}
