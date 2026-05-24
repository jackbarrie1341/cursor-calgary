//
//  FinanceBuddyWidgetLiveActivity.swift
//  FinanceBuddyWidget
//
//  Created by Jack Barrie on 2026-05-23.
//

import ActivityKit
import WidgetKit
import SwiftUI

private let widgetBackgroundColor = Color(red: 0.976, green: 0.961, blue: 0.925)

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

struct FinanceBuddyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinanceBuddyWidgetAttributes.self) { context in
            HStack(spacing: 12) {
                LiveActivityBuddyImageView(state: context.state)
                    .frame(width: 72, height: 72)
                if let reactionText = context.state.reactionText {
                    Text(reactionText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(context.state.reactionColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .activityBackgroundTint(widgetBackgroundColor)
            .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 10) {
                        LiveActivityBuddyImageView(state: context.state)
                            .frame(width: 64, height: 64)
                        if let reactionText = context.state.reactionText {
                            Text(reactionText)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(context.state.reactionColor)
                        }
                    }
                }
            } compactLeading: {
                LiveActivityBuddyImageView(state: context.state)
                    .frame(width: 28, height: 28)
            } compactTrailing: {
                Text(context.state.reactionText ?? context.state.percentText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.state.purchaseAmountCents != nil ? context.state.reactionColor : context.state.moodColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } minimal: {
                LiveActivityBuddyImageView(state: context.state)
                    .frame(width: 22, height: 22)
            }
            .keylineTint(nil)
        }
    }
}

private struct LiveActivityBuddyImageView: View {
    let state: FinanceBuddyWidgetAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            let frameIndex = frameIndex(for: timeline.date)

            ZStack {
                if let fillAssetName = state.fillAssetName(frameIndex: frameIndex),
                   UIImage(named: fillAssetName) != nil {
                    Image(fillAssetName)
                        .resizable()
                        .interpolation(.none)
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(state.catFillColor)
                }

                Image(state.lineAssetName(frameIndex: frameIndex))
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()

                if let hatAssetName = state.hatAssetName {
                    Image(hatAssetName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .rotationEffect(state.hatRotation)
                        .offset(state.hatOffset)
                } else if let hatSymbolName = state.hatSymbolName {
                    Image(systemName: hatSymbolName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                        .offset(y: -9)
                }
            }
        }
    }

    private func frameIndex(for date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate) % 2 == 0 ? 1 : 2
    }
}

private extension FinanceBuddyWidgetAttributes.ContentState {
    func normalizedFrameIndex(_ frameIndex: Int) -> Int {
        frameIndex == 2 ? 2 : 1
    }

    func lineAssetName(frameIndex: Int) -> String {
        let frameIndex = normalizedFrameIndex(frameIndex)
        if let cents = purchaseAmountCents {
            if cents > 0 {
                return "Cat_Money_Spread_\(frameIndex)"
            } else {
                return "\(frameIndex)_Cat_Cheesing"
            }
        }
        switch mood {
        case "nervous": return "\(frameIndex)_Cat_Worried"
        case "hungry": return "\(frameIndex)_Cat_Broke"
        case "sick": return "Cat_Money_Spread_\(frameIndex)"
        default: return "\(frameIndex)_Cat_Cheesing"
        }
    }

    func fillAssetName(frameIndex: Int) -> String? {
        let frameIndex = normalizedFrameIndex(frameIndex)
        if let cents = purchaseAmountCents {
            if cents > 0 {
                return "\(frameIndex)_Fill_Cat_Money_Spread"
            } else {
                return "\(frameIndex)_Fill_Cat_Cheesing"
            }
        }
        switch mood {
        case "nervous": return "1_2_Fill_Cat_Worried"
        case "hungry": return "1_2_Fill_Cat_Broke"
        case "sick": return "\(frameIndex)_Fill_Cat_Money_Spread"
        default: return "\(frameIndex)_Fill_Cat_Cheesing"
        }
    }

    var reactionText: String? {
        guard let cents = purchaseAmountCents else { return nil }
        let dollars = Double(abs(cents)) / 100.0
        let prefix = cents > 0 ? "-" : "+"
        return String(format: "%@$%.2f", prefix, dollars)
    }

    var reactionColor: Color {
        guard let cents = purchaseAmountCents else { return moodColor }
        return cents > 0 ? .red : Color(red: 0.05, green: 0.62, blue: 0.30)
    }

    var moodColor: Color {
        switch mood {
        case "nervous": .yellow
        case "hungry": .red
        case "sick": Color(red: 0.05, green: 0.62, blue: 0.30)
        default: Color(red: 0.30, green: 0.72, blue: 0.38)
        }
    }

    var catFillColor: Color {
        Color(
            hue: catFillHue,
            saturation: catFillSaturation,
            brightness: catFillBrightness
        )
    }

    var percentText: String {
        "\(dailyBudgetSpentPercent)%"
    }

    var hatAssetName: String? {
        guard let hatAssetKey, UIImage(named: hatAssetKey) != nil else { return nil }
        return hatAssetKey
    }

    var hatOffset: CGSize {
        guard mood == "sick", hatAssetKey != nil else { return .zero }
        if hatAssetKey == "Hat_Sprout" {
            return CGSize(width: -1.5, height: 0.7)
        }
        return CGSize(width: -1.5, height: -1.2)
    }

    var hatRotation: Angle {
        guard mood == "sick", hatAssetKey != "Hat_Sprout" else { return .zero }
        return .degrees(-8)
    }
}

#Preview("Notification", as: .content, using: FinanceBuddyWidgetAttributes.preview) {
   FinanceBuddyWidgetLiveActivity()
} contentStates: {
    FinanceBuddyWidgetAttributes.ContentState.happyOne
    FinanceBuddyWidgetAttributes.ContentState.happyTwo
}

private extension FinanceBuddyWidgetAttributes {
    static var preview: FinanceBuddyWidgetAttributes {
        FinanceBuddyWidgetAttributes(name: "Bean")
    }
}

private extension FinanceBuddyWidgetAttributes.ContentState {
    static var happyOne: FinanceBuddyWidgetAttributes.ContentState {
        FinanceBuddyWidgetAttributes.ContentState(
            mood: "happy",
            frameIndex: 1,
            dailyBudgetSpentPercent: 42,
            catFillHue: 0.04,
            catFillSaturation: 0.48,
            catFillBrightness: 1.0,
            hatAssetKey: "hat_santa",
            hatSymbolName: "snowflake"
        )
    }

    static var happyTwo: FinanceBuddyWidgetAttributes.ContentState {
        FinanceBuddyWidgetAttributes.ContentState(
            mood: "happy",
            frameIndex: 2,
            dailyBudgetSpentPercent: 43,
            catFillHue: 0.04,
            catFillSaturation: 0.48,
            catFillBrightness: 1.0,
            hatAssetKey: "hat_santa",
            hatSymbolName: "snowflake"
        )
    }
}
