import SwiftUI

// Composition root. Builds AppState with live services and injects it into the SwiftUI environment.

@main
struct CrearoApp: App {
    @State private var app = AppState(services: .live())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .preferredColorScheme(.light)  // the paper theatre uses light stock and dark ink
                .task { await app.bootstrap() }
                .tint(Theme.ember)
        }
    }
}
