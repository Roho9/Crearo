import SwiftUI
import CrearoCore

// One world. The persistent RealityKit world is always on screen; the opening sequence, the HUD,
// and the touch controls draw on top of it. No tabs — the world IS the app.
struct RootView: View {
    @Environment(AppState.self) private var app
    @StateObject private var world = WorldController()

    /// Grey (0) before any making; warms toward full colour (1) with the companion's brightness,
    /// dimmed by the Greying. Starts low so the player *sees* the world relight as they create.
    private var worldVitality: Float {
        guard let ws = app.worldState else { return 0.12 }
        return Float(max(0.12, ws.companion.brightness * (1 - ws.home.corruptionLevel)))
    }

    var body: some View {
        ZStack {
            WorldStage(controller: world).ignoresSafeArea()
            WeatherOverlay(weather: world.weather).ignoresSafeArea().allowsHitTesting(false)

            if app.didBootstrap {
                if app.worldState == nil {
                    OpeningOverlay()
                } else {
                    WorldHUD()
                    WorldControls(controller: world)
                }
            }
        }
        .onAppear {
            world.onGather = { n in Task { await app.gather(creaCash: n) } }
            world.setVitality(worldVitality)
        }
        .onChange(of: worldVitality) { _, v in world.setVitality(v) }
    }
}

#Preview {
    RootView().environment(AppState(services: .preview()))
}
