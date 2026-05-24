import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if appState.isLoading && appState.buddy == nil {
                    ProgressView()
                } else if !appState.isAuthenticated {
                    AuthView()
                        .environmentObject(appState)
                } else if appState.buddy?.hasOnboarded != true {
                    OnboardingView()
                        .environmentObject(appState)
                } else if appState.buddy?.isLinked != true {
                    BankOnboardingView()
                        .environmentObject(appState)
                } else {
                    MainTabView()
                        .environmentObject(appState)
                }
            }
            .font(DoodleFont.body)
            .doodleTracking()
            .toolbar {
                if appState.isLoading {
                    ProgressView()
                }
            }
            .task {
                await appState.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, appState.isAuthenticated, appState.buddy != nil else { return }
                Task {
                    await appState.refreshBuddy()
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appState.errorMessage ?? "")
            }
            .sheet(isPresented: $appState.isPresentingPlaid) {
                if let linkToken = appState.linkToken {
                    PlaidLinkView(
                        linkToken: linkToken,
                        onSuccess: { publicToken in
                            Task {
                                await appState.plaidSucceeded(publicToken: publicToken)
                            }
                        },
                        onExit: { error in
                            appState.plaidExited(error: error)
                        }
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
