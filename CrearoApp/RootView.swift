import SwiftUI
import CrearoCore

struct RootView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ZStack {
            Theme.night.ignoresSafeArea()
            if app.worldState == nil {
                CharacterCreationView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeBaseView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            ForestView()
                .tabItem { Label("World", systemImage: "tree.fill") }
            CreationForgeView()
                .tabItem { Label("Forge", systemImage: "hammer.fill") }
            DailyQuestView()
                .tabItem { Label("Daily", systemImage: "sparkles") }
            GrowthReportView()
                .tabItem { Label("Path", systemImage: "moon.stars.fill") }
        }
    }
}

#Preview {
    RootView().environment(AppState(services: .preview()))
}
