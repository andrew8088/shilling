import SwiftUI

struct EmptyStateView: View {
    struct ActionItem {
        let title: String
        let systemImage: String?
        let isPrimary: Bool
        let action: () -> Void

        init(
            _ title: String,
            systemImage: String? = nil,
            isPrimary: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.isPrimary = isPrimary
            self.action = action
        }
    }

    let icon: String
    let title: String
    let message: String
    let actions: [ActionItem]

    init(icon: String, title: String, message: String, actions: [ActionItem] = []) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Color.shillingTextTertiary)
            Text(title)
                .font(.shillingHeading)
                .foregroundStyle(Color.shillingTextPrimary)
            Text(message)
                .font(.shillingBody)
                .foregroundStyle(Color.shillingTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if !actions.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                        if item.isPrimary {
                            Button(action: item.action) {
                                if let systemImage = item.systemImage {
                                    Label(item.title, systemImage: systemImage)
                                } else {
                                    Text(item.title)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: item.action) {
                                if let systemImage = item.systemImage {
                                    Label(item.title, systemImage: systemImage)
                                } else {
                                    Text(item.title)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
