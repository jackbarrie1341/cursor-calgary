import Foundation

/// Deterministic, on-device spending analytics.
///
/// The language model decides *which* of these to call and how to phrase the
/// result, but every number is computed here in Swift. Small language models
/// are unreliable at arithmetic, so projections, averages, and outlier scores
/// must never be left to the model to "guess".
///
/// Marked `nonisolated` because it is pure and stateless: the on-device model's
/// tools call it from a non-main-actor context, and there is no shared state to
/// protect.
nonisolated enum FinanceCatAnalytics {

    // MARK: - Recurring / repeat merchants

    struct RecurringCharge: Equatable, Sendable {
        let merchant: String
        let occurrences: Int
        let totalCents: Int
        let typicalCents: Int
    }

    /// Groups transactions by a normalized merchant key and returns merchants
    /// hit more than once this period, sorted by total spend. This is how the
    /// cat catches "death by a thousand coffees" — repeated small charges that
    /// never look alarming on their own.
    static func recurringCharges(
        in transactions: [FinanceCatSnapshot.Transaction],
        minOccurrences: Int = 2
    ) -> [RecurringCharge] {
        var groups: [String: [FinanceCatSnapshot.Transaction]] = [:]
        for transaction in transactions where transaction.amountCents > 0 {
            groups[normalizedMerchant(transaction.name), default: []].append(transaction)
        }

        return groups.values
            .filter { $0.count >= minOccurrences }
            .map { matches in
                let total = matches.reduce(0) { $0 + $1.amountCents }
                return RecurringCharge(
                    merchant: displayName(for: matches),
                    occurrences: matches.count,
                    totalCents: total,
                    typicalCents: total / matches.count
                )
            }
            .sorted { $0.totalCents > $1.totalCents }
    }

    // MARK: - Anomaly detection (z-score)

    struct Anomaly: Equatable, Sendable {
        let name: String
        let amountCents: Int
        let zScore: Double
    }

    /// Flags transactions whose amount is a statistical outlier against the
    /// user's own spending distribution, using a population z-score. Requires
    /// enough samples and non-zero spread to be meaningful, so it stays quiet
    /// on sparse data rather than crying wolf.
    static func anomalies(
        in transactions: [FinanceCatSnapshot.Transaction],
        threshold: Double = 1.8,
        minSampleSize: Int = 5
    ) -> [Anomaly] {
        let spends = transactions.filter { $0.amountCents > 0 }
        guard spends.count >= minSampleSize else { return [] }

        let amounts = spends.map { Double($0.amountCents) }
        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(amounts.count)
        let standardDeviation = variance.squareRoot()
        guard standardDeviation > 0 else { return [] }

        return spends
            .compactMap { transaction -> Anomaly? in
                let zScore = (Double(transaction.amountCents) - mean) / standardDeviation
                guard zScore >= threshold else { return nil }
                return Anomaly(name: transaction.name, amountCents: transaction.amountCents, zScore: zScore)
            }
            .sorted { $0.zScore > $1.zScore }
    }

    // MARK: - Month-end projection (deterministic run-rate)

    struct Projection: Equatable, Sendable {
        let projectedMonthEndCents: Int
        let daysElapsed: Int
        let daysInMonth: Int
        let monthlyBudgetCents: Int

        var isOverBudget: Bool {
            monthlyBudgetCents > 0 && projectedMonthEndCents > monthlyBudgetCents
        }

        var overBudgetCents: Int {
            max(0, projectedMonthEndCents - monthlyBudgetCents)
        }
    }

    /// Linear run-rate projection: (spend so far / days elapsed) * days in month.
    /// Kept entirely in Swift so the model can talk about the number without
    /// ever computing it.
    static func projection(
        monthSpentCents: Int,
        monthStartDate: String,
        asOfDate: String,
        dailyAllowanceCents: Int
    ) -> Projection? {
        guard
            let start = date(from: monthStartDate),
            let asOf = date(from: asOfDate),
            let dayRange = calendar.range(of: .day, in: .month, for: asOf)
        else { return nil }

        let daysElapsed = (calendar.dateComponents([.day], from: start, to: asOf).day ?? 0) + 1
        guard daysElapsed > 0 else { return nil }

        let daysInMonth = dayRange.count
        let dailyRate = Double(monthSpentCents) / Double(daysElapsed)
        let projected = Int((dailyRate * Double(daysInMonth)).rounded())

        return Projection(
            projectedMonthEndCents: projected,
            daysElapsed: daysElapsed,
            daysInMonth: daysInMonth,
            monthlyBudgetCents: dailyAllowanceCents * daysInMonth
        )
    }

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Edmonton") ?? .current
        return calendar
    }()

    private static func date(from string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }

    /// Collapses noisy card-network merchant strings so "SQ *BLUE BOTTLE #42"
    /// and "BLUE BOTTLE LA" resolve to the same key.
    static func normalizedMerchant(_ raw: String) -> String {
        var value = raw.lowercased()
        for prefix in ["sq *", "sq*", "tst*", "tst* ", "pos ", "pp*", "paypal *", "amzn mktp", "amazon mktpl"] {
            if value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count))
                break
            }
        }

        let cleaned = String(value.map { $0.isLetter || $0 == " " ? $0 : " " })
        let tokens = cleaned.split(separator: " ").map(String.init)
        let key = tokens.prefix(2).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? raw.lowercased() : key
    }

    private static func displayName(for transactions: [FinanceCatSnapshot.Transaction]) -> String {
        let counts = Dictionary(grouping: transactions, by: { $0.name }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? transactions.first?.name ?? "Unknown"
    }
}
