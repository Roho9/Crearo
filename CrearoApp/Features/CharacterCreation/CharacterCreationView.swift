import SwiftUI
import CrearoCore

// A short introduction to the same paper world the player will enter, followed by just two names.
struct OnboardingView: View {
    @Environment(AppState.self) private var app
    @State private var name = ""
    @State private var companion = ""
    @State private var starting = false
    @FocusState private var focusedField: NameField?

    private enum NameField: Hashable {
        case maker, companion
    }

    private var canBegin: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !starting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WELCOME TO CREARO")
                        .font(.caption.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(Theme.grey)
                    Text("A little world.\nA new way to think.")
                        .font(Theme.title)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Invent surprising ways through playful puzzles. Grow your ideas, earn a creativity score, and bring Prism to life with a companion by your side.")
                        .font(Theme.body)
                        .lineSpacing(3)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaperTheatreStageView(levelTitle: "The Spark", vitality: 0.65)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Theme.edge.opacity(0.65), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 18) {
                    Text("Who's stepping onto the stage?")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    nameField("Your name", text: $name, prompt: "Wren", field: .maker)
                    VStack(alignment: .leading, spacing: 8) {
                        nameField("Your companion's name", text: $companion,
                                  prompt: "Kindle", field: .companion)
                        Text("Leave this blank to meet Kindle.")
                            .font(.footnote)
                            .foregroundStyle(Theme.grey)
                    }
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PaperPageBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                Button(action: begin) {
                    HStack(spacing: 10) {
                        if starting { ProgressView().tint(.white) }
                        Text(starting ? "Setting the stage…" : "Begin my story")
                    }
                }
                .buttonStyle(PaperPrimaryButtonStyle())
                .disabled(!canBegin)
                .accessibilityHint("Create your world and open the first chapter.")
                Text("One chapter a day. You can refine your idea and try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.grey)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 24)
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

    private func nameField(_ label: String, text: Binding<String>, prompt: String,
                           field: NameField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.grey))
                .font(Theme.body)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 24)
                .padding(14)
                .background(PaperCardSurface(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(focusedField == field ? Theme.sky : .clear, lineWidth: 2)
                }
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(field == .maker ? .next : .done)
                .onSubmit {
                    if field == .maker { focusedField = .companion }
                    else { begin() }
                }
                .accessibilityLabel(label)
                .accessibilityHint(field == .maker ? "Enter the name you'll use in your story." : "Optional. Leave blank to use Kindle.")
        }
    }

    private func begin() {
        guard canBegin else { return }
        focusedField = nil
        starting = true
        Task {
            await app.startNewGame(characterName: name.isEmpty ? "Maker" : name,
                                   companionName: companion.isEmpty ? "Kindle" : companion)
            starting = false
        }
    }
}
