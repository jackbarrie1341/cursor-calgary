import SwiftUI

struct TypewriterText: View {
    let text: String
    let baseCharacterDelay: TimeInterval
    let cursor: String
    let cursorBlinkInterval: TimeInterval

    @State private var revealedCount = 0
    @State private var cursorVisible = true

    init(
        _ text: String,
        baseCharacterDelay: TimeInterval = 0.045,
        cursor: String = "|",
        cursorBlinkInterval: TimeInterval = 0.5
    ) {
        self.text = text
        self.baseCharacterDelay = baseCharacterDelay
        self.cursor = cursor
        self.cursorBlinkInterval = cursorBlinkInterval
    }

    var body: some View {
        Text("\(String(text.prefix(revealedCount)))\(Text(cursor).foregroundColor(cursorVisible ? .primary : .clear))")
        .task(id: text) {
            revealedCount = 0
            cursorVisible = true

            let characters = Array(text)
            for (index, char) in characters.enumerated() {
                revealedCount = index + 1
                let delay = delayFor(character: char)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled { return }
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(cursorBlinkInterval * 1_000_000_000))
                cursorVisible.toggle()
            }
        }
    }

    private func delayFor(character: Character) -> TimeInterval {
        let jitter = Double.random(in: 0.7...1.3)
        switch character {
        case ".", "!", "?":
            return baseCharacterDelay * 6 * jitter
        case ",", ";", ":":
            return baseCharacterDelay * 3 * jitter
        case " ":
            return baseCharacterDelay * 1.4 * jitter
        default:
            return baseCharacterDelay * jitter
        }
    }
}
