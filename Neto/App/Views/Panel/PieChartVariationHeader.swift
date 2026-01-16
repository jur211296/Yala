//
//  PieChartVariationHeader.swift
//  Neto
//
//  Reusable header component for pie chart widgets showing period variation.
//

import SwiftUI

/// Header component for pie chart widgets that displays:
/// - Title and total amount (left)
/// - Variation chip and M/A selector (right)
/// - Comparison period text (right, below selector)
struct PieChartVariationHeader: View {

    // MARK: - Properties

    let title: String
    let totalAmount: Double
    let previousAmount: Double?
    let currencyCode: String
    let period: DetailPeriod
    let customRange: DateInterval?
    @Binding var comparisonMode: ComparisonMode

    var onShowDetail: (() -> Void)?

    // MARK: - Namespace for selector animation

    @Namespace private var selectorNamespace

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

    private var showSelector: Bool {
        PreviousPeriodHelper.isSelectorVisible(for: period)
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

            // Right: Variation chip, selector, and comparison text
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                // Row with variation chip and selector
                HStack(spacing: DS.Spacing.sm) {
                    // Variation chip
                    variationChip

                    // M/A Selector (only if visible)
                    if showSelector {
                        comparisonSelector
                    }
                }

                // Comparison period text
                if !comparisonText.isEmpty {
                    Text(comparisonText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

    // MARK: - Comparison Mode Selector

    private var comparisonSelector: some View {
        HStack(spacing: 0) {
            ForEach(ComparisonMode.allCases) { mode in
                selectorButton(for: mode)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func selectorButton(for mode: ComparisonMode) -> some View {
        let isSelected = comparisonMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                comparisonMode = mode
            }
        } label: {
            Text(mode.shortName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(
                                    id: "comparisonSelector", in: selectorNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func formattedCurrency(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        // With selector
        PieChartVariationHeader(
            title: "Distribución por categoría",
            totalAmount: 5000,
            previousAmount: 4500,
            currencyCode: "PEN",
            period: .thisMonth,
            customRange: nil,
            comparisonMode: .constant(.month)
        )
        .padding()
        .background(Color.netoCard)
        .cornerRadius(DS.Radius.xl)

        // Without selector (year period)
        PieChartVariationHeader(
            title: "Distribución por categoría",
            totalAmount: 25000,
            previousAmount: 30000,
            currencyCode: "PEN",
            period: .thisYear,
            customRange: nil,
            comparisonMode: .constant(.year)
        )
        .padding()
        .background(Color.netoCard)
        .cornerRadius(DS.Radius.xl)
    }
    .padding()
    .background(Color.netoBackground)
}
