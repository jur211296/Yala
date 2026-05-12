//
//  FilterControlBar.swift
//  Yala
//
//  Shared control bar with period selector, filter chips, and optional trailing
//  content. Used by TrendsTabView, CategoriesTabView, InsightsTabView, RecordsTabView
//  and FinancialReportView.
//
//  Two render modes:
//  - Legacy (`panelStyle = false`, default): HStack inline con periodSelector + chips
//    + trailingContent. Comportamiento pre-polish para callsites no migrados.
//  - Panel style (`panelStyle = true`): chips dentro de `PanelSection` con
//    `GlassEffectContainer` (mismo lenguaje que `PanelFilterControlBar`). El host
//    coloca el periodSelector en su hero; `trailingContent` se ignora.
//
//  TODO(stats-polish-epic): eliminar `panelStyle`/`inlinePeriodSelector`, el branch
//  legacy y la convenience init cuando las 4 tabs Stats + FinancialReport migren.
//  Ver Backlog/stats-polish-panel-alignment.md "Cleanup post-épico".
//

import SwiftData
import SwiftUI

// MARK: - Filter Control Bar

struct FilterControlBar<VM: Filterable & Observable, PeriodView: View, TrailingContent: View>: View {

    // MARK: - Properties

    let periodSelector: PeriodView
    @Bindable var viewModel: VM
    let accounts: [Account]
    let categories: [Category]
    let allSubcategories: [Subcategory]
    let tags: [Tag]
    let animationValue: DetailPeriod

    // Optional (Records only)
    var transactionTypeFilter: TransactionTypeFilter? = nil
    var onClearTransactionType: (() -> Void)? = nil

    // Optional callback after any filter change (Records uses this)
    var onFilterChange: (() -> Void)? = nil

    /// Panel-style render: chips dentro de `PanelSection` con `GlassEffectContainer`.
    /// Cuando `true`, `trailingContent` se ignora y el host coloca el periodSelector
    /// en el hero. Default `false` mantiene comportamiento legacy retrocompat.
    var panelStyle: Bool = false

    /// Mostrar el periodSelector inline en el HStack legacy. En panel style se
    /// fuerza a `false` independientemente del valor pasado (el host lo monta
    /// en el hero). Mantenido como property explícita para claridad de callsites.
    var inlinePeriodSelector: Bool = true

    // Trailing slot (legacy only)
    @ViewBuilder let trailingContent: () -> TrailingContent

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Namespace para morphing de chips (panel style — `glassEffectID` por chip).
    @Namespace private var chipNamespace

    // MARK: - Body

    var body: some View {
        Group {
            if panelStyle {
                if FilterControlBarLogic.shouldRenderPanelSection(
                    panelStyle: true,
                    activeFilterCount: viewModel.activeFilterCount
                ) {
                    PanelSection(title: L10n.Panel.FilterBar.sectionTitle) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            GlassEffectContainer(spacing: DS.Spacing.sm) {
                                chipsContent
                            }
                        }
                        .contentMargins(.horizontal, DS.Spacing.md, for: .scrollContent)
                        .scrollClipDisabled()
                    }
                }
            } else {
                HStack(spacing: DS.Spacing.md) {
                    if FilterControlBarLogic.shouldShowInlinePeriodSelector(panelStyle: panelStyle) {
                        periodSelector
                    }

                    if viewModel.isExcludeMode {
                        ExcludeModeBadge()
                    }

                    if viewModel.hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            chipsContent
                        }
                    }

                    Spacer()

