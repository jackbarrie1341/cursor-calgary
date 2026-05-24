import Foundation
import WidgetKit

struct BuddyWidgetSnapshot: Codable {
    struct Friend: Codable {
        let buddyName: String
        let mood: String
        let catFillHue: Double?
        let catFillSaturation: Double?
        let catFillBrightness: Double?
        let hatAssetKey: String?
        let hatSymbolName: String?
    }

    let buddyName: String
    let mood: String
    let spentTodayCents: Int
    let spentWeekCents: Int
    let spentMonthCents: Int
    let dailyAllowanceCents: Int
    let catFillHue: Double
    let catFillSaturation: Double
    let catFillBrightness: Double
    let hatAssetKey: String?
    let hatSymbolName: String?
    let friends: [Friend]
    let updatedAt: Date
}

enum BuddyWidgetSnapshotStore {
    private static let suiteName = "group.cursor-calgary.finance-buddy"
    private static let key = "latest_buddy_widget_snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(
        _ buddy: BuddyState,
        mood: BuddyMood,
        equippedHat: HatItem?,
        friends: [FriendBuddy],
        catFillHue: Double,
        catFillSaturation: Double,
        catFillBrightness: Double
    ) {
        let snapshot = BuddyWidgetSnapshot(
            buddyName: buddy.buddyName,
            mood: mood.rawValue,
            spentTodayCents: buddy.spentTodayCents,
            spentWeekCents: buddy.spentWeekCents,
            spentMonthCents: buddy.spentMonthCents,
            dailyAllowanceCents: buddy.dailyAllowanceCents,
            catFillHue: catFillHue,
            catFillSaturation: catFillSaturation,
            catFillBrightness: catFillBrightness,
            hatAssetKey: equippedHat?.assetKey,
            hatSymbolName: equippedHat?.symbolName,
            friends: friends.prefix(4).map {
                BuddyWidgetSnapshot.Friend(
                    buddyName: $0.buddyName,
                    mood: $0.mood.rawValue,
                    catFillHue: $0.catFillHue,
                    catFillSaturation: $0.catFillSaturation,
                    catFillBrightness: $0.catFillBrightness,
                    hatAssetKey: $0.hatAssetKey,
                    hatSymbolName: $0.hatSymbolName
                )
            },
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddySpendingWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyCrewWidget")
    }

    static func clear() {
        defaults.removeObject(forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddySpendingWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyCrewWidget")
    }
}
