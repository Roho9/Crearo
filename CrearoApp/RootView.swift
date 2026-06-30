import SwiftUI
import CrearoCore

// A daily creativity practice. One app: a brief onboarding, then today's challenge.
struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            if !app.didBootstrap {
                SplashView()
            } else if app.worldState == nil {
                OnboardingView()
            } else {
                DailyHomeView()
            }
        }
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
