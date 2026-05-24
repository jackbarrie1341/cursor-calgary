import SwiftUI
import UIKit

struct PurchaseReactionOverlayView: View {
    let frameAssetNames: [String]
    let frameDuration: TimeInterval

    @State private var frameIndex = 0

    init(
        frameAssetNames: [String],
        frameDuration: TimeInterval = 0.3
    ) {
        self.frameAssetNames = frameAssetNames
        self.frameDuration = frameDuration
    }

    var body: some View {
        Group {
            if let currentAsset, UIImage(named: currentAsset) != nil {
                Image(currentAsset)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            }
        }
        .allowsHitTesting(false)
        .task(id: frameAssetNames) {
            guard !frameAssetNames.isEmpty else { return }
            while !Task.isCancelled {
                for index in frameAssetNames.indices {
                    frameIndex = index
                    try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
                    if Task.isCancelled { return }
                }
            }
        }
    }

    private var currentAsset: String? {
        guard frameAssetNames.indices.contains(frameIndex) else { return nil }
        return frameAssetNames[frameIndex]
    }

    static let happyFrames = ["1_Heart", "2_Heart"]
    static let sadFrames = ["1_Mad", "2_Mad"]
}
