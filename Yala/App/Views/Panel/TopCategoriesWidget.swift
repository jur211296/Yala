//
//  TopCategoriesWidget.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

struct TopCategoriesWidget: View {
    @Environment(AppPreferences.self) private var appPreferences
    let categories: [CategorySpendingSummary]
    let currencyCode: String

    // Filter State
    var selectedCategoryID: PersistentIdentifier?
    var isExcludeMode: Bool = false
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

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

    // MARK: - Static Formatters (avoid recreation on each render)

    fileprivate static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter
    }()

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
        Group {
            if size == .small {
                smallCardContent
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    headerSection

                    if categories.isEmpty {
                        emptyState
                    } else {
                        contentForSize
                    }
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .solidCard(padding: DS.Card.paddingCompact)
        .frame(height: size == .small ? WidgetSize.smallHeight : nil)
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
                HStack(spacing: DS.Spacing.xs) {
                    Text(size == .small ? L10n.Widget.main : L10n.Widget.topCategories)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if size != .small {
                        if let headerInfoButton {
                            headerInfoButton
                        } else {
                            InfoHintButton(
                                title: L10n.WidgetType.topSpending,
                                message: L10n.Widget.Hint.topCategories
                            )
                        }
                    }
                }

                // Total amount with vs comparison (only for medium/large with variation header)
                if showVariationHeader && size != .small && !categories.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        Text(appPreferences.currency(totalAmount, currencyCode: currencyCode))
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        if let prevAmount = previousTotalAmount {
                            Text("vs \(appPreferences.number(prevAmount))")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.thSecondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }

            Spacer()

            // Right: Variation chip and comparison text (only when showVariationHeader and has data)
            if showVariationHeader && size != .small && !categories.isEmpty && variation != nil {
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

        }
    }

    // MARK: - Lists (Large & Medium)

    private func categoriesList(limit: Int) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // In exclude mode, hide excluded items entirely
            let visibleCategories: [CategorySpendingSummary] = {
                if isExcludeMode, let excludedID = selectedCategoryID {
                    return categories.filter { $0.category.persistentModelID != excludedID }
                }
                return categories
            }()

            if let maxAmount = visibleCategories.first?.amount {
                let displayedCategories =
                    limit >= visibleCategories.count ? visibleCategories : Array(visibleCategories.prefix(limit))
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryID == summary.category.persistentModelID
                    let isAnySelected = selectedCategoryID != nil
                    // In exclude mode, excluded items are hidden — no dimming needed
                    let shouldDim = !isExcludeMode && isAnySelected && !isSelected

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
        Group {
            if categories.isEmpty {
                smallEmptyState
            } else {
                // En exclude mode, el item excluido se esconde (espejo del largeLayout);
                // en modo normal todos son visibles y el dim se aplica por row.
                let visibleCategories: [CategorySpendingSummary] = {
                    if isExcludeMode, let excludedID = selectedCategoryID {
                        return categories.filter { $0.category.persistentModelID != excludedID }
                    }
                    return categories
                }()

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    PanelSmallWidgetHeader(
                        title: L10n.Widget.topCategories,
                        accessibilityLabel: L10n.Panel.seeMoreInDistribution,
                        action: onShowMore,
                        headerInfoButton: headerInfoButton
                    )

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(Array(visibleCategories.prefix(2))) { summary in
                            smallCategoryRow(for: summary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func smallCategoryRow(for summary: CategorySpendingSummary) -> some View {
        let color = Color(hex: summary.category.colorHex)
        let clampedPercentage = max(0, min(100, summary.percentage))
        let isSelected = selectedCategoryID == summary.category.persistentModelID
        let shouldDim = !isExcludeMode && selectedCategoryID != nil && !isSelected

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Línea 1: ícono + nombre (ocupa casi todo el ancho para nombres largos)
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)

                    Image(systemName: summary.category.iconName ?? "tag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                Text(summary.category.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }

            // Línea 2: barra de progreso + monto + % (datos compactos juntos)
            HStack(spacing: DS.Spacing.sm) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(color.opacity(0.15))

                        Capsule()
                            .fill(color)
                            .frame(width: max(0, geo.size.width * CGFloat(clampedPercentage / 100.0)))
                    }
                }
                .frame(height: 6)

                Text(formattedAmount(summary.amount))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(formattedPercentage(summary.percentage))
                    .font(DS.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .opacity(shouldDim ? 0.3 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectCategory?(summary.category.persistentModelID)
        }
    }

    /// Empty state compacto para el layout `.small` — evita `YalaEmptyState(style: .widget)`
    /// que desborda el alto fijo del card.
    private var smallEmptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Spacer(minLength: 0)

            Image(systemName: "folder.fill")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            Text("—")
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        if size == .small {
            YalaEmptyState(icon: "folder.fill", title: L10n.Empty.noExpenses, style: .widget)
        } else {
            YalaEmptyState(
                icon: "folder.fill",
                title: L10n.Widget.noExpensesPeriod,
                message: L10n.Widget.noExpensesDescriptionCategories,
                style: .widget
            )
        }
    }

    // Helpers (moved inside View to be accessible)
    private func formattedAmount(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Category Row Component

private struct CategoryRow: View {
    @Environment(AppPreferences.self) private var appPreferences
    let summary: CategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showNAWhenNil: Bool = false

    /// Ancho medido de la barra — reemplaza GeometryReader para soportar halfWidthPair.
    @State private var barWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.category.colorHex))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                Image(systemName: summary.category.iconName ?? "tag.fill")  // Use actual category icon
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(appPreferences.currency(summary.amount, currencyCode: currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentage)) \(L10n.Widget.ofExpense)")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Variation chip (aligned to right)
                        VariationChip(variation: summary.variation, size: .small, showNAWhenNil: showNAWhenNil)
                    }

                    // Bar
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DS.Semantic.neutralBackground)
                            .frame(maxWidth: .infinity)
                            .frame(height: 6)

                        let width = maxAmount > 0 ? (summary.amount / maxAmount) * barWidth : 0
                        Capsule()
                            .fill(Color(hex: summary.category.colorHex))
                            .frame(width: width, height: 6)
                    }
                    .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
                        barWidth = newWidth
                    }
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        TopCategoriesWidget.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
