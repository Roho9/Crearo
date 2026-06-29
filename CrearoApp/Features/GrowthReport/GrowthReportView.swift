import SwiftUI
import CrearoCore

struct GrowthReportView: View {
    @Environment(AppState.self) private var app
    @State private var vm = GrowthReportViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let ws = app.worldState {
                    VStack(alignment: .leading, spacing: 20) {
                        if let prophecy = app.latestProphecy {
                            ProphecyBanner(text: prophecy)
                        }

                        // The "Sky of Makings": brightness is the only signal. No numbers (GDD §39, §43).
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Sky of Makings").font(Theme.heading).foregroundStyle(Theme.candle)
                            Text("Each star brightens as that part of you grows. The dim ones are where the Unwritten still waits.")
                                .font(.footnote).foregroundStyle(Theme.grey)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                                ForEach(CreativeDimension.allCases, id: \.self) { dim in
                                    let brightness = ws.profile.value(dim)
                                    VStack(spacing: 6) {
                                        Image(systemName: "star.fill")
                                            .font(.title2)
                                            .foregroundStyle(Theme.candle.opacity(0.18 + 0.82 * brightness))
                                            .shadow(color: Theme.ember.opacity(brightness), radius: 6 * brightness)
                                        Text(GrowthReportViewModel.starName[dim] ?? "")
                                            .font(.caption2).foregroundStyle(Theme.grey)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))

                        if let cls = ws.character.dominantClass() {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("The world has come to know you as").font(.footnote).foregroundStyle(Theme.grey)
                                GlowTag(text: "the \(cls.title)", color: Theme.magic)
                            }
                        }

                        if !ws.badges.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Marks").font(.headline).foregroundStyle(Theme.candle)
                                ForEach(ws.badges) { badge in
                                    Label(badge.markName, systemImage: "seal.fill")
                                        .font(.subheadline).foregroundStyle(Theme.ink)
                                }
                            }
                        }

                        // Glimpse the personalized final boss forming from your weakest patterns (GDD §50).
                        Button {
                            vm.revealShadow(app: app)
                        } label: {
                            Label("Glimpse the shadow you are becoming", systemImage: "eye.trianglebadge.exclamationmark")
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Theme.fog.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.candle)
                        }
                    }
                    .padding(20)
                } else {
                    Text("No path yet.").foregroundStyle(Theme.grey).padding()
                }
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Your Path")
            .sheet(isPresented: $vm.showShadow) {
                ShadowSheet(boss: vm.boss)
            }
        }
    }
}

private struct ShadowSheet: View {
    let boss: PersonalizedBoss?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("The Unwritten").font(Theme.title).foregroundStyle(Theme.candle)
                if let boss {
                    Text("“\(boss.taunt)”").font(.callout.italic()).foregroundStyle(Theme.ink)
                    Text("It would test you here:").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
                    ForEach(boss.phases, id: \.name) { phase in
                        HearthCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phase.name).font(.headline).foregroundStyle(Theme.magic)
                                Text(phase.winCondition).font(.footnote).foregroundStyle(Theme.ink.opacity(0.9))
                            }
                        }
                    }
                    Text("Grow these, and the shadow has nothing left to wear.")
                        .font(.footnote).foregroundStyle(Theme.grey)
                } else {
                    Text("The shadow has not yet taken shape. Keep making.").foregroundStyle(Theme.grey)
                }
            }
            .padding(20)
        }
        .background(Theme.night.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    GrowthReportView().environment(AppState(services: .preview()))
}
