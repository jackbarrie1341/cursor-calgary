import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSettings = false

    private let openingAnimationLastFrame = "3_Thought"

    private var buddy: BuddyState {
        appState.buddy ?? BuddyState(
            mood: .happy,
            spentTodayCents: 0,
            spentWeekCents: 0,
            spentMonthCents: 0,
            dailyAllowanceCents: 0,
            streak: 0,
            asOfDate: "",
            buddyName: "Buddy",
            catFillHue: nil,
            catFillSaturation: nil,
            catFillBrightness: nil,
            isLinked: false,
            hasOnboarded: true,
            ownedHats: [],
            equippedHatId: nil
        )
    }

    var body: some View {
        ZStack {
            homeBackgroundColor
                .ignoresSafeArea()

            ScrollView {
                ZStack(alignment: .top) {
                    GeometryReader { proxy in
                        VStack(spacing: 0) {
                            homeBackgroundColor
                                .frame(height: proxy.size.height * 0.55)
                            buddyTextPanelColor
                                .frame(height: proxy.size.height * 0.45)
                        }
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("pawket change")
                            .font(DoodleFont.homeLargeTitle)
                            .doodleTracking(1.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 20)
                            .padding(.bottom, 225)

                        buddyCard
                            .padding(.bottom, 70)

                        spendCard
                            .padding(.bottom, 20)

                        controls
                    }
                    .padding()

                    if appState.didCompleteInitialBoot {
                        if appState.openingAnimationFinished {
                            Image(openingAnimationLastFrame)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .offset(x: 0, y: -200)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)
                        } else {
                            OpeningAnimationView {
                                appState.openingAnimationFinished = true
                            }
                        }
                    }

                    purchaseReactionOverlay
                }
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                isShowingSettings = true
            } label: {
                Image("settings")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .frame(width: 44, height: 44)
                    .background(homeBackgroundColor, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .padding(.trailing, 16)
            .padding(.top, 4)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if oldPhase == .background && newPhase == .active {
                appState.openingAnimationFinished = false
            }
        }
        .task {
            await appState.prepareFinanceCatForHome()
        }
    }

    private var buddyCard: some View {
        VStack(spacing: 16) {
            buddyHeroScene

            Color.clear
                .frame(height: 0)
                .overlay { financeCatBubble }

            VStack(spacing: 8) {
                Text(buddy.buddyName)
                    .font(DoodleFont.largeTitle)
                    .doodleTracking(-1.2)

                Text(effectiveMood.title)
                    .font(DoodleFont.title3)
                    .doodleTracking(-0.8)
                    .foregroundStyle(moodColor)

                HStack(spacing: 10) {
                    Image(systemName: "flame")
                    Text("\(buddy.streak) day streak")
                }
                .font(DoodleFont.headline)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private var buddyHeroScene: some View {
        ZStack(alignment: .bottom) {
            roomBackgroundDecor

            BuddyImageView(
                mood: effectiveMood,
                overrideAssetName: nil,
                fallbackSymbolName: effectiveMood.symbolName,
                fallbackColor: moodColor,
                hatAssetKey: equippedHat?.assetKey,
                hatSymbolName: equippedHat?.symbolName,
                fillColor: catFillColor
            )
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 245)
        .frame(maxWidth: .infinity)

    }

    @ViewBuilder
    private var purchaseReactionOverlay: some View {
        if let cents = appState.pendingPurchaseAmountCents {
            let frames = cents > 0
                ? PurchaseReactionOverlayView.sadFrames
                : PurchaseReactionOverlayView.happyFrames
            PurchaseReactionOverlayView(frameAssetNames: frames)
                .frame(width: 300, height: 300)
                .offset(x: -10, y: -70)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 20), value: appState.pendingPurchaseAmountCents)
        }
    }

    private var roomBackgroundDecor: some View {
        ZStack(alignment: .bottom) {
//            Image("Text_bubble")
//                .resizable()
//                .interpolation(.none)
//                .scaledToFit()
//                .frame(width: 400, height: 270)
//                .offset(x: 0, y: -400)
            
            
            
            Image("Wave")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 400, height: 270)
                .offset(x: 0, y: 120)
            
            Image("Rug")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 400, height: 245)
                .offset(x: 0, y: -6)
                .clipped()
            
            Image("Plant_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(clayPotColor)
                .scaledToFit()
                .frame(width: 235, height: 235)
                .offset(x: -132, y: -35)

            Image(plantLineAssetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 300, height: 300)
                .offset(x: -132, y: 6)

            Image("Yarn_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(yarnRedColor)
                .scaledToFit()
                .frame(width: 300, height: 300)
                .offset(x: -105, y: 80)

            Image("Yarn")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 300, height: 300)
                .offset(x: -105, y: 80)

            Image("Couch_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(couchFillColor)
                .scaledToFit()
                .frame(width: 270, height: 270)
                .offset(x: 160, y: 0)

            Image("Couch")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 270, height: 270)
                .offset(x: 160, y: 0)
            
        }
    }

    @ViewBuilder
    private var financeCatBubble: some View {
        if appState.openingAnimationFinished {
            Group {
                if let streaming = appState.financeCatStreamingHeadline, !streaming.isEmpty {
                    Text("\"\(streaming)\"")
                        .foregroundStyle(.black)
                } else if let storedVerdict = appState.financeCatVerdict {
                    Text("\"\(storedVerdict.verdict.headline)\"")
                        .foregroundStyle(.black)
                } else if appState.financeCatAgentStatus == .generating {
                    Text("Your cat is reading the receipts...")
                        .foregroundStyle(.black)
                } else {
                    TypewriterText("I don't have any thoughts right now")
                        .foregroundStyle(.black)
                }
            }
            .font(DoodleFont.headline)
            .doodleTracking(-0.7)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .offset(y: -400)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: appState.financeCatStreamingHeadline)
        }
    }

    private var spendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today", systemImage: "calendar")
                Spacer()

                HStack(spacing: 10) {
                    Text(buddy.asOfDate)
                        .foregroundStyle(.secondary)

                    refreshTransactionsButton(size: 34, iconSize: 14)
                }
            }
            .font(DoodleFont.subheadline)

            HStack(alignment: .firstTextBaseline) {
                Text(money(buddy.spentTodayCents))
                    .font(DoodleFont.largeTitle)
                    .doodleTracking(-1.2)
                Text("of \(money(buddy.dailyAllowanceCents))")
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(moodColor)

            HStack(spacing: 10) {
                spendMetric(title: "Today", cents: buddy.spentTodayCents)
                spendMetric(title: "Week", cents: buddy.spentWeekCents)
                spendMetric(title: "Month", cents: buddy.spentMonthCents)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(buddyTextPanelColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private func spendMetric(title: String, cents: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DoodleFont.caption)
                .foregroundStyle(.secondary)
            Text(money(cents))
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(buddyTextPanelInnerColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if !buddy.isLinked {
                Button {
                    Task {
                        await appState.connectBank()
                    }
                } label: {
                    Label("Connect Plaid Sandbox", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .font(DoodleFont.headline)
            }
        }
    }

    private func refreshTransactionsButton(size: CGFloat, iconSize: CGFloat) -> some View {
        Button {
            Task {
                await appState.refreshTransactions()
            }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(refreshButtonColor, in: Circle())
                .shadow(color: refreshButtonColor.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!buddy.isLinked)
        .opacity(buddy.isLinked ? 1.0 : 0.45)
        .accessibilityLabel("Refresh Transactions")
        .accessibilityHint("Fetches latest transactions from your linked bank")
    }

    private var progress: Double {
        guard buddy.dailyAllowanceCents > 0 else { return 0 }
        return min(Double(buddy.spentTodayCents) / Double(buddy.dailyAllowanceCents), 1.0)
    }

    private var displayedMood: BuddyMood {
        appState.displayMood(for: buddy)
    }

    private var moodColor: Color {
        displayedMood.color
    }

    private var effectiveMood: BuddyMood {
        displayedMood
    }

    private var catFillColor: Color {
        Color(
            hue: appState.catFillHue,
            saturation: appState.catFillSaturation,
            brightness: appState.catFillBrightness
        )
    }

    private var homeBackgroundColor: Color {
        Color("HomeSceneDominant")
    }

    private var clayPotColor: Color {
        Color(red: 0.76, green: 0.42, blue: 0.30)
    }

    private var yarnRedColor: Color {
        Color(red: 0.78, green: 0.22, blue: 0.24)
    }

    private var buddyTextPanelColor: Color {
        Color(red: 0.773, green: 0.733, blue: 0.965)
    }

    private var buddyTextPanelInnerColor: Color {
        Color(red: 0.86, green: 0.83, blue: 0.98)
    }

    private var refreshButtonColor: Color {
        Color(red: 0.23, green: 0.45, blue: 0.63)
    }

    private var couchFillColor: Color {
        appState.isCouchAccentColor
            ? Color(red: 0.95, green: 0.62, blue: 0.66)
            : Color(red: 0.55, green: 0.70, blue: 0.86)
    }

    private var plantLineAssetName: String {
        appState.isPlantAlive ? "Plant_Healthy" : "Plant_Dead"
    }

    private var equippedHat: HatItem? {
        guard let equippedHatId = appState.equippedHatId else { return nil }
        return appState.ownedHats.first(where: { $0.id == equippedHatId })
    }

    private func money(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var budgetUtilOverrideInput = ""
    @State private var budgetUtilOverrideError: String?
    @State private var simulatePurchaseInput = "5.00"

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !appState.currentDisplayName.isEmpty {
                        LabeledContent("Name", value: appState.currentDisplayName)
                    }
                    if !appState.currentUsername.isEmpty {
                        LabeledContent("Account", value: appState.currentUsername)
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Cat color")
                            Spacer()
                            Circle()
                                .fill(catFillColor)
                                .frame(width: 28, height: 28)
                                .overlay(Circle().stroke(.secondary.opacity(0.35), lineWidth: 1))
                        }

                        VStack(spacing: 10) {
                            colorSlider("Hue", value: $appState.catFillHue)
                            colorSlider("Saturation", value: $appState.catFillSaturation)
                            colorSlider("Brightness", value: $appState.catFillBrightness)
                        }

                        Button {
                            randomizeCatColor()
                        } label: {
                            Label("Randomize", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        BuddyImageView(
                            mood: effectiveMood,
                            overrideAssetName: nil,
                            fallbackSymbolName: effectiveMood.symbolName,
                            fallbackColor: moodColor,
                            hatAssetKey: selectedHat?.assetKey,
                            hatSymbolName: selectedHat?.symbolName,
                            fillColor: catFillColor,
                            size: 96
                        )
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Buddy color")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Plant alive", isOn: $appState.isPlantAlive)
                        Toggle("Accent couch color", isOn: $appState.isCouchAccentColor)

                        HStack(spacing: 10) {
                            Text("Couch fill")
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(couchFillColor)
                                .frame(width: 32, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(.secondary.opacity(0.35), lineWidth: 1)
                                )
                            Text(appState.isPlantAlive ? "Plant: Healthy" : "Plant: Dead")
                                .font(DoodleFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Room placeholder")
                }

                Section {
                    Toggle("Lobby music", isOn: $appState.isLobbyMusicEnabled)
                } header: {
                    Text("Audio")
                }

                Section {
                    Toggle("Show buddy in Dynamic Island", isOn: $appState.isBuddyLiveActivityEnabled)
                } header: {
                    Text("Dynamic Island")
                } footer: {
                    Text("Shows the current budget-based buddy status when Live Activities are available.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Preview hat", selection: hatSelectionBinding) {
                            Text("None").tag(Optional<String>.none)
                            ForEach(appState.ownedHats) { hat in
                                Text(hat.name).tag(Optional(hat.id))
                            }
                        }

                        Button {
                            Task {
                                await appState.toggleEquipSelectedHat()
                            }
                        } label: {
                            Text(isSelectedHatEquipped ? "Unequip selected hat" : "Equip selected hat")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.selectedHatId == nil)
                    }
                } header: {
                    Text("Hats")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Budget usage % (e.g. 72.5)", text: $budgetUtilOverrideInput)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack(spacing: 8) {
                            Button("Apply override") {
                                applyBudgetUtilOverride()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Clear override") {
                                appState.devBudgetUtilOverridePercent = nil
                                budgetUtilOverrideInput = ""
                                budgetUtilOverrideError = nil
                            }
                            .buttonStyle(.bordered)
                            .disabled(appState.devBudgetUtilOverridePercent == nil)
                        }

                        if let overridePercent = appState.devBudgetUtilOverridePercent {
                            Text("Active override: \(overridePercent.formatted(.number.precision(.fractionLength(0...2))))% (\(effectiveMood.title))")
                                .font(DoodleFont.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let budgetUtilOverrideError {
                            Text(budgetUtilOverrideError)
                                .font(DoodleFont.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        appState.retryFinanceCatVerdict()
                    } label: {
                        Label("Retry cat analysis", systemImage: "sparkles")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Simulate purchase")
                            .font(DoodleFont.caption)
                            .foregroundStyle(.secondary)

                        TextField("Amount ($)", text: $simulatePurchaseInput)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack(spacing: 8) {
                            Button {
                                applySimulatedPurchase(sign: 1)
                            } label: {
                                Label("Spend", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)

                            Button {
                                applySimulatedPurchase(sign: -1)
                            } label: {
                                Label("Refund", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                } header: {
                    Text("Developer")
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        Task {
                            await appState.signOut()
                        }
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .font(DoodleFont.body)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            await appState.loadHats()
            syncBudgetUtilOverrideInputFromState()
        }
    }

    private var catFillColor: Color {
        Color(
            hue: appState.catFillHue,
            saturation: appState.catFillSaturation,
            brightness: appState.catFillBrightness
        )
    }

    private var couchFillColor: Color {
        appState.isCouchAccentColor
            ? Color(red: 0.95, green: 0.62, blue: 0.66)
            : Color(red: 0.55, green: 0.70, blue: 0.86)
    }

    private var effectiveMood: BuddyMood {
        guard let buddy = appState.buddy else { return .happy }
        return appState.displayMood(for: buddy)
    }

    private var moodColor: Color {
        effectiveMood.color
    }

    private var hatSelectionBinding: Binding<String?> {
        Binding(
            get: { appState.selectedHatId },
            set: { newValue in
                guard let newValue else {
                    appState.selectedHatId = nil
                    return
                }
                appState.selectHatForPreview(id: newValue)
            }
        )
    }

    private var isSelectedHatEquipped: Bool {
        appState.selectedHatId != nil && appState.selectedHatId == appState.equippedHatId
    }

    private var selectedHat: HatItem? {
        guard let selectedHatId = appState.selectedHatId else { return nil }
        return appState.ownedHats.first(where: { $0.id == selectedHatId })
    }

    private func randomizeCatColor() {
        appState.catFillHue = Double.random(in: 0...1)
        appState.catFillSaturation = Double.random(in: 0.32...0.72)
        appState.catFillBrightness = Double.random(in: 0.72...1.0)
    }

    private func syncBudgetUtilOverrideInputFromState() {
        if let overridePercent = appState.devBudgetUtilOverridePercent {
            budgetUtilOverrideInput = overridePercent.formatted(.number.precision(.fractionLength(0...2)))
        } else {
            budgetUtilOverrideInput = ""
        }
    }

    private func applyBudgetUtilOverride() {
        let normalized = budgetUtilOverrideInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else {
            budgetUtilOverrideError = "Enter a budget utilization percentage first."
            return
        }
        guard let value = Double(normalized), value >= 0 else {
            budgetUtilOverrideError = "Please enter a valid non-negative number."
            return
        }
        appState.devBudgetUtilOverridePercent = value
        budgetUtilOverrideError = nil
    }

    private func applySimulatedPurchase(sign: Int) {
        let normalized = simulatePurchaseInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let dollars = Double(normalized), dollars > 0 else { return }
        let cents = Int((dollars * 100).rounded()) * sign
        appState.simulatePurchase(amountCents: cents)
    }

    private func colorSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }
}
