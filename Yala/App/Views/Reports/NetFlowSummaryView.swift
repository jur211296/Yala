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
                .font(DS.Typography.captionSmall)
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
                .frame(height: DS.Sizing.dividerHeightStandard)

            // Amounts
            VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                AmountText(
                    value: currentAmount,
                    currencyCode: currencyCode,
                    font: DS.Typography.label.weight(.semibold),
                    tint: .color(currentAmount >= 0 ? Color.electricIndigo : Color.hotPink)
                )

                if let previousAmount {
                    AmountText(
                        value: previousAmount,
                        currencyCode: currencyCode,
                        font: DS.Typography.captionSmall,
                        secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary
                    )
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
