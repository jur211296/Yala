//
//  PivotRowView.swift
//  Yala
//
//  Row view for a single pivot table node with indentation.
//

import SwiftUI

struct PivotRowView: View {

    let node: PivotNode
    let level: Int
    let preferredCurrency: String

    @AppStorage("showVariations") private var showVariations: Bool = true

    /// Currency to use for formatting this node
    private var displayCurrency: String {
        node.currencyCode ?? preferredCurrency
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Icon area
            iconView

            // Label
            Text(node.label)
                .font(level == 0 ? DS.Typography.label : DS.Typography.subheadline)
                .fontWeight(level == 0 ? .semibold : .regular)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: DS.Spacing.sm)

            // Thin divider between label and amounts
            Divider()
                .frame(height: 28)

            // Amounts
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(YalaFormatter.currency(value: node.amount, currencyCode: displayCurrency))
                    .font(level == 0 ? DS.Typography.label : DS.Typography.subheadline)
                    .fontWeight(level == 0 ? .semibold : .regular)
                    .foregroundStyle(node.isIncome ? DS.Semantic.successForeground : .primary)

                if let previousAmount = node.previousAmount {
                    Text(YalaFormatter.currency(value: previousAmount, currencyCode: displayCurrency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)

            // Variation chip
            if showVariations {
                VariationChip(
                    variation: node.variation,
                    size: .small,
                    showNAWhenNil: node.previousAmount == nil,
                    isExpenseContext: !node.isIncome
                )
                .frame(minWidth: 52, alignment: .trailing)
            }
        }
        .padding(.leading, DS.Spacing.lg + CGFloat(max(0, level - 1)) * (DS.Spacing.lg / 2))
        .padding(.trailing, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        if node.dimension.isEntityDimension, let colorHex = node.colorHex, let iconName = node.iconName {
            // Entity dimension: colored circle with white icon
            let badgeSize = level == 0 ? DS.Icon.badgeMedium : DS.Icon.badgeSmall
            let iconSize = level == 0 ? DS.Icon.sizeMedium : DS.Icon.sizeSmall

            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: badgeSize, height: badgeSize)

                Image(systemName: iconName)
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
        } else if let colorHex = node.colorHex {
            // Has color but no icon (or non-entity) — color dot
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
        } else if let iconName = node.iconName {
            // Non-entity dimension icon (tipo, divisa, naturaleza)
            Image(systemName: iconName)
                .font(.caption2)
                .foregroundStyle(node.isIncome ? DS.Semantic.successForeground : DS.Semantic.errorForeground)
                .frame(width: DS.Chip.dotSize)
        }
    }
}