                    trailingContent()
                }
            }
        }
        .animation(nil, value: animationValue)
    }

    // MARK: - Chips Content (shared entre branches)

    @ViewBuilder
    private var chipsContent: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Account chips
            ForEach(buildAccountChips(selectedAccounts: viewModel.selectedAccounts, allAccounts: accounts), id: \.id) { chip in
                FilterChipView(
                    accountName: chip.name,
                    count: chip.count,
                    onClear: {
                        viewModel.selectedAccounts.removeAll()
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.account", in: chipNamespace)
            }

            // Category chip (aggregated from subcategories)
            if let catChip = aggregatedCategoryChip(
                selectedSubcategories: viewModel.selectedSubcategories,
                allSubcategories: allSubcategories
            ) {
                FilterChipView(
                    categoryName: catChip.name,
                    iconName: catChip.iconName,
                    colorHex: catChip.colorHex,
                    count: catChip.count,
                    onClear: {
                        viewModel.selectedCategories.removeAll()
                        viewModel.selectedSubcategories.removeAll()
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.category", in: chipNamespace)
            } else if !viewModel.selectedCategories.isEmpty {
                let selectedCats = categories.filter { viewModel.selectedCategories.contains($0.persistentModelID) }
                if let firstCat = selectedCats.first {
                    FilterChipView(
                        categoryName: firstCat.name,
                        iconName: firstCat.iconName,
                        colorHex: firstCat.colorHex,
                        count: selectedCats.count,
                        onClear: {
                            viewModel.selectedCategories.removeAll()
                            onFilterChange?()
                        }
                    )
                    .excludeMode(viewModel.isExcludeMode)
                    .glassEffectID("chip.category", in: chipNamespace)
                }
            }

            // Subcategory chip (aggregated)
            if let subChip = aggregatedSubcategoryChip(
                selectedSubcategories: viewModel.selectedSubcategories,
                allSubcategories: allSubcategories
            ) {
                FilterChipView(
                    subcategoryName: subChip.name,
                    iconName: subChip.iconName,
                    colorHex: subChip.colorHex,
                    count: subChip.count,
                    onClear: {
                        viewModel.selectedSubcategories.removeAll()
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.subcategory", in: chipNamespace)
            }

            // Tag chips
            ForEach(buildTagChips(selectedTags: viewModel.selectedTags, allTags: tags), id: \.id) { chip in
                FilterChipView(
                    tagName: chip.name,
                    iconName: chip.iconName,
                    colorHex: chip.colorHex,
                    onClear: {
                        viewModel.selectedTags.remove(chip.tagID)
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.tag.\(chip.tagID.hashValue)", in: chipNamespace)
            }

            // Need chips
            ForEach(buildNeedChips(selectedNeeds: viewModel.selectedNeeds), id: \.need.rawValue) { chipData in
                FilterChipView(
                    need: chipData.need,
                    onClear: {
                        viewModel.selectedNeeds.remove(chipData.need)
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.need.\(chipData.need.rawValue)", in: chipNamespace)
            }

            // Transaction nature chip (hidden in expenses-only mode)
            if !sessionState.isExpensesOnlyMode,
                viewModel.selectedTransactionNatures.count == 1,
                let nature = viewModel.selectedTransactionNatures.first
            {
                FilterChipView(
                    transactionNature: nature,
                    onClear: {
                        viewModel.selectedTransactionNatures.removeAll()
                        onFilterChange?()
                    }
                )
                .glassEffectID("chip.nature", in: chipNamespace)
            }

            // Transaction type chip (Records only)
            if let filter = transactionTypeFilter,
                filter != .all,
                let onClear = onClearTransactionType
            {
                FilterChipView(text: filter.displayName) {
                    onClear()
                    onFilterChange?()
                }
                .glassEffectID("chip.transactionType", in: chipNamespace)
            }

            // Currency chips
            ForEach(Array(viewModel.selectedCurrencies).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { currency in
                FilterChipView(
                    currencyCode: currency.rawValue,
                    onClear: {
                        viewModel.selectedCurrencies.remove(currency)
                        onFilterChange?()
                    }
                )
                .excludeMode(viewModel.isExcludeMode)
                .glassEffectID("chip.currency.\(currency.rawValue)", in: chipNamespace)
            }

            // Amount chip
            if viewModel.amountCondition.isActive {
                FilterChipView(
                    amountText: viewModel.amountCondition.displayText,
                    onClear: {
                        viewModel.amountCondition = .any
                        onFilterChange?()
                    }
                )
                .glassEffectID("chip.amount", in: chipNamespace)
            }

            // Search/Note chip
            if !viewModel.searchText.isEmpty {
                FilterChipView(
                    noteText: viewModel.searchText,
                    onClear: {
                        viewModel.searchText = ""
                        onFilterChange?()
                    }
                )
                .glassEffectID("chip.note", in: chipNamespace)
            }

            // Clear all button
            if viewModel.activeFilterCount > 1 {
                Button {
                    dsWithAnimation(reduceMotion) {
                        viewModel.clearFilters()
                        onFilterChange?()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(L10n.Action.clearAll)
                .glassEffectID("chip.clearAll", in: chipNamespace)
            }
        }
    }
}

// MARK: - Convenience Init (no trailing content)

extension FilterControlBar where TrailingContent == EmptyView {
    init(
        periodSelector: PeriodView,
        viewModel: VM,
        accounts: [Account],
        categories: [Category],
        allSubcategories: [Subcategory],
        tags: [Tag],
        animationValue: DetailPeriod,
        transactionTypeFilter: TransactionTypeFilter? = nil,
        onClearTransactionType: (() -> Void)? = nil,
        onFilterChange: (() -> Void)? = nil,
        panelStyle: Bool = false,
        inlinePeriodSelector: Bool = true
    ) {
        self.periodSelector = periodSelector
        self._viewModel = Bindable(wrappedValue: viewModel)
        self.accounts = accounts
        self.categories = categories
        self.allSubcategories = allSubcategories
        self.tags = tags
        self.animationValue = animationValue
        self.transactionTypeFilter = transactionTypeFilter
        self.onClearTransactionType = onClearTransactionType
        self.onFilterChange = onFilterChange
        self.panelStyle = panelStyle
        self.inlinePeriodSelector = inlinePeriodSelector
        self.trailingContent = { EmptyView() }
    }
}
