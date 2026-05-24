import Foundation

enum GeneratedBuddyMood: String, Codable, Equatable, CaseIterable, Sendable {
    case happy
    case nervous
    case hungry
    case sick

    var buddyMood: BuddyMood {
        switch self {
        case .happy: .happy
        case .nervous: .nervous
        case .hungry: .hungry
        case .sick: .sick
        }
    }
}

struct BuddyVerdict: Codable, Equatable, Sendable {
    let mood: GeneratedBuddyMood
    let severity: Int
    let headline: String
    let roast: String
    let biggestCulprit: String?
    let tip: String
    let projectedMonthEndCents: Int?

    var withoutEmoji: BuddyVerdict {
        BuddyVerdict(
            mood: mood,
            severity: severity,
            headline: headline.cleaningModelDisplayText,
            roast: roast.cleaningModelDisplayText,
            biggestCulprit: biggestCulprit?.cleaningModelDisplayText,
            tip: tip.cleaningModelDisplayText,
            projectedMonthEndCents: projectedMonthEndCents
        )
    }

}

enum FinanceCatTextCleaner {
    static func clean(_ text: String) -> String {
        text.cleaningModelDisplayText
    }
}

struct StoredBuddyVerdict: Codable, Equatable, Sendable {
    let verdict: BuddyVerdict
    let generatedAt: Date
    let sourceTransactionCount: Int
    let usedFoundationModels: Bool

    var isRecent: Bool {
        Date().timeIntervalSince(generatedAt) < 30 * 60
    }
}

enum FinanceCatAgentStatus: Equatable, Sendable {
    case idle
    case generating
    case unavailable(String)
    case failed(String)

    var message: String? {
        switch self {
        case .idle, .generating:
            nil
        case let .unavailable(message), let .failed(message):
            message
        }
    }
}

enum FinanceCatVerdictStore {
    private static let key = "finance_cat_verdict_v6"

    static func load() -> StoredBuddyVerdict? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StoredBuddyVerdict.self, from: data)
    }

    static func save(_ verdict: StoredBuddyVerdict) {
        guard let data = try? JSONEncoder().encode(verdict) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct FinanceCatSnapshot: Sendable {
    struct BudgetStatus: Sendable {
        let spentTodayCents: Int
        let spentWeekCents: Int
        let spentMonthCents: Int
        let dailyAllowanceCents: Int
        let streak: Int
        let backendMood: BuddyMood
        let asOfDate: String
    }

    struct Transaction: Sendable {
        let name: String
        let amountCents: Int
        let date: String?
        let pending: Bool
    }

    struct MerchantBreakdown: Sendable {
        let name: String
        let totalCents: Int
        let count: Int
        let lastDate: String?
    }

    let budgetStatus: BudgetStatus
    let todaysTransactions: [Transaction]
    let recentTransactions: [Transaction]
    /// Every synced transaction this period. Analytical tools compute over the
    /// full set, not just the rows surfaced to the raw-transaction tools.
    let allTransactions: [Transaction]
    let monthlyBreakdown: [MerchantBreakdown]
    let monthStartDate: String
    let monthTotalCents: Int
    let transactionCount: Int

    init?(buddy: BuddyState?, spending: SpendingResponse?) {
        guard let buddy, let spending else { return nil }

        budgetStatus = BudgetStatus(
            spentTodayCents: buddy.spentTodayCents,
            spentWeekCents: buddy.spentWeekCents,
            spentMonthCents: buddy.spentMonthCents,
            dailyAllowanceCents: buddy.dailyAllowanceCents,
            streak: buddy.streak,
            backendMood: buddy.mood,
            asOfDate: buddy.asOfDate
        )
        let transactions = spending.transactions.map {
            Transaction(
                name: $0.name,
                amountCents: $0.amountCents,
                date: $0.date,
                pending: $0.pending
            )
        }
        todaysTransactions = transactions.filter { $0.date == buddy.asOfDate }.prefix(20).map { $0 }
        recentTransactions = Array(transactions.prefix(20))
        allTransactions = transactions
        monthlyBreakdown = spending.monthlyBreakdown.prefix(10).map {
            MerchantBreakdown(
                name: $0.name,
                totalCents: $0.totalCents,
                count: $0.count,
                lastDate: $0.lastDate
            )
        }
        monthStartDate = spending.monthStartDate
        monthTotalCents = spending.monthTotalCents
        transactionCount = spending.transactions.count
    }
}

/// A snapshot of a verdict mid-stream. Every field is optional because the
/// model fills them in over time; `completeVerdict` returns a real
/// `BuddyVerdict` only once the required fields have all arrived.
struct StreamedVerdict: Sendable, Equatable {
    var mood: GeneratedBuddyMood?
    var severity: Int?
    var headline: String?
    var roast: String?
    var biggestCulprit: String?
    var tip: String?
    var projectedMonthEndCents: Int?

    var completeVerdict: BuddyVerdict? {
        guard let mood, let severity, let headline, let roast, let tip else { return nil }
        return BuddyVerdict(
            mood: mood,
            severity: severity,
            headline: headline,
            roast: roast,
            biggestCulprit: biggestCulprit,
            tip: tip,
            projectedMonthEndCents: projectedMonthEndCents
        )
    }
}

private extension String {
    var cleaningModelDisplayText: String {
        var cleaned = String(unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation
        })
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”")))
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)^([^":]+):\s*\d+\s+times.*$"#,
            with: "$1 again?",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)\b\d+\s*c\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i),?\s*money\s+total|,?\s*about\s+money\s+each"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d{6,}\b"#,
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
