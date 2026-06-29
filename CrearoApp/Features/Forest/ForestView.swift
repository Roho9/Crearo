import SwiftUI
import CrearoCore
#if canImport(RealityKit) && canImport(UIKit)
import RealityKit
#endif

struct ForestView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                RealityForest(corruption: Float(app.worldState?.home.corruptionLevel ?? 0))
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 10) {
                    if let ws = app.worldState {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(ws.unlockedRegions, id: \.self) { region in
                                    Button { app.selectedRegion = region } label: {
                                        GlowTag(text: region.displayName,
                                                color: region == app.selectedRegion ? Theme.ember : Theme.grey)
                                    }
                                }
                            }
                        }
                    }
                    Text("The fog moves like it's listening. Make something the Mirrorwood hasn't seen — head to the Forge.")
                        .font(.footnote).foregroundStyle(Theme.candle)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.night.opacity(0.6)))
                    // NOTE: touch movement (the floating joystick) is stubbed for the MVP; traversal
                    // controls attach to the RealityKit camera rig in ForestSceneController next.
                }
                .padding(16)
            }
            .navigationTitle(app.selectedRegion.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if canImport(RealityKit) && canImport(UIKit)
/// Hosts the RealityKit diorama and pushes corruption changes into it.
struct RealityForest: UIViewRepresentable {
    var corruption: Float

    func makeUIView(context: Context) -> ARView {
        let controller = ForestSceneController()
        context.coordinator.controller = controller
        controller.setCorruption(corruption)
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.controller?.setCorruption(corruption)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var controller: ForestSceneController? }
}
#else
/// Fallback for platforms without RealityKit (e.g., Linux preview builds).
struct RealityForest: View {
    var corruption: Float
    var body: some View {
        LinearGradient(colors: [Theme.moss.opacity(0.5), Theme.fog], startPoint: .top, endPoint: .bottom)
    }
}
#endif

#Preview {
    ForestView().environment(AppState(services: .preview()))
}
