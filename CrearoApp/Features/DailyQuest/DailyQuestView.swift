import SwiftUI
import CrearoCore

struct DailyQuestView: View {
    @Environment(AppState.self) private var app
    @State private var vm = DailyQuestViewModel()

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HearthCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(vm.prompt.title).font(Theme.heading).foregroundStyle(Theme.candle)
                            Text(vm.prompt.body).font(Theme.body).foregroundStyle(Theme.ink.opacity(0.9))

                            TextField("", text: $vm.response,
                                      prompt: Text("your answer…").foregroundStyle(Theme.grey), axis: .vertical)
                                .lineLimit(3...7).textFieldStyle(.plain).padding(10)
                                .background(Theme.night, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(Theme.ink)

                            Picker("How", selection: $vm.modality) {
                                ForEach(Modality.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                            }.pickerStyle(.menu).tint(Theme.ember)

                            Button {
                                Task { await vm.submit(app: app); vm.refreshPrompt(for: app) }
                            } label: {
                                Text(app.isWorking ? "Offering…" : "Offer it to the hearth")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                                    .background(Theme.ember, in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(Theme.night).font(.headline)
                            }
                            .disabled(!vm.canSubmit || app.isWorking)
                            .opacity(vm.canSubmit ? 1 : 0.5)
                        }
                    }

                    if let toast = app.toast { Text(toast).font(.footnote).foregroundStyle(Theme.candle) }
                    if let prophecy = app.latestProphecy { ProphecyBanner(text: prophecy) }
                    if let line = app.latestCompanionLine, let ws = app.worldState {
                        CompanionBanner(name: ws.companion.name, line: line, brightness: ws.companion.brightness)
                    }

                    Text("Come back each day. The hearth stays bright while you do, and dims, gently, when you're gone too long.")
                        .font(.footnote).foregroundStyle(Theme.grey)
                }
                .padding(20)
            }
            .background(Theme.night.ignoresSafeArea())
            .navigationTitle("Daily Making")
            .onAppear { vm.refreshPrompt(for: app) }
        }
    }
}

#Preview {
    DailyQuestView().environment(AppState(services: .preview()))
}
