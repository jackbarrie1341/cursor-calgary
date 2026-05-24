import CoreText
import SwiftUI
import WidgetKit

struct BuddyWidgetSnapshot: Codable {
    let buddyName: String
    let mood: String
    let spentTodayCents: Int
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
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
        HStack(spacing: 10) {
            BuddyWidgetImageView(snapshot: entry.snapshot)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot.buddyName)
                    .font(WidgetFont.font(18))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(entry.snapshot.moodTitle)
                    .font(WidgetFont.font(15))
                    .foregroundStyle(entry.snapshot.moodColor)
                    .lineLimit(1)

                Text(entry.snapshot.spentTodayCents.moneyText)
                    .font(WidgetFont.font(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

private struct BuddyWidgetImageView: View {
    let snapshot: BuddyWidgetSnapshot

    var body: some View {
        ZStack {
            if let fillAssetName = snapshot.fillAssetName, UIImage(named: fillAssetName) != nil {
                Image(fillAssetName)
                    .resizable()
                    .interpolation(.none)
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(snapshot.catFillColor)
            }

            Image(snapshot.lineAssetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        }
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
        catFillHue: 0.04,
        catFillSaturation: 0.48,
        catFillBrightness: 1.0,
        updatedAt: .now
    )

    var moodTitle: String {
        switch mood {
        case "nervous": "Nervous"
        case "hungry": "Broke"
        case "sick": "Sick"
        default: "Happy"
        }
    }

    var lineAssetName: String {
        switch mood {
        case "nervous": "Cat_Worried"
        case "hungry": "1_Cat_Broke"
        case "sick": "Cat_Money_Spread_1"
        default: "1_Cat_Cheesing"
        }
    }

    var fillAssetName: String? {
        switch mood {
        case "sick": "1_Fill_Cat_Money_Spread"
        case "happy": "1_Fill_Cat_Cheesing"
        case "hungry": "1_2_Fill_Cat_Broke"
        default: nil
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
            hue: catFillHue ?? 0.04,
            saturation: catFillSaturation ?? 0.48,
            brightness: catFillBrightness ?? 1.0
        )
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
