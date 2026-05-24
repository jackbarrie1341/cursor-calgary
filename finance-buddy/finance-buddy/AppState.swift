import Combine
import Foundation
import Supabase

@MainActor
final class AppState: ObservableObject {
    @Published var buddy: BuddyState? {
        didSet {
            if let buddy {
                Task { @MainActor in
                    self.applyCatColor(from: buddy)
                    self.saveWidgetSnapshot(for: buddy)
                    self.applyHats(from: buddy)
                }
            } else {
                Task { @MainActor in
                    BuddyWidgetSnapshotStore.clear()
                    self.ownedHats = []
                    self.equippedHatId = nil
                    self.selectedHatId = nil
                }
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
    @Published var spending: SpendingResponse?
    @Published var ownedHats: [HatItem] = []
    @Published var equippedHatId: String?
    @Published var selectedHatId: String?
    @Published var devBudgetUtilOverridePercent: Double? = UserDefaults.standard.object(forKey: "dev_budget_util_override_percent") as? Double {
        didSet {
            if let devBudgetUtilOverridePercent {
                UserDefaults.standard.set(devBudgetUtilOverridePercent, forKey: "dev_budget_util_override_percent")
            } else {
                UserDefaults.standard.removeObject(forKey: "dev_budget_util_override_percent")
            }
        }
    }
    @Published var isPlantAlive: Bool = UserDefaults.standard.object(forKey: "room_plant_alive") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isPlantAlive, forKey: "room_plant_alive")
        }
    }
    @Published var isCouchAccentColor: Bool = UserDefaults.standard.object(forKey: "room_couch_accent_color") as? Bool ?? false {
        didSet {
            UserDefaults.standard.set(isCouchAccentColor, forKey: "room_couch_accent_color")
        }
    }
    @Published var financeCatVerdict: StoredBuddyVerdict? = FinanceCatVerdictStore.load()
    @Published var financeCatAgentStatus: FinanceCatAgentStatus = .idle
    /// The headline as it streams in token-by-token. Non-nil only while a
    /// verdict is actively being written.
    @Published var financeCatStreamingHeadline: String?
    @Published var catFillHue: Double = UserDefaults.standard.object(forKey: "cat_fill_hue") as? Double ?? 0.04 {
        didSet {
            UserDefaults.standard.set(catFillHue, forKey: "cat_fill_hue")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
            persistCatColorIfNeeded()
        }
    }
    @Published var catFillSaturation: Double = UserDefaults.standard.object(forKey: "cat_fill_saturation") as? Double ?? 0.48 {
        didSet {
            UserDefaults.standard.set(catFillSaturation, forKey: "cat_fill_saturation")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
            persistCatColorIfNeeded()
        }
    }
    @Published var catFillBrightness: Double = UserDefaults.standard.object(forKey: "cat_fill_brightness") as? Double ?? 1.0 {
        didSet {
            UserDefaults.standard.set(catFillBrightness, forKey: "cat_fill_brightness")
            if let buddy {
                saveWidgetSnapshot(for: buddy)
            }
            persistCatColorIfNeeded()
        }
    }

