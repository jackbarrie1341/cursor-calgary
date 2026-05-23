import Combine
import SwiftUI

struct BuddyImageView: View {
    let mood: BuddyMood
    let overrideAssetName: String?
    let fallbackSymbolName: String
    let fallbackColor: Color
    var size: CGFloat = 170

    @State private var frameIndex = 0

    private let timer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    private var assetName: String {
        overrideAssetName ?? mood.assetName
    }

    private var frameNames: [String] {
        guard assetName == "Cat_Money_Spread" else {
            return [assetName]
        }

        return [
            "Cat_Money_Spread_1",
            "Cat_Money_Spread_2",
            "Cat_Money_Spread_3",
            "Cat_Money_Spread_2"
        ]
    }

    private var currentAssetName: String {
        frameNames[min(frameIndex, frameNames.count - 1)]
    }

    var body: some View {
        ZStack {
            if UIImage(named: currentAssetName) != nil {
                Image(currentAssetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: 82, weight: .semibold))
                    .foregroundStyle(fallbackColor)
            }
        }
        .frame(width: size, height: size)
        .background(fallbackColor.opacity(0.14), in: Circle())
        .onReceive(timer) { _ in
            guard frameNames.count > 1 else { return }
            frameIndex = (frameIndex + 1) % frameNames.count
        }
        .onChange(of: assetName) { _, _ in
            frameIndex = 0
        }
        .accessibilityLabel("\(mood.title) buddy")
    }
}

extension BuddyMood {
    var assetName: String {
        switch self {
        case .happy: "Cat_Cheesing"
        case .nervous: "Cat_Worried"
        case .hungry: "Cat_Tear_Pool"
        case .sick: "Cat_Broke"
        }
    }
}
