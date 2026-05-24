import Combine
import SwiftUI

struct BuddyImageView: View {
    let mood: BuddyMood
    let overrideAssetName: String?
    let fallbackSymbolName: String
    let fallbackColor: Color
    var hatAssetKey: String?
    var hatSymbolName: String?
    var fillColor: Color = Color(hue: 0.04, saturation: 0.45, brightness: 1.0)
    var size: CGFloat = 170

    @State private var frameIndex = 0

    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    private var assetName: String {
        overrideAssetName ?? mood.assetName
    }

    private var frames: [BuddyImageFrame] {
        BuddyImageFrame.frames(for: assetName)
    }

    private var currentFrame: BuddyImageFrame {
        frames[min(frameIndex, frames.count - 1)]
    }

    private var currentFrameNumber: Int {
        min(frameIndex, frames.count - 1) + 1
    }

    private var moneySpreadHatAdjustment: (offset: CGSize, rotation: Angle) {
        guard assetName == "Cat_Money_Spread", let hatAssetKey else {
            return (.zero, .zero)
        }
        switch hatAssetKey {
        case "Hat_Sprout":
            return (CGSize(width: -size * 0.05, height: size * 0.03), .zero)
        default:
            return (
                CGSize(width: -size * 0.05, height: -size * 0.04),
                .degrees(-8)
            )
        }
    }

    private var currentHatAssetName: String? {
        guard let hatAssetKey else { return nil }
        let frameSpecificName = "\(hatAssetKey)_\(currentFrameNumber)"
        if UIImage(named: frameSpecificName) != nil {
            return frameSpecificName
        }
        if UIImage(named: hatAssetKey) != nil {
            return hatAssetKey
        }
        return nil
    }

    var body: some View {
        ZStack {
            if let fillAssetName = currentFrame.fillAssetName, UIImage(named: fillAssetName) != nil {
                Image(fillAssetName)
                    .resizable()
                    .interpolation(.none)
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(fillColor)
            }

            if UIImage(named: currentFrame.lineAssetName) != nil {
                Image(currentFrame.lineAssetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else if currentFrame.fillAssetName == nil {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: 82, weight: .semibold))
                    .foregroundStyle(fallbackColor)
            }

            if let currentHatAssetName {
                Image(currentHatAssetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .rotationEffect(moneySpreadHatAdjustment.rotation)
                    .offset(moneySpreadHatAdjustment.offset)
            } else if let hatSymbolName {
                Image(systemName: hatSymbolName)
                    .font(.system(size: size * 0.2, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                    .offset(y: -size * 0.33)
            }
        }
        .frame(width: size, height: size)
        .onReceive(timer) { _ in
            guard frames.count > 1 else { return }
            frameIndex = (frameIndex + 1) % frames.count
        }
        .onChange(of: assetName) { _, _ in
            frameIndex = 0
        }
        .accessibilityLabel("\(mood.title) buddy")
    }
}

private struct BuddyImageFrame {
    let lineAssetName: String
    let fillAssetName: String?

    static func frames(for assetName: String) -> [BuddyImageFrame] {
        switch assetName {
        case "Cat_Cheesing":
            [
                BuddyImageFrame(lineAssetName: "1_Cat_Cheesing", fillAssetName: "1_Fill_Cat_Cheesing"),
                BuddyImageFrame(lineAssetName: "2_Cat_Cheesing", fillAssetName: "2_Fill_Cat_Cheesing")
            ]
        case "Cat_Worried":
            [
                BuddyImageFrame(lineAssetName: "1_Cat_Worried", fillAssetName: "1_2_Fill_Cat_Worried"),
                BuddyImageFrame(lineAssetName: "2_Cat_Worried", fillAssetName: "1_2_Fill_Cat_Worried")
            ]
        case "Cat_Money_Spread":
            [
                BuddyImageFrame(lineAssetName: "Cat_Money_Spread_1", fillAssetName: "1_Fill_Cat_Money_Spread"),
                BuddyImageFrame(lineAssetName: "Cat_Money_Spread_2", fillAssetName: "2_Fill_Cat_Money_Spread"),
                BuddyImageFrame(lineAssetName: "Cat_Money_Spread_3", fillAssetName: "3_Fill_Cat_Money_Spread"),
                BuddyImageFrame(lineAssetName: "Cat_Money_Spread_2", fillAssetName: "2_Fill_Cat_Money_Spread")
            ]
        case "Cat_Broke":
            [
                BuddyImageFrame(lineAssetName: "1_Cat_Broke", fillAssetName: "1_2_Fill_Cat_Broke"),
                BuddyImageFrame(lineAssetName: "2_Cat_Broke", fillAssetName: "1_2_Fill_Cat_Broke")
            ]
        default:
            [
                BuddyImageFrame(lineAssetName: assetName, fillAssetName: nil)
            ]
        }
    }
}

extension BuddyMood {
    var assetName: String {
        switch self {
        case .happy: "Cat_Cheesing"
        case .nervous: "Cat_Worried"
        case .hungry: "Cat_Broke"
        case .sick: "Cat_Money_Spread"
        }
    }
}
