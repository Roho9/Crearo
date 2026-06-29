import SwiftUI
import CrearoCore

struct HomeBaseView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            ScrollView {
                if let ws = app.worldState {
                    VStack(alignment: .leading, spacing: 18) {
                        // Atmosphere shifts with corruption (GDD §48): warm when tended, grey when neglected.
                        let corruption = ws.home.corruptionLevel
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ws.character.name).font(Theme.title).foregroundStyle(Theme.candle)
                            Text(ws.character.title).font(.subheadline).foregroundStyle(Theme.grey)
                        }

                        CompanionBanner(name: ws.companion.name, line: app.latestCompanionLine,
                                        brightness: ws.companion.brightness)

                        if corruption > 0.05 {
                            Label("The Grey has crept in. Make something to restore the house.",
                                  systemImage: "cloud.fog.fill")
                                .font(.footnote).foregroundStyle(Theme.grey)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.fog.opacity(0.25)))
                        }

                        section("Your resources") { ResourceWalletView(wallet: ws.wallet) }

                        section("Rooms of the house") {
                            VStack(spacing: 8) {
                                ForEach(ws.home.rooms) { room in
                                    HStack {
                                        Image(systemName: icon(for: room.kind)).foregroundStyle(Theme.ember)
                                        Text(room.name).foregroundStyle(Theme.ink)
                                        Spacer()
                                        if room.corruption > 0.1 { GlowTag(text: "fading", color: Theme.grey) }
                                    }
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
                                }
                            }
                        }

                        if !ws.badges.isEmpty {
                            section("Marks earned") {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack { ForEach(ws.badges) { GlowTag(text: $0.markName, color: Theme.magic) } }
                                }
                            }
                        }

                        section("Gallery of makings (\(ws.creations.count))") {
                            VStack(spacing: 12) {
                                ForEach(ws.creations) { CreationCard(creation: $0) }
                                if ws.creations.isEmpty {
                                    Text("Nothing made yet. Visit the Forge.")
                                        .font(.footnote).foregroundStyle(Theme.grey)
                                }
                            }
                        }
                    }
                    .padding(20)
                } else {
                    Text("No home yet.").foregroundStyle(Theme.grey).padding()
                }
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Lastlight")
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline).foregroundStyle(Theme.candle)
            content()
        }
    }

    private func icon(for kind: String) -> String {
        switch kind {
        case "hearth": return "flame.fill"
        case "library": return "books.vertical.fill"
        case "forge": return "hammer.fill"
        case "greenhouse": return "leaf.fill"
        case "gallery": return "photo.artframe"
        default: return "square.stack.3d.up.fill"
        }
    }
}

#Preview {
    HomeBaseView().environment(AppState(services: .preview()))
}
