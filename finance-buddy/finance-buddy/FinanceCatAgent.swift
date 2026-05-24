import Foundation
import FoundationModels

@available(iOS 26.0, *)
nonisolated extension GeneratedBuddyMood: Generable {
    static var generationSchema: GenerationSchema {
        GenerationSchema(type: Self.self, anyOf: Self.allCases.map(\.rawValue))
    }

    init(_ content: GeneratedContent) throws {
        let rawValue = try String(content)
        guard let mood = Self(rawValue: rawValue) else {
            throw FinanceCatAgentError.invalidGeneratedMood(rawValue)
        }
        self = mood
    }

    var generatedContent: GeneratedContent {
        GeneratedContent(rawValue)
    }
}

/// The model-generated shape of a verdict. Using the `@Generable` macro (rather
/// than a hand-written schema) gives us a synthesized `PartiallyGenerated` type
/// with all-optional fields, which is what makes token-by-token streaming work.
///
/// Note what is *not* here: `projectedMonthEndCents`. Run-rate math is computed
/// deterministically in `FinanceCatAnalytics` and merged in afterwards, so the
/// language model never has to do arithmetic it would get wrong.
@available(iOS 26.0, *)
@Generable
struct GeneratedFinanceVerdict {
    @Guide(description: "The cat mood to display: happy, nervous, hungry, or sick.")
    let mood: GeneratedBuddyMood
    @Guide(description: "How concerned the cat is, from 0 calm to 10 alarmed.", .range(0...10))
    let severity: Int
    @Guide(description: "One simple Home-screen sentence under 12 words. No emoji, no money amounts, no lists.")
    let headline: String
    @Guide(description: "A one-sentence playful spending comment, maximum 12 words.")
    let roast: String
    @Guide(description: "Top merchant or category driving spend, or an empty string if none stands out.")
    let biggestCulprit: String
    @Guide(description: "One concrete spending tip, maximum 12 words.")
    let tip: String
}

@available(iOS 26.0, *)
extension GeneratedFinanceVerdict {
    func asBuddyVerdict(projectedMonthEndCents: Int?) -> BuddyVerdict {
        BuddyVerdict(
            mood: mood,
            severity: severity,
            headline: headline,
            roast: roast,
            biggestCulprit: biggestCulprit.isEmpty ? nil : biggestCulprit,
            tip: tip,
            projectedMonthEndCents: projectedMonthEndCents
        )
    }
}

@available(iOS 26.0, *)
final class FinanceCatAgent {
    private static let generationOptions = GenerationOptions(
        sampling: .greedy,
        temperature: 0.2,
        maximumResponseTokens: 220
    )

    func prewarm(snapshot: FinanceCatSnapshot) {
        print("[FinanceCat] model availability before prewarm: \(SystemLanguageModel.default.availability)")
        guard case .available = SystemLanguageModel.default.availability else { return }
        makeSession(snapshot: snapshot).prewarm(promptPrefix: Prompt("Write one short cat spending line."))
        print("[FinanceCat] prewarm requested")
    }

    /// One-shot generation. Kept as the fallback path when streaming produces an
    /// incomplete result.
    func generateVerdict(snapshot: FinanceCatSnapshot) async throws -> BuddyVerdict {
        try Self.requireAvailableModel()

        let session = makeSession(snapshot: snapshot)
        let response = try await session.respond(
            to: Self.analysisPrompt,
            generating: GeneratedFinanceVerdict.self,
            options: Self.generationOptions
        )
        return response.content.asBuddyVerdict(
            projectedMonthEndCents: Self.projectedMonthEndCents(for: snapshot)
        )
    }

    /// Streams the verdict as the model writes it, yielding a growing
    /// `StreamedVerdict` so the UI can type the headline out live. The
    /// deterministic month-end projection is attached to every snapshot.
    func streamVerdict(snapshot: FinanceCatSnapshot) -> AsyncThrowingStream<StreamedVerdict, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try Self.requireAvailableModel()

