//
//  FinanceBuddyWidgetLiveActivity.swift
//  FinanceBuddyWidget
//
//  Created by Jack Barrie on 2026-05-23.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FinanceBuddyWidgetAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let mood: String
        let frameIndex: Int
        let dailyBudgetSpentPercent: Int
        let catFillHue: Double
        let catFillSaturation: Double
        let catFillBrightness: Double
    }

    let name: String
}

struct FinanceBuddyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinanceBuddyWidgetAttributes.self) { context in
            LiveActivityBuddyImageView(state: context.state)
                .frame(width: 72, height: 72)
                .frame(maxWidth: .infinity, minHeight: 96)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LiveActivityBuddyImageView(state: context.state)
                        .frame(width: 64, height: 64)
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
        case "nervous": .yellow
        case "hungry": .orange
        case "sick": .red
        default: .green
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
            catFillBrightness: 1.0
        )
    }

    static var happyTwo: FinanceBuddyWidgetAttributes.ContentState {
        FinanceBuddyWidgetAttributes.ContentState(
            mood: "happy",
            frameIndex: 2,
            dailyBudgetSpentPercent: 43,
            catFillHue: 0.04,
            catFillSaturation: 0.48,
            catFillBrightness: 1.0
        )
    }
}
