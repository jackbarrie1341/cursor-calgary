import CoreText
import SwiftUI
import WidgetKit

struct BuddyWidgetSnapshot: Codable {
    let buddyName: String
    let mood: String
    let spentTodayCents: Int
    let updatedAt: Date
}

private enum SnapshotStore {
    static let suiteName = "group.cursor-calgary.finance-buddy"
    static let key = "latest_buddy_widget_snapshot"

    static func load() -> BuddyWidgetSnapshot? {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BuddyWidgetSnapshot.self, from: data)
    }
}

private enum WidgetFont {
    static let name: String = {
        guard
            let url = Bundle.main.url(forResource: "Candy Beans", withExtension: "otf"),
            let provider = CGDataProvider(url: url as CFURL),
            let font = CGFont(provider)
        else {
            return "MarkerFelt-Wide"
        }

        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return font.postScriptName as String? ?? "MarkerFelt-Wide"
    }()

    static func font(_ size: CGFloat) -> Font {
        .custom(name, size: size)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BuddyEntry {
        BuddyEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BuddyEntry) -> Void) {
        completion(BuddyEntry(date: .now, snapshot: SnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuddyEntry>) -> Void) {
        let entry = BuddyEntry(date: .now, snapshot: SnapshotStore.load() ?? .placeholder)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct BuddyEntry: TimelineEntry {
    let date: Date
    let snapshot: BuddyWidgetSnapshot
}

struct FinanceBuddyWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(entry.snapshot.assetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(maxHeight: 76)
                .padding(.top, 2)

            Text(entry.snapshot.buddyName)
                .font(WidgetFont.font(18))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(entry.snapshot.moodTitle)
                .font(WidgetFont.font(15))
                .foregroundStyle(entry.snapshot.moodColor)

            Text(entry.snapshot.spentTodayCents.moneyText)
                .font(WidgetFont.font(20))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

struct FinanceBuddyWidget: Widget {
    let kind: String = "FinanceBuddyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FinanceBuddyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Finance Buddy")
        .description("See your buddy mood and today’s spending.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension BuddyWidgetSnapshot {
    static let placeholder = BuddyWidgetSnapshot(
        buddyName: "Bean",
        mood: "happy",
        spentTodayCents: 0,
        updatedAt: .now
    )

    var moodTitle: String {
        switch mood {
        case "nervous": "Nervous"
        case "hungry": "Hungry"
        case "sick": "Sick"
        default: "Happy"
        }
    }

    var assetName: String {
        switch mood {
        case "nervous": "Cat_Worried"
        case "hungry": "Cat_Tear_Pool"
        case "sick": "Cat_Broke"
        default: "Cat_Cheesing"
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
}

private extension Int {
    var moneyText: String {
        let value = Decimal(self) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }
}

#Preview(as: .systemSmall) {
    FinanceBuddyWidget()
} timeline: {
    BuddyEntry(date: .now, snapshot: .placeholder)
}
