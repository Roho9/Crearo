import SwiftUI
import CrearoCore

// The only persistent chrome over the world: how much CreaCash you hold, and the Forge.
// No tabs — everything is the world; panels rise over it.
struct WorldHUD: View {
    @Environment(AppState.self) private var app
    @Binding var forgeOpen: Bool
    @State private var confirmingReset = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if let ws = app.worldState {
                        CreaCashTag(amount: ws.wallet[.embers])
                    }
                    Spacer()
                    Menu {
                        Button("New Game", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmingReset = true
                        }
                    } label: {
                        hudCircle("ellipsis", filled: false)
                    }
                    Button { forgeOpen = true } label: {
                        hudCircle("hammer.fill", filled: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)

                Spacer()

                // A whisper of fiction, never numbers (GDD §39).
                if let line = app.latestCompanionLine {
                    Text(line)
                        .font(.callout.italic()).foregroundStyle(Theme.candle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.panel.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 18).padding(.bottom, 20)
                }
            }

            if let toast = app.toast {
                Text(toast)
                    .font(.subheadline.weight(.medium)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.panel, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.ember.opacity(0.3), lineWidth: 1))
                    .padding(.top, 72)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: app.toast)
        .confirmationDialog("Begin again?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Start a new game", role: .destructive) { Task { await app.resetGame() } }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("This clears your current world and returns to the opening. Your makings won't be recoverable.")
        }
    }

    private func hudCircle(_ systemName: String, filled: Bool) -> some View {
        Image(systemName: systemName)
            .font(.system(size: filled ? 20 : 18, weight: .semibold))
            .foregroundStyle(filled ? Theme.night : Theme.candle)
            .frame(width: 46, height: 46)
            .background(Circle().fill(filled ? Theme.ember : Theme.panel))
            .overlay(filled ? nil : Circle().strokeBorder(Theme.ember.opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }
}

/// The visible currency: a single CreaCash readout.
struct CreaCashTag: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.caption)
            Text("\(amount) \(Resource.embers.displayName)").font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(Theme.candle)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(Theme.panel))
        .overlay(Capsule().strokeBorder(Theme.ember.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)
    }
}

/// The Forge: an opaque panel that rises over the world. Speak an idea; it becomes a real making.
struct ForgePanel: View {
    @Environment(AppState.self) private var app
    @Binding var isPresented: Bool
    @State private var idea = ""
    @State private var working = false

    private var canForge: Bool { !idea.trimmingCharacters(in: .whitespaces).isEmpty && !working }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { if !working { isPresented = false } }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("The Forge").font(Theme.heading).foregroundStyle(Theme.candle)
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(Theme.grey)
                    }
                }
                Text("Speak an idea into being. The forge shapes it to fit this place, and the world remembers it.")
                    .font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))

                TextField("", text: $idea,
                          prompt: Text("a sword that shoots honey to slow enemies").foregroundStyle(Theme.grey),
                          axis: .vertical)
                    .lineLimit(1...4).textFieldStyle(.plain).padding(12)
                    .background(Theme.night, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.ink)

                Button {
                    Task {
                        working = true
                        await app.forge(ideaText: idea, modality: .writing)
                        working = false; idea = ""; isPresented = false
                    }
                } label: {
                    HStack {
                        if working { ProgressView().tint(Theme.night) }
                        Text(working ? "Forging…" : "Forge it").font(.headline)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Theme.night)
                }
                .disabled(!canForge)
                .opacity(canForge ? 1 : 0.5)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel)
            .clipShape(.rect(topLeadingRadius: 26, topTrailingRadius: 26))
            .shadow(color: .black.opacity(0.5), radius: 16, y: -4)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .transition(.opacity)
    }
}
