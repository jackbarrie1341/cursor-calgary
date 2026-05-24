import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    init() {
        DoodleAppearance.configure()
    }

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(appState)
                .tabItem { Label("Home", image: "finalhomecat_tab") }

            FriendsView()
                .environmentObject(appState)
                .tabItem { Label("Friends", image: "cat_yinyang_tab") }
        }
    }
}
