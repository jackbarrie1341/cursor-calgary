import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState

    private var buddy: BuddyState {
        appState.buddy ?? BuddyState(
            mood: .happy,
            spentTodayCents: 0,
            dailyAllowanceCents: 0,
            streak: 0,
            asOfDate: "",
            buddyName: "Buddy",
            isLinked: false,
            hasOnboarded: true
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                buddyCard
                spendCard
                controls
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var buddyCard: some View {
        VStack(spacing: 16) {
            Image(systemName: buddy.mood.symbolName)
                .font(.system(size: 82, weight: .semibold))
                .frame(width: 150, height: 150)
                .foregroundStyle(moodColor)
                .background(moodColor.opacity(0.14), in: Circle())

            VStack(spacing: 6) {
                Text(buddy.buddyName)
                    .font(.largeTitle.bold())

                Text(buddy.mood.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(moodColor)
            }

            HStack(spacing: 10) {
                Image(systemName: "flame")
                Text("\(buddy.streak) day streak")
            }
            .font(.headline)
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
            .font(.subheadline)

            HStack(alignment: .firstTextBaseline) {
                Text(money(buddy.spentTodayCents))
                    .font(.system(size: 34, weight: .bold))
                Text("of \(money(buddy.dailyAllowanceCents))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(moodColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
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

    private func money(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
