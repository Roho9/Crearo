import SwiftUI
import CrearoCore

// One world. The persistent RealityKit world is always on screen; the opening sequence and every
// panel (the Forge, …) appear as overlays inside it. No tabs — the world IS the app.
struct RootView: View {
    @Environment(AppState.self) private var app

    /// Grey (0) before any making; warms toward full colour (1) with the companion's brightness,
    /// dimmed by the Greying. Starts low so the player *sees* the world relight as they create.
    private var worldVitality: Float {
        guard let ws = app.worldState else { return 0.12 }
        return Float(max(0.12, ws.companion.brightness * (1 - ws.home.corruptionLevel)))
    }

    var body: some View {
        ZStack {
            // Colour returns as you make: vitality rises with the companion's brightness and falls
            // as the Greying (corruption) creeps in. Before a game exists, the world is greyest.
            BlobStage(vitality: worldVitality).ignoresSafeArea()

            if app.didBootstrap {
                if app.worldState == nil {
                    OpeningOverlay()        // immersive opening: questions as a compact opaque panel
                } else {
                    WorldHUD()              // CreaCash + Forge, panels slide up over the world
                }
            }
        }
    }
}

#Preview {
    RootView().environment(AppState(services: .preview()))
}
