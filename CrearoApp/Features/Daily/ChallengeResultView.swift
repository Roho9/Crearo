import SwiftUI
import CrearoCore

// Shown after answering: the pixel companion celebrates, your creative shape for this answer, the
// coaching (Claude when a key is set, else the offline growth note), and your streak/sparks.
struct ChallengeResultView: View {
    @Environment(\.dismiss) private var dismiss
    let outcome: ChallengeOutcome
    var onDone: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                PixelCompanion(vitality: 0.95, celebrate: true).frame(height: 160).padding(.top, 28)

                Text(outcome.advancedStreak ? "Day \(outcome.streak) 🔥" : "Nicely made.")
                    .font(Theme.title).foregroundStyle(Theme.candle)

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

                Text(outcome.coaching)
                    .font(.callout).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16))

                if !outcome.earned.isEmpty {
                    Text("+ " + outcome.earned.map { "\($0.amount) \($0.resource.displayName)" }.joined(separator: ", "))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
                }

                Button("Done") { onDone(); dismiss() }
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.night)
            }
            .padding(20)
        }
        .background(Theme.night.ignoresSafeArea())
    }
}
