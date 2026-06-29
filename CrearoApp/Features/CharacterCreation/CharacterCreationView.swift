import SwiftUI
import CrearoCore

struct CharacterCreationView: View {
    @Environment(AppState.self) private var app
    @State private var vm = CharacterCreationViewModel()

    var body: some View {
        @Bindable var vm = vm
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You wake in a small wooden house.")
                        .font(Theme.title).foregroundStyle(Theme.candle)
                    Text("The hearth is cold. The world outside is grey. In the corner, something colourless waits — and you are one of the last who can still make new things.")
                        .font(Theme.body).foregroundStyle(Theme.ink.opacity(0.85))
                }

                HearthCard {
                    VStack(alignment: .leading, spacing: 16) {
                        field("Your name", text: $vm.characterName, prompt: "Wren")
                        field("Name the small creature in the corner", text: $vm.companionName, prompt: "Kindle")
                        field("One object that means something to you", text: $vm.symbolicObject, prompt: "my grandmother's bus ticket")
                        multilineField("A mark, so this place knows you live here", text: $vm.firstMark,
                                       prompt: "describe or name a sigil — a spiral of sparks, a small sun…")
                        multilineField("What did you make, once, that you were proud of?", text: $vm.backstory,
                                       prompt: "anything — it will be remembered")
                    }
                }

                Text("Nothing here is a test. Make as little or as much as you like — the room simply warms to whatever you give it.")
                    .font(.footnote).foregroundStyle(Theme.grey)

                Button {
                    Task { await vm.begin(app: app) }
                } label: {
                    HStack {
                        if vm.isSubmitting { ProgressView().tint(Theme.night) }
                        Text(vm.isSubmitting ? "Lighting the fire…" : "Light the fire")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.night)
                }
                .disabled(!vm.canBegin || vm.isSubmitting)
                .opacity(vm.canBegin ? 1 : 0.5)
            }
            .padding(20)
        }
        .background(Theme.night.ignoresSafeArea())
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey))
                .textFieldStyle(.plain).padding(10)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.ink)
        }
    }

    private func multilineField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey), axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.plain).padding(10)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.ink)
        }
    }
}

#Preview {
    CharacterCreationView().environment(AppState(services: .preview()))
}
