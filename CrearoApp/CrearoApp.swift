import SwiftUI

// Composition root. Builds AppState with live services and injects it into the SwiftUI environment.

@main
struct CrearoApp: App {
    @State private var app = AppState(services: .live())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.dark)   // cozy dark fantasy (GDD §7)
                .task { await app.bootstrap() }
                .tint(Theme.ember)
        }
    }
}
