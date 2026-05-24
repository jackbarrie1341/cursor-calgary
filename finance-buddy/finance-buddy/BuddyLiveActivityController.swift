import ActivityKit
import Foundation

struct FinanceBuddyWidgetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let mood: String
        let frameIndex: Int
        let dailyBudgetSpentPercent: Int
        let catFillHue: Double
        let catFillSaturation: Double
        let catFillBrightness: Double
        let hatAssetKey: String?
        let hatSymbolName: String?
        var purchaseAmountCents: Int? = nil
    }

    let name: String
}

@available(iOS 16.2, *)
enum BuddyLiveActivityController {
    static func startOrUpdate(
        buddy: BuddyState,
        mood: BuddyMood,
        equippedHat: HatItem?,
        frameIndex: Int,
        catFillHue: Double,
        catFillSaturation: Double,
        catFillBrightness: Double,
        purchaseAmountCents: Int? = nil
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = FinanceBuddyWidgetAttributes.ContentState(
            mood: mood.rawValue,
            frameIndex: frameIndex,
            dailyBudgetSpentPercent: buddy.dailyBudgetSpentPercent,
            catFillHue: catFillHue,
            catFillSaturation: catFillSaturation,
            catFillBrightness: catFillBrightness,
            hatAssetKey: equippedHat?.assetKey,
            hatSymbolName: equippedHat?.symbolName,
            purchaseAmountCents: purchaseAmountCents
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(60 * 60)
        )

        if let activity = Activity<FinanceBuddyWidgetAttributes>.activities.first {
            await activity.update(content)
            return
        }

        do {
            _ = try Activity.request(
                attributes: FinanceBuddyWidgetAttributes(name: buddy.buddyName),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities can be disabled by device, user setting, or policy.
        }
    }

    static func endAll() async {
        for activity in Activity<FinanceBuddyWidgetAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

private extension BuddyState {
    var dailyBudgetSpentPercent: Int {
        guard dailyAllowanceCents > 0 else { return 0 }
        let ratio = Double(spentTodayCents) / Double(dailyAllowanceCents)
        return max(0, Int((ratio * 100).rounded()))
    }
}
