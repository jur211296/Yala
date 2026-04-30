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
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.isWidgetPreviewMode) private var isWidgetPreviewMode

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

    /// Slot pedagógico opcional inyectado en el header (Panel Polish #2).
    var headerInfoButton: AnyView? = nil

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
        Group {
            if size == .small {
                smallCardContent
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    headerSection

                    if subcategories.isEmpty {
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
                    HStack(spacing: DS.Spacing.xs) {
                        Text(size == .small ? L10n.Widget.subcategories : L10n.Widget.topSubcategories)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if size != .small {
                            WidgetHeaderInfoSlot(
                                injected: headerInfoButton,
                                legacyTitle: L10n.WidgetType.topSubcategories,
                                legacyMessage: L10n.Widget.Hint.topSubcategories
                            )
                        }
                    }

                    // Total amount with vs comparison (only with variation header, regular sizes)
                    if size != .small && showVariationHeader && !subcategories.isEmpty {
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

            }

            // Row 2: Selector (Only Medium/Large, no en preview pedagógico).
            // El selector con `ScrollView(.horizontal)` + chips dinámicos sobre
            // `viewModel.allCategories` cargados en `onAppear` provoca un layout
            // loop infinito cuando el widget se renderiza dentro del previewBox
            // del `WidgetInfoSheet` (watchdog 0x8BADF00D — ver crash log
            // 2026-04-30). El sheet pedagógico solo necesita mostrar la lista
            // de subcategorías, no el selector interactivo.
            if size != .small && !isWidgetPreviewMode {
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

    // MARK: - Small Card Content (PP2-06)

    private var smallCardContent: some View {
        Group {
            if visibleSubcategoriesForSmall.isEmpty {
                smallEmptyState
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    PanelSmallWidgetHeader(
                        title: L10n.Widget.topSubcategories,
                        accessibilityLabel: L10n.Panel.seeMoreInDistribution,
                        action: onShowMore,
                        headerInfoButton: headerInfoButton
                    )

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(Array(visibleSubcategoriesForSmall.prefix(2))) { summary in
                            smallSubcategoryRow(for: summary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// PP2-06: aplica el filtro global de categoría (consistencia con medium/large)
    /// y esconde los excluidos en exclude mode. No aplica `localCategoryFilterID`
    /// porque el picker no está disponible en `.small`.
    private var visibleSubcategoriesForSmall: [SubcategorySpendingSummary] {
        let globallyFiltered: [SubcategorySpendingSummary] = {
            if let globalID = globalCategoryFilterID {
                return subcategories.filter { $0.category?.persistentModelID == globalID }
            }
            return subcategories
        }()

        if isExcludeMode, !selectedSubcategoryIDs.isEmpty {
            return globallyFiltered.filter {
                guard let id = $0.persistentID else { return true }
                return !selectedSubcategoryIDs.contains(id)
            }
        }
        return globallyFiltered
    }

    @ViewBuilder
    private func smallSubcategoryRow(for summary: SubcategorySpendingSummary) -> some View {
        let color = Color(hex: summary.colorHex ?? AppConstants.defaultSubcategoryColorHex)
        let clampedPercentage = max(0, min(100, summary.percentageOfTotal))
        let isSelected = summary.persistentID.map { selectedSubcategoryIDs.contains($0) } ?? false
        let shouldDim = !isExcludeMode && !selectedSubcategoryIDs.isEmpty && !isSelected

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Línea 1: ícono + nombre
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)

                    Image(systemName: summary.subcategory?.iconName ?? summary.category?.iconName ?? "tag.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                Text(summary.subcategoryName)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)
            }

            // Línea 2: barra de progreso + monto + %
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

                Text(formattedPercentage(summary.percentageOfTotal))
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
            if let persistentID = summary.persistentID {
                onSelectSubcategory?(persistentID)
            }
        }
    }

    /// PP2-06: empty state compacto para `.small` — evita `YalaEmptyState(style:.widget)`
    /// que desborda el alto fijo del card.
    private var smallEmptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Spacer(minLength: 0)

            Image(systemName: "list.bullet.indent")
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
        YalaEmptyState(
            icon: "list.bullet.indent",
            title: L10n.Widget.noExpensesPeriod,
            message: L10n.Widget.noExpensesDescriptionSubcategories,
            style: .widget
        )
    }

    // MARK: - Formatters

    private func formattedAmount(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode)
    }

    private func formattedPercentage(_ value: Double) -> String {
        sharedPercentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row

private struct SubcategoryRow: View {
    @Environment(AppPreferences.self) private var appPreferences
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
                                appPreferences.currency(summary.amount, currencyCode: currencyCode)
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
