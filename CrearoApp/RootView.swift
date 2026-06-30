import SwiftUI
import CrearoCore

// One world. The persistent RealityKit world is always on screen; the opening sequence and every
// panel (the Forge, …) appear as overlays inside it. No tabs — the world IS the app.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            BlobStage().ignoresSafeArea()   // the living world: clay companion in a grove

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
