import SwiftUI
import CrearoCore

// The home of the app: today's one creative challenge, with the companion above it. Answer it →
// the result sheet shows the pixel celebration, your creative shape, coaching, and streak.
struct DailyHomeView: View {
    @Environment(AppState.self) private var app
    @State private var answer = ""
    @State private var outcome: ChallengeOutcome?
    @State private var submitting = false
    @State private var showGrowth = false

    var body: some View {
        let challenge = app.todaysChallenge
        let vitality = app.worldState?.companion.brightness ?? 0.3
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Label("\(app.worldState?.streak ?? 0)", systemImage: "flame.fill").foregroundStyle(Theme.ember)
                        Spacer()
                        Label("\(app.worldState?.wallet[.embers] ?? 0)", systemImage: "sparkles").foregroundStyle(Theme.candle)
                    }
                    .font(.headline)

                    PixelCompanion(vitality: vitality).frame(height: 150)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(challenge.mode.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Theme.grey).tracking(1.5)
                        Text(challenge.prompt).font(Theme.heading).foregroundStyle(Theme.candle)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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
                            if submitting { ProgressView().tint(Theme.night) }
                            Text(submitting ? "Reflecting…" : (app.hasDoneToday ? "Make something else" : "Submit"))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.night)
                    }
                    .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty || submitting)
                    .opacity(answer.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    if app.hasDoneToday {
                        Text("You've made your thing today. Come back tomorrow for a new challenge, or keep practising.")
                            .font(.footnote).foregroundStyle(Theme.grey)
                    }
                }
                .padding(20)
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Path", systemImage: "chart.line.uptrend.xyaxis") { showGrowth = true }
                }
            }
            .sheet(item: $outcome) { o in
                ChallengeResultView(outcome: o) { answer = "" }
            }
            .sheet(isPresented: $showGrowth) { GrowthView() }
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
                        if let p = app.latestProphecy {
                            Text(p).font(.callout.italic()).foregroundStyle(Theme.candle)
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14))
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
