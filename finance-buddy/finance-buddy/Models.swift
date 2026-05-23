import Foundation

enum BuddyMood: String, Codable, CaseIterable {
    case happy
    case nervous
    case hungry
    case sick

    var title: String {
        switch self {
        case .happy: "Happy"
        case .nervous: "Nervous"
        case .hungry: "Hungry"
        case .sick: "Sick"
        }
    }

    var symbolName: String {
        switch self {
        case .happy: "face.smiling"
        case .nervous: "exclamationmark.triangle"
        case .hungry: "fork.knife"
        case .sick: "bandage"
        }
    }
}

struct BuddyState: Codable, Equatable {
    let mood: BuddyMood
    let spentTodayCents: Int
    let dailyAllowanceCents: Int
    let streak: Int
    let asOfDate: String
    let buddyName: String
    let isLinked: Bool
    let hasOnboarded: Bool
}

struct OnboardingInput {
    var monthlyIncome: Decimal = 4_000
    var monthlyBudget: Decimal = 1_500
    var buddyName: String = "Bean"

    var monthlyIncomeCents: Int {
        Self.cents(from: monthlyIncome)
    }

    var monthlyBudgetCents: Int {
        Self.cents(from: monthlyBudget)
    }

    private static func cents(from value: Decimal) -> Int {
        NSDecimalNumber(decimal: value * 100).rounding(accordingToBehavior: nil).intValue
    }
}

struct LinkTokenResponse: Codable {
    let linkToken: String
}
