import CoreText
import SwiftUI
import WidgetKit

private let widgetBackgroundColor = Color(red: 0.976, green: 0.961, blue: 0.925)

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
    let spentWeekCents: Int?
    let spentMonthCents: Int?
    let dailyAllowanceCents: Int?
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let hatAssetKey: String?
    let hatSymbolName: String?
    let friends: [Friend]?
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
            let url = Bundle.main.url(forResource: "BangTamvan", withExtension: "ttf"),
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
                        .font(WidgetFont.font(widgetFamily == .systemSmall ? 10 : 12))
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
        .containerBackground(widgetBackgroundColor, for: .widget)
    }
}

struct FinanceBuddySpendingWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 3) {
                Text(entry.snapshot.buddyName)
                    .font(WidgetFont.font(21))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

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
        .containerBackground(widgetBackgroundColor, for: .widget)
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
        WidgetBuddyArtView(snapshot: snapshot.displaySnapshot)
    }
}

private struct WidgetBuddyArtView: View {
    let snapshot: WidgetBuddyDisplaySnapshot

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

private struct WidgetBuddyDisplaySnapshot {
    let buddyName: String
    let mood: String
    let catFillHue: Double?
    let catFillSaturation: Double?
    let catFillBrightness: Double?
    let hatAssetKey: String?
    let hatSymbolName: String?
}

struct FinanceBuddyCrewWidgetEntryView: View {
    var entry: Provider.Entry

    private let friendPositions = [
        CGPoint(x: 0.13, y: 0.58),
        CGPoint(x: 0.35, y: 0.79),
        CGPoint(x: 0.65, y: 0.80),
        CGPoint(x: 0.89, y: 0.61)
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let centerSize = side * 0.54
            let friendSize = side * 0.29
            let friends = Array(entry.snapshot.friendDisplaySnapshots.prefix(4))

            ZStack {
                ForEach(Array(friends.enumerated()), id: \.offset) { index, friend in
                    CrewBuddyView(snapshot: friend, imageSize: friendSize, fontSize: 13)
                        .position(
                            x: proxy.size.width * friendPositions[index].x,
                            y: proxy.size.height * friendPositions[index].y
                        )
                }

                CrewBuddyView(snapshot: entry.snapshot.displaySnapshot, imageSize: centerSize, fontSize: 18, nameOffset: -14)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.37)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(widgetBackgroundColor, for: .widget)
    }
}

private struct CrewBuddyView: View {
    let snapshot: WidgetBuddyDisplaySnapshot
    let imageSize: CGFloat
    let fontSize: CGFloat
    var nameOffset: CGFloat = -9

    var body: some View {
        VStack(spacing: 0) {
            WidgetBuddyArtView(snapshot: snapshot)
                .frame(width: imageSize, height: imageSize)

            Text(snapshot.buddyName)
                .font(WidgetFont.font(fontSize))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: imageSize * 1.18)
                .offset(y: nameOffset)
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

struct FinanceBuddyCrewWidget: Widget {
    let kind: String = "FinanceBuddyCrewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            FinanceBuddyCrewWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Finance Buddy Crew")
        .description("See your buddy with up to four friends.")
        .supportedFamilies([.systemLarge])
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
        friends: [
            Friend(
                buddyName: "Miso",
                mood: "sick",
                catFillHue: 0.78,
                catFillSaturation: 0.48,
                catFillBrightness: 0.95,
                hatAssetKey: "Hat_Party",
                hatSymbolName: nil
            ),
            Friend(
                buddyName: "Nori",
                mood: "happy",
                catFillHue: 0.56,
                catFillSaturation: 0.45,
                catFillBrightness: 0.98,
                hatAssetKey: nil,
                hatSymbolName: nil
            ),
            Friend(
                buddyName: "Luna",
                mood: "nervous",
                catFillHue: 0.92,
                catFillSaturation: 0.48,
                catFillBrightness: 1.0,
                hatAssetKey: "Hat_Sprout",
                hatSymbolName: nil
            ),
            Friend(
                buddyName: "Mochi",
                mood: "hungry",
                catFillHue: 0.12,
                catFillSaturation: 0.52,
                catFillBrightness: 1.0,
                hatAssetKey: nil,
                hatSymbolName: nil
            )
        ],
        updatedAt: .now
    )

    var displaySnapshot: WidgetBuddyDisplaySnapshot {
        WidgetBuddyDisplaySnapshot(
            buddyName: buddyName,
            mood: mood,
            catFillHue: catFillHue,
            catFillSaturation: catFillSaturation,
            catFillBrightness: catFillBrightness,
            hatAssetKey: hatAssetKey,
            hatSymbolName: hatSymbolName
        )
    }

    var friendDisplaySnapshots: [WidgetBuddyDisplaySnapshot] {
        (friends ?? []).map {
            WidgetBuddyDisplaySnapshot(
                buddyName: $0.buddyName,
                mood: $0.mood,
                catFillHue: $0.catFillHue,
                catFillSaturation: $0.catFillSaturation,
                catFillBrightness: $0.catFillBrightness,
                hatAssetKey: $0.hatAssetKey,
                hatSymbolName: $0.hatSymbolName
            )
        }
    }

    var moodTitle: String {
        switch mood {
        case "nervous": "Nervous"
        case "hungry": "Broke"
        case "sick": "Flexing"
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
        case "hungry": .red
        case "sick": Color(red: 0.05, green: 0.62, blue: 0.30)
        default: Color(red: 0.30, green: 0.72, blue: 0.38)
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
}

private extension WidgetBuddyDisplaySnapshot {
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

    var catFillColor: Color {
        Color(
            hue: catFillHue ?? 0.04,
            saturation: catFillSaturation ?? 0.48,
            brightness: catFillBrightness ?? 1.0
        )
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
