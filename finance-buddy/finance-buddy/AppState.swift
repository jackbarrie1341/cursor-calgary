import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var buddy: BuddyState? {
        didSet {
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            } else {
                BuddyWidgetSnapshotStore.clear()
            }
        }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var linkToken: String?
    @Published var isPresentingPlaid = false
    @Published var isAuthenticated = false
    @Published var currentDisplayName = ""
    @Published var currentUsername = ""
    @Published var friends: [FriendBuddy] = []
    @Published var friendSearchResults: [FriendSearchResult] = []
    @Published var debugBuddyAssetName: String?
    @Published var catFillHue: Double = UserDefaults.standard.object(forKey: "cat_fill_hue") as? Double ?? 0.04 {
        didSet {
            UserDefaults.standard.set(catFillHue, forKey: "cat_fill_hue")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
        }
    }
    @Published var catFillSaturation: Double = UserDefaults.standard.object(forKey: "cat_fill_saturation") as? Double ?? 0.48 {
        didSet {
            UserDefaults.standard.set(catFillSaturation, forKey: "cat_fill_saturation")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
        }
    }
    @Published var catFillBrightness: Double = UserDefaults.standard.object(forKey: "cat_fill_brightness") as? Double ?? 1.0 {
        didSet {
            UserDefaults.standard.set(catFillBrightness, forKey: "cat_fill_brightness")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
        }
    }

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
            try await restoreSession()
            if isAuthenticated {
                buddy = try await backend.getBuddy()
                await subscribeToBuddyUpdates()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(_ input: AuthInput) async {
        await run(requiresAuth: false) {
            guard AppConfig.hasSupabaseConfig else {
                throw AppConfigurationError.missingSupabaseConfig
            }

            let response = try await self.supabase.auth.signUp(
                email: input.normalizedEmail,
                password: input.password,
                data: [
                    "name": .string(input.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                    "email": .string(input.normalizedEmail)
                ]
            )

            guard let session = response.session else {
                throw AuthFlowError.emailConfirmationEnabled
            }

            self.currentDisplayName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
            self.apply(session: session)
            self.buddy = try await self.backend.getBuddy()
            await self.subscribeToBuddyUpdates()
        }
    }

    func signIn(_ input: AuthInput) async {
        await run(requiresAuth: false) {
            guard AppConfig.hasSupabaseConfig else {
                throw AppConfigurationError.missingSupabaseConfig
            }

            let session = try await self.supabase.auth.signIn(
                email: input.normalizedEmail,
                password: input.password
            )
            self.apply(session: session)
            self.buddy = try await self.backend.getBuddy()
            await self.subscribeToBuddyUpdates()
        }
    }

    func completeOnboarding(_ input: OnboardingInput) async {
        await run {
            self.buddy = try await self.backend.completeOnboarding(input)
            self.currentUsername = input.normalizedUsername
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

    func signOut() async {
        await run(requiresAuth: false) {
            try await self.supabase.auth.signOut()
            self.realtimeTask?.cancel()
            self.realtimeTask = nil
            self.accessToken = nil
            self.userId = nil
            self.buddy = nil
            self.linkToken = nil
            self.isPresentingPlaid = false
            self.isAuthenticated = false
            self.currentDisplayName = ""
            self.currentUsername = ""
            self.friends = []
            self.friendSearchResults = []
        }
    }

    func loadFriends() async {
        await run {
            self.friends = try await self.backend.getFriends()
        }
    }

    func searchFriends(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            friendSearchResults = []
            return
        }

        await run {
            self.friendSearchResults = try await self.backend.searchFriends(query: trimmed)
        }
    }

    func addFriend(username: String) async {
        await run {
            let friend = try await self.backend.addFriend(username: username.lowercased())
            if !self.friends.contains(where: { $0.userId == friend.userId }) {
                self.friends.insert(friend, at: 0)
            }
            self.friendSearchResults = self.friendSearchResults.map { result in
                guard result.username == friend.username else { return result }
                return FriendSearchResult(
                    userId: result.userId,
                    username: result.username,
                    displayName: result.displayName,
                    buddyName: result.buddyName,
                    mood: result.mood,
                    streak: result.streak,
                    isFriend: true
                )
            }
        }
    }

    private func run(requiresAuth: Bool = true, _ operation: @escaping () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if requiresAuth {
                try await restoreSession()
            }
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreSession() async throws {
        guard AppConfig.hasSupabaseConfig else {
            throw AppConfigurationError.missingSupabaseConfig
        }

        if accessToken != nil, userId != nil {
            return
        }

        do {
            let session = try await supabase.auth.session
            if session.user.isAnonymous {
                try await supabase.auth.signOut()
                isAuthenticated = false
                return
            }
            apply(session: session)
        } catch {
            isAuthenticated = false
        }
    }

    private func apply(session: Session) {
        accessToken = session.accessToken
        userId = session.user.id.uuidString
        currentDisplayName = session.user.userMetadata["name"]?.stringValue ?? currentDisplayName
        currentUsername = session.user.email?.components(separatedBy: "@").first
            ?? currentUsername
        isAuthenticated = true
    }

    private func saveWidgetSnapshot(for buddy: BuddyState) {
        BuddyWidgetSnapshotStore.save(
            buddy,
            catFillHue: catFillHue,
            catFillSaturation: catFillSaturation,
            catFillBrightness: catFillBrightness
        )
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
