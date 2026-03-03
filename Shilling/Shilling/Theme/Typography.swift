import SwiftUI

// MARK: - Shilling Type Scale
//
// Consistent typographic scale for macOS.
// Based on Origin research: clear hierarchy, monospaced digits for financial data.
// Uses SF Pro (system font) with explicit sizes and weights.

extension Font {
    /// 28pt semibold — dashboard hero numbers, net worth
    static let shillingLargeTitle: Font = .system(size: 28, weight: .semibold)

    /// 22pt semibold — view/page titles
    static let shillingTitle: Font = .system(size: 22, weight: .semibold)

    /// 17pt medium — section headers
    static let shillingHeading: Font = .system(size: 17, weight: .medium)

    /// 15pt medium — card titles, row primary text
    static let shillingSubheading: Font = .system(size: 15, weight: .medium)

    /// 14pt regular — default body text
    static let shillingBody: Font = .system(size: 14, weight: .regular)

    /// 12pt regular — metadata, timestamps, secondary info
    static let shillingCaption: Font = .system(size: 12, weight: .regular)

    /// 10pt medium — badges, tags, chart axis labels
    static let shillingLabel: Font = .system(size: 10, weight: .medium)

    /// 28pt semibold monospaced digits — large financial amounts
    static let shillingLargeTitleMono: Font = .system(size: 28, weight: .semibold).monospacedDigit()

    /// 15pt medium monospaced digits — inline financial amounts
    static let shillingAmountMono: Font = .system(size: 15, weight: .medium).monospacedDigit()

    /// 14pt regular monospaced digits — table/list amounts
    static let shillingBodyMono: Font = .system(size: 14, weight: .regular).monospacedDigit()
}

// MARK: - Preview

#Preview("Type Scale") {
    let samples: [(String, Font)] = [
        ("Large Title — $42,150.00", .shillingLargeTitle),
        ("Title — Account Overview", .shillingTitle),
        ("Heading — Recent Transactions", .shillingHeading),
        ("Subheading — Checking Account", .shillingSubheading),
        ("Body — Regular text content", .shillingBody),
        ("Caption — Updated 2 hours ago", .shillingCaption),
        ("Label — INCOME", .shillingLabel),
    ]

    let monoSamples: [(String, Font)] = [
        ("Large Title Mono — $42,150.00", .shillingLargeTitleMono),
        ("Amount Mono — $1,234.56", .shillingAmountMono),
        ("Body Mono — $99.99", .shillingBodyMono),
    ]

    ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            Text("Standard").font(.headline)
            ForEach(samples, id: \.0) { label, font in
                Text(label).font(font)
            }

            Divider().padding(.vertical, 8)

            Text("Monospaced Digits").font(.headline)
            ForEach(monoSamples, id: \.0) { label, font in
                Text(label).font(font)
            }
        }
        .padding(24)
    }
    .frame(width: 400, height: 500)
}
