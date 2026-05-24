import Charts
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

                categoryBreakdownCard
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

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Month by category")
                    .font(DoodleFont.title2)
                    .doodleTracking(-0.9)

                Spacer()

                Text(money(spending?.monthTotalCents ?? 0))
                    .font(DoodleFont.headline)
                    .doodleTracking(-0.7)
                    .foregroundStyle(.secondary)
            }

            if categoryEntries.isEmpty {
                emptyText("No categorized spending this month.")
            } else {
                HStack(spacing: 16) {
                    ZStack {
                        Chart(categoryEntries) { entry in
                            SectorMark(
                                angle: .value("Spending", entry.totalCents),
                                innerRadius: .ratio(0.62),
                                angularInset: 1.4
                            )
                            .cornerRadius(4)
                            .foregroundStyle(entry.color)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 142, height: 142)

                        VStack(spacing: 0) {
                            Text("\(categoryEntries.count)")
                                .font(DoodleFont.title2)
                                .doodleTracking(-0.9)
                            Text("groups")
                                .font(DoodleFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 9) {
                        ForEach(categoryEntries.prefix(5)) { entry in
                            categoryLegendRow(entry)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    if let categoryName = transaction.categoryDisplayName {
                        Text(categoryName)
                            .foregroundStyle(transaction.categoryColor)
                    }
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

    private func categoryLegendRow(_ entry: CategoryEntry) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(entry.color)
                .frame(width: 10, height: 10)

            Text(entry.title)
                .font(DoodleFont.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 6)

            Text(money(entry.totalCents))
                .font(DoodleFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var categoryEntries: [CategoryEntry] {
        guard let spending else { return [] }
        let known = spending.categoryBreakdown
            .filter { $0.totalCents > 0 }
            .sorted { $0.totalCents > $1.totalCents }

        let top = known.prefix(6)
        let remaining = known.dropFirst(6)
        var entries = top.map {
            CategoryEntry(
                category: $0.category,
                totalCents: $0.totalCents,
                count: $0.count
            )
        }

        let otherTotal = remaining.reduce(0) { $0 + $1.totalCents }
        let otherCount = remaining.reduce(0) { $0 + $1.count }
        if otherTotal > 0 {
            entries.append(CategoryEntry(category: "OTHER", totalCents: otherTotal, count: otherCount))
        }
        return entries
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

private struct CategoryEntry: Identifiable {
    let category: String
    let totalCents: Int
    let count: Int

    var id: String { category }

    var title: String {
        category.readableCategoryName
    }

    var color: Color {
        category.categoryColor
    }
}

private extension SpendingTransaction {
    var categoryDisplayName: String? {
        guard let categoryPrimary, !categoryPrimary.isEmpty else { return nil }
        return categoryPrimary.readableCategoryName
    }

    var categoryColor: Color {
        (categoryPrimary ?? "UNCATEGORIZED").categoryColor
    }
}

private extension String {
    var readableCategoryName: String {
        lowercased()
            .split(separator: "_")
            .map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    var categoryColor: Color {
        switch uppercased() {
        case "FOOD_AND_DRINK": return Color(red: 0.94, green: 0.42, blue: 0.33)
        case "TRANSPORTATION": return Color(red: 0.23, green: 0.56, blue: 0.94)
        case "GENERAL_MERCHANDISE": return Color(red: 0.60, green: 0.38, blue: 0.86)
        case "ENTERTAINMENT": return Color(red: 0.93, green: 0.56, blue: 0.18)
        case "RENT_AND_UTILITIES": return Color(red: 0.22, green: 0.68, blue: 0.56)
        case "TRANSFER_IN", "TRANSFER_OUT": return Color(red: 0.47, green: 0.53, blue: 0.62)
        case "LOAN_PAYMENTS", "BANK_FEES": return Color(red: 0.84, green: 0.31, blue: 0.42)
        case "MEDICAL": return Color(red: 0.19, green: 0.64, blue: 0.78)
        case "PERSONAL_CARE": return Color(red: 0.92, green: 0.39, blue: 0.66)
        case "TRAVEL": return Color(red: 0.36, green: 0.69, blue: 0.28)
        case "INCOME": return Color(red: 0.20, green: 0.70, blue: 0.38)
        case "OTHER", "UNCATEGORIZED": return Color(red: 0.56, green: 0.58, blue: 0.64)
        default: return Color(red: 0.40, green: 0.46, blue: 0.85)
        }
    }
}
