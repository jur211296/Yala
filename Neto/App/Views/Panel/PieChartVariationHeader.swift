//
//  PieChartVariationHeader.swift
//  Neto
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

    private var variation: Double? {
        guard let previous = previousAmount else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: totalAmount,
            previousAmount: previous
        )
    }

    private var variationText: String {
        PreviousPeriodHelper.formatVariation(variation)
    }

    private var variationColor: Color {
        guard let variation = variation else { return .gray }
        return variation >= 0 ? .electricIndigo : .hotPink
    }

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

                Text(formattedCurrency(totalAmount))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Right: Variation chip and comparison text (only when there's comparison data)
            if variation != nil {
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    // Variation chip
                    variationChip

                    // Comparison period text
                    if !comparisonText.isEmpty {
                        Text(comparisonText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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

    // MARK: - Variation Chip

    private var variationChip: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(variationColor)
                .frame(width: 6, height: 6)

            Text(variationText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(variationColor)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            Capsule()
                .fill(variationColor.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
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
        .background(Color.netoCard)
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
        .background(Color.netoCard)
        .cornerRadius(DS.Radius.xl)
    }
    .padding()
    .background(Color.netoBackground)
}
