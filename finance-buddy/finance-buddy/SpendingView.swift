import SwiftUI

struct SpendingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isShowingOlderTransactions = false

    private var spending: SpendingResponse? {
        appState.spending
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spending")
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                    Text("Recent purchases and this month’s biggest bites.")
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                }

                if appState.financeCatVerdict != nil {
                    catsReadCard
                }

                todaysSpendingCard
                monthTransactionsCard
                olderTransactionsCard
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await appState.loadSpending()
        }
        .refreshable {
            await appState.loadSpending()
        }
    }

    private var catsReadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cat's read", systemImage: "sparkles")
                    .font(DoodleFont.title3)
                    .doodleTracking(-0.8)
            }

            if let verdict = appState.financeCatVerdict?.verdict {
                Text("\"\(verdict.headline)\"")
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if let biggestCulprit = verdict.biggestCulprit, !biggestCulprit.isEmpty {
                        readMetric(title: "Culprit", value: biggestCulprit)
                    }

                    if let projectedMonthEndCents = verdict.projectedMonthEndCents {
                        readMetric(title: "Projected", value: money(projectedMonthEndCents))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var todaysSpendingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(DoodleFont.title2)
                    .doodleTracking(-0.9)
                Spacer()
                Text(spending?.asOfDate ?? "")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            }

            Text(money(total(for: todaysTransactions)))
                .font(DoodleFont.largeTitle)
                .doodleTracking(-1.2)

            if todaysTransactions.isEmpty {
                emptyText("No spending logged today.")
            } else {
                transactionList(todaysTransactions)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var monthTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Rest of this month")
                    .font(DoodleFont.title2)
                    .doodleTracking(-0.9)
                Spacer()
                Text(money(total(for: restOfMonthTransactions)))
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .foregroundStyle(.secondary)
            }

            if restOfMonthTransactions.isEmpty {
                emptyText("No other transactions this month.")
            } else {
                transactionList(restOfMonthTransactions)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var olderTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            DisclosureGroup(isExpanded: $isShowingOlderTransactions) {
                if olderTransactions.isEmpty {
                    emptyText("No older transactions synced yet.")
                } else {
                    transactionList(olderTransactions)
                        .padding(.top, 8)
                }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("Earlier transactions")
                        .font(DoodleFont.title2)
                        .doodleTracking(-0.9)
                    Spacer()
                    Text("\(olderTransactions.count)")
                        .font(DoodleFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func transactionList(_ transactions: [SpendingTransaction]) -> some View {
        VStack(spacing: 10) {
            ForEach(transactions) { transaction in
                transactionRow(transaction)
            }
        }
    }

    private func transactionRow(_ transaction: SpendingTransaction) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.name)
                    .font(DoodleFont.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 6) {
                    Text(transaction.date ?? "unknown date")
                    if transaction.pending {
                        Text("pending")
                    }
                }
                .font(DoodleFont.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(money(transaction.amountCents))
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
        }
        .padding(.vertical, 8)
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(DoodleFont.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func readMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DoodleFont.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var todaysTransactions: [SpendingTransaction] {
        guard let spending else { return [] }
        return spending.transactions.filter { $0.date == spending.asOfDate }
    }

    private var restOfMonthTransactions: [SpendingTransaction] {
        guard let spending else { return [] }
        return spending.transactions.filter { transaction in
            guard let date = transaction.date else { return false }
            return date >= spending.monthStartDate && date < spending.asOfDate
        }
    }

    private var olderTransactions: [SpendingTransaction] {
        guard let spending else { return [] }
        return spending.transactions.filter { transaction in
            guard let date = transaction.date else { return true }
            return date < spending.monthStartDate || date > spending.asOfDate
        }
    }

    private func total(for transactions: [SpendingTransaction]) -> Int {
        transactions.reduce(0) { $0 + $1.amountCents }
    }

    private func money(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
