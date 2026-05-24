import Foundation

enum BuddyMood: String, Codable, CaseIterable {
    case happy
    case nervous
    case hungry
    case sick

    var title: String {
        switch self {
        case .happy: "Cheesing"
        case .nervous: "Worried"
        case .hungry: "Broke"
        case .sick: "Money Spread"
        }
    }

    var symbolName: String {
        switch self {
        case .happy: "face.smiling.inverse"
        case .nervous: "exclamationmark.triangle"
        case .hungry: "xmark.octagon"
        case .sick: "banknote"
        }
    }
}

extension BuddyMood {
    static func forBudgetUsageRatio(_ ratio: Double) -> BuddyMood {
        if ratio < 0.5 { return .sick }      // Money Spread
        if ratio < 0.8 { return .happy }     // Cheesing
        if ratio < 1.0 { return .nervous }   // Worried
        return .hungry                       // Broke
    }
}

extension BuddyState {
    var budgetUsageRatio: Double {
        guard dailyAllowanceCents > 0 else { return 0 }
        return Double(spentTodayCents) / Double(dailyAllowanceCents)
    }

    var budgetMood: BuddyMood {
        .forBudgetUsageRatio(budgetUsageRatio)
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
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let isLinked: Bool
    let hasOnboarded: Bool
    let ownedHats: [HatItem]
    let equippedHatId: String?

    enum CodingKeys: String, CodingKey {
        case mood
        case spentTodayCents
        case spentWeekCents
        case spentMonthCents
        case dailyAllowanceCents
        case streak
        case asOfDate
        case buddyName
        case catFillHue
        case catFillSaturation
        case catFillBrightness
        case isLinked
        case hasOnboarded
        case ownedHats
        case equippedHatId
    }

    init(
        mood: BuddyMood,
        spentTodayCents: Int,
        spentWeekCents: Int,
        spentMonthCents: Int,
        dailyAllowanceCents: Int,
        streak: Int,
        asOfDate: String,
        buddyName: String,
        catFillHue: Double?,
        catFillSaturation: Double?,
        catFillBrightness: Double?,
        isLinked: Bool,
        hasOnboarded: Bool,
        ownedHats: [HatItem],
        equippedHatId: String?
    ) {
        self.mood = mood
        self.spentTodayCents = spentTodayCents
        self.spentWeekCents = spentWeekCents
        self.spentMonthCents = spentMonthCents
        self.dailyAllowanceCents = dailyAllowanceCents
        self.streak = streak
        self.asOfDate = asOfDate
        self.buddyName = buddyName
        self.catFillHue = catFillHue
        self.catFillSaturation = catFillSaturation
        self.catFillBrightness = catFillBrightness
        self.isLinked = isLinked
        self.hasOnboarded = hasOnboarded
        self.ownedHats = ownedHats
        self.equippedHatId = equippedHatId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mood = try container.decode(BuddyMood.self, forKey: .mood)
        spentTodayCents = try container.decode(Int.self, forKey: .spentTodayCents)
        spentWeekCents = try container.decode(Int.self, forKey: .spentWeekCents)
        spentMonthCents = try container.decode(Int.self, forKey: .spentMonthCents)
        dailyAllowanceCents = try container.decode(Int.self, forKey: .dailyAllowanceCents)
        streak = try container.decode(Int.self, forKey: .streak)
        asOfDate = try container.decode(String.self, forKey: .asOfDate)
        buddyName = try container.decode(String.self, forKey: .buddyName)
        catFillHue = try container.decodeIfPresent(Double.self, forKey: .catFillHue)
        catFillSaturation = try container.decodeIfPresent(Double.self, forKey: .catFillSaturation)
        catFillBrightness = try container.decodeIfPresent(Double.self, forKey: .catFillBrightness)
        isLinked = try container.decode(Bool.self, forKey: .isLinked)
        hasOnboarded = try container.decode(Bool.self, forKey: .hasOnboarded)
        ownedHats = try container.decodeIfPresent([HatItem].self, forKey: .ownedHats) ?? []
        equippedHatId = try container.decodeIfPresent(String.self, forKey: .equippedHatId)
    }
}

struct HatItem: Codable, Identifiable, Equatable {
    let id: String
    let slug: String
    let name: String
    let assetKey: String
    let symbolName: String
}

struct HatsResponse: Codable, Equatable {
    let ownedHats: [HatItem]
    let equippedHatId: String?
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
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let hatAssetKey: String?
    let hatSymbolName: String?
    let mood: BuddyMood
    let streak: Int

    var id: String { userId }
}

struct FriendSearchResult: Codable, Identifiable, Equatable {
    let userId: String
    let username: String
    let displayName: String
    let buddyName: String
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let hatAssetKey: String?
    let hatSymbolName: String?
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

struct SpendingResponse: Codable, Equatable {
    let asOfDate: String
    let monthStartDate: String
    let monthTotalCents: Int
    let transactions: [SpendingTransaction]
    let categoryBreakdown: [CategorySpendingBreakdown]
    let monthlyBreakdown: [MonthlySpendingBreakdown]
}

struct SpendingTransaction: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let amountCents: Int
    let date: String?
    let pending: Bool
    let categoryPrimary: String?
    let categoryDetailed: String?
}

struct CategorySpendingBreakdown: Codable, Identifiable, Equatable {
    let category: String
    let totalCents: Int
    let count: Int

    var id: String { category }
}

struct MonthlySpendingBreakdown: Codable, Identifiable, Equatable {
    let name: String
    let totalCents: Int
    let count: Int
    let lastDate: String?

    var id: String { name }
}
