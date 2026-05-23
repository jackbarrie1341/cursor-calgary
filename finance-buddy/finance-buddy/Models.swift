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
    let spentWeekCents: Int
    let spentMonthCents: Int
    let dailyAllowanceCents: Int
    let streak: Int
    let asOfDate: String
    let buddyName: String
    let isLinked: Bool
    let hasOnboarded: Bool
}

struct AuthInput {
    var name = ""
    var email = ""
    var password = ""

    var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var usernameFromEmail: String {
        normalizedEmail.components(separatedBy: "@").first ?? normalizedEmail
    }

    var isValidForSignIn: Bool {
        normalizedEmail.contains("@") && normalizedEmail.contains(".") && password.count >= 6
    }

    var isValidForSignUp: Bool {
        isValidForSignIn && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct OnboardingInput {
    var monthlyIncome: Decimal = 4_000
    var monthlyBudget: Decimal = 1_500
    var buddyName: String = "Bean"
    var displayName: String = ""
    var username: String = ""

    var normalizedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var isUsernameValid: Bool {
        let pattern = "^[a-z0-9_]{3,20}$"
        return normalizedUsername.range(of: pattern, options: .regularExpression) != nil
    }

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

struct FriendBuddy: Codable, Identifiable, Equatable {
    let userId: String
    let username: String
    let displayName: String
    let buddyName: String
    let mood: BuddyMood
    let streak: Int

    var id: String { userId }
}

struct FriendSearchResult: Codable, Identifiable, Equatable {
    let userId: String
    let username: String
    let displayName: String
    let buddyName: String
    let mood: BuddyMood
    let streak: Int
    let isFriend: Bool

    var id: String { userId }
}

struct FriendsResponse: Codable {
    let friends: [FriendBuddy]
}

struct FriendSearchResponse: Codable {
    let results: [FriendSearchResult]
}

struct AddFriendResponse: Codable {
    let friend: FriendBuddy
}
