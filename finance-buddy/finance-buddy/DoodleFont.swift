import CoreText
import SwiftUI
import UIKit

enum DoodleFont {
    private static let bodyFontName = registerFont(candidates: [
        ("BangTamvan", "ttf")
    ])

    private static let titleFontName = registerFont(candidates: [
        ("BangTamvan", "ttf")
    ])

    private static let beanTitleFontName = registerFont(candidates: [
        ("Candy Beans", "otf"),
        ("catfont2", "otf")
    ])

    private static func registerFont(candidates: [(name: String, ext: String)]) -> String {
        for candidate in candidates {
            guard
                let url = Bundle.main.url(forResource: candidate.name, withExtension: candidate.ext),
                let provider = CGDataProvider(url: url as CFURL),
                let font = CGFont(provider)
            else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            return font.postScriptName as String? ?? "MarkerFelt-Wide"
        }

        return "MarkerFelt-Wide"
    }

    static func custom(_ size: CGFloat) -> Font {
        .custom(bodyFontName, size: size)
    }

    static func titleCustom(_ size: CGFloat) -> Font {
        .custom(titleFontName, size: size)
    }

    static func beanTitleCustom(_ size: CGFloat) -> Font {
        .custom(beanTitleFontName, size: size)
    }

    static let largeTitle = titleCustom(38)
    static let homeLargeTitle = beanTitleCustom(38)
    static let title = titleCustom(28)
    static let title2 = titleCustom(24)
    static let title3 = titleCustom(21)
    static let headline = titleCustom(19)
    static let body = custom(17)
    static let subheadline = custom(15)
    static let caption = custom(13)

    static func uiFont(_ size: CGFloat) -> UIFont {
        UIFont(name: bodyFontName, size: size) ?? UIFont.systemFont(ofSize: size, weight: .semibold)
    }
}

enum DoodleAppearance {
    static func configure() {
        let normalFont = DoodleFont.uiFont(13)
        let selectedFont = DoodleFont.uiFont(13)
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .font: normalFont
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .font: selectedFont,
            .foregroundColor: UIColor.systemBlue
        ]

        let itemAppearance = UITabBarItem.appearance()
        itemAppearance.setTitleTextAttributes(normalAttributes, for: .normal)
        itemAppearance.setTitleTextAttributes(selectedAttributes, for: .selected)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        [
            tabAppearance.stackedLayoutAppearance,
            tabAppearance.inlineLayoutAppearance,
            tabAppearance.compactInlineLayoutAppearance
        ].forEach { appearance in
            appearance.normal.titleTextAttributes = normalAttributes
            appearance.selected.titleTextAttributes = selectedAttributes
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}

extension View {
    func doodleTracking(_ amount: CGFloat = -0.45) -> some View {
        tracking(amount)
    }
}
