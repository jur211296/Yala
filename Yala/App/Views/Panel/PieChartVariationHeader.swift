//
//  PieChartVariationHeader.swift
//  Yala
//
//  Reusable header component for pie chart widgets showing period variation.
//

import SwiftUI

/// Header component for pie chart widgets that displays:
/// - Title and total amount (left)
/// - Variation chip (right)
/// - Comparison period text (right, below chip)
struct PieChartVariationHeader: View {

    // MARK: - Settings

    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Properties

    let title: String
    let totalAmount: Double
    let previousAmount: Double?
    let currencyCode: String
    let period: DetailPeriod
    let customRange: DateInterval?
    let comparisonMode: ComparisonMode

    var onShowDetail: (() -> Void)?

    // MARK: - Computed Properties

    private var previousInterval: DateInterval {
        PreviousPeriodHelper.previousInterval(
            for: period,
            mode: comparisonMode,
            customRange: customRange
        )
    }

    private var comparisonText: String {
        PreviousPeriodHelper.formatComparisonText(
            previousInterval: previousInterval,
            period: period,
            mode: comparisonMode
        )
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top) {
            // Left: Title and Amount
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                    .padding(.bottom, DS.Spacing.xxs)

                // KPI with "vs previous amount"
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(formattedCurrency(totalAmount))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Show previous period value for comparison (only when showVariations is ON)
                    if appPreferences.showVariations, let prevAmount = previousAmount {
                        Text("vs \(YalaFormatter.number(value: prevAmount))")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            Spacer()

            // Right: Variation chip and comparison text (show when previousAmount exists and showVariations is ON)
            if appPreferences.showVariations && previousAmount != nil {
                VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                    // Variation chip
                    VariationChip(
                        currentAmount: totalAmount,
                        previousAmount: previousAmount,
                        size: .medium,
                        showNAWhenNil: true,
                        isExpenseContext: true
                    )

                    // Comparison period text
                    if !comparisonText.isEmpty {
                        Text(comparisonText)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

        }
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        // With variation
        PieChartVariationHeader(
            title: "Distribución por categoría",
            totalAmount: 5000,
            previousAmount: 4500,
            currencyCode: "PEN",
            period: .thisMonth,
            customRange: nil,
            comparisonMode: .month
        )
        .padding()
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))

        // Without previous data (N/A)
        PieChartVariationHeader(
            title: "Distribución por categoría",
            totalAmount: 25000,
            previousAmount: nil,
            currencyCode: "PEN",
            period: .thisYear,
            customRange: nil,
            comparisonMode: .year
        )
        .padding()
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
    }
    .padding()
    .background(.thBackground)
}
