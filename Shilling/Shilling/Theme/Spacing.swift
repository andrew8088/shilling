import SwiftUI

// MARK: - Shilling Spacing & Layout
//
// 8pt grid system with named constants.
// See docs/origin-research.md: Origin uses 8px base with 8/12/16/20/24 padding values.

enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum ShillingLayout {
    /// Card corner radius
    static let cardCornerRadius: CGFloat = 10

    /// Internal card padding
    static let cardPadding: CGFloat = Spacing.md

    /// Vertical spacing between sections
    static let sectionSpacing: CGFloat = Spacing.xl

    /// Default list row insets
    static let listRowInsets = EdgeInsets(
        top: Spacing.xs,
        leading: Spacing.sm,
        bottom: Spacing.xs,
        trailing: Spacing.sm
    )
}