    private let supabase = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )

    private var accessToken: String?
    private var userId: String?
    private var realtimeTask: Task<Void, Never>?
    private var catColorPersistTask: Task<Void, Never>?
    private var financeCatTask: Task<Void, Never>?
    private var isApplyingRemoteCatColor = false

    var backend: BackendClient {
        BackendClient(baseURL: AppConfig.backendBaseURL, accessToken: accessToken)
    }

    func start() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await restoreSession(allowMissing: true)
            if isAuthenticated {
                buddy = try await withFreshSession {
                    try await self.backend.getBuddy()
                }
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
            self.spending = try await self.backend.getSpending()
            self.refreshFinanceCatVerdictIfPossible(force: true)
        }
    }

    func refreshBuddy() async {
        await run {
            self.buddy = try await self.backend.getBuddy()
            self.refreshFinanceCatVerdictIfPossible(force: false)
        }
    }

    func loadHats() async {
        do {
            try await restoreSession()
            let response = try await backend.getHats()
            applyHats(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectHatForPreview(id: String) {
        guard ownedHats.contains(where: { $0.id == id }) else { return }
        selectedHatId = id
    }

    func toggleEquipSelectedHat() async {
        let targetHatId = selectedHatId == equippedHatId ? nil : selectedHatId
        do {
            try await restoreSession()
            let response = try await backend.updateEquippedHat(hatId: targetHatId)
            applyHats(response)
        } catch {
            errorMessage = error.localizedDescription
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
            self.ownedHats = []
            self.equippedHatId = nil
            self.selectedHatId = nil
            self.spending = nil
            self.financeCatTask?.cancel()
            self.financeCatTask = nil
            self.financeCatVerdict = nil
            self.financeCatStreamingHeadline = nil
            self.financeCatAgentStatus = .idle
            FinanceCatVerdictStore.clear()
        }
    }

    func loadFriends() async {
        await run {
            self.friends = try await self.backend.getFriends()
        }
    }

    func loadSpending() async {
        await run {
            self.spending = try await self.backend.getSpending()
            self.refreshFinanceCatVerdictIfPossible(force: false)
        }
    }

    func prepareFinanceCatForHome() async {
        if spending == nil, buddy?.isLinked == true {
            await run {
                self.spending = try await self.backend.getSpending()
            }
        }

        guard let snapshot = FinanceCatSnapshot(buddy: buddy, spending: spending) else { return }

        if #available(iOS 26.0, *) {
            FinanceCatAgent().prewarm(snapshot: snapshot)
        } else {
            financeCatAgentStatus = .unavailable("Cat analysis requires iOS 26.")
            return
        }

        refreshFinanceCatVerdictIfPossible(force: false)
    }

    func retryFinanceCatVerdict() {
        refreshFinanceCatVerdictIfPossible(force: true)
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
                    catFillHue: result.catFillHue,
                    catFillSaturation: result.catFillSaturation,
                    catFillBrightness: result.catFillBrightness,
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
                try await withFreshSession(operation)
            } else {
                try await operation()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func withFreshSession<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        try await restoreSession()

        do {
            return try await operation()
        } catch BackendError.server(let statusCode, _) where statusCode == 401 {
            try await restoreSession(forceRefresh: true)
            return try await operation()
        }
    }

    private func refreshFinanceCatVerdictIfPossible(force: Bool) {
        guard let snapshot = FinanceCatSnapshot(buddy: buddy, spending: spending) else { return }

        guard #available(iOS 26.0, *) else {
            financeCatAgentStatus = .unavailable("Cat analysis requires iOS 26.")
            return
        }

        if !force,
           let financeCatVerdict,
           financeCatVerdict.isRecent,
           financeCatVerdict.sourceTransactionCount == snapshot.transactionCount {
            return
        }

        financeCatTask?.cancel()
        financeCatAgentStatus = .generating
        financeCatStreamingHeadline = nil

        financeCatTask = Task { [snapshot] in
            let agent = FinanceCatAgent()
            do {
                // Stream the verdict so the headline types out live, keeping the
                // last fully-formed snapshot to persist once the model finishes.
                var lastComplete: BuddyVerdict?
                for try await partial in agent.streamVerdict(snapshot: snapshot) {
                    guard !Task.isCancelled else { return }
                    if let headline = partial.headline, !headline.isEmpty {
                        self.financeCatStreamingHeadline = headline
                    }
                    if let complete = partial.completeVerdict {
                        lastComplete = complete
                    }
                }
                guard !Task.isCancelled else { return }

                // If streaming ended without every required field, fall back to a
                // one-shot generation so we never strand the user with a partial.
                let verdict: BuddyVerdict
                if let lastComplete {
                    verdict = lastComplete
                } else {
                    verdict = try await agent.generateVerdict(snapshot: snapshot)
                }
                self.commitFinanceCatVerdict(
                    verdict.withoutEmoji.refinedForHome(using: snapshot),
                    transactionCount: snapshot.transactionCount
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.financeCatStreamingHeadline = nil
                self.financeCatAgentStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func commitFinanceCatVerdict(_ verdict: BuddyVerdict, transactionCount: Int) {
        let storedVerdict = StoredBuddyVerdict(
            verdict: verdict,
            generatedAt: Date(),
            sourceTransactionCount: transactionCount,
            usedFoundationModels: true
        )
        FinanceCatVerdictStore.save(storedVerdict)
        financeCatVerdict = storedVerdict
        financeCatStreamingHeadline = nil
        financeCatAgentStatus = .idle
    }

    private func restoreSession(forceRefresh: Bool = false, allowMissing: Bool = false) async throws {
        guard AppConfig.hasSupabaseConfig else {
            throw AppConfigurationError.missingSupabaseConfig
        }

        do {
            let session: Session
            if forceRefresh {
                session = try await supabase.auth.refreshSession()
            } else {
                session = try await supabase.auth.session
            }
            if session.user.isAnonymous {
                try await supabase.auth.signOut()
                clearLocalAuthState()
                if allowMissing { return }
                throw AuthSessionError.missingSession
            }
            apply(session: session)
        } catch {
            clearLocalAuthState()
            if allowMissing {
                return
            }
            throw error
        }
    }

    private func clearLocalAuthState() {
        accessToken = nil
        userId = nil
        isAuthenticated = false
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

    private func applyCatColor(from buddy: BuddyState) {
        guard
            let hue = buddy.catFillHue,
            let saturation = buddy.catFillSaturation,
            let brightness = buddy.catFillBrightness
        else { return }

        isApplyingRemoteCatColor = true
        catFillHue = hue
        catFillSaturation = saturation
        catFillBrightness = brightness
        isApplyingRemoteCatColor = false
    }

    private func persistCatColorIfNeeded() {
        guard !isApplyingRemoteCatColor, accessToken != nil, buddy != nil else { return }

        let hue = catFillHue
        let saturation = catFillSaturation
        let brightness = catFillBrightness
        catColorPersistTask?.cancel()
        catColorPersistTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
                try await backend.updateCatColor(hue: hue, saturation: saturation, brightness: brightness)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
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

    private func applyHats(from buddy: BuddyState) {
        applyHats(HatsResponse(ownedHats: buddy.ownedHats, equippedHatId: buddy.equippedHatId))
    }

    private func applyHats(_ response: HatsResponse) {
        ownedHats = response.ownedHats
        equippedHatId = response.equippedHatId

        if
            let selectedHatId,
            !response.ownedHats.contains(where: { $0.id == selectedHatId })
        {
            self.selectedHatId = response.equippedHatId
            return
        }

        if self.selectedHatId == nil {
            self.selectedHatId = response.equippedHatId ?? response.ownedHats.first?.id
        }
    }
}
