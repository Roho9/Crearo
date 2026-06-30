import Foundation
import Observation
import CrearoCore

struct DailyPrompt {
    let title: String
    let body: String
    let focusDimension: CreativeDimension?

    /// Reward weighting that emphasizes the dimension this prompt is training.
    var focus: DimensionScores {
        var f = DimensionScores.uniform
        if let d = focusDimension { f[d] = 2.0 }
        return f
    }

    static let `default` = DailyPrompt(
        title: "A small making",
        body: "The hearth asks for one new thing today. Make something, anything, the world hasn't seen from you yet.",
        focusDimension: nil)

    /// Targeted daily prompt for the player's current growth edge (GDD §31).
    static func forDimension(_ d: CreativeDimension) -> DailyPrompt {
        switch d {
        case .originality:
            return .init(title: "Something the Grey can't predict",
                         body: "Name or describe a creation unlike anything you've made. Surprise the fog.",
                         focusDimension: d)
        case .flexibility:
            return .init(title: "Another road",
                         body: "Describe a SECOND, completely different way to cross a freezing river with no bridge.",
                         focusDimension: d)
        case .elaboration:
            return .init(title: "Give it rooms",
                         body: "Take a plain idea, a lantern, and add rich, specific detail until it feels real.",
                         focusDimension: d)
        case .usefulness:
            return .init(title: "Make it work",
                         body: "Invent a light the fog cannot drink, and say exactly how it works.",
                         focusDimension: d)
        case .riskTaking:
            return .init(title: "A leap",
                         body: "Describe the strangest, riskiest creation you'd be a little afraid to actually make.",
                         focusDimension: d)
        case .emotionalExpression:
            return .init(title: "Something that aches",
                         body: "Make something that carries a real feeling: grief, hope, or warmth. Not clever. True.",
                         focusDimension: d)
        case .symbolicThinking:
            return .init(title: "Speak in symbol",
                         body: "What does courage look like as an object? Describe it as a relic.",
                         focusDimension: d)
        case .fluency:
            return .init(title: "Many sparks",
                         body: "List as many different uses as you can for a single broken bell.",
                         focusDimension: d)
        }
    }
}

@MainActor
@Observable
final class DailyQuestViewModel {
    var response = ""
    var modality: Modality = .writing
    private(set) var prompt: DailyPrompt = .default

    var canSubmit: Bool { !response.trimmingCharacters(in: .whitespaces).isEmpty }

    func refreshPrompt(for app: AppState) {
        guard let ws = app.worldState, let weak = ws.profile.weakestDimensions(1).first else {
            prompt = .default; return
        }
        // If the player is still brand-new (few acts), keep it gentle/open.
        prompt = ws.profile.totalActs < 2 ? .default : .forDimension(weak)
    }

    func submit(app: AppState) async {
        guard canSubmit else { return }
        await app.completeDailyQuest(responseText: response, modality: modality, focus: prompt.focus)
        response = ""
    }
}
