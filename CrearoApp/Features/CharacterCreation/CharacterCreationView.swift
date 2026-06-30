import SwiftUI
import CrearoCore

// Light onboarding for the daily creativity app: your name + a companion to grow with.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var name = ""
    @State private var companion = ""
    @State private var starting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PixelCompanion(vitality: 0.4).frame(height: 150).frame(maxWidth: .infinity)

                Text("A daily practice in making things.")
                    .font(Theme.title).foregroundStyle(Theme.candle)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Each day, one creative challenge. Answer it, and your companion, like your creativity, grows a little.")
                    .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                field("Your name", text: $name, prompt: "Wren")
                field("Name your companion", text: $companion, prompt: "Kindle")

                Button {
                    Task {
                        starting = true
                        await app.startNewGame(characterName: name.isEmpty ? "Maker" : name,
                                               companionName: companion.isEmpty ? "Kindle" : companion)
                        starting = false
                    }
                } label: {
                    HStack {
                        if starting { ProgressView().tint(Theme.night) }
                        Text(starting ? "Beginning…" : "Begin").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(Theme.night)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || starting)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(24)
        }
        .background(Theme.night.ignoresSafeArea())
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey))
                .textFieldStyle(.plain).padding(12)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.ink)
        }
    }
}
