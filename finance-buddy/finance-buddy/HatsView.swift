import SwiftUI

struct HatsView: View {
    @EnvironmentObject private var appState: AppState

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var buddy: BuddyState {
        appState.buddy ?? BuddyState(
            mood: .happy,
            spentTodayCents: 0,
            spentWeekCents: 0,
            spentMonthCents: 0,
            dailyAllowanceCents: 0,
            streak: 0,
            asOfDate: "",
            buddyName: "Buddy",
            catFillHue: nil,
            catFillSaturation: nil,
            catFillBrightness: nil,
            isLinked: false,
            hasOnboarded: true,
            ownedHats: [],
            equippedHatId: nil
        )
    }

    private var previewHat: HatItem? {
        let candidateId = appState.selectedHatId ?? appState.equippedHatId
        guard let candidateId else { return nil }
        return appState.ownedHats.first(where: { $0.id == candidateId })
    }

    private var catFillColor: Color {
        Color(hue: appState.catFillHue, saturation: 0.48, brightness: 1.0)
    }

    private var isPreviewEquipped: Bool {
        appState.selectedHatId != nil && appState.selectedHatId == appState.equippedHatId
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                topPreviewSection(height: geometry.size.height * 0.54)
                hatsGridSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .background(Color("HomeSceneDominant").ignoresSafeArea())
        .task {
            await appState.loadHats()
        }
        .navigationTitle("Hats")
    }

    @ViewBuilder
    private func topPreviewSection(height: CGFloat) -> some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottom) {
                roomBackgroundDecor

                BuddyImageView(
                    mood: effectiveMood,
                    overrideAssetName: nil,
                    fallbackSymbolName: effectiveMood.symbolName,
                    fallbackColor: moodColor,
                    hatAssetKey: previewHat?.assetKey,
                    hatSymbolName: previewHat?.symbolName,
                    fillColor: catFillColor,
                    size: min(height * 0.72, 240)
                )
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height - 54)

            Button {
                Task {
                    await appState.toggleEquipSelectedHat()
                }
            } label: {
                Text(isPreviewEquipped ? "Unequip" : "Equip")
                    .font(DoodleFont.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(previewHat == nil)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, alignment: .top)
    }

    private var hatsGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Owned hats")
                .font(DoodleFont.title3)
                .doodleTracking(-0.7)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(appState.ownedHats) { hat in
                        hatCell(hat)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(Color(.systemBackground).opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func hatCell(_ hat: HatItem) -> some View {
        let isSelected = appState.selectedHatId == hat.id
        let isEquipped = appState.equippedHatId == hat.id

        return Button {
            appState.selectHatForPreview(id: hat.id)
        } label: {
            VStack(spacing: 8) {
                Group {
                    if UIImage(named: hat.assetKey) != nil {
                        Image(hat.assetKey)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        Image(systemName: hat.symbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(height: 34)

                Text(hat.name)
                    .font(DoodleFont.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isEquipped ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hat.name)\(isEquipped ? ", equipped" : "")")
    }

    private var moodColor: Color {
        switch effectiveMood {
        case .happy: .green
        case .nervous: .yellow
        case .hungry: .orange
        case .sick: .red
        }
    }

    private var effectiveMood: BuddyMood {
        if let overridePercent = appState.devBudgetUtilOverridePercent {
            return .forBudgetUsageRatio(overridePercent / 100)
        }
        return buddy.mood
    }

    private var roomBackgroundDecor: some View {
        ZStack(alignment: .bottom) {
            Image("Plant_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(clayPotColor)
                .scaledToFit()
                .frame(width: 138, height: 138)
                .offset(x: -165, y: 10)

            Image(plantLineAssetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 138, height: 138)
                .offset(x: -165, y: 10)

            Image("Yarn_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(yarnRedColor)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .offset(x: -90, y: 30)

            Image("Yarn")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 112, height: 112)
                .offset(x: -90, y: 30)

            Image("Couch_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(couchFillColor)
                .scaledToFit()
                .frame(width: 320, height: 190)
                .offset(x: 138, y: 20)

            Image("Couch")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 320, height: 190)
                .offset(x: 138, y: 20)
        }
    }

    private var couchFillColor: Color {
        appState.isCouchAccentColor
            ? Color(red: 0.95, green: 0.62, blue: 0.66)
            : Color(red: 0.55, green: 0.70, blue: 0.86)
    }

    private var clayPotColor: Color {
        Color(red: 0.76, green: 0.42, blue: 0.30)
    }

    private var yarnRedColor: Color {
        Color(red: 0.78, green: 0.22, blue: 0.24)
    }

    private var plantLineAssetName: String {
        appState.isPlantAlive ? "Plant_Healthy" : "Plant_Dead"
    }
}
