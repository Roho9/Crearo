import SwiftUI
import CrearoCore

// One little stage, one clear problem, and plenty of room to invent the way forward.
struct DailyHomeView: View {
    @Environment(AppState.self) private var app
    @State private var answer = ""
    @State private var outcome: ChallengeOutcome?
    @State private var submitting = false
    @State private var showGrowth = false
    @State private var showStory = false
    @State private var submissionNote: String?
    @State private var focusDraftAfterResult = false
    @State private var draftLevel: Int?
    @State private var showHint = false
    @FocusState private var answerFocused: Bool

    private var hasAnswer: Bool {
        !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var exceedsAnswerLimit: Bool { answer.count > AppState.maximumChallengeLength }

    var body: some View {
        let challenge = app.todaysChallenge
        let vitality = app.worldState?.companion.brightness ?? 0.3
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    chapterHeader(challenge)

                    PaperTheatreStageView(levelTitle: challenge.title, vitality: vitality)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Theme.edge.opacity(0.65), lineWidth: 1)
                        }

                    levelPrompt(challenge)

                    progressFootnote
                }
                .frame(maxWidth: 640)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PaperPageBackground())
            .navigationTitle("Crearo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStory = true } label: {
                        Label("Journal", systemImage: "book.closed")
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Read the story you have made so far.")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showGrowth = true } label: {
                        Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("See your level, scores, and creative growth.")
                }
            }
            .tint(Theme.ink)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                submitBar(challenge)
            }
            .fullScreenCover(item: $outcome, onDismiss: {
                if focusDraftAfterResult {
                    answerFocused = true
                    focusDraftAfterResult = false
                }
            }) { result in
                OutcomeView(outcome: result,
                            onRetry: { focusDraftAfterResult = true })
            }
            .sheet(isPresented: $showGrowth) { GrowthView() }
            .sheet(isPresented: $showStory) { StoryView() }
            .task(id: challenge.level) {
                // Loading a chapter never saves the previous chapter's text under its new key.
                draftLevel = challenge.level
                answer = app.challengeDraft(forLevel: challenge.level)
                showHint = false
                submissionNote = nil
            }
            .onChange(of: answer) { _, value in
                guard draftLevel == challenge.level,
                      value != app.challengeDraft(forLevel: challenge.level) else { return }
                app.saveChallengeDraft(value, forLevel: challenge.level)
            }
        }
    }

    private func chapterHeader(_ challenge: DailyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(challenge.region.title) · \(challenge.regionIndex) of \(challenge.regionCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.moss)
                .fixedSize(horizontal: false, vertical: true)
            Text(challenge.title)
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Chapter \(challenge.level) · Make your own way through")
                .font(.footnote)
                .foregroundStyle(Theme.grey)
        }
    }

    private func levelPrompt(_ challenge: DailyChallenge) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 14) {
                Text(challenge.setup)
                    .font(Theme.body)
                    .lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Label {
                    Text(challenge.goal)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "flag.fill").accessibilityHidden(true)
                }
                .font(.headline)
                .foregroundStyle(Theme.moss)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Theme.moss.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your goal: \(challenge.goal)")

                if !challenge.constraint.isEmpty {
                    Label {
                        Text(challenge.constraint)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "paperclip").accessibilityHidden(true)
                    }
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Creative constraint: \(challenge.constraint)")
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Your invention")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(challenge.question)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("", text: $answer,
                          prompt: Text(challenge.placeholder).foregroundStyle(Theme.grey), axis: .vertical)
                    .lineLimit(6...14)
                    .textFieldStyle(.plain)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .padding(18)
                    .background(PaperCardSurface())
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(answerFocused ? Theme.sky : .clear, lineWidth: 2)
                    }
                    .focused($answerFocused)
                    .disabled(submitting || app.isWorking)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Your idea")
                    .accessibilityHint("Describe your invention and how it solves the challenge.")

                Label(hasAnswer ? "Draft kept on this device" : "Your draft will stay with this chapter",
                      systemImage: "square.and.pencil")
                    .font(.footnote)
                    .foregroundStyle(Theme.grey)

                if exceedsAnswerLimit {
                    Text("Keep your idea within \(AppState.maximumChallengeLength.formatted()) characters before submitting. Your full draft is still saved.")
                        .font(.footnote)
                        .foregroundStyle(Theme.ember)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                DisclosureGroup(isExpanded: $showHint) {
                    Text(challenge.hint)
                        .font(Theme.body)
                        .lineSpacing(3)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                } label: {
                    Label("Find another angle", systemImage: "lightbulb")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Theme.moss)
                        .frame(minHeight: 44)
                }
                .tint(Theme.moss)
                .accessibilityHint("Reveal a question to help you explore a different approach.")
            }

            if app.isLocalPractice {
                Label {
                    Text("Practice feedback looks for written clues about your goal and how your idea works. You can revise as often as you like.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "leaf").accessibilityHidden(true)
                }
                .font(.footnote)
                .foregroundStyle(Theme.grey)
                .accessibilityElement(children: .combine)
            }

            if let submissionNote {
                Label(submissionNote, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(Theme.ink)
                    .accessibilityElement(children: .combine)
            }
        }
    }

    private func submitBar(_ challenge: DailyChallenge) -> some View {
        VStack(spacing: 9) {
            Button {
                guard hasAnswer, !exceedsAnswerLimit, !submitting, !app.isWorking,
                      draftLevel == challenge.level else { return }
                let submittedAnswer = answer
                answerFocused = false
                submitting = true
                submissionNote = nil
                Task {
                    outcome = await app.submitChallenge(challenge, answer: submittedAnswer)
                    submitting = false
                    if outcome == nil {
                        submissionNote = "Your idea is still here. Please try again."
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if submitting { ProgressView().tint(.white) }
                    Text(submitting ? "Setting the stage…" : "Try my idea")
                }
            }
            .buttonStyle(PaperPrimaryButtonStyle())
            .disabled(!hasAnswer || exceedsAnswerLimit || submitting || app.isWorking || draftLevel != challenge.level)
            .accessibilityHint("Receive a score and feedback for this chapter.")

            Text("Reach \(challenge.passMark) / 100 to clear this chapter. You can refine and retry.")
                .font(.footnote)
                .foregroundStyle(Theme.grey)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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

    private var progressFootnote: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { progressLabels }
            VStack(alignment: .leading, spacing: 8) { progressLabels }
        }
        .font(.footnote)
        .foregroundStyle(Theme.grey)
        .padding(.top, 4)
    }

    @ViewBuilder private var progressLabels: some View {
        Label("\(app.worldState?.totalPoints ?? 0) lifetime points", systemImage: "sparkle")
        let streak = app.worldState?.streak ?? 0
        if streak > 0 {
            Label("\(streak) \(streak == 1 ? "day" : "days") of making", systemImage: "leaf")
        }
    }
}

