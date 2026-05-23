import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .environmentObject(appState)
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            FriendsView()
                .environmentObject(appState)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
        }
    }
}
