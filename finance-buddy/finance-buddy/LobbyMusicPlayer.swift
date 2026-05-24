import AVFoundation
import Foundation
import UIKit

@MainActor
final class LobbyMusicPlayer {
    static let shared = LobbyMusicPlayer()

    private var player: AVAudioPlayer?
    private var isEnabled = true

    private init() {}

    func setEnabled(_ isEnabled: Bool, shouldPlay: Bool = true) {
        self.isEnabled = isEnabled
        if isEnabled, shouldPlay {
            play()
        } else {
            stop()
        }
    }

    func play() {
        guard isEnabled else { return }
        prepareIfNeeded()
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    private func stop() {
        player?.stop()
        player?.currentTime = 0
    }

    private func prepareIfNeeded() {
        guard player == nil else { return }
        guard let asset = NSDataAsset(name: "Lobby Couch Shuffle (Fade Out)") else { return }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(data: asset.data)
            player.numberOfLoops = -1
            player.volume = 0.35
            player.prepareToPlay()
            self.player = player
        } catch {
            self.player = nil
        }
    }
}
