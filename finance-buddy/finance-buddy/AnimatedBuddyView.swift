import Combine
import SwiftUI

struct BuddyImageView: View {
    let mood: BuddyMood
    let overrideAssetName: String?
    let fallbackSymbolName: String
    let fallbackColor: Color
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
        }
        .frame(width: size, height: size)
        .background(fallbackColor.opacity(0.14), in: Circle())
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
        case .hungry: "Cat_Tear_Pool"
        case .sick: "Cat_Money_Spread"
        }
    }
}