                    let projection = Self.projectedMonthEndCents(for: snapshot)
                    let session = self.makeSession(snapshot: snapshot)
                    let stream = session.streamResponse(
                        to: Self.analysisPrompt,
                        generating: GeneratedFinanceVerdict.self,
                        options: Self.generationOptions
                    )

                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        let partial = snapshot.content
                        let culprit = partial.biggestCulprit
                        continuation.yield(
                            StreamedVerdict(
                                mood: partial.mood,
                                severity: partial.severity,
                                headline: partial.headline,
                                roast: partial.roast,
                                biggestCulprit: (culprit?.isEmpty ?? true) ? nil : culprit,
                                tip: partial.tip,
                                projectedMonthEndCents: projection
                            )
                        )
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func requireAvailableModel() throws {
        print("[FinanceCat] checking model availability: \(SystemLanguageModel.default.availability)")
        switch SystemLanguageModel.default.availability {
        case .available:
            return
        case let .unavailable(reason):
            throw FinanceCatAgentError.modelUnavailable(reason)
        }
    }

    /// Deterministic run-rate projection. Computed in Swift, never by the model.
    private static func projectedMonthEndCents(for snapshot: FinanceCatSnapshot) -> Int? {
        FinanceCatAnalytics.projection(
            monthSpentCents: snapshot.monthTotalCents,
            monthStartDate: snapshot.monthStartDate,
            asOfDate: snapshot.budgetStatus.asOfDate,
            dailyAllowanceCents: snapshot.budgetStatus.dailyAllowanceCents
        )?.projectedMonthEndCents
    }

    private static let analysisPrompt = """
    Use the tools and write one short sentence for the cat to say on Home.
    Comment only on today's purchases.
    Use repeated-merchant context only when that same merchant also appears today.
    Pick exactly one observation from today: a repeat offender, an unnecessary purchase, or something good.
    Keep the headline under 12 words.
    Sound like a dry little cat, but do not overdo cat words.
    Do not use emoji, emoticons, money amounts, percentages, dates, IDs, account text, or lists.
    Do not mention merchants that did not appear today.
    Do not copy tool output.
    Good examples: "Starbucks again? The cat noticed." "No takeout today. Suspiciously good."
    Bad examples: "Sony PlayStation: 3 times" "You spent money today."
    """

    private func makeSession(snapshot: FinanceCatSnapshot) -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                GetBudgetStatusTool(snapshot: snapshot),
                GetTodaysTransactionsTool(snapshot: snapshot),
                GetRecurringChargesTool(snapshot: snapshot)
            ],
            instructions: """
            You are the private finance brain for a cartoon cat.
            You never call network APIs. You only use the provided local tools.
            Give short, specific analysis based on the user's already-fetched app state.
            The Home headline is a single simple sentence, not a summary.
            Sound observant, dry, a little picky, and occasionally pleased.
            Never use emoji or emoticons.
            Friends and backend systems will not see this verdict.
            """
        )
    }
}

@available(iOS 26.0, *)
private enum FinanceCatAgentError: LocalizedError {
    case invalidGeneratedMood(String)
    case modelUnavailable(SystemLanguageModel.Availability.UnavailableReason)

    var errorDescription: String? {
        switch self {
        case let .invalidGeneratedMood(value):
            "The model returned an unknown mood: \(value)."
        case let .modelUnavailable(reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                "Apple Intelligence is off. Your cat is thinking offline."
            case .deviceNotEligible:
                "This device does not support cat analysis."
            case .modelNotReady:
                "Cat analysis is not ready yet."
            @unknown default:
                "Cat analysis is unavailable."
            }
        }
    }
}

@available(iOS 26.0, *)
@Generable
private struct EmptyFinanceCatToolArguments {}

@available(iOS 26.0, *)
private struct GetBudgetStatusTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getBudgetStatus" }
    var description: String {
        "Returns simple budget context without exact money amounts."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        let status = snapshot.budgetStatus
        let dailyPercent = status.dailyAllowanceCents > 0
            ? Int((Double(status.spentTodayCents) / Double(status.dailyAllowanceCents) * 100).rounded())
            : 0
        let dayStatus: String
        if dailyPercent < 50 {
            dayStatus = "comfortably under today's budget"
        } else if dailyPercent < 80 {
            dayStatus = "using today's budget steadily"
        } else if dailyPercent <= 100 {
            dayStatus = "close to today's budget"
        } else {
            dayStatus = "over today's budget"
        }

        return """
        Today is \(dayStatus).
        Streak: \(status.streak) days.
        Current mood: \(status.backendMood.title).
        """
    }
}

