import SwiftUI

// MARK: - SectionHeader
//
// Styled section header with title, optional subtitle (e.g., a total or count),
// and an optional trailing action button.

struct SectionHeader: View {
    let title: String
    let subtitle: String?
    let action: (() -> Void)?
    let actionLabel: String?

    init(
        _ title: String,
        subtitle: String? = nil,
        action: (() -> Void)? = nil,
        actionLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.actionLabel = actionLabel
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.shillingHeading)
                    .foregroundStyle(Color.shillingTextPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.shillingCaption)
                        .foregroundStyle(Color.shillingTextSecondary)
                }
            }

            Spacer()

            if let action, let actionLabel {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderless)
                    .font(.shillingBody)
                    .foregroundStyle(Color.shillingAccent)
            }
        }
    }
}

// MARK: - Preview

#Preview("SectionHeader") {
    VStack(spacing: Spacing.xl) {
        SectionHeader("Recent Transactions")

        Divider()

        SectionHeader(
            "Accounts",
            subtitle: "5 accounts"
        )

        Divider()

        SectionHeader(
            "Budget",
            subtitle: "March 2026",
            action: {},
            actionLabel: "See All"
        )

        Divider()

        SectionHeader(
            "Income",
            action: {},
            actionLabel: "Add"
        )
    }
    .padding(Spacing.xl)
    .background(Color.shillingBackground)
    .frame(width: 420)
}
