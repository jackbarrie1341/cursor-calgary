import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var buddy: BuddyState?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var linkToken: String?
    @Published var isPresentingPlaid = false

    private let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    private var accessToken: String?
    private var userId: String?
    private var realtimeTask: Task<Void, Never>?

    var backend: BackendClient {
        BackendClient(baseURL: AppConfig.backendBaseURL, accessToken: accessToken)
    }

    func start() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await ensureSession()
            buddy = try await backend.getBuddy()
            await subscribeToBuddyUpdates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeOnboarding(_ input: OnboardingInput) async {
        await run {
            self.buddy = try await self.backend.completeOnboarding(input)
        }
    }

    func connectBank() async {
        await run {
            self.linkToken = try await self.backend.createLinkToken()
            self.isPresentingPlaid = true
        }
    }

    func plaidSucceeded(publicToken: String) async {
        isPresentingPlaid = false
        linkToken = nil

        await run {
            self.buddy = try await self.backend.exchangePublicToken(publicToken)
        }
    }

    func plaidExited(error: Error?) {
        isPresentingPlaid = false
        linkToken = nil
        if let error {
            errorMessage = error.localizedDescription
        }
    }

    func refreshTransactions() async {
        await run {
            try await self.backend.refreshTransactions()
        }
    }

    func refreshBuddy() async {
        await run {
            self.buddy = try await self.backend.getBuddy()
        }
    }

    private func run(_ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await ensureSession()
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func ensureSession() async throws {
        guard AppConfig.hasSupabaseConfig else {
            throw AppConfigurationError.missingSupabaseConfig
        }

        if accessToken != nil, userId != nil {
            return
        }

        do {
            let session = try await supabase.auth.session
            accessToken = session.accessToken
            userId = session.user.id.uuidString
        } catch {
            let session = try await supabase.auth.signInAnonymously()
            accessToken = session.accessToken
            userId = session.user.id.uuidString
        }
    }

    private func subscribeToBuddyUpdates() async {
        guard realtimeTask == nil, let userId else { return }

        realtimeTask = Task { [supabase] in
            let channel = supabase.channel("buddy-state-\(userId)")
            let inserts = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "buddy_states",
                filter: .eq("user_id", value: userId)
            )
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "buddy_states",
                filter: .eq("user_id", value: userId)
            )

            await channel.subscribe()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in inserts {
                        await self.refreshBuddy()
                    }
                }

                group.addTask {
                    for await _ in updates {
                        await self.refreshBuddy()
                    }
                }
            }
        }
    }
}
