import Foundation

// Turns hidden metrics into the world's VOICE: prophecy-style growth reports (§45) and
// companion dialogue (§19). Lines are authored phrase-banks selected by metric state — never
// free-generated — so tone stays safe and on-brand. The player never sees a number.

// MARK: - Prophecy growth reports (GDD §45)

public struct ProphecyComposer: Sendable {
    public init() {}

    /// Compose a prophecy from the change between two profile snapshots.
    public func prophecy(from previous: CreativeProfile, to current: CreativeProfile) -> String {
        // The dimension that grew the most, and the one still weakest.
        let rising = CreativeDimension.allCases.max { a, b in
            (current.value(a) - previous.value(a)) < (current.value(b) - previous.value(b))
        }
        let weakest = current.weakestDimensions(1).first

        var lines: [String] = []
        if let r = rising, current.value(r) - previous.value(r) > 0.03 {
            lines.append(Self.risingLine(r))
        }
        if let w = weakest, current.value(w) < 0.35 {
            lines.append(Self.stillLowLine(w))
        }
        if lines.isEmpty {
            lines.append("The world held its breath, and remembered you. Make something it cannot predict.")
        }
        return lines.joined(separator: " ")
    }

    static func risingLine(_ d: CreativeDimension) -> String {
        switch d {
        case .flexibility:
            return "The Mirrorwood no longer sees only one path in you. Where one road ran, three now branch — and the Stag has lost your scent."
        case .originality:
            return "The Grey hummed your name and, for once, could not finish the tune."
        case .emotionalExpression:
            return "Your makings have begun to ache. The dead bells of the Lull turned, just slightly, toward you."
        case .riskTaking:
            return "You stepped where the floor was not yet drawn — and it held. The Cartographer marks a road that wasn't there yesterday."
        case .elaboration:
            return "Your work has grown roots and small rooms. The Unfinished frowns; there is less of you for it to fray."
        case .usefulness:
            return "Beauty learned to bear weight in your hands. The Forgefather grunts, which from him is praise."
        case .symbolicThinking:
            return "You have begun to speak in doors and tides. The old carvings answer you now."
        case .fluency:
            return "Ideas come to you like moths to the one warm window. The drought breaks."
        }
    }

    static func stillLowLine(_ d: CreativeDimension) -> String {
        switch d {
        case .flexibility: return "Still you walk the same road twice. Somewhere, a single mouth waits to swallow it."
        case .originality: return "The Grey still knows your favourite song by heart. Sing it something stranger."
        case .emotionalExpression: return "Your lights are bright, but cold. The Lull will not open to a maker who never aches."
        case .riskTaking: return "You build only where the floor is sure. The Sealed Door does not open to the careful."
        case .elaboration: return "Your makings are thin as first frost. Give them more of yourself, or they will keep breaking."
        case .usefulness: return "Lovely things, all of them — and not one would hold in a storm. Make something that works."
        case .symbolicThinking: return "You answer riddles with their own plain words. Learn to reply in symbol."
        case .fluency: return "One idea, and then a long quiet. The well is deeper than you let it run."
        }
    }
}

// MARK: - Companion direction (GDD §19, §55)

public enum CompanionEvent: Sendable {
    case firstMaking
    case genuineNovelty
    case repetitionNudge
    case returnedAfterAbsence
    case neglectConcern
    case emotionalLonging
}

public struct CompanionDirector: Sendable {
    public init() {}

    /// Nudge the companion's tone from the character of a creative act.
    public func updatedTone(_ tone: ToneVector, after score: CreativityScore) -> ToneVector {
        var t = tone
        let d = score.dimensions
        let rate = 0.08
        t.warmth = clamp01(t.warmth + rate * (d.emotionalExpression - 0.5) * 2)
        t.strangeness = clamp01(t.strangeness + rate * (d.originality - 0.5) * 2)
        t.somberness = clamp01(t.somberness + rate * (d.symbolicThinking - 0.5) * 2)
        t.playfulness = clamp01(t.playfulness + rate * (d.fluency - 0.5) * 2)
        return t
    }

    /// Select an authored line, filled with the companion's name + a remembered creation.
    public func line(for event: CompanionEvent, companion: Companion, lastCreation: String?) -> String {
        let last = lastCreation ?? companion.rememberedCreations.last ?? "that thing you made"
        switch event {
        case .firstMaking:
            return "Oh. You're one of the ones who can still do that. I'd almost forgotten the colour of being seen."
        case .genuineNovelty:
            return strange(companion.tone)
                ? "Yes — yes! I have no idea what that is and I LOVE it. Do that again. Do something worse."
                : "I've never seen anything like the \(last). The world feels a little less finished now. Good."
        case .repetitionNudge:
            return "The Hollow Stag has watched you reach for the \(last) thrice now. It's learning the song. Sing it a different one."
        case .returnedAfterAbsence:
            return warm(companion.tone)
                ? "You came back. The hearth and I were getting very good at waiting. Light something?"
                : "Back, then. The dust found the high shelves before you did. No matter — make, and the room remembers fast."
        case .neglectConcern:
            return "Do you ever miss... colour? Real colour? The \(last) is going grey at the edges. So am I, a little."
        case .emotionalLonging:
            return "Make me something that aches. Not strong, not clever. Something that means a thing. I want to feel it."
        }
    }

    private func warm(_ t: ToneVector) -> Bool { t.warmth >= 0.55 }
    private func strange(_ t: ToneVector) -> Bool { t.strangeness >= 0.6 }
}
