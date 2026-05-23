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
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct FinanceBuddyWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FinanceBuddyWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension FinanceBuddyWidgetAttributes {
    fileprivate static var preview: FinanceBuddyWidgetAttributes {
        FinanceBuddyWidgetAttributes(name: "World")
    }
}

extension FinanceBuddyWidgetAttributes.ContentState {
    fileprivate static var smiley: FinanceBuddyWidgetAttributes.ContentState {
        FinanceBuddyWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: FinanceBuddyWidgetAttributes.ContentState {
         FinanceBuddyWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: FinanceBuddyWidgetAttributes.preview) {
   FinanceBuddyWidgetLiveActivity()
} contentStates: {
    FinanceBuddyWidgetAttributes.ContentState.smiley
    FinanceBuddyWidgetAttributes.ContentState.starEyes
}
