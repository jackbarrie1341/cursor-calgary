import Foundation
import WidgetKit

struct BuddyWidgetSnapshot: Codable {
    let buddyName: String
    let mood: String
    let spentTodayCents: Int
    let catFillHue: Double
    let catFillSaturation: Double
    let catFillBrightness: Double
    let hatAssetKey: String?
    let hatSymbolName: String?
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
        catFillHue: Double,
        catFillSaturation: Double,
        catFillBrightness: Double
    ) {
        let snapshot = BuddyWidgetSnapshot(
            buddyName: buddy.buddyName,
            mood: mood.rawValue,
            spentTodayCents: buddy.spentTodayCents,
            catFillHue: catFillHue,
            catFillSaturation: catFillSaturation,
            catFillBrightness: catFillBrightness,
            hatAssetKey: equippedHat?.assetKey,
            hatSymbolName: equippedHat?.symbolName,
            updatedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyWidget")
    }

    static func clear() {
        defaults.removeObject(forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "FinanceBuddyWidget")
    }
}
