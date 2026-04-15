//
//  TopSubcategoriesWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

private let sharedPercentFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 1
    return formatter
}()

struct TopSubcategoriesWidget: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var viewModel = TopSubcategoriesWidgetViewModel()

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
    var isExcludeMode: Bool = false

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
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
        .id(subcategories.isEmpty ? "empty" : "content-\(subcategories.count)")
        .onAppear {
            viewModel.setContext(modelContext)
        }
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
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    } else {
                        Text(L10n.Widget.topSubcategories)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Total amount with vs comparison (only with variation header)
                        if showVariationHeader && !subcategories.isEmpty {
                            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                                Text(YalaFormatter.currency(value: totalAmount, currencyCode: currencyCode))
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                if let prevAmount = previousTotalAmount {
                                    Text("vs \(YalaFormatter.number(value: prevAmount))")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.thSecondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                            }
                        }
                    }
                }

                if size != .small {
                    InfoHintButton(
                        title: L10n.WidgetType.topSubcategories,
                        message: L10n.Widget.Hint.topSubcategories
                    )
                }

                Spacer()

                // Right: Variation chip and comparison text (only when showVariationHeader and has data)
                if showVariationHeader && size != .small && !subcategories.isEmpty && variation != nil {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        VariationChip(variation: variation, size: .medium)

                        if !comparisonText.isEmpty {
                            Text(comparisonText)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }

                // Chevron (conditionally shown)
                if onShowMore != nil {
                    Button {
                        onShowMore?()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.headline)
                            .foregroundStyle(.secondary)
                            .padding(.leading, DS.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Accessibility.showMoreSubcategories)
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
                let category = viewModel.allCategories.first(where: { $0.persistentModelID == globalID })
            {
                // Locked State (Global Filter Active)
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: category.iconName ?? "tag.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(Color(hex: category.colorHex))
                        .accessibilityHidden(true)

                    Text(category.name)
                        .font(DS.Typography.labelSmall)

                    Image(systemName: "lock.fill")
                        .font(DS.Typography.captionSmall)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Semantic.neutralBackground)
                .clipShape(Capsule())
            } else {
                // Interactive State (Local Filter)
                // Interactive State (Local Filter)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // "Todas" Chip
                        Button {
                            localCategoryFilterID = nil
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "list.bullet")
                                    .font(DS.Typography.captionSmall)
                                Text(L10n.Common.all)
                                    .font(DS.Typography.labelSmall)
                            }
                            .foregroundStyle(localCategoryFilterID == nil ? .white : .primary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Chip.paddingV)
                            .background(
                                Capsule()
                                    .fill(
                                        localCategoryFilterID == nil
                                            ? theme.accent : DS.Semantic.neutralBackground)
                            )
                        }

                        // Category Chips
                        ForEach(viewModel.allCategories) { category in
                            let isSelected = localCategoryFilterID == category.persistentModelID
                            Button {
                                localCategoryFilterID = category.persistentModelID
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Image(systemName: category.iconName ?? "tag.fill")
                                        .font(DS.Typography.captionSmall)
                                    Text(category.name)
                                        .font(DS.Typography.labelSmall)
                                }
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Chip.paddingV)
                                .background(
                                    Capsule()
                                        .fill(
                                            isSelected
                                                ? Color(hex: category.colorHex)
                                                : DS.Semantic.neutralBackground)
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
        viewModel.categoryName(forID: localCategoryFilterID)
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

            // In exclude mode, hide excluded items entirely
            let visibleSubcategories: [SubcategorySpendingSummary] = {
                if isExcludeMode && !selectedSubcategoryIDs.isEmpty {
                    return filteredSubcategories.filter {
                        guard let id = $0.persistentID else { return true }
                        return !selectedSubcategoryIDs.contains(id)
                    }
                }
                return filteredSubcategories
            }()

            // Find max amount for bar scaling from visible list
            if let maxAmount = visibleSubcategories.first?.amount {
                let displayed = Array(visibleSubcategories.prefix(limit))
                ForEach(displayed) { summary in
                    let isSelected = summary.persistentID.map { selectedSubcategoryIDs.contains($0) } ?? false
                    // In exclude mode, excluded items are hidden — no dimming needed
                    let isDimmed = !isExcludeMode && !selectedSubcategoryIDs.isEmpty && !isSelected

                    SubcategoryRow(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode,
                        showNAWhenNil: showVariationHeader
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
                            .fill(Color(hex: top.colorHex ?? AppConstants.defaultSubcategoryColorHex))
                            .frame(width: 48, height: 48)

                        Image(
                            systemName: top.subcategory?.iconName ?? top.category?.iconName
                                ?? "tag.fill"
                        )
                        .font(DS.Typography.headline)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(top.subcategoryName)
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(formattedAmount(top.amount))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        // % of Category (Most relevant context for subcats)
                        HStack(spacing: DS.Spacing.xs) {
                            Text(
                                "\(formattedPercentage(top.percentageOfCategory)) \(String(format: L10n.Widget.of, top.category?.name ?? L10n.Widget.categoryAbbr))"
                            )
                            .font(DS.Typography.labelTiny)
                            .foregroundStyle(Color(hex: top.colorHex ?? AppConstants.defaultSubcategoryColorHex))
                        }
                        .padding(.horizontal, DS.Chip.paddingV)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(Color(hex: top.colorHex ?? AppConstants.defaultSubcategoryColorHex).opacity(0.1))
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
        if size == .small {
            YalaEmptyState(icon: "list.bullet.indent", title: L10n.Empty.noExpenses, style: .widget)
        } else {
            YalaEmptyState(
                icon: "list.bullet.indent",
                title: L10n.Widget.noExpensesPeriod,
                message: L10n.Widget.noExpensesDescriptionSubcategories,
                style: .widget
            )
        }
    }

    // MARK: - Formatters

    private func formattedAmount(_ value: Double) -> String {
        YalaFormatter.currency(value: value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        sharedPercentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row

private struct SubcategoryRow: View {
    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showNAWhenNil: Bool = false

    /// Ancho medido de la barra — reemplaza GeometryReader para soportar halfWidthPair.
    @State private var barWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name + Amount
                HStack(spacing: DS.Spacing.md) {
                    // Icon (Default placeholder as requested)
                    ZStack {
                        Circle()
                            .fill(Color(hex: summary.colorHex ?? AppConstants.defaultSubcategoryColorHex))
                            .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                        Image(
                            systemName: summary.subcategory?.iconName ?? summary.category?.iconName
                                ?? "tag.fill"
                        )
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        // Name and Amount
                        HStack {
                            Text(summary.subcategoryName)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(
                                YalaFormatter.currency(
                                    value: summary.amount, currencyCode: currencyCode)
                            )
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                        }

                        // Percentages + Variation Chip (inline, chip aligned right)
                        HStack(spacing: DS.Spacing.sm) {
                            Text(
                                "\(formattedPercentage(summary.percentageOfCategory)) \(String(format: L10n.Widget.of, summary.category?.name ?? L10n.Widget.categoryAbbr))"
                            )
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                            Text("•")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.secondary.opacity(0.5))

                            Text(
                                "\(formattedPercentage(summary.percentageOfTotal)) \(L10n.Widget.ofTotal)"
                            )
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                            Spacer()

                            // Variation chip (aligned to right)
                            VariationChip(variation: summary.variation, size: .small, showNAWhenNil: showNAWhenNil)
                        }

                        // Bar
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Semantic.neutralBackground)
                                .frame(maxWidth: .infinity)
                                .frame(height: 6)
                            let width = maxAmount > 0 ? (summary.amount / maxAmount) * barWidth : 0
                            Capsule().fill(Color(hex: summary.colorHex ?? AppConstants.defaultSubcategoryColorHex))
                                .frame(width: width, height: 6)
                        }
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
                            barWidth = newWidth
                        }
                    }
                }
            }
        }

    }

    private func formattedPercentage(_ value: Double) -> String {
        sharedPercentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
