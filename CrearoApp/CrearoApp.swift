import SwiftUI

// Composition root. Builds AppState with live services and injects it into the SwiftUI environment.

@main
struct CrearoApp: App {
    @State private var app = AppState(services: .live())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.light)  // the paper theatre uses light stock and dark ink
                .task { await app.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { Task { await app.flushChallengeDrafts() } }
                }
                .tint(Theme.ember)
        }
    }
}
