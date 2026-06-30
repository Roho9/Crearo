import SwiftUI
import CrearoCore

// After answering: first the companion acts out your idea (CutSceneView), then a result panel with
// the new story beat, your creativity for this answer, coaching, and sparks.
struct OutcomeView: View {
    let outcome: ChallengeOutcome
    var onDone: () -> Void = {}
    @State private var showScene = true

    var body: some View {
        ZStack {
            if showScene {
                CutSceneView(item: outcome.scene.item, colorName: outcome.scene.colorName,
                             action: outcome.scene.action, target: outcome.scene.target,
                             outcome: outcome.scene.outcomeCaption) {
                    withAnimation(.easeInOut) { showScene = false }
                }
            } else {
                ResultPanel(outcome: outcome, onDone: onDone)
            }
        }
    }
}

private struct ResultPanel: View {
    @Environment(\.dismiss) private var dismiss
    let outcome: ChallengeOutcome
    var onDone: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PixelCompanion(vitality: 0.95, celebrate: true).frame(height: 150).padding(.top, 30)

                Text(outcome.advancedStreak ? "Day \(outcome.streak)!" : "Lovely.")
                    .font(Theme.title).foregroundStyle(Theme.candle)

                HearthCard {
                    Text(outcome.storyBeat).font(.callout).foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your creativity today").font(.headline).foregroundStyle(Theme.candle)
                    FlowChips(chips: [
                        ("Originality", outcome.score.dimensions.originality * 100),
                        ("Usefulness", outcome.score.dimensions.usefulness * 100),
                        ("Detail", outcome.score.dimensions.elaboration * 100),
                        ("Flexibility", outcome.score.dimensions.flexibility * 100),
                        ("Emotion", outcome.score.dimensions.emotionalExpression * 100),
                        ("Boldness", outcome.score.dimensions.riskTaking * 100),
                    ])
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !outcome.coaching.isEmpty {
                    HearthCard {
                        Text(outcome.coaching).font(.callout).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !outcome.earned.isEmpty {
                    Text("+ " + outcome.earned.map { "\($0.amount) \($0.resource.displayName)" }.joined(separator: ", "))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.berry)
                }

                Button("Continue the adventure") { onDone(); dismiss() }
                    .font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(20)
        }
        .background(Theme.night.ignoresSafeArea())
    }
}
