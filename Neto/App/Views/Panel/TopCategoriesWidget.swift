//
//  TopCategoriesWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct TopCategoriesWidget: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedCategoryID: PersistentIdentifier?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?

    // Placeholder for future navigation
    var onShowMore: (() -> Void)? = nil

    // MARK: - Layout Variants

    enum CardSize {
        case large
        case medium
        case small
    }

    var size: CardSize = .large
    var limit: Int? = nil  // nil = show all

    // MARK: - Period Comparison

    var period: DetailPeriod = .thisMonth
    var previousTotalAmount: Double? = nil
    var showVariationHeader: Bool = false

    private var totalAmount: Double {
        categories.reduce(0) { $0 + $1.amount }
    }

    private var variation: Double? {
        guard let previous = previousTotalAmount else { return nil }
        return PreviousPeriodHelper.calculateVariation(
            currentAmount: totalAmount,
            previousAmount: previous
        )
    }

    private var previousInterval: DateInterval {
        PreviousPeriodHelper.previousInterval(for: period, mode: .month, customRange: nil)
    }

    private var comparisonText: String {
        PreviousPeriodHelper.formatComparisonText(
            previousInterval: previousInterval,
            period: period,
            mode: .month
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? DS.Spacing.md : DS.Spacing.lg) {
            headerSection

            if categories.isEmpty {
                emptyState
            } else {
                contentForSize
            }
        }
        .padding(size == .small ? DS.Spacing.lg : DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Content Switcher

    @ViewBuilder
    private var contentForSize: some View {
        switch size {
        case .large:
            categoriesList(limit: limit ?? 5)
        case .medium:
            categoriesList(limit: limit ?? 3)
        case .small:
            smallCardContent
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .top) {
            // Left: Title and total amount
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(size == .small ? L10n.Widget.main : L10n.Widget.topCategories)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Total amount (only for medium/large with variation header)
                if showVariationHeader && size != .small && !categories.isEmpty {
                    Text(NetoFormatter.currency(value: totalAmount, currencyCode: currencyCode))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            // Right: Variation chip and comparison text (only when showVariationHeader and has data)
            if showVariationHeader && size != .small && !categories.isEmpty && variation != nil {
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    VariationChip(variation: variation, size: .medium)

                    if !comparisonText.isEmpty {
                        Text(comparisonText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Chevron for Detail View
            if onShowMore != nil {
                Button {
                    onShowMore?()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(Color.gray.opacity(0.7))
                        .padding(.leading, DS.Spacing.xs)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Lists (Large & Medium)

    private func categoriesList(limit: Int) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            if let maxAmount = categories.first?.amount {
                let displayedCategories =
                    limit >= categories.count ? categories : Array(categories.prefix(limit))
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryID == summary.category.persistentModelID
                    let isAnySelected = selectedCategoryID != nil
                    let shouldDim = isAnySelected && !isSelected

                    CategoryRow(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode,
                        showNAWhenNil: showVariationHeader
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)  // Dimming effect
                    .contentShape(Rectangle())  // Make entire row tappable
                    .onTapGesture {
                        if isSelected {
                            // Deselect if already selected?
                            // Requirements "filter that category". Maybe tap again to deselect is good UX.
                            // But usually close chip to deselect. Let's strictly follow "filter that category".
                            // If I tap again, I might want to do nothing or re-select.
                            // Let's assume onSelectCategory handles the toggle or just sets it.
                            onSelectCategory?(summary.category.persistentModelID)
                        } else {
                            onSelectCategory?(summary.category.persistentModelID)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Small Card Content

    private var smallCardContent: some View {
        // Show only the top 1 category in a focused way
        Group {
            if let topCategory = categories.first {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Large Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: topCategory.category.colorHex))
                            .frame(width: 48, height: 48)  // Slightly smaller for dense layout

                        Image(systemName: topCategory.category.iconName ?? "tag.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(topCategory.category.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(formattedAmount(topCategory.amount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        Text(
                            "\(formattedPercentage(topCategory.percentage)) \(L10n.Widget.ofTotal)"
                        )
                        .font(.caption2.bold())
                        .foregroundStyle(Color(hex: topCategory.category.colorHex))
                        .padding(.horizontal, DS.Spacing.xs)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Color(hex: topCategory.category.colorHex).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DS.Spacing.sm)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectCategory?(topCategory.category.persistentModelID)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            if size == .small {
                Spacer()  // Push down
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(L10n.Empty.noExpenses)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()  // Push up
            } else {
                Image(systemName: "creditcard")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, DS.Spacing.xs)

                Text(L10n.Widget.noExpensesPeriod)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(L10n.Widget.noExpensesDescriptionCategories)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill available space
        .padding(.vertical, size == .small ? 0 : DS.Spacing.xxl)
    }

    // Helpers (moved inside View to be accessible)
    private func formattedAmount(_ value: Double) -> String {
        NetoFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Category Row Component

private struct CategoryRow: View {
    let summary: CategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showNAWhenNil: Bool = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.category.colorHex))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                Image(systemName: summary.category.iconName ?? "tag.fill")  // Use actual category icon
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(NetoFormatter.currency(value: summary.amount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentage)) \(L10n.Widget.ofExpense)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Variation chip (aligned to right)
                        VariationChip(variation: summary.variation, size: .small, showNAWhenNil: showNAWhenNil)
                    }

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.category.colorHex))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
