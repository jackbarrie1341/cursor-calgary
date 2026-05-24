import CoreText
import SwiftUI
import WidgetKit

struct BuddyWidgetSnapshot: Codable {
    let buddyName: String
    let mood: String
    let spentTodayCents: Int
    let spentWeekCents: Int?
    let spentMonthCents: Int?
    let dailyAllowanceCents: Int?
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let hatAssetKey: String?
    let hatSymbolName: String?
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
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        HStack(spacing: widgetFamily == .systemSmall ? 8 : 16) {
            BuddyWidgetImageView(snapshot: entry.snapshot)
                .frame(width: widgetFamily == .systemSmall ? 66 : 116)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: widgetFamily == .systemSmall ? 3 : 5) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.snapshot.buddyName)
                        .font(WidgetFont.font(widgetFamily == .systemSmall ? 15 : 19))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(entry.snapshot.moodTitle)
                        .font(WidgetFont.font(widgetFamily == .systemSmall ? 12 : 14))
                        .foregroundStyle(entry.snapshot.moodColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text(entry.snapshot.spentTodayCents.moneyText)
                    .font(WidgetFont.font(widgetFamily == .systemSmall ? 20 : 25))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(entry.snapshot.dailyBudgetText)
                    .font(WidgetFont.font(widgetFamily == .systemSmall ? 10 : 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(widgetFamily == .systemSmall ? 10 : 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

struct FinanceBuddySpendingWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 3) {
                Text(entry.snapshot.buddyName)
                    .font(WidgetFont.font(17))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                BuddyWidgetImageView(snapshot: entry.snapshot)
                    .frame(width: 98, height: 76)

                Text(entry.snapshot.moodTitle)
                    .font(WidgetFont.font(13))
                    .foregroundStyle(entry.snapshot.moodColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(width: 116)
            .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                spendingLine(cents: entry.snapshot.spentTodayCents, label: "day")
                spendingLine(cents: entry.snapshot.spentWeekCents ?? 0, label: "week")
                spendingLine(cents: entry.snapshot.spentMonthCents ?? 0, label: "month")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private func spendingLine(cents: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(cents.compactMoneyText)
                .font(WidgetFont.font(22))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .monospacedDigit()

            Text(label)
                .font(WidgetFont.font(12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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

            if let hatAssetName = snapshot.hatAssetName {
                Image(hatAssetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .rotationEffect(snapshot.hatRotation)
                    .offset(snapshot.hatOffset)
            } else if let hatSymbolName = snapshot.hatSymbolName {
                Image(systemName: hatSymbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .offset(y: -28)
            }
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

struct FinanceBuddySpendingWidget: Widget {
    let kind: String = "FinanceBuddySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FinanceBuddySpendingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Finance Buddy Spending")
        .description("See your buddy and spending totals.")
        .supportedFamilies([.systemMedium])
    }
}

private extension BuddyWidgetSnapshot {
    static let placeholder = BuddyWidgetSnapshot(
        buddyName: "Bean",
        mood: "happy",
        spentTodayCents: 0,
        spentWeekCents: 0,
        spentMonthCents: 0,
        dailyAllowanceCents: 0,
        catFillHue: 0.04,
        catFillSaturation: 0.48,
        catFillBrightness: 1.0,
        hatAssetKey: nil,
        hatSymbolName: nil,
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

    var dailyBudgetText: String {
        guard let dailyAllowanceCents else { return "of daily budget" }
        return "of \(dailyAllowanceCents.moneyText) daily budget"
    }

    var hatAssetName: String? {
        guard let hatAssetKey, UIImage(named: hatAssetKey) != nil else { return nil }
        return hatAssetKey
    }

    var hatOffset: CGSize {
        guard mood == "sick", hatAssetKey != nil else { return .zero }
        if hatAssetKey == "Hat_Sprout" {
            return CGSize(width: -4, height: 2)
        }
        return CGSize(width: -4, height: -4)
    }

    var hatRotation: Angle {
        guard mood == "sick", hatAssetKey != "Hat_Sprout" else { return .zero }
        return .degrees(-8)
    }
}

private extension Int {
    var moneyText: String {
        let value = Decimal(self) / 100
        return value.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
    }

    var compactMoneyText: String {
        let value = Decimal(self) / 100
        return value.formatted(
            .currency(code: Locale.current.currency?.identifier ?? "USD")
                .precision(.fractionLength(0...0))
                .notation(.compactName)
        )
    }
}

#Preview(as: .systemSmall) {
    FinanceBuddyWidget()
} timeline: {
    BuddyEntry(date: .now, snapshot: .placeholder)
}
