import SwiftUI

struct NatureCompactLegendItem: View {
    let nature: SubcategoryNature
    let isSelected: Bool
    let total: Double
    let currencyCode: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(nature.color)
                    .frame(width: 8, height: 8)

                Text(nature.displayName)
                    .font(.caption)
                    .foregroundStyle(Color.primary)

                if total > 0 {
                    Text(YalaFormatter.currency(value: total, currencyCode: currencyCode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.yalaBackground : Color.clear)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .opacity(isSelected || total > 0 ? 1.0 : 0.6)
        }
    }
}
