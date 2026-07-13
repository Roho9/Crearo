import SwiftUI
import CrearoCore

// After you answer a level: if your idea cleared the gate, your companion acts it out in the pixel
// cut-scene and then you see the celebration + score. If it fell short, you skip straight to the
// score breakdown and a chance to try again. The animation is the reward for being creative enough.
struct OutcomeView: View {
    let outcome: ChallengeOutcome
    var onRetry: () -> Void = {}
    var onDone: () -> Void = {}
    @State private var showScene: Bool

    init(outcome: ChallengeOutcome, onRetry: @escaping () -> Void = {}, onDone: @escaping () -> Void = {}) {
        self.outcome = outcome
        self.onRetry = onRetry
        self.onDone = onDone
        // Only passing ideas earn the cut-scene.
        _showScene = State(initialValue: outcome.passed)
    }

    var body: some View {
        ZStack {
            if showScene {
                CutSceneView(item: outcome.scene.item, colorName: outcome.scene.colorName,
                             action: outcome.scene.action, target: outcome.scene.target,
                             outcome: outcome.scene.outcomeCaption) {
                    withAnimation(.easeInOut) { showScene = false }
                }
            } else {
                ResultPanel(outcome: outcome, onRetry: onRetry, onDone: onDone)
            }
        }
    }
}

private struct ResultPanel: View {
    @Environment(\.dismiss) private var dismiss
    let outcome: ChallengeOutcome
    var onRetry: () -> Void = {}
    var onDone: () -> Void = {}

    private var bandColor: Color { OutcomeView.color(for: outcome.rubric.band) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PixelCompanion(vitality: outcome.passed ? 0.95 : 0.4, celebrate: outcome.passed)
                    .frame(height: 140).padding(.top, 28)

                // The headline: passed advances the story, failed invites another try.
                Text(outcome.passed ? "Level \(outcome.level) cleared!" : "Not bright enough yet")
                    .font(Theme.title).foregroundStyle(outcome.passed ? Theme.candle : Theme.grey)
                    .multilineTextAlignment(.center)

                ScoreDial(total: outcome.rubric.total, passMark: outcome.passMark,
                          band: outcome.rubric.band, color: bandColor)

                Text(outcome.rubric.band.reaction)
                    .font(.callout).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Per-criterion breakdown so the score never feels like a black box.
                VStack(alignment: .leading, spacing: 12) {
                    Text("How it scored").font(.headline).foregroundStyle(Theme.candle)
                    ForEach(RubricCriterion.allCases, id: \.self) { c in
                        RubricBar(title: c.title, blurb: c.blurb,
                                  points: outcome.rubric.points[c] ?? 0, weight: c.weight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if outcome.passed {
                    HearthCard {
                        Text(outcome.storyBeat).font(.callout).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !outcome.coaching.isEmpty {
                    HearthCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Coach").font(.caption.weight(.bold)).foregroundStyle(Theme.magic).tracking(1)
                            Text(outcome.coaching).font(.callout).foregroundStyle(Theme.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if outcome.passed, !outcome.earned.isEmpty {
                    Text("+ " + outcome.earned.map { "\($0.amount) \($0.resource.displayName)" }.joined(separator: ", "))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.berry)
                }

                if outcome.passed {
                    primaryButton("Continue the adventure") { onDone(); dismiss() }
                } else {
                    VStack(spacing: 10) {
                        primaryButton("Try a bolder idea") { onRetry(); dismiss() }
                        Text("You need \(outcome.passMark) to clear Level \(outcome.level). Refine your idea and go again.")
                            .font(.footnote).foregroundStyle(Theme.grey).multilineTextAlignment(.center)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.night.ignoresSafeArea())
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.ember, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Score pieces

/// The big number: your score out of 100 with the band, and the mark you needed.
struct ScoreDial: View {
    let total: Int
    let passMark: Int
    let band: ScoreBand
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(total)").font(.system(size: 68, weight: .heavy, design: .rounded)).foregroundStyle(color)
                Text("/ 100").font(.title3.weight(.semibold)).foregroundStyle(Theme.grey)
            }
            GlowTag(text: band.label, color: color)
            // A slim track showing where the score fell against the pass mark.
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panel).frame(height: 8)
                    Capsule().fill(color).frame(width: max(6, w * CGFloat(total) / 100), height: 8)
                    Rectangle().fill(Theme.ink.opacity(0.55)).frame(width: 2, height: 16)
                        .offset(x: w * CGFloat(passMark) / 100)
                }
            }
            .frame(height: 16)
            Text("Pass mark: \(passMark)").font(.caption2).foregroundStyle(Theme.grey)
        }
    }
}

/// One criterion's line: name, points earned out of its weight, and a little bar.
struct RubricBar: View {
    let title: String
    let blurb: String
    let points: Int
    let weight: Int

    private var ratio: Double { weight > 0 ? Double(points) / Double(weight) : 0 }
    private var barColor: Color {
        ratio >= 0.75 ? Theme.moss : (ratio >= 0.45 ? Theme.sky : Theme.ember)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(points)/\(weight)").font(.caption.weight(.bold)).foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panel).frame(height: 7)
                    Capsule().fill(barColor).frame(width: max(4, geo.size.width * ratio), height: 7)
                }
            }
            .frame(height: 7)
            Text(blurb).font(.caption2).foregroundStyle(Theme.grey)
        }
    }
}

extension OutcomeView {
    /// A friendly colour for each band.
    static func color(for band: ScoreBand) -> Color {
        switch band {
        case .spark:     return Theme.grey
        case .glimmer:   return Theme.sun
        case .bright:    return Theme.sky
        case .brilliant: return Theme.magic
        case .luminous:  return Theme.berry
        }
    }
}