@available(iOS 26.0, *)
private struct GetTodaysTransactionsTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getTodaysTransactions" }
    var description: String {
        "Returns today's merchant names only, limited to 12."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.todaysTransactions.isEmpty else {
            return "No synced transactions for today."
        }

        let names = snapshot.todaysTransactions.prefix(12).map { FinanceCatToolText.merchantName($0.name) }
        return "Today's purchases: \(names.joined(separator: ", "))."
    }
}

@available(iOS 26.0, *)
private struct GetRecentTransactionsTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getRecentTransactions" }
    var description: String {
        "Returns recent merchant names only."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.recentTransactions.isEmpty else {
            return "No synced transactions are available."
        }

        let names = snapshot.recentTransactions.prefix(12).map { FinanceCatToolText.merchantName($0.name) }
        return "Recent purchases: \(names.joined(separator: ", "))."
    }
}

@available(iOS 26.0, *)
private struct GetMonthlyBreakdownTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getMonthlyBreakdown" }
    var description: String {
        "Returns this month's repeated merchants without exact money amounts."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.monthlyBreakdown.isEmpty else {
            return "No monthly merchant breakdown is available."
        }

        return snapshot.monthlyBreakdown.prefix(8).map { item in
            let name = FinanceCatToolText.merchantName(item.name)
            if item.count == 1 {
                return "\(name) appeared once this month."
            }
            return "\(name) appeared \(item.count) times this month."
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetRecurringChargesTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getRecurringCharges" }
    var description: String {
        "Returns repeated monthly merchants only when that merchant also appeared today."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        let todaysMerchantKeys = Set(
            snapshot.todaysTransactions.map { FinanceCatAnalytics.normalizedMerchant($0.name) }
        )
        guard !todaysMerchantKeys.isEmpty else {
            return "No purchases today, so there are no today's repeat merchants."
        }

        let charges = FinanceCatAnalytics.recurringCharges(in: snapshot.allTransactions)
            .filter { todaysMerchantKeys.contains(FinanceCatAnalytics.normalizedMerchant($0.merchant)) }
        guard !charges.isEmpty else {
            return "None of today's merchants are repeated this month."
        }

        return charges.prefix(8).map { charge in
            let name = FinanceCatToolText.merchantName(charge.merchant)
            return "\(name) appeared \(charge.occurrences) times this month."
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetAnomaliesTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getAnomalies" }
    var description: String {
        "Returns statistically unusual transactions (high z-score against the user's own spending). Empty when nothing stands out."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        let anomalies = FinanceCatAnalytics.anomalies(in: snapshot.allTransactions)
        guard !anomalies.isEmpty else {
            return "No statistically unusual purchases."
        }

        return anomalies.prefix(5).map { anomaly in
            "\(FinanceCatToolText.merchantName(anomaly.name)) stood out as unusual."
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetMonthEndProjectionTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getMonthEndProjection" }
    var description: String {
        "Returns the deterministic run-rate projection for total month-end spend and whether it is on pace to exceed the budget."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard let projection = FinanceCatAnalytics.projection(
            monthSpentCents: snapshot.monthTotalCents,
            monthStartDate: snapshot.monthStartDate,
            asOfDate: snapshot.budgetStatus.asOfDate,
            dailyAllowanceCents: snapshot.budgetStatus.dailyAllowanceCents
        ) else {
            return "Not enough data to project the month."
        }

        return projection.isOverBudget
            ? "The month is on pace to go over budget."
            : "The month is on pace to stay within budget."
    }
}

private enum FinanceCatToolText {
    static func merchantName(_ rawName: String) -> String {
        var name = rawName
        name = name.replacingOccurrences(
            of: #"(?i)\b(ach|eft|pos|debit|credit|withdrawal|online|transfer|check|tfr|tsfr|transaction|purchase)\b"#,
            with: " ",
            options: .regularExpression
        )
        name = name.replacingOccurrences(
            of: #"\b\d{3,}\b"#,
            with: " ",
            options: .regularExpression
        )
        name = name.replacingOccurrences(
            of: #"[_*/\\|#]+"#,
            with: " ",
            options: .regularExpression
        )
        name = name.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "that purchase" : String(name.prefix(32))
    }
}
