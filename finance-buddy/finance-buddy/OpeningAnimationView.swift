import SwiftUI
import UIKit

struct OpeningAnimationView: View {
    let frameAssetNames: [String]
    let frameDuration: TimeInterval
    let onComplete: () -> Void

    @State private var frameIndex = 0

    init(
        frameAssetNames: [String] = ["","1_Thought", "2_Thought", "3_Thought"],
        frameDuration: TimeInterval = 1.0,
        onComplete: @escaping () -> Void = {}
    ) {
        self.frameAssetNames = frameAssetNames
        self.frameDuration = frameDuration
        self.onComplete = onComplete
    }

    var body: some View {
        ZStack {
            if let currentAsset, UIImage(named: currentAsset) != nil {
                Image(currentAsset)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .offset(x: 0, y: -200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .task {
            guard !frameAssetNames.isEmpty else {
                onComplete()
                return
            }
            for index in frameAssetNames.indices {
                frameIndex = index
                if index < frameAssetNames.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(frameDuration * 1_000_000_000))
                }
            }
            onComplete()
        }
    }

    private var currentAsset: String? {
        guard frameAssetNames.indices.contains(frameIndex) else { return nil }
        return frameAssetNames[frameIndex]
    }
}
