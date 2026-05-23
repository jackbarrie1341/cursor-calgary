import SwiftUI

struct BuddyImageView: View {
    let mood: BuddyMood
    let overrideAssetName: String?
    let fallbackSymbolName: String
    let fallbackColor: Color

    private var assetName: String {
        overrideAssetName ?? mood.assetName
    }

    var body: some View {
        ZStack {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: fallbackSymbolName)
                    .font(.system(size: 82, weight: .semibold))
                    .foregroundStyle(fallbackColor)
            }
        }
        .frame(width: 170, height: 170)
        .background(fallbackColor.opacity(0.14), in: Circle())
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
