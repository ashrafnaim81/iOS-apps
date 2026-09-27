import SwiftUI
import UIKit

enum Theme {
    static let accent = Color(hex: 0x2A7BF6)
    static let accentDeep = Color(hex: 0x123FB0)
    static let gold = Color(hex: 0xFFC53D)

    static let background = dynamic(light: 0xF3F6FC, dark: 0x0C1120)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x171E33)
    static let surfaceAlt = dynamic(light: 0xE8EEF8, dark: 0x222B45)
    static let ink = dynamic(light: 0x0F1A33, dark: 0xE8EDF8)
    static let inkSoft = dynamic(light: 0x5B6784, dark: 0x9AA6C3)
    static let userDigit = dynamic(light: 0x2366DB, dark: 0x7AA9FF)
    static let thinLine = dynamic(light: 0xD5DCEA, dark: 0x2C3651)
    static let thickLine = dynamic(light: 0x27407F, dark: 0x8AA6E8)
    static let related = dynamic(light: 0xEAF1FE, dark: 0x1C2744)
    static let sameNumber = dynamic(light: 0xCFE0FD, dark: 0x294275)
    static let selected = dynamic(light: 0xA7C6FB, dark: 0x3B63B3)
    static let error = dynamic(light: 0xD93B40, dark: 0xFF6B6F)
    static let errorBackground = dynamic(light: 0xFDE7E8, dark: 0x4A1D26)

    static let brandGradient = LinearGradient(
        colors: [Color(hex: 0x3A8BFF), Color(hex: 0x1D4FCB), Color(hex: 0x14307F)],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }
}
