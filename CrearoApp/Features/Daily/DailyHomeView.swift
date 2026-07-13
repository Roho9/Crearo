import SwiftUI
import CrearoCore

// Home: the next chapter of your story, with one deep question that asks you to invent the way
// forward. Answer it, and your companion acts it out.
struct DailyHomeView: View {
    @Environment(AppState.self) private var app
    @State private var answer = ""
    @State private var outcome: ChallengeOutcome?
    @State private var submitting = false
    @State private var showGrowth = false
    @State private var showStory = false

    var body: some View {
        let challenge = app.todaysChallenge
        let vitality = app.worldState?.companion.brightness ?? 0.3
        let done = app.hasDoneToday
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("\(app.worldState?.streak ?? 0)", systemImage: "flame.fill").foregroundStyle(Theme.ember)
                        Spacer()
                        Label("\(app.worldState?.totalPoints ?? 0) pts", systemImage: "sparkles").foregroundStyle(Theme.berry)
                    }
                    .font(.headline)

                    PixelCompanion(vitality: vitality).frame(height: 150).frame(maxWidth: .infinity)

                    if done {
                        clearedToday(nextLevel: challenge)
                    } else {
                        levelPrompt(challenge)
                    }
                }
                .padding(20)
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Prism")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Story", systemImage: "book.fill") { showStory = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Path", systemImage: "chart.line.uptrend.xyaxis") { showGrowth = true }
                }
            }
            .fullScreenCover(item: $outcome) { o in
                // Passing clears the box for tomorrow; failing keeps the idea so it can be refined.
                OutcomeView(outcome: o, onRetry: {}, onDone: { answer = "" })
            }
            .sheet(isPresented: $showGrowth) { GrowthView() }
            .sheet(isPresented: $showStory) { StoryView() }
        }
    }

    // The active level: scene, goal, target score, and the answer box.
    @ViewBuilder private func levelPrompt(_ challenge: DailyChallenge) -> some View {
        HStack {
            Text("LEVEL \(challenge.level)  •  \(challenge.title.uppercased())")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.magic).tracking(1)
            Spacer()
            GlowTag(text: "Goal: \(challenge.passMark) pts", color: Theme.sky)
        }

        HearthCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(challenge.setup).font(Theme.body).foregroundStyle(Theme.ink)
                Label(challenge.goal, systemImage: "target").font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ember)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Text(challenge.question).font(Theme.heading).foregroundStyle(Theme.candle)
            .fixedSize(horizontal: false, vertical: true)

        TextField("", text: $answer,
                  prompt: Text(challenge.placeholder).foregroundStyle(Theme.grey), axis: .vertical)
            .lineLimit(4...12).textFieldStyle(.plain).padding(14)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(Theme.ink)

        Button {
            Task {
                submitting = true
                outcome = await app.submitChallenge(challenge, answer: answer)
                submitting = false
            }
        } label: {
            HStack {
                if submitting { ProgressView().tint(.white) }
                Text(submitting ? "Bringing it to life…" : "Make it happen").font(.headline)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
        .opacity(answer.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

        Text("Your idea is graded out of 100. Reach \(challenge.passMark) to clear this level.")
            .font(.footnote).foregroundStyle(Theme.grey)
    }

    // Once you clear a level, that is your one level for today.
    @ViewBuilder private func clearedToday(nextLevel challenge: DailyChallenge) -> some View {
        HearthCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Level cleared today", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(Theme.moss)
                Text("You brought a little more of Prism back to life. Come back tomorrow for Level \(challenge.level): \(challenge.title).")
                    .font(.callout).foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        Button("Read the story so far") { showStory = true }
            .font(.headline).foregroundStyle(Theme.magic)
    }
}

// "Story so far": the unfolding adventure the player has built, one beat per day.
struct StoryView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let beats = app.worldState?.storyLog ?? []
                    if beats.isEmpty {
                        Text("Your story begins with your first making. Answer today's challenge to write its first line.")
                            .font(.callout).foregroundStyle(Theme.grey)
                    } else {
                        ForEach(Array(beats.enumerated()), id: \.offset) { i, beat in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    .frame(width: 26, height: 26).background(Circle().fill(Theme.rainbow[i % Theme.rainbow.count]))
                                Text(beat).font(.callout).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Story so far")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// "Your Path": streak, totals, and your creative shape over time.
struct GrowthView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let ws = app.worldState {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            stat("\(ws.level)", "level")
                            stat("\(ws.streak)", "day streak")
                            stat("\(ws.bestScore)", "best score")
                        }
                        HStack {
                            stat("\(ws.totalPoints)", "total points")
                            stat("\(ws.profile.totalActs)", "ideas tried")
                            stat("\(ws.wallet[.embers])", "sparks")
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your creative shape").font(.headline).foregroundStyle(Theme.candle)
                            FlowChips(chips: CreativeDimension.allCases.map { (Self.label($0), ws.profile.value($0) * 100) })
                        }
                    }
                    .padding(20)
                } else {
                    Text("Make something first.").foregroundStyle(Theme.grey).padding()
                }
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Your Path")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title.bold()).foregroundStyle(Theme.ember)
            Text(label).font(.caption).foregroundStyle(Theme.grey)
        }
        .frame(maxWidth: .infinity)
    }

    static func label(_ d: CreativeDimension) -> String {
        switch d {
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
