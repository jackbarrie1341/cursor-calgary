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
    @Guide(description: "One specific Home-screen sentence naming the merchant, purchase type, or category behind the judgment.")
    let headline: String
    @Guide(description: "A one-sentence playful spending comment, maximum 14 words.")
    let roast: String
    @Guide(description: "Top merchant or category driving spend, or an empty string if none stands out.")
    let biggestCulprit: String
    @Guide(description: "One concrete spending tip, maximum 14 words.")
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
        makeSession(snapshot: snapshot).prewarm(promptPrefix: Prompt("Review the user's finance snapshot."))
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
    Inspect the user's spending with the tools, then judge today.
    Call getRecurringCharges to find repeat offenders, getAnomalies to find unusual purchases, and getMonthEndProjection to see where the month is heading.
    Look for unnecessary purchases, repeated small charges that add up, and areas where the user is doing well.
    The headline must be exactly one specific sentence for the Home screen.
    The headline must mention the merchant, purchase type, or category behind the judgment when one exists.
    Keep the headline under 75 characters.
    Simplify noisy bank transaction names into plain language; say "that withdrawal" or "that transfer" instead of full ACH, card, check, or account strings.
    Do not copy, list, enumerate, or restate the raw tool output.
    Do not include cents, account numbers, check numbers, transaction IDs, multiple merchants, or comma-separated transaction lists in the headline.
    Never use raw cent notation like "7500c"; write normal words instead, or avoid the amount entirely.
    Never write generic summaries like "another day of spending" or "you spent money today."
    Prefer lines like "Three coffees before noon? My whiskers noticed." or "No takeout today, impressive."
    Make the headline sound lightly like a cat without forcing cat words. No emoji or emoticons anywhere.
    Do not invent merchants. If there are no transactions today, comment on today's quiet spending.
    Put the same core observation in roast, and put a short practical follow-up in tip.
    """

    private func makeSession(snapshot: FinanceCatSnapshot) -> LanguageModelSession {
        LanguageModelSession(
            tools: [
                GetBudgetStatusTool(snapshot: snapshot),
                GetTodaysTransactionsTool(snapshot: snapshot),
                GetRecentTransactionsTool(snapshot: snapshot),
                GetMonthlyBreakdownTool(snapshot: snapshot),
                GetRecurringChargesTool(snapshot: snapshot),
                GetAnomaliesTool(snapshot: snapshot),
                GetMonthEndProjectionTool(snapshot: snapshot)
            ],
            instructions: """
            You are the private finance brain for a cartoon cat.
            You never call network APIs. You only use the provided local tools.
            The analytical tools (recurring charges, anomalies, projection) already did the math; trust their numbers and never recompute them yourself.
            Give short, specific, useful analysis based on the user's already-fetched app state.
            Sound like a cat in attitude: observant, dry, a little picky, and occasionally pleased.
            Do not overuse cat words. Avoid meow unless it genuinely fits. Never use emoji or emoticons.
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
        "Returns today's, week's, and month's spend, allowance, streak, date, and current backend mood."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        let status = snapshot.budgetStatus
        return """
        asOfDate: \(status.asOfDate)
        spentTodayCents: \(status.spentTodayCents)
        spentWeekCents: \(status.spentWeekCents)
        spentMonthCents: \(status.spentMonthCents)
        dailyAllowanceCents: \(status.dailyAllowanceCents)
        streak: \(status.streak)
        backendMood: \(status.backendMood.rawValue)
        """
    }
}

@available(iOS 26.0, *)
private struct GetTodaysTransactionsTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getTodaysTransactions" }
    var description: String {
        "Returns today's local transactions, limited to 20."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.todaysTransactions.isEmpty else {
            return "No synced transactions for today."
        }

        return snapshot.todaysTransactions.enumerated().map { index, transaction in
            let pending = transaction.pending ? " pending" : ""
            return "\(index + 1). \(transaction.name): \(transaction.amountCents)c\(pending)"
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetRecentTransactionsTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getRecentTransactions" }
    var description: String {
        "Returns at most 20 recent local transactions already fetched by the app."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.recentTransactions.isEmpty else {
            return "No synced transactions are available."
        }

        return snapshot.recentTransactions.enumerated().map { index, transaction in
            let pending = transaction.pending ? " pending" : ""
            return "\(index + 1). \(transaction.name): \(transaction.amountCents)c on \(transaction.date ?? "unknown date")\(pending)"
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetMonthlyBreakdownTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getMonthlyBreakdown" }
    var description: String {
        "Returns the top monthly merchants from the app's local spending breakdown."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        guard !snapshot.monthlyBreakdown.isEmpty else {
            return "No monthly merchant breakdown is available."
        }

        return snapshot.monthlyBreakdown.enumerated().map { index, item in
            "\(index + 1). \(item.name): \(item.totalCents)c across \(item.count) purchases, last \(item.lastDate ?? "unknown date")"
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
private struct GetRecurringChargesTool: Tool {
    let snapshot: FinanceCatSnapshot

    var name: String { "getRecurringCharges" }
    var description: String {
        "Detects merchants charged more than once this period after normalizing noisy card-network names. Use it to catch death-by-a-thousand-cuts spending."
    }

    func call(arguments: EmptyFinanceCatToolArguments) async throws -> String {
        let charges = FinanceCatAnalytics.recurringCharges(in: snapshot.allTransactions)
        guard !charges.isEmpty else {
            return "No repeated merchants this period."
        }

        return charges.prefix(8).map { charge in
            "\(charge.merchant): \(charge.occurrences) times, \(charge.totalCents)c total, about \(charge.typicalCents)c each"
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
            "\(anomaly.name): \(anomaly.amountCents)c, \(String(format: "%.1f", anomaly.zScore)) standard deviations above normal"
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

        let pace = projection.isOverBudget
            ? "on pace to overspend by \(projection.overBudgetCents)c"
            : "on pace to stay within budget"
        return """
        projectedMonthEndCents: \(projection.projectedMonthEndCents)
        monthlyBudgetCents: \(projection.monthlyBudgetCents)
        daysElapsed: \(projection.daysElapsed) of \(projection.daysInMonth)
        pace: \(pace)
        """
    }
}
