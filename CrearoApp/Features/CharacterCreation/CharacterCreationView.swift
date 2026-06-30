import SwiftUI
import CrearoCore

struct CharacterCreationView: View {
    @Environment(AppState.self) private var app
    @State private var vm = CharacterCreationViewModel()

    var body: some View {
        @Bindable var vm = vm
        // Single page, no scroll: everything fits one screen (GeometryReader keeps it bounded
        // on smaller devices by tightening spacing rather than overflowing).
        GeometryReader { geo in
            let tight = geo.size.height < 760
            VStack(alignment: .leading, spacing: tight ? 10 : 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You wake in a small wooden house.")
                        .font(tight ? Theme.heading : Theme.title).foregroundStyle(Theme.candle)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("The hearth is cold. The world outside is grey. In the corner, something colourless waits, and you are one of the last who can still make new things.")
                        .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HearthCard {
                    VStack(alignment: .leading, spacing: tight ? 8 : 12) {
                        field("Your name", text: $vm.characterName, prompt: "Wren")
                        field("Name the small creature in the corner", text: $vm.companionName, prompt: "Kindle")
                        field("One object that means something to you", text: $vm.symbolicObject, prompt: "my grandmother's bus ticket")
                        multilineField("A mark, so this place knows you live here", text: $vm.firstMark,
                                       prompt: "a sigil: a spiral of sparks, a small sun…")
                        multilineField("What did you make, once, that you were proud of?", text: $vm.backstory,
                                       prompt: "anything; it will be remembered")
                    }
                }

                Text("Nothing here is a test. Make as little or as much as you like; the room simply warms to whatever you give it.")
                    .font(.caption).foregroundStyle(Theme.grey)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

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
            .padding(.horizontal, 20)
            .padding(.vertical, tight ? 12 : 20)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(Theme.night.ignoresSafeArea())
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey))
                .textFieldStyle(.plain).padding(8)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.ink)
        }
    }

    private func multilineField(_ label: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey), axis: .vertical)
                .lineLimit(1...3).textFieldStyle(.plain).padding(8)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(Theme.ink)
        }
    }
}

#Preview {
    CharacterCreationView().environment(AppState(services: .preview()))
}
