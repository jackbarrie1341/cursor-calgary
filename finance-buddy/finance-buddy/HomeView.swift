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
            hasOnboarded: true
        )
    }

    var body: some View {
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
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(appState)
        }
    }

    private var buddyCard: some View {
        VStack(spacing: 16) {
            BuddyImageView(
                mood: buddy.mood,
                overrideAssetName: appState.debugBuddyAssetName,
                fallbackSymbolName: buddy.mood.symbolName,
                fallbackColor: moodColor,
                fillColor: catFillColor
            )

            VStack(spacing: 6) {
                Text(buddy.buddyName)
                    .font(DoodleFont.largeTitle)
                    .doodleTracking(-1.2)

                Text(buddy.mood.title)
                    .font(DoodleFont.title3)
                    .doodleTracking(-0.8)
                    .foregroundStyle(moodColor)
            }

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
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var spendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today", systemImage: "calendar")
                Spacer()
                Text(buddy.asOfDate)
                    .foregroundStyle(.secondary)
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

            Button {
                Task {
                    await appState.refreshTransactions()
                }
            } label: {
                Label("Refresh Transactions", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .font(DoodleFont.headline)
            .disabled(!buddy.isLinked)
        }
    }

    private var progress: Double {
        guard buddy.dailyAllowanceCents > 0 else { return 0 }
        return min(Double(buddy.spentTodayCents) / Double(buddy.dailyAllowanceCents), 1.2)
    }

    private var moodColor: Color {
        switch buddy.mood {
        case .happy: .green
        case .nervous: .yellow
        case .hungry: .orange
        case .sick: .red
        }
    }

    private var catFillColor: Color {
        Color(hue: appState.catFillHue, saturation: 0.48, brightness: 1.0)
    }

    private func money(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

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
                            mood: .happy,
                            overrideAssetName: "Cat_Cheesing",
                            fallbackSymbolName: BuddyMood.happy.symbolName,
                            fallbackColor: .green,
                            fillColor: catFillColor,
                            size: 96
                        )
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Buddy color")
                }

                Section {
                    Picker("Test buddy", selection: $appState.debugBuddyAssetName) {
                        Text("Mood default").tag(Optional<String>.none)
                        ForEach(debugBuddyAssets, id: \.self) { assetName in
                            Text(assetName.replacingOccurrences(of: "Cat_", with: "").replacingOccurrences(of: "_", with: " "))
                                .tag(Optional(assetName))
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
    }

    private var debugBuddyAssets: [String] {
        [
            "Cat_Broke",
            "Cat_Cheesing",
            "Cat_Cheesing_Blink",
            "Cat_Money_Spread",
            "Cat_Tear_Pool",
            "Cat_Worried"
        ]
    }

    private var catFillColor: Color {
        Color(
            hue: appState.catFillHue,
            saturation: appState.catFillSaturation,
            brightness: appState.catFillBrightness
        )
    }

    private var darknessBinding: Binding<Double> {
        Binding(
            get: { 1 - appState.catFillBrightness },
            set: { appState.catFillBrightness = 1 - $0 }
        )
    }

    private func colorSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: 0...1)
        }
    }
}
