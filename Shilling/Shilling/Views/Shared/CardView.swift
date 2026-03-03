import SwiftUI

// MARK: - CardView
//
// Generic container with surface background, rounded corners, and optional border.
// Use this as the standard card wrapper throughout the app.

struct CardView<Content: View>: View {
    let bordered: Bool
    @ViewBuilder let content: () -> Content

    init(bordered: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.bordered = bordered
        self.content = content
    }

    var body: some View {
        content()
            .padding(ShillingLayout.cardPadding)
            .background(Color.shillingSurface)
            .clipShape(RoundedRectangle(cornerRadius: ShillingLayout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: ShillingLayout.cardCornerRadius)
                    .stroke(Color.shillingBorder, lineWidth: bordered ? 1 : 0)
            )
    }
}

// MARK: - Preview

#Preview("CardView") {
    VStack(spacing: Spacing.md) {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Bordered Card (default)")
                    .font(.shillingHeading)
                    .foregroundStyle(Color.shillingTextPrimary)
                Text("This card has a subtle border.")
                    .font(.shillingBody)
                    .foregroundStyle(Color.shillingTextSecondary)
            }
        }

        CardView(bordered: false) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Borderless Card")
                    .font(.shillingHeading)
                    .foregroundStyle(Color.shillingTextPrimary)
                Text("This card has no border — relies on background contrast.")
                    .font(.shillingBody)
                    .foregroundStyle(Color.shillingTextSecondary)
            }
        }

        CardView {
            HStack {
                Text("Compact card with icon")
                    .font(.shillingSubheading)
                    .foregroundStyle(Color.shillingTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.shillingTextTertiary)
            }
        }
    }
    .padding(Spacing.xl)
    .background(Color.shillingBackground)
    .frame(width: 400)
}
