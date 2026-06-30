import Foundation
import CrearoCore

// One deep, open-ended creative problem per day. The *type* rotates across research-backed
// creativity modes (one per CreativeDimension), and biases toward the player's weakest dimension
// so daily practice naturally progresses across skills.

struct DailyChallenge: Identifiable {
    let id: String                 // stable per calendar day ("yyyy-MM-dd")
    let mode: String               // e.g. "Divergent thinking"
    let prompt: String
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

    /// Today's challenge: 4 of every 5 days train the player's weakest dimension; the rest rotate
    /// so no skill is neglected. Deterministic per day so it's the same all day.
    static func challenge(for date: Date = Date(), weakest: CreativeDimension?) -> DailyChallenge {
        let dayIndex = Int(date.timeIntervalSince1970 / 86_400)
        let dims = CreativeDimension.allCases
        let dim: CreativeDimension = (weakest != nil && dayIndex % 5 != 0) ? weakest! : dims[abs(dayIndex) % dims.count]
        let bank = pool[dim] ?? pool[.originality]!
        let pick = bank[abs(dayIndex) % bank.count]
        return DailyChallenge(id: dayKey(date), mode: modeName(dim), prompt: pick.0,
                              placeholder: pick.1, focusDimension: dim)
    }

    private static func modeName(_ d: CreativeDimension) -> String {
        switch d {
        case .originality: return "Originality"
        case .fluency: return "Fluency"
        case .flexibility: return "Flexibility"
        case .elaboration: return "Elaboration"
        case .usefulness: return "Useful invention"
        case .riskTaking: return "Bold leaps"
        case .emotionalExpression: return "Emotional truth"
        case .symbolicThinking: return "Symbolic thinking"
        }
    }

    // (prompt, placeholder) per dimension.
    private static let pool: [CreativeDimension: [(String, String)]] = [
        .originality: [
            ("Invent something the world has never seen that solves a problem you had this week. Describe what it is and how it works.", "a small machine that…"),
            ("Design a brand-new holiday. What is it called, what do people do, and why would it matter?", "On this day, people…"),
        ],
        .fluency: [
            ("List as many genuinely different uses as you can for a single paperclip. Quantity first — don't filter.", "a paperclip could be…"),
            ("In two minutes, name every way you could get a stranger to smile. Go wide.", "you could…"),
        ],
        .flexibility: [
            ("You must cross a freezing river with no bridge. Describe THREE completely different approaches — no overlap.", "First, I could… Second… Third…"),
            ("Re-explain how a phone works to: a child, a medieval blacksmith, and an alien. Make each genuinely different.", "To the child…"),
        ],
        .elaboration: [
            ("Take a plain idea — 'a lamp' — and add rich, specific detail until it feels completely real. What does it look, sound, and feel like?", "It's a lamp made of…"),
            ("Describe your perfect room in such vivid detail that someone could draw it from your words alone.", "When you walk in…"),
        ],
        .usefulness: [
            ("Invent a tool that would make one annoying daily task delightful. Say exactly how it works.", "It works by…"),
            ("Redesign the umbrella so it actually solves the things umbrellas fail at. Be specific and practical.", "My umbrella would…"),
        ],
        .riskTaking: [
            ("Describe the strangest, boldest creation you'd be a little afraid to actually make. Don't play it safe.", "I'd make…"),
            ("Propose an idea that most people would call impossible — then argue why it could work anyway.", "Everyone says it's impossible, but…"),
        ],
        .emotionalExpression: [
            ("Make something that carries a real feeling — grief, hope, longing, or joy. Not clever. True. Describe it.", "It would feel like…"),
            ("Describe an object that would comfort someone on their worst day. Why would it work?", "It's a…"),
        ],
        .symbolicThinking: [
            ("If courage were an object you could hold, what would it be? Describe it as a relic.", "Courage looks like…"),
            ("Turn an ordinary moment from today into a small metaphor for something larger about life.", "It was like…"),
        ],
    ]
}
