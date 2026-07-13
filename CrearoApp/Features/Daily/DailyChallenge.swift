import Foundation
import CrearoCore

// Crearo is a creativity game in the spirit of Scribblenauts: each level is a little puzzle in the
// bright world of Prism, and you solve it by INVENTING the thing that gets you through. Your idea is
// graded out of 100 against a hard rubric, and you only advance to the next level if it is creative
// enough. When it is, your companion acts your idea out in a pixel cut-scene. One level a day.

struct DailyChallenge: Identifiable {
    let id: String                 // "yyyy-MM-dd" (stable per day)
    let level: Int                 // 1-based level number
    let title: String
    let setup: String              // the scene / the problem you face
    let goal: String               // what solving this level looks like (the win condition)
    let question: String           // the creative ask: invent the thing that solves it
    let placeholder: String
    let focusDimension: CreativeDimension?

    var focus: DimensionScores {
        var f = DimensionScores.uniform
        if let d = focusDimension { f[d] = 2.0 }
        return f
    }

    /// The score you must reach to clear this level (rises as levels climb).
    var passMark: Int { LevelGate.passMark(forLevel: level) }
}

enum ChallengeProvider {
    static func dayKey(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    /// The level you face right now. It only changes when you clear the current one, so it stays put
    /// all day and moves forward when your idea passes the gate. Beyond the hand-written bank the
    /// levels cycle, but the pass mark keeps climbing, so they get harder either way.
    static func challenge(level: Int, date: Date = Date()) -> DailyChallenge {
        let n = max(1, level)
        let lv = levels[(n - 1) % levels.count]
        return DailyChallenge(id: dayKey(date), level: n, title: lv.title, setup: lv.setup,
                              goal: lv.goal, question: lv.question, placeholder: lv.placeholder,
                              focusDimension: lv.focus)
    }

    private struct LevelSpec {
        let title, setup, goal, question, placeholder: String
        let focus: CreativeDimension?
    }

    private static let levels: [LevelSpec] = [
        LevelSpec(
            title: "The Spark",
            setup: "You wake in Prism, a world where everything is bright but oddly still, as if it forgot how to play. Your companion blinks awake beside you.",
            goal: "Wake the world up.",
            question: "Invent the very first thing you and your companion make together to wake Prism up. What is it, and what does it do?",
            placeholder: "We make a…", focus: .originality),

        LevelSpec(
            title: "The Wide Gap",
            setup: "The path ends at a canyon far too wide to jump. A friendly cloud drifts by, unbothered.",
            goal: "Get across the gap.",
            question: "Invent a wonderfully clever way to cross. The stranger and more delightful, the better.",
            placeholder: "I cross it by…", focus: .riskTaking),

        LevelSpec(
            title: "The Grumble",
            setup: "A small, grumpy creature called a Grumble sits in the road, refusing to move because it has never seen anything fun.",
            goal: "Make the Grumble laugh.",
            question: "Invent something so joyful it makes the Grumble burst out laughing. Describe it in vivid detail.",
            placeholder: "I show it a…", focus: .emotionalExpression),

        LevelSpec(
            title: "Three Doors",
            setup: "A wall has three identical doors and no handles. Your companion tilts its head.",
            goal: "Open a handleless door.",
            question: "Give three completely different ways to open a door with no handle. Make each one truly different.",
            placeholder: "First… Second… Third…", focus: .flexibility),

        LevelSpec(
            title: "The Lantern Tree",
            setup: "A tall tree is covered in tiny dark lanterns, waiting for light.",
            goal: "Light the lantern tree.",
            question: "Invent a light the night sky has never seen. What does it look and feel like?",
            placeholder: "A light made of…", focus: .elaboration),

        LevelSpec(
            title: "The Tangle",
            setup: "A field of vines has knotted itself into a giant tangle, blocking the meadow.",
            goal: "Clear the tangle, usefully.",
            question: "Design a tool that untangles the vines and turns the mess into something useful. Say exactly how it works.",
            placeholder: "My tool works by…", focus: .usefulness),

        LevelSpec(
            title: "The Echo",
            setup: "A cave repeats everything in funny voices and will only let you pass if you say something it has never heard.",
            goal: "Say something brand new.",
            question: "Make up a sentence the cave could never have heard before. Be playful and original.",
            placeholder: "I say…", focus: .originality),

        LevelSpec(
            title: "The Long List",
            setup: "A bridge keeper holds a single plain button and will lower the bridge only for a truly inventive mind.",
            goal: "Impress the bridge keeper.",
            question: "List as many genuinely different uses for a button as you can. Quantity first, do not filter.",
            placeholder: "A button could…", focus: .fluency),

        LevelSpec(
            title: "The Riddle Pond",
            setup: "A still pond shows a reflection that asks: what does courage look like if you could hold it?",
            goal: "Answer the pond's riddle.",
            question: "Describe courage as an object you could carry. What is it made of, and how does it feel in your hand?",
            placeholder: "Courage looks like…", focus: .symbolicThinking),

        LevelSpec(
            title: "The Sleepy Giant",
            setup: "A gentle giant snores across the only road, and waking it rudely would be unkind.",
            goal: "Wake the giant kindly.",
            question: "Invent a kind, creative way to wake the giant that would make it smile.",
            placeholder: "To wake it I…", focus: .emotionalExpression),

        LevelSpec(
            title: "The Color Thief",
            setup: "A mischievous breeze called the Fizzle has been swiping colours and hiding them. It loves a good trade.",
            goal: "Trade back the colours.",
            question: "Invent something so wonderful the Fizzle happily trades every colour back for it.",
            placeholder: "I offer it a…", focus: .originality),

        LevelSpec(
            title: "The Last Bright",
            setup: "At the heart of Prism stands a great grey statue of yourself, made of every idea you were once too unsure to try.",
            goal: "Bring the statue to life.",
            question: "Invent the boldest creation yet to wake the statue and finish bringing Prism back to life.",
            placeholder: "I make a…", focus: .riskTaking),
    ]
}
