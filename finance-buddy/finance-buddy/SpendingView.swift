import SwiftUI

struct SpendingView: View {
    @EnvironmentObject private var appState: AppState

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

                monthCard
                transactionsCard
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

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This month")
                    .font(DoodleFont.title2)
                    .doodleTracking(-0.9)
                Spacer()
                Text(spending?.asOfDate ?? "")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            }

            Text(money(spending?.monthTotalCents ?? 0))
                .font(DoodleFont.largeTitle)
                .doodleTracking(-1.2)

            if let breakdown = spending?.monthlyBreakdown, !breakdown.isEmpty {
                VStack(spacing: 10) {
                    ForEach(breakdown) { item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(DoodleFont.headline)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Text("\(item.count) purchases · last \(item.lastDate ?? "unknown")")
                                    .font(DoodleFont.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(money(item.totalCents))
                                .font(DoodleFont.headline)
                                .doodleTracking(-0.7)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                emptyText("No spending this month yet.")
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("History")
                .font(DoodleFont.title2)
                .doodleTracking(-0.9)

            if let transactions = spending?.transactions, !transactions.isEmpty {
                VStack(spacing: 10) {
                    ForEach(transactions) { transaction in
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
                }
            } else {
                emptyText("No transactions synced yet.")
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(DoodleFont.body)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func money(_ cents: Int) -> String {
        let value = Decimal(cents) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}
