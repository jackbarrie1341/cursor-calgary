import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Group {
                if appState.isLoading && appState.buddy == nil {
                    ProgressView()
                } else if appState.buddy?.hasOnboarded == true {
                    HomeView()
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(appState)
                }
            }
            .navigationTitle("Finance Buddy")
            .toolbar {
                if appState.isLoading {
                    ProgressView()
                }
            }
            .task {
                await appState.start()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
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
