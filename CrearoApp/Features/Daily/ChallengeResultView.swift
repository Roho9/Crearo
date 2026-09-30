import SwiftUI
import CrearoCore

// Passing ideas take the stage; every attempt gets an understandable score and a way forward.
struct OutcomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let outcome: ChallengeOutcome
    var onRetry: () -> Void = {}
    var onDone: () -> Void = {}
    @State private var showScene: Bool

    init(outcome: ChallengeOutcome, onRetry: @escaping () -> Void = {}, onDone: @escaping () -> Void = {}) {
        self.outcome = outcome
        self.onRetry = onRetry
        self.onDone = onDone
        _showScene = State(initialValue: outcome.passed)
    }

    var body: some View {
        ZStack {
            if showScene {
                CutSceneView(item: outcome.scene.item, colorName: outcome.scene.colorName,
                             action: outcome.scene.action, target: outcome.scene.target,
                             outcome: outcome.scene.outcomeCaption) {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        showScene = false
                    }
                }
                .transition(.opacity)
            } else {
                ResultPanel(outcome: outcome, onRetry: onRetry, onDone: onDone)
                    .transition(.opacity)
            }
        }
        .background(PaperPageBackground())
    }
}

private struct ResultPanel: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showRubric = false
    let outcome: ChallengeOutcome
    var onRetry: () -> Void = {}
    var onDone: () -> Void = {}

    private var bandColor: Color { OutcomeView.color(for: outcome.rubric.band) }
    private var coaching: String {
        outcome.coaching.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? refinementPrompt(for: outcome.rubric.weakestCriterion)
            : outcome.coaching
    }
    private var roundedCriteriaDiffer: Bool {
        outcome.rubric.points.values.reduce(0, +) != outcome.rubric.total
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CHAPTER \(outcome.level) · \(outcome.levelTitle)")
                        .font(.caption.weight(.semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.grey)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(outcome.passed ? "A chapter brought to life" : "An idea worth growing")
                        .font(Theme.title)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(outcome.passed
                         ? "Level \(outcome.level) cleared. Your imagination moved the story forward."
                         : "Keep the spark. A little refinement can take this idea further.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.grey)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaperTheatreStageView(levelTitle: outcome.levelTitle,
                                      vitality: outcome.passed ? 0.95 : 0.5,
                                      celebrate: outcome.passed)
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.edge.opacity(0.65), lineWidth: 1)
                    }

                HearthCard {
                    ScoreDial(total: outcome.rubric.total, passMark: outcome.passMark,
                              band: outcome.rubric.band, color: bandColor,
                              isPracticeEstimate: outcome.isPracticeEstimate)
                }

                HearthCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Label(outcome.passed ? "Carry this into your next idea" : "One way to grow this idea",
                              systemImage: "pencil.tip")
                            .font(.headline)
                            .foregroundStyle(Theme.moss)
                        Text(coaching)
                            .font(Theme.body)
                            .lineSpacing(3)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DisclosureGroup(isExpanded: $showRubric) {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(RubricCriterion.allCases, id: \.self) { criterion in
                            RubricBar(title: criterion.title, blurb: criterion.blurb,
                                      points: outcome.rubric.points[criterion] ?? 0,
                                      weight: criterion.weight)
                        }
                        if roundedCriteriaDiffer {
                            Text("Each criterion is rounded separately. The total is calculated before rounding.")
                                .font(.footnote)
                                .foregroundStyle(Theme.grey)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 14)
                } label: {
                    Label("How your score works", systemImage: "list.bullet")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(PaperCardSurface())
                .tint(Theme.moss)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showRubric)

                if outcome.passed {
                    HearthCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("A new page in your journal", systemImage: "book.closed")
                                .font(.headline).foregroundStyle(Theme.ink)
                            Text(outcome.storyBeat)
                                .font(Theme.body).lineSpacing(3)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if outcome.passed, !outcome.earned.isEmpty {
                    Label {
                        Text(outcome.earned.map { "+\($0.amount) \($0.resource.displayName)" }
                            .joined(separator: " · "))
                    } icon: {
                        Image(systemName: "sparkle").accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.moss)
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(PaperPageBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                Button(outcome.passed ? "Back to my world" : "Refine my idea") {
                    if outcome.passed { onDone() } else { onRetry() }
                    dismiss()
                }
                .buttonStyle(PaperPrimaryButtonStyle())
                .accessibilityHint(outcome.passed
                                   ? "Return to your world and journal."
                                   : "Return to your existing draft. Your idea is kept for you.")
                if !outcome.passed {
                    Text("Chapter target: \(outcome.passMark) / 100. Your draft is waiting for you.")
                        .font(.footnote)
                        .foregroundStyle(Theme.grey)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background {
                Theme.night.overlay(PaperGrainView(opacity: 0.028)).ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle().fill(Theme.edge.opacity(0.45)).frame(height: 1)
            }
        }
    }

    private func refinementPrompt(for criterion: RubricCriterion) -> String {
        switch criterion {
        case .originality:
            return "Change one familiar part. What could an unexpected material or unusual helper do for your invention?"
        case .elaboration:
            return "Name a material, describe one moving part, and explain what happens when your invention starts."
        case .fit:
            return "Connect your invention to the goal. Explain, step by step, how it gets past this particular obstacle."
        case .boldness:
            return "Turn one assumption around. Could the obstacle itself become part of your solution?"
        case .depth:
            return "Give your invention a second meaning. What could it reveal about the problem while it solves it?"
        case .delight:
            return "Add a small surprise: an unexpected sound, a funny reaction, or a detail that makes someone smile."
        }
    }
}

/// The score and threshold use the same 0...100 scale. Zero has no coloured fill, and the threshold
/// marker is centred on its true position. The full meaning is available without seeing the track.
struct ScoreDial: View {
    let total: Int
    let passMark: Int
    let band: ScoreBand
    let color: Color
    var isPracticeEstimate: Bool = false
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 58

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isPracticeEstimate ? "PRACTICE SCORE" : "CREATIVITY SCORE")
                .font(.caption.weight(.semibold))
                .tracking(1.1)
                .foregroundStyle(Theme.grey)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    scoreNumber
                    Spacer(minLength: 8)
                    GlowTag(text: band.label, color: color)
                }
                VStack(alignment: .leading, spacing: 8) {
                    scoreNumber
                    GlowTag(text: band.label, color: color)
                }
            }

            GeometryReader { geometry in
                let width = geometry.size.width
                let scoreFraction = min(1, max(0, CGFloat(total) / 100))
                let targetFraction = min(1, max(0, CGFloat(passMark) / 100))
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.edge.opacity(0.3)).frame(height: 8)
                    Capsule().fill(color).frame(width: width * scoreFraction, height: 8)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.ink)
                        .frame(width: 2, height: 18)
                        .offset(x: max(0, min(width - 2, width * targetFraction - 1)))
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
            .accessibilityHidden(true)

            Label(total >= passMark ? "Chapter target met: \(passMark) / 100" : "Chapter target: \(passMark) / 100",
                  systemImage: total >= passMark ? "checkmark.circle" : "flag")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.grey)
            if isPracticeEstimate {
                Text("Estimated feedback for this attempt.")
                    .font(.footnote)
                    .foregroundStyle(Theme.grey)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPracticeEstimate ? "Practice score" : "Creativity score")
        .accessibilityValue("\(total) out of 100. \(band.label). Chapter target: \(passMark) out of 100. \(isPracticeEstimate ? "Estimated feedback for this attempt." : "")")
    }

    private var scoreNumber: some View {
        HStack(alignment: .lastTextBaseline, spacing: 5) {
            Text("\(total)")
                .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
            Text("/ 100")
                .font(.title3)
                .foregroundStyle(Theme.grey)
        }
    }
}

struct RubricBar: View {
    let title: String
    let blurb: String
    let points: Int
    let weight: Int

    private var ratio: Double {
        weight > 0 ? min(1, max(0, Double(points) / Double(weight))) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    Text(title)
                    Spacer(minLength: 10)
                    Text("\(points) / \(weight)").monospacedDigit()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text("\(points) / \(weight)").monospacedDigit()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.edge.opacity(0.3))
                    Capsule().fill(Theme.moss)
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)

            Text(blurb)
                .font(.footnote)
                .foregroundStyle(Theme.grey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(points) of \(weight) points. \(blurb)")
    }
}

extension OutcomeView {
    static func color(for band: ScoreBand) -> Color {
        switch band {
        case .spark: return Theme.grey
        case .glimmer: return Theme.sun
        case .bright: return Theme.sky
        case .brilliant: return Theme.magic
        case .luminous: return Theme.moss
        }
    }
}
