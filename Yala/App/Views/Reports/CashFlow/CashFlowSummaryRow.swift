//
//  CashFlowSummaryRow.swift
//  Yala
//
//  Sticky bottom summary showing available and accumulated balance per month.
//

import SwiftUI

struct CashFlowSummaryRow: View {
    let months: [CashFlowMonth]
    let nameColumnWidth: CGFloat
    let monthColumnWidth: CGFloat
    let currencyCode: String

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            Divider()

            // Available (net flow per month)
            summaryLine(
                label: L10n.CashFlowPlan.available,
                values: months.map(\.netFlow)
            )

            Divider()

            // Accumulated
            summaryLine(
                label: L10n.CashFlowPlan.accumulated,
                values: months.map(\.accumulatedBalance)
            )
        }
        .background(.thCard)
    }

    private func summaryLine(label: String, values: [Double]) -> some View {
        HStack(spacing: DS.Spacing.none) {
            // Name column
            Text(label)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .frame(width: nameColumnWidth, alignment: .leading)
                .padding(.leading, DS.Spacing.md)

            // Scrollable values
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.none) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        Text(YalaFormatter.currencyCompact(value: value, currencyCode: currencyCode))
                            .font(DS.Typography.amountSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(value >= 0 ? DS.Semantic.successForeground : DS.Semantic.errorForeground)
                            .frame(width: monthColumnWidth)
                    }
                }
            }
        }
        .frame(height: 36)
    }

}
