import Foundation
import CrearoCore

// The story is a bright, whimsical adventure through the world of Prism, where colour and wonder
// come from imagination. Each day is the next chapter: a little story setup, then one deep question
// that asks you to invent the way forward. Your answer is then acted out by your companion.

struct DailyChallenge: Identifiable {
    let id: String                 // "yyyy-MM-dd" (stable per day)
    let chapter: Int               // 1-based chapter number
    let title: String
    let setup: String              // story context
    let question: String           // the creative ask
    let placeholder: String
    let focusDimension: CreativeDimension?

    var focus: DimensionScores {
        var f = DimensionScores.uniform
        if let d = focusDimension { f[d] = 2.0 }
        return f
    }
}

enum ChallengeProvider {
    static func dayKey(_ d: Date = Date()) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: d)
    }

    /// The chapter advances with the story (one new beat per completed day), so it stays the same
    /// all day and only moves forward when you finish a challenge.
    static func challenge(chapterIndex: Int, date: Date = Date()) -> DailyChallenge {
        let ch = chapters[chapterIndex % chapters.count]
        return DailyChallenge(id: dayKey(date), chapter: chapterIndex + 1, title: ch.0, setup: ch.1,
                              question: ch.2, placeholder: ch.3, focusDimension: ch.4)
    }

    // (title, setup, question, placeholder, focus dimension)
    private static let chapters: [(String, String, String, String, CreativeDimension?)] = [
        ("The Spark",
         "You wake in Prism, a world where everything is bright but oddly still, as if it forgot how to play. Your companion blinks awake beside you, curious.",
         "Invent the very first thing you and your companion make together to wake the world up. What is it, and what does it do?",
         "We make a…", .originality),

        ("The Wide Gap",
         "The path ends at a canyon, far too wide to jump. A friendly cloud drifts by, unbothered.",
         "Describe a wonderfully clever way to cross the gap. The stranger and more delightful, the better.",
         "I would cross it by…", .riskTaking),

        ("The Grumble",
         "A small, grumpy creature called a Grumble sits in the road, refusing to move because it has never seen anything fun.",
         "Invent something so joyful it makes the Grumble laugh. Describe it in vivid detail.",
         "I show it a…", .emotionalExpression),

        ("Three Doors",
         "A wall has three identical doors and no handles. Your companion tilts its head.",
         "Give three completely different ways to open a door that has no handle. Make each one truly different.",
         "First… Second… Third…", .flexibility),

        ("The Lantern Tree",
         "A tall tree is covered in tiny dark lanterns, waiting for light.",
         "Invent a light for the lanterns that the night sky has never seen. What does it look and feel like?",
         "A light made of…", .elaboration),

        ("The Tangle",
         "A field of vines has knotted itself into a giant tangle blocking the meadow.",
         "Design a tool that untangles the vines and turns the mess into something useful. Say exactly how it works.",
         "My tool works by…", .usefulness),

        ("The Echo",
         "A cave repeats everything in funny voices and will only let you pass if you say something it has never heard.",
         "Make up a sentence the cave could never have heard before. Be playful and original.",
         "I say…", .originality),

        ("The Long List",
         "A bridge keeper will lower the bridge if you can name enough uses for the single button in their hand.",
         "List as many genuinely different uses for a button as you can. Quantity first, do not filter.",
         "A button could…", .fluency),

        ("The Riddle Pond",
         "A still pond shows a reflection that asks: what does courage look like if you could hold it?",
         "Describe courage as an object you could carry. What is it made of?",
         "Courage looks like…", .symbolicThinking),

        ("The Sleepy Giant",
         "A gentle giant snores across the only road, and waking it rudely would be unkind.",
         "Invent a kind, creative way to wake the giant that would make it smile.",
         "To wake it I…", .emotionalExpression),

        ("The Color Thief",
         "A mischievous breeze called the Fizzle has been swiping colours and hiding them. It loves a good trade.",
         "Invent something so wonderful the Fizzle happily trades all the colours back for it.",
         "I offer it a…", .originality),

        ("The Last Bright",
         "At the heart of Prism stands a great grey statue of yourself, made of every idea you were once too unsure to try.",
         "Invent the boldest creation yet to bring the statue to life and finish waking the world.",
         "I make a…", .riskTaking),
    ]
}