// A quiet journal keeps the player's authored moments together.
struct StoryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    let beats = app.worldState?.storyLog ?? []
                    let entries = app.worldState?.challengeHistory ?? []
                    // New entries also append a story beat. Keep earlier saves' unarchived pages.
                    let earlierBeats = Array(beats.prefix(max(0, beats.count - entries.count)))
                    if beats.isEmpty && entries.isEmpty {
                        HearthCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("The first page is yours")
                                    .font(Theme.heading).foregroundStyle(Theme.ink)
                                Text("Try a challenge to begin the story. Every chapter you clear keeps your invention and adds a moment made from your imagination.")
                                    .font(Theme.body).foregroundStyle(Theme.grey)
                            }
                        }
                    } else {
                        Text("A world shaped by your ideas.")
                            .font(Theme.body).foregroundStyle(Theme.grey)
                        ForEach(Array(earlierBeats.enumerated()), id: \.offset) { index, beat in
                            HearthCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("CHAPTER \(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .tracking(1.2).foregroundStyle(Theme.moss)
                                    Text(beat)
                                        .font(Theme.body).lineSpacing(3)
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .accessibilityElement(children: .combine)
                        }
                        ForEach(entries, id: \.id) { entry in
                            journalEntry(entry)
                        }
                    }
                }
                .frame(maxWidth: 640)
                .padding(22)
                .frame(maxWidth: .infinity)
            }
            .background(PaperPageBackground())
            .navigationTitle("Your journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.frame(minHeight: 44)
                }
            }
            .tint(Theme.ink)
        }
    }

    private func journalEntry(_ entry: ChallengeJournalEntry) -> some View {
        HearthCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHAPTER \(entry.level)")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2).foregroundStyle(Theme.moss)
                    Text(entry.title)
                        .font(Theme.heading).foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(entry.createdAt, style: .date)
                        .font(.footnote).foregroundStyle(Theme.grey)
                }
                Text(entry.answer)
                    .font(Theme.body).lineSpacing(3)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                Label("\(entry.isPracticeEstimate ? "Practice estimate" : "Feedback score") · \(entry.score) / 100",
                      systemImage: "sparkle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.moss)
                Text(entry.storyBeat)
                    .font(.callout).lineSpacing(3)
                    .foregroundStyle(Theme.grey)
                    .fixedSize(horizontal: false, vertical: true)
                ShareLink(item: ChallengeShareText.make(level: entry.level, title: entry.title,
                                                       answer: entry.answer, score: entry.score,
                                                       isPracticeEstimate: entry.isPracticeEstimate)) {
                    Label("Share this invention", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(PaperSecondaryButtonStyle())
                .accessibilityHint("Choose who receives your invention and its locally saved score.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct GrowthView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 130), spacing: 14, alignment: .leading)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if let world = app.worldState {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Look what you've made")
                            .font(Theme.title).foregroundStyle(Theme.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("Every attempt is practice. These are the chapters and ideas you've built so far.")
                            .font(Theme.body).foregroundStyle(Theme.grey)

                        LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                            stat("\(world.level)", "current level")
                            stat("\(world.bestScore) / 100", "best score")
                            stat("\(world.totalPoints)", "lifetime points")
                            stat("\(world.profile.totalActs)", "ideas brought to life")
                            stat("\(world.streak)", "day streak")
                            stat("\(world.wallet[.embers])", "sparks collected")
                        }

                        HearthCard {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Your creative shape")
                                    .font(Theme.heading).foregroundStyle(Theme.ink)
                                Text("A sketch of the qualities you've practised across your ideas.")
                                    .font(.footnote).foregroundStyle(Theme.grey)
                                ForEach(CreativeDimension.allCases, id: \.self) { dimension in
                                    profileRow(dimension, value: world.profile.value(dimension))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(22)
                    .frame(maxWidth: .infinity)
                } else {
                    Text("Your path begins with your first idea.")
                        .font(Theme.body).foregroundStyle(Theme.grey).padding(22)
                }
            }
            .background(PaperPageBackground())
            .navigationTitle("Your progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.frame(minHeight: 44)
                }
            }
            .tint(Theme.ink)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HearthCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.8)
                Text(label).font(.footnote).foregroundStyle(Theme.grey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func profileRow(_ dimension: CreativeDimension, value: Double) -> some View {
        let clamped = min(1, max(0, value))
        return VStack(alignment: .leading, spacing: 6) {
            Text(Self.label(dimension))
                .font(.subheadline).foregroundStyle(Theme.ink)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.edge.opacity(0.3))
                    Capsule().fill(Theme.moss.opacity(0.85))
                        .frame(width: geometry.size.width * clamped)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(dimension))
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }

    static func label(_ dimension: CreativeDimension) -> String {
        switch dimension {
        case .originality: return "Originality"
        case .fluency: return "Fluency"
        case .flexibility: return "Flexibility"
        case .elaboration: return "Detail"
        case .usefulness: return "Usefulness"
        case .riskTaking: return "Boldness"
        case .emotionalExpression: return "Emotion"
        case .symbolicThinking: return "Symbol"
        }
    }
}
