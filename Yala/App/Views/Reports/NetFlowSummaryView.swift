//
//  NetFlowSummaryView.swift
//  Yala
//
//  Summary view showing net cash flow with comparison.
//

import SwiftUI

struct NetFlowSummaryView: View {

    let currentAmount: Double
    let previousAmount: Double?
    let variation: Double?
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences
    private var showVariations: Bool { appPreferences.showVariations }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Icon matching TrendsTabView balance
            Image(systemName: TrendType.balance.iconName)
                .font(.caption2)
                .foregroundStyle(.primary)
                .frame(width: DS.Chip.dotSize)

            // Label
            Text(L10n.Report.netFlow)
                .font(DS.Typography.label)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer(minLength: DS.Spacing.sm)

            // Thin divider
            Divider()
                .frame(height: 28)

            // Amounts
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                Text(appPreferences.currency(currentAmount, currencyCode: currencyCode))
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(currentAmount >= 0 ? Color.electricIndigo : Color.hotPink)

                if let previousAmount {
                    Text(appPreferences.currency(previousAmount, currencyCode: currencyCode))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 80, alignment: .trailing)

            if showVariations {
                VariationChip(
                    variation: variation,
                    size: .small,
                    showNAWhenNil: previousAmount == nil,
                    isExpenseContext: false
                )
                .frame(minWidth: 52, alignment: .trailing)
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }
}
