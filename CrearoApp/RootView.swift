import SwiftUI
import CrearoCore

// The new construction game keeps earlier AppState saves available through the collection.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        AtelierView()
    }
}

/// A calm loading state while the saved profile is restored.
struct SplashView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(Theme.ember)
            ProgressView().tint(Theme.candle)
        }
    }
}

#Preview {
    RootView().environment(AppState(services: .preview()))
}
