import SwiftUI
import CrearoCore

struct CreationForgeView: View {
    @Environment(AppState.self) private var app
    @State private var vm = CreationForgeViewModel()

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Speak an idea into being. The forge will shape it to fit this place, and the world will remember it.")
                        .font(Theme.body).foregroundStyle(Theme.ink.opacity(0.85))

                    if let ws = app.worldState {
                        ResourceWalletView(wallet: ws.wallet)
                    }

                    HearthCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Your idea").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.candle)
                            TextField("", text: $vm.ideaText,
                                      prompt: Text("a sword that shoots honey to slow enemies…").foregroundStyle(Theme.grey),
                                      axis: .vertical)
                                .lineLimit(2...5).textFieldStyle(.plain).padding(10)
                                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(Theme.ink)

                            Picker("How are you making it?", selection: $vm.modality) {
                                ForEach(Modality.allCases, id: \.self) { m in
                                    Text(m.rawValue.capitalized).tag(m)
                                }
                            }
                            .pickerStyle(.menu).tint(Theme.ember)

                            Button {
                                Task { await vm.forge(app: app) }
                            } label: {
                                HStack {
                                    if app.isWorking { ProgressView().tint(Theme.night) }
                                    Text(app.isWorking ? "Forging…" : "Forge it")
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Theme.ember, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.night).font(.headline)
                            }
                            .disabled(!vm.canForge || app.isWorking)
                            .opacity(vm.canForge ? 1 : 0.5)
                        }
                    }

                    if let toast = app.toast {
                        Text(toast).font(.footnote).foregroundStyle(Theme.candle)
                    }
                    if let prophecy = app.latestProphecy {
                        ProphecyBanner(text: prophecy)
                    }
                    if let creation = app.lastForged {
                        Text("Newly forged").font(.caption.weight(.semibold)).foregroundStyle(Theme.grey)
                        CreationCard(creation: creation)
                    }
                    if let line = app.latestCompanionLine, let ws = app.worldState {
                        CompanionBanner(name: ws.companion.name, line: line, brightness: ws.companion.brightness)
                    }
                }
                .padding(20)
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("The Forge")
        }
    }
}

#Preview {
    CreationForgeView().environment(AppState(services: .preview()))
}
