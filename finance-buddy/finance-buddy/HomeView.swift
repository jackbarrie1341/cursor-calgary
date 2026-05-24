import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingSettings = false

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
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        Text("Finance Buddy")
                            .font(DoodleFont.largeTitle)
                            .doodleTracking(-1.2)

                        Spacer()

                        Button {
                            isShowingSettings = true
                        } label: {
                            Image("settings")
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .frame(width: 44, height: 44)
                                .background(Color(.systemBackground), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    buddyCard
                    spendCard
                    controls
                }
                .padding()
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .task {
            await appState.prepareFinanceCatForHome()
        }
    }

    private var buddyCard: some View {
        VStack(spacing: 16) {
            buddyHeroScene

            VStack(spacing: 6) {
                Text(buddy.buddyName)
                    .font(DoodleFont.largeTitle)
                    .doodleTracking(-1.2)

                Text(effectiveMood.title)
                    .font(DoodleFont.title3)
                    .doodleTracking(-0.8)
                    .foregroundStyle(moodColor)
            }

            financeCatBubble

            HStack(spacing: 10) {
                Image(systemName: "flame")
                Text("\(buddy.streak) day streak")
            }
            .font(DoodleFont.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.systemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
    }

    private var buddyHeroScene: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [homeBackgroundColor.opacity(0.86), homeBackgroundColor.opacity(0.64)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)

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
    }

    private var roomBackgroundDecor: some View {
        ZStack(alignment: .bottom) {
            Image("Plant_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(Color.green.opacity(0.35))
                .scaledToFit()
                .frame(width: 74, height: 74)
                .offset(x: -104, y: 6)

            Image(plantLineAssetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 74, height: 74)
                .offset(x: -104, y: 6)

            Image("Couch_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(couchFillColor)
                .scaledToFit()
                .frame(width: 214, height: 118)
                .offset(x: 14, y: 14)

            Image("Couch")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 214, height: 118)
                .offset(x: 14, y: 14)
        }
    }

    @ViewBuilder
    private var financeCatBubble: some View {
        if let streaming = appState.financeCatStreamingHeadline, !streaming.isEmpty {
            catBubble {
                Text("\"\(streaming)\"")
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let storedVerdict = appState.financeCatVerdict {
            catBubble {
                Text("\"\(storedVerdict.verdict.headline)\"")
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if appState.financeCatAgentStatus == .generating {
            catBubble {
                Label("Your cat is reading the receipts...", systemImage: "sparkles")
                    .font(DoodleFont.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if let message = appState.financeCatAgentStatus.message {
            catBubble {
                Text(message)
                    .font(DoodleFont.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func catBubble<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .top) {
                Triangle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 18, height: 10)
                    .offset(y: -9)
            }
            .animation(.easeInOut(duration: 0.15), value: appState.financeCatStreamingHeadline)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
        if let overridePercent = appState.devBudgetUtilOverridePercent {
            return .forBudgetUsageRatio(overridePercent / 100)
        }
        return appState.financeCatVerdict?.verdict.mood.buddyMood ?? buddy.mood
    }

    private var moodColor: Color {
        switch displayedMood {
        case .happy: .green
        case .nervous: .yellow
        case .hungry: .orange
        case .sick: .red
        }
    }

    private var effectiveMood: BuddyMood {
        displayedMood
    }

    private var catFillColor: Color {
        Color(hue: appState.catFillHue, saturation: 0.48, brightness: 1.0)
    }

    private var homeBackgroundColor: Color {
        Color("HomeSceneDominant")
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
                            colorSlider("Darkness", value: darknessBinding)
                        }

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
        if let overridePercent = appState.devBudgetUtilOverridePercent {
            return .forBudgetUsageRatio(overridePercent / 100)
        }
        return appState.buddy?.mood ?? .happy
    }

    private var moodColor: Color {
        switch effectiveMood {
        case .happy: .green
        case .nervous: .yellow
        case .hungry: .orange
        case .sick: .red
        }
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

    private var darknessBinding: Binding<Double> {
        Binding(
            get: { 1 - appState.catFillBrightness },
            set: { appState.catFillBrightness = 1 - $0 }
        )
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

    private func colorSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }
}
