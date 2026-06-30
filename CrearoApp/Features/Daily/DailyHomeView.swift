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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("\(app.worldState?.streak ?? 0)", systemImage: "flame.fill").foregroundStyle(Theme.ember)
                        Spacer()
                        Label("\(app.worldState?.wallet[.embers] ?? 0)", systemImage: "sparkles").foregroundStyle(Theme.berry)
                    }
                    .font(.headline)

                    PixelCompanion(vitality: vitality).frame(height: 150).frame(maxWidth: .infinity)

                    Text("CHAPTER \(challenge.chapter)  •  \(challenge.title.uppercased())")
                        .font(.caption.weight(.bold)).foregroundStyle(Theme.magic).tracking(1)

                    HearthCard {
                        Text(challenge.setup).font(Theme.body).foregroundStyle(Theme.ink)
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

                    if app.hasDoneToday {
                        Text("You moved the story forward today. Come back tomorrow for the next chapter, or keep playing.")
                            .font(.footnote).foregroundStyle(Theme.grey)
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
            .fullScreenCover(item: $outcome) { o in OutcomeView(outcome: o) { answer = "" } }
            .sheet(isPresented: $showGrowth) { GrowthView() }
            .sheet(isPresented: $showStory) { StoryView() }
        }
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
                            stat("\(ws.streak)", "day streak")
                            stat("\(ws.profile.totalActs)", "makings")
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
