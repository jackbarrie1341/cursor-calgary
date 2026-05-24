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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("HomeSceneDominant").opacity(0.95),
                                Color("HomeSceneDominant").opacity(0.68)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )

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
                    if let thumbnail = HatThumbnailCache.image(named: hat.assetKey) {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        Image(systemName: hat.symbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(height: 44)

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
        appState.displayMood(for: buddy)
    }

    private var roomBackgroundDecor: some View {
        ZStack(alignment: .bottom) {
            Image("Plant_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(Color.green.opacity(0.35))
                .scaledToFit()
                .frame(width: 84, height: 84)
                .offset(x: -122, y: 9)

            Image(plantLineAssetName)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 84, height: 84)
                .offset(x: -122, y: 9)

            Image("Couch_Fill")
                .resizable()
                .interpolation(.none)
                .renderingMode(.template)
                .foregroundStyle(couchFillColor)
                .scaledToFit()
                .frame(width: 238, height: 132)
                .offset(x: 16, y: 18)

            Image("Couch")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 238, height: 132)
                .offset(x: 16, y: 18)
        }
    }

    private var couchFillColor: Color {
        appState.isCouchAccentColor
            ? Color(red: 0.95, green: 0.62, blue: 0.66)
            : Color(red: 0.55, green: 0.70, blue: 0.86)
    }

    private var plantLineAssetName: String {
        appState.isPlantAlive ? "Plant_Healthy" : "Plant_Dead"
    }
}

private enum HatThumbnailCache {
    private static var cache: [String: UIImage] = [:]

    static func image(named assetName: String) -> UIImage? {
        if let cached = cache[assetName] {
            return cached
        }
        guard let image = UIImage(named: assetName) else { return nil }
        let trimmed = image.trimmingTransparentPixels() ?? image
        cache[assetName] = trimmed
        return trimmed
    }
}

private extension UIImage {
    func trimmingTransparentPixels(alphaThreshold: UInt8 = 8) -> UIImage? {
        guard let cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * bytesPerRow) + (x * bytesPerPixel) + 3]
                guard alpha > alphaThreshold else { continue }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
    }
}
