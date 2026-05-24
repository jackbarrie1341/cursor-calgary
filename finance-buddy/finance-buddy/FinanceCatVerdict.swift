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
            headline: headline.removingEmoji,
            roast: roast.removingEmoji,
            biggestCulprit: biggestCulprit?.removingEmoji,
            tip: tip.removingEmoji,
            projectedMonthEndCents: projectedMonthEndCents
        )
    }

    func refinedForHome(using snapshot: FinanceCatSnapshot) -> BuddyVerdict {
        let refinedHeadline = headline.needsCatHeadlineReplacement
            ? Self.makeCatHeadline(using: snapshot, biggestCulprit: biggestCulprit)
            : headline

        return BuddyVerdict(
            mood: mood,
            severity: severity,
            headline: refinedHeadline.removingEmoji,
            roast: roast.removingEmoji,
            biggestCulprit: biggestCulprit?.removingEmoji,
            tip: tip.removingEmoji,
            projectedMonthEndCents: projectedMonthEndCents
        )
    }

    private static func makeCatHeadline(using snapshot: FinanceCatSnapshot, biggestCulprit: String?) -> String {
        if let repeated = snapshot.repeatedTodaysTransaction {
            return "\(repeated.name) again? My whiskers noticed."
        }

        if let largest = snapshot.todaysTransactions.max(by: { $0.amountCents < $1.amountCents }) {
            return "\(largest.name) today? The cat is watching."
        }

        if let biggestCulprit, !biggestCulprit.isEmpty {
            return "\(biggestCulprit) is looking a little too familiar."
        }

        return "Quiet spending today. The cat approves."
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
    private static let key = "finance_cat_verdict_v4"

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

private extension FinanceCatSnapshot {
    var repeatedTodaysTransaction: Transaction? {
        todaysTransactions
            .filter { transaction in
                monthlyBreakdown.contains { breakdown in
                    breakdown.count > 1 && breakdown.name.caseInsensitiveCompare(transaction.name) == .orderedSame
                }
            }
            .max { left, right in
                let leftCount = monthlyBreakdown.first { $0.name.caseInsensitiveCompare(left.name) == .orderedSame }?.count ?? 0
                let rightCount = monthlyBreakdown.first { $0.name.caseInsensitiveCompare(right.name) == .orderedSame }?.count ?? 0
                if leftCount == rightCount {
                    return left.amountCents < right.amountCents
                }
                return leftCount < rightCount
            }
    }
}

private extension String {
    var removingEmoji: String {
        String(unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation
        })
    }

    var needsCatHeadlineReplacement: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let genericPhrases = [
            "another day of spending",
            "you spent money today",
            "day of spending",
            "recent purchases",
            "transactions today"
        ]

        return trimmed.count > 90
            || trimmed.contains("\n")
            || trimmed.contains("c,")
            || trimmed.filter({ $0 == "," }).count >= 2
            || trimmed.filter({ $0 == ":" }).count >= 2
            || genericPhrases.contains { trimmed.localizedCaseInsensitiveContains($0) }
    }
}
