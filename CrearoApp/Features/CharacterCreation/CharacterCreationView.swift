import SwiftUI
import CrearoCore

// The opening, reimagined as a moment INSIDE the world: the clay companion stands in the grove
// behind, and one question at a time rises as an opaque prompt at the bottom. No walls of text —
// you answer, it fades to the next, then the world is yours.
struct OpeningOverlay: View {
    @Environment(AppState.self) private var app
    @State private var vm = CharacterCreationViewModel()
    @State private var step = 0
    @State private var shown = false

    private struct Step {
        let label: String
        let prompt: String
        let text: Binding<String>
        let multiline: Bool
        let required: Bool
        init(_ label: String, _ prompt: String, _ text: Binding<String>, multiline: Bool, required: Bool = false) {
            self.label = label; self.prompt = prompt; self.text = text
            self.multiline = multiline; self.required = required
        }
    }

    var body: some View {
        @Bindable var vm = vm
        let steps: [Step] = [
            Step("What do they call you?", "Wren", $vm.characterName, multiline: false, required: true),
            Step("Name the small creature in the corner.", "Kindle", $vm.companionName, multiline: false),
            Step("One object that means something to you.", "my grandmother's bus ticket", $vm.symbolicObject, multiline: false),
            Step("Leave a mark, so this place knows you live here.", "a spiral of sparks, a small sun…", $vm.firstMark, multiline: true),
            Step("What did you make once, that you were proud of?", "anything; it will be remembered", $vm.backstory, multiline: true),
        ]
        let current = steps[min(step, steps.count - 1)]
        let isLast = step >= steps.count - 1
        let blocked = current.required && current.text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty

        VStack(spacing: 0) {
            // A whisper of fiction up top; the world & companion fill the space below it.
            Text("In a world drained of colour, you are one of the last who can still make new things.")
                .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28).padding(.top, 8)
                .shadow(color: .black.opacity(0.6), radius: 6)

            Spacer(minLength: 0)

            // The questions: the solid, opaque feature over the immersive world.
            VStack(alignment: .leading, spacing: 14) {
                Text("\(step + 1) of \(steps.count)")
                    .font(.caption2.weight(.semibold)).foregroundStyle(Theme.grey)
                Text(current.label)
                    .font(Theme.heading).foregroundStyle(Theme.candle)
                    .fixedSize(horizontal: false, vertical: true)

                Group {
                    if current.multiline {
                        TextField("", text: current.text,
                                  prompt: Text(current.prompt).foregroundStyle(Theme.grey), axis: .vertical)
                            .lineLimit(1...3)
                    } else {
                        TextField("", text: current.text,
                                  prompt: Text(current.prompt).foregroundStyle(Theme.grey))
                    }
                }
                .textFieldStyle(.plain).padding(12)
                .background(Theme.night, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(Theme.ink)

                HStack {
                    if step > 0 {
                        Button("Back") { withAnimation(.easeInOut) { step -= 1 } }
                            .foregroundStyle(Theme.grey)
                    }
                    Spacer()
                    Button {
                        if isLast { Task { await vm.begin(app: app) } }
                        else { withAnimation(.easeInOut) { step += 1 } }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isSubmitting { ProgressView().tint(Theme.night) }
                            Text(isLast ? "Light the fire" : "Next").font(.headline)
                        }
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(Theme.night)
                    }
                    .disabled(blocked || vm.isSubmitting)
                    .opacity(blocked ? 0.5 : 1)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)   // opaque
            .clipShape(.rect(topLeadingRadius: 26, topTrailingRadius: 26))
            .shadow(color: .black.opacity(0.45), radius: 14, y: -4)
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 60)
        }
        .padding(.top, 50)
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear { withAnimation(.easeOut(duration: 0.7).delay(0.5)) { shown = true } }
    }
}
