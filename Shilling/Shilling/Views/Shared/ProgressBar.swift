import SwiftUI

// MARK: - ProgressBar
//
// Horizontal progress bar for budget tracking.
// Value is clamped to [0, 1]. Color can be explicit or auto-computed from value:
//   ≤ 60%  → green (under budget)
//   ≤ 85%  → yellow (nearing limit)
//   > 85%  → red (over or nearly over budget)

struct ProgressBar: View {
    let value: Double
    let color: Color?
    let height: CGFloat
    @State private var displayedValue: Double = 0

    init(value: Double, color: Color? = nil, height: CGFloat = 8) {
        self.value = value
        self.color = color
        self.height = height
    }

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var resolvedColor: Color {
        if let color { return color }
        switch clampedValue {
        case ...0.60: return .shillingPositive
        case ...0.85: return .shillingWarning
        default:      return .shillingNegative
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.shillingSurfaceSecondary)

                // Fill
                Capsule()
                    .fill(resolvedColor)
                    .frame(width: geometry.size.width * displayedValue)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.45)) {
                displayedValue = clampedValue
            }
        }
        .onChange(of: clampedValue) {
            withAnimation(.easeInOut(duration: 0.3)) {
                displayedValue = clampedValue
            }
        }
    }
}

// MARK: - Preview

#Preview("ProgressBar") {
    let items: [(String, Double)] = [
        ("30% — well under budget", 0.30),
        ("60% — at threshold", 0.60),
        ("75% — warning zone", 0.75),
        ("85% — at warning threshold", 0.85),
        ("95% — over budget", 0.95),
        ("100% — maxed out", 1.0),
        ("110% — clamped to 100%", 1.10),
        ("0% — empty", 0.0),
    ]

    VStack(alignment: .leading, spacing: Spacing.md) {
        Text("Auto-color (budget tracking)")
            .font(.shillingHeading)
            .foregroundStyle(Color.shillingTextPrimary)

        ForEach(items, id: \.0) { label, value in
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label)
                    .font(.shillingCaption)
                    .foregroundStyle(Color.shillingTextSecondary)
                ProgressBar(value: value)
            }
        }

        Divider().padding(.vertical, Spacing.xs)

        Text("Explicit color")
            .font(.shillingHeading)
            .foregroundStyle(Color.shillingTextPrimary)

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Info blue, tall (12pt)")
                .font(.shillingCaption)
                .foregroundStyle(Color.shillingTextSecondary)
            ProgressBar(value: 0.65, color: .shillingInfo, height: 12)
        }

        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Accent, slim (4pt)")
                .font(.shillingCaption)
                .foregroundStyle(Color.shillingTextSecondary)
            ProgressBar(value: 0.45, color: .shillingAccent, height: 4)
        }
    }
    .padding(Spacing.xl)
    .background(Color.shillingBackground)
    .frame(width: 380)
}
