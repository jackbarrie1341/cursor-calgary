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
private let liveActivityTextColor = Color(red: 0.05, green: 0.05, blue: 0.04)
private let liveActivitySecondaryTextColor = Color(red: 0.42, green: 0.41, blue: 0.38)

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
    }

    let name: String
}

struct FinanceBuddyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinanceBuddyWidgetAttributes.self) { context in
            LiveActivityLockScreenView(
                name: context.attributes.name,
                state: context.state
            )
                .activityBackgroundTint(widgetBackgroundColor)
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityBuddyImageView(state: context.state)
                        .frame(width: 54, height: 54)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.name)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(liveActivityTextColor)
                            .lineLimit(1)

                        Text(context.state.moodTitle)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(context.state.moodColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.percentText)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(context.state.moodColor)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LiveActivityProgressBar(state: context.state)
                        .frame(height: 8)
                        .padding(.horizontal, 8)
                }
            } compactLeading: {
                LiveActivityBuddyImageView(state: context.state)
                    .frame(width: 28, height: 28)
            } compactTrailing: {
                Text(context.state.percentText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(context.state.moodColor)
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

private struct LiveActivityLockScreenView: View {
    let name: String
    let state: FinanceBuddyWidgetAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(state.moodColor.opacity(0.14))
                    .overlay(
                        Circle()
                            .stroke(state.moodColor.opacity(0.26), lineWidth: 1)
                    )

                LiveActivityBuddyImageView(state: state)
                    .padding(7)
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(liveActivityTextColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(state.moodTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(state.moodColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text(state.percentText)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(state.moodColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Daily budget")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(liveActivitySecondaryTextColor)

                        Text(state.paceLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(liveActivityTextColor.opacity(0.78))
                            .lineLimit(1)
                    }

                    LiveActivityProgressBar(state: state)
                        .frame(height: 12)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
    }
}

private struct LiveActivityProgressBar: View {
    let state: FinanceBuddyWidgetAttributes.ContentState

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fillWidth = max(8, width * state.progressValue)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))

                Capsule()
                    .fill(state.moodColor)
                    .frame(width: fillWidth)

                ZStack(alignment: .leading) {
                    ForEach([0.5, 0.8, 1.0], id: \.self) { marker in
                        Rectangle()
                            .fill(Color.white.opacity(0.72))
                            .frame(width: 1.5)
                            .padding(.vertical, 2)
                            .offset(x: max(0, min(width - 1.5, width * marker)))
                    }
                }
            }
            .clipShape(Capsule())
        }
        .accessibilityLabel("Daily budget pace \(state.percentText)")
    }
}

private struct LiveActivityBuddyImageView: View {
    let state: FinanceBuddyWidgetAttributes.ContentState

    var body: some View {
        ZStack {
            if let fillAssetName = state.fillAssetName(frameIndex: state.frameIndex),
               UIImage(named: fillAssetName) != nil {
                Image(fillAssetName)
                    .resizable()
                    .interpolation(.none)
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(state.catFillColor)
                    .contentTransition(.identity)
            }

            Image(state.lineAssetName(frameIndex: state.frameIndex))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .contentTransition(.identity)

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
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

private extension FinanceBuddyWidgetAttributes.ContentState {
    func normalizedFrameIndex(_ frameIndex: Int) -> Int {
        frameIndex == 2 ? 2 : 1
    }

    func lineAssetName(frameIndex: Int) -> String {
        let frameIndex = normalizedFrameIndex(frameIndex)
        switch mood {
        case "nervous": return "\(frameIndex)_Cat_Worried"
        case "hungry": return "\(frameIndex)_Cat_Broke"
        case "sick": return "Cat_Money_Spread_\(frameIndex)"
        default: return "\(frameIndex)_Cat_Cheesing"
        }
    }

    func fillAssetName(frameIndex: Int) -> String? {
        let frameIndex = normalizedFrameIndex(frameIndex)
        switch mood {
        case "nervous": return "1_2_Fill_Cat_Worried"
        case "hungry": return "1_2_Fill_Cat_Broke"
        case "sick": return "\(frameIndex)_Fill_Cat_Money_Spread"
        default: return "\(frameIndex)_Fill_Cat_Cheesing"
        }
    }

    var moodColor: Color {
        switch mood {
        case "nervous": Color(red: 0.92, green: 0.58, blue: 0.20)
        case "hungry": Color(red: 0.90, green: 0.24, blue: 0.20)
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

    var progressValue: Double {
        min(max(Double(dailyBudgetSpentPercent) / 100.0, 0), 1)
    }

    var moodTitle: String {
        switch mood {
        case "nervous": "Worried"
        case "hungry": "Broke"
        case "sick": "Flexing"
        default: "Cheesing"
        }
    }

    var paceLabel: String {
        switch dailyBudgetSpentPercent {
        case ..<50: "Plenty of room"
        case 50..<80: "Steady"
        case 80..<100: "Getting close"
        default: "Over limit"
        }
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
            dailyBudgetSpentPercent: 86,
            catFillHue: 0.04,
            catFillSaturation: 0.48,
            catFillBrightness: 1.0,
            hatAssetKey: "hat_santa",
            hatSymbolName: "snowflake"
        )
    }
}
