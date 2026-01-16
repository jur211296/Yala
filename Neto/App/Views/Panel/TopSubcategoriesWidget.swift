//
//  TopSubcategoriesWidget.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

struct TopSubcategoriesWidget: View {
    let subcategories: [SubcategorySpendingSummary]
    let currencyCode: String

    // Filter State
    // "Global" category filter (from Top Spending widget)
    let globalCategoryFilterID: PersistentIdentifier?

    // "Local" widget filter (controlled by this widget's dropdown)
    @Binding var localCategoryFilterID: PersistentIdentifier?

    // Action when a subcategory is tapped (now uses PersistentIdentifier)
    var onSelectSubcategory: ((PersistentIdentifier) -> Void)?

    // Selected Subcategory IDs (for dimming others) - uses PersistentIdentifier for uniqueness
    var selectedSubcategoryIDs: Set<PersistentIdentifier> = []

    // Navigation Action
    var onShowMore: (() -> Void)? = nil

    // Size config
    var size: TopCategoriesWidget.CardSize = .large

    // MARK: - Period Comparison

    var period: DetailPeriod = .thisMonth
    var previousTotalAmount: Double? = nil
    var showVariationHeader: Bool = false

    private var totalAmount: Double {
        subcategories.reduce(0) { $0 + $1.amount }
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

    // Fetch all categories for the dropdown
    @Query(sort: \Category.name) private var allCategories: [Category]

    var body: some View {
        VStack(alignment: .leading, spacing: size == .small ? DS.Spacing.md : DS.Spacing.lg) {
            headerSection

            if subcategories.isEmpty {
                emptyState
            } else {
                contentForSize
            }
        }
        .padding(size == .small ? DS.Spacing.lg : DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
        .id(subcategories.isEmpty ? "empty" : "content-\(subcategories.count)")
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Row 1: Title + Variation + Chevron
            HStack(alignment: .top) {
                // Left: Title and total amount
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    if size == .small {
                        Text(L10n.Widget.subcategories)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text(L10n.Widget.topSubcategories)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Total amount (only with variation header)
                        if showVariationHeader && !subcategories.isEmpty {
                            Text(NetoFormatter.currency(value: totalAmount, currencyCode: currencyCode))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Spacer()

                // Right: Variation chip and comparison text (only when showVariationHeader and has data)
                if showVariationHeader && size != .small && !subcategories.isEmpty && variation != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        VariationChip(variation: variation, size: .medium)

                        if !comparisonText.isEmpty {
                            Text(comparisonText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Chevron (conditionally shown)
                if onShowMore != nil {
                    Button {
                        onShowMore?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline)
                            .foregroundStyle(Color.gray.opacity(0.7))
                            .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Row 2: Selector (Only Medium/Large)
            if size != .small {
                categorySelector
            }
        }
    }

    private var categorySelector: some View {
        Group {
            if let globalID = globalCategoryFilterID,
                let category = allCategories.first(where: { $0.persistentModelID == globalID })
            {
                // Locked State (Global Filter Active)
                HStack(spacing: 4) {
                    Image(systemName: category.iconName ?? "tag.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: category.colorHex))

                    Text(category.name)
                        .font(.caption.weight(.medium))

                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            } else {
                // Interactive State (Local Filter)
                // Interactive State (Local Filter)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // "Todas" Chip
                        Button {
                            localCategoryFilterID = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                    .font(.caption2)
                                Text(L10n.Common.all)
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(localCategoryFilterID == nil ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        localCategoryFilterID == nil
                                            ? Color.electricIndigo : Color.gray.opacity(0.1))
                            )
                        }

                        // Category Chips
                        ForEach(allCategories) { category in
                            let isSelected = localCategoryFilterID == category.persistentModelID
                            Button {
                                localCategoryFilterID = category.persistentModelID
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: category.iconName ?? "tag.fill")
                                        .font(.caption2)
                                    Text(category.name)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? Color(hex: category.colorHex)
                                                : Color.gray.opacity(0.1))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 1)  // Tiny padding for shadow/clip safety
                }
            }
        }
    }

    private var currentFilterName: String {
        if let localID = localCategoryFilterID,
            let category = allCategories.first(where: { $0.persistentModelID == localID })
        {
            return category.name
        }
        return L10n.Common.all
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForSize: some View {
        switch size {
        case .large:
            subcategoriesList(limit: 5)
        case .medium:
            subcategoriesList(limit: 3)
        case .small:
            smallCardContent
        }
    }

    // MARK: - Lists

    private func subcategoriesList(limit: Int) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Filter subcategories by local category filter first
            let filteredSubcategories: [SubcategorySpendingSummary] = {
                if let localFilterID = localCategoryFilterID {
                    return subcategories.filter { $0.category?.persistentModelID == localFilterID }
                }
                return subcategories
            }()

            // Find max amount for bar scaling from filtered list
            if let maxAmount = filteredSubcategories.first?.amount {
                let displayed = Array(filteredSubcategories.prefix(limit))
                ForEach(displayed) { summary in
                    let isSelected = summary.persistentID.map { selectedSubcategoryIDs.contains($0) } ?? false
                    let isDimmed = !selectedSubcategoryIDs.isEmpty && !isSelected

                    SubcategoryRow(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode
                    )
                    .opacity(isDimmed ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let persistentID = summary.persistentID {
                            onSelectSubcategory?(persistentID)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Small Content

    private var smallCardContent: some View {
        Group {
            if let top = subcategories.first {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: top.colorHex ?? "#888888"))
                            .frame(width: 48, height: 48)

                        Image(
                            systemName: top.subcategory?.iconName ?? top.category?.iconName
                                ?? "tag.fill"
                        )
                        .font(.headline)
                        .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(top.subcategoryName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(formattedAmount(top.amount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        // % of Category (Most relevant context for subcats)
                        HStack(spacing: 4) {
                            Text(
                                "\(formattedPercentage(top.percentageOfCategory)) \(String(format: L10n.Widget.of, top.category?.name ?? L10n.Widget.categoryAbbr))"
                            )
                            .font(.caption2.bold())
                            .foregroundStyle(Color(hex: top.colorHex ?? "#888888"))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: top.colorHex ?? "#888888").opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let persistentID = top.persistentID {
                        onSelectSubcategory?(persistentID)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            if size == .small {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                Text(L10n.Empty.noExpenses)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary.opacity(0.5))
                    .padding(.bottom, 4)

                Text(L10n.Widget.noExpensesPeriod)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(L10n.Widget.noExpensesDescriptionSubcategories)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: size == .small ? 120 : 180)
        .padding(.vertical, size == .small ? DS.Spacing.md : DS.Spacing.xxl)
    }

    // MARK: - Formatters

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

// MARK: - Subcategory Row

private struct SubcategoryRow: View {
    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                // Name + Amount
                HStack(spacing: DS.Spacing.md) {
                    // Icon (Default placeholder as requested)
                    ZStack {
                        Circle()
                            .fill(Color(hex: summary.colorHex ?? "#888888"))
                            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                        Image(
                            systemName: summary.subcategory?.iconName ?? summary.category?.iconName
                                ?? "tag.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        // Name and Amount
                        HStack {
                            Text(summary.subcategoryName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(
                                NetoFormatter.currency(
                                    value: summary.amount, currencyCode: currencyCode)
                            )
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        }

                        // Percentages + Variation Chip (inline, chip aligned right)
                        HStack(spacing: DS.Spacing.sm) {
                            Text(
                                "\(formattedPercentage(summary.percentageOfCategory)) \(String(format: L10n.Widget.of, summary.category?.name ?? L10n.Widget.categoryAbbr))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary.opacity(0.5))

                            Text(
                                "\(formattedPercentage(summary.percentageOfTotal)) \(L10n.Widget.ofTotal)"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                            Spacer()

                            // Variation chip (aligned to right)
                            VariationChip(variation: summary.variation, size: .small)
                        }

                        // Bar
                        GeometryReader { geo in
                            let width =
                                maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.1)).frame(height: 6)
                                Capsule().fill(Color(hex: summary.colorHex ?? "#888888")).frame(
                                    width: width, height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
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
