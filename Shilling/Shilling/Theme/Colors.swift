import SwiftUI

// MARK: - Shilling Color Tokens
//
// Semantic color palette for the Shilling design system.
// Light mode is primary; dark mode support via Color(light:dark:) initializer.
// See docs/origin-research.md for design rationale.

extension Color {
    // MARK: Backgrounds

    /// Primary window background
    static let shillingBackground = Color(
        light: Color(red: 0.976, green: 0.976, blue: 0.984),  // #f9f9fb — very subtle cool gray
        dark: Color(red: 0.067, green: 0.067, blue: 0.078)    // #111114
    )

    /// Card / container surface (slightly elevated)
    static let shillingSurface = Color(
        light: .white,
        dark: Color(red: 0.118, green: 0.118, blue: 0.133)    // #1e1e22
    )

    /// Nested container / grouped background
    static let shillingSurfaceSecondary = Color(
        light: Color(red: 0.949, green: 0.949, blue: 0.957),  // #f2f2f4
        dark: Color(red: 0.153, green: 0.153, blue: 0.173)    // #27272c
    )

    // MARK: Text

    /// Primary text — high contrast
    static let shillingTextPrimary = Color(
        light: Color(red: 0.071, green: 0.071, blue: 0.094),  // #121218
        dark: Color(red: 0.961, green: 0.961, blue: 0.969)    // #f5f5f7
    )

    /// Secondary text — labels, metadata
    static let shillingTextSecondary = Color(
        light: Color(red: 0.388, green: 0.388, blue: 0.420),  // #63636b
        dark: Color(red: 0.600, green: 0.600, blue: 0.631)    // #9999a1
    )

    /// Tertiary text — placeholders, disabled
    static let shillingTextTertiary = Color(
        light: Color(red: 0.600, green: 0.600, blue: 0.624),  // #99999f
        dark: Color(red: 0.420, green: 0.420, blue: 0.451)    // #6b6b73
    )

    // MARK: Semantic

    /// Positive — income, credits, under-budget, gains
    static let shillingPositive = Color(
        light: Color(red: 0.133, green: 0.600, blue: 0.333),  // #229955
        dark: Color(red: 0.200, green: 0.729, blue: 0.420)    // #33ba6b
    )

    /// Negative — expenses over budget, debits, losses
    static let shillingNegative = Color(
        light: Color(red: 0.831, green: 0.184, blue: 0.184),  // #d42f2f
        dark: Color(red: 0.918, green: 0.318, blue: 0.318)    // #ea5151
    )

    /// Warning — budget nearing limit
    static let shillingWarning = Color(
        light: Color(red: 0.843, green: 0.616, blue: 0.098),  // #d79d19
        dark: Color(red: 0.929, green: 0.725, blue: 0.200)    // #edb933
    )

    /// Info — neutral informational highlights
    static let shillingInfo = Color(
        light: Color(red: 0.200, green: 0.467, blue: 0.808),  // #3377ce
        dark: Color(red: 0.325, green: 0.569, blue: 0.878)    // #5391e0
    )

    // MARK: Accent & Chrome

    /// Primary brand accent
    static let shillingAccent = Color(
        light: Color(red: 0.200, green: 0.467, blue: 0.808),  // #3377ce — same as info in light
        dark: Color(red: 0.325, green: 0.569, blue: 0.878)    // #5391e0
    )

    /// Subtle border / divider
    static let shillingBorder = Color(
        light: Color(red: 0.878, green: 0.878, blue: 0.894),  // #e0e0e4
        dark: Color(red: 0.220, green: 0.220, blue: 0.243)    // #38383e
    )
}

// MARK: - Color(light:dark:) initializer

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}

// MARK: - Preview

#Preview("Color Tokens") {
    let semanticColors: [(String, Color)] = [
        ("positive", .shillingPositive),
        ("negative", .shillingNegative),
        ("warning", .shillingWarning),
        ("info", .shillingInfo),
        ("accent", .shillingAccent),
    ]

    let surfaceColors: [(String, Color)] = [
        ("background", .shillingBackground),
        ("surface", .shillingSurface),
        ("surfaceSecondary", .shillingSurfaceSecondary),
        ("border", .shillingBorder),
    ]

    let textColors: [(String, Color)] = [
        ("textPrimary", .shillingTextPrimary),
        ("textSecondary", .shillingTextSecondary),
        ("textTertiary", .shillingTextTertiary),
    ]

    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            swatchSection("Surfaces", surfaceColors)
            swatchSection("Text", textColors)
            swatchSection("Semantic", semanticColors)
        }
        .padding(24)
        .background(Color.shillingBackground)
    }
    .frame(width: 400, height: 500)
}

@ViewBuilder
private func swatchSection(_ title: String, _ colors: [(String, Color)]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.headline)
        ForEach(colors, id: \.0) { name, color in
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.shillingBorder, lineWidth: 1)
                    )
                Text(name)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }
}
