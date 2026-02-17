import SwiftUI

enum Theme {
    static let accent = Color(red: 0.18, green: 0.62, blue: 0.88)
    static let accentDeep = Color(red: 0.10, green: 0.38, blue: 0.68)
    static let accentSecondary = Color(red: 0.40, green: 0.84, blue: 0.78)
    static let accentSoft = Color(red: 0.82, green: 0.92, blue: 0.98)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.99, blue: 1.00),
            Color(red: 0.92, green: 1.00, blue: 0.95),
            Color(red: 1.00, green: 0.96, blue: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGlow = RadialGradient(
        colors: [
            Color(red: 0.16, green: 0.84, blue: 0.98).opacity(0.45),
            Color.clear
        ],
        center: .topTrailing,
        startRadius: 24,
        endRadius: 560
    )

    static let backgroundGlowSecondary = RadialGradient(
        colors: [
            Color(red: 1.00, green: 0.74, blue: 0.52).opacity(0.28),
            Color.clear
        ],
        center: .bottomLeading,
        startRadius: 40,
        endRadius: 560
    )

    static let glassFill = LinearGradient(
        colors: [
            Color.white.opacity(0.65),
            Color.white.opacity(0.35)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassStroke = LinearGradient(
        colors: [
            Color.white.opacity(0.8),
            Color.white.opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardShadow = Color.black.opacity(0.12)

    static let radiusXL: CGFloat = 28
    static let radiusLarge: CGFloat = 22
    static let radiusMedium: CGFloat = 16
    static let radiusSmall: CGFloat = 10

    static let spacingXS: CGFloat = 6
    static let spacingS: CGFloat = 10
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    static let tabBarHeight: CGFloat = 78
}
