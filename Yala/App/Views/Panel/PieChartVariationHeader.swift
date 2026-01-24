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
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 2)

                // KPI with "vs previous amount"
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    Text(formattedCurrency(totalAmount))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Show previous period value for comparison
                    if let prevAmount = previousAmount {
                        Text("vs \(YalaFormatter.number(value: prevAmount))")
                            .font(.caption)
                            .foregroundStyle(Color.yalaSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            Spacer()

            // Right: Variation chip and comparison text (show when previousAmount exists)
            if previousAmount != nil {
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
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            // Chevron for detail (if provided)
            if onShowDetail != nil {
                Button {
                    onShowDetail?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.leading, DS.Spacing.sm)
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
        .background(Color.yalaCard)
        .cornerRadius(DS.Radius.xl)

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
        .background(Color.yalaCard)
        .cornerRadius(DS.Radius.xl)
    }
    .padding()
    .background(Color.yalaBackground)
}
