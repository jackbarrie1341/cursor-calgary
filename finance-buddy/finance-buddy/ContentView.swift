import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    // TESTING: force the loading screen to stay visible for this long.
    // Set to 0 (or remove) to disable.
    private let minimumLoadingDuration: TimeInterval = 10
    @State private var minimumLoadingComplete = false

    private var isBooting: Bool {
        !minimumLoadingComplete || (appState.isLoading && appState.buddy == nil)
    }

    var body: some View {
        ZStack {
            NavigationStack {
                contentBody
            }
            .opacity(isBooting ? 0 : 1)
        }
        .animation(.easeOut(duration: 0.4), value: isBooting)
        .task {
            try? await Task.sleep(nanoseconds: UInt64(minimumLoadingDuration * 1_000_000_000))
            minimumLoadingComplete = true
        }
        .onChange(of: isBooting) { _, newValue in
            if !newValue {
                appState.didCompleteInitialBoot = true
            }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        Group {
            if !appState.isAuthenticated {
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
                if newPhase == .active {
                    appState.resumeLobbyMusicIfEnabled()
                } else {
                    appState.pauseLobbyMusic()
                }

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

#Preview {
    ContentView()
}
