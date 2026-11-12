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

    /// Registros con chips rápidos (revisión 2.3, decisión 16): lo INCLUIDO de cuenta y de categoría lo dicen los chips
    /// de arriba, y la banda solo enseña lo de «Más filtros» (también lo oculto de esas dimensiones).
    var hidesQuickFilterDimensions: Bool = false

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
                if FilterControlBarLogic.shouldRenderPanelSection(panelStyle: true, activeFilterCount: bandFilterCount) {
                    PanelSection(title: L10n.Panel.FilterBar.sectionTitle, compact: true) {
                        band
                    }
                }
            } else {
                // Informes: el período en su fila y, debajo, la banda (antes los chips iban en la misma fila, en un
                // carrusel que escondía los de la derecha).
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.md) {
                        if FilterControlBarLogic.shouldShowInlinePeriodSelector(panelStyle: panelStyle) {
                            periodSelector
                        }

                        Spacer()

                        trailingContent()
                    }

                    if bandFilterCount > 0 {
                        band
                    }
                }
            }
        }
        .animation(nil, value: animationValue)
    }

    // MARK: - Banda (revisión 2.3 · L1)

    /// Cuántos filtros pinta la banda: todos, o sin lo que ya dicen los chips rápidos de Registros.
    private var bandFilterCount: Int {
        FilterBandLogic.bandFilterCount(
            userFilterCount: viewModel.userFilterCount(isExpensesOnlyMode: sessionState.isExpensesOnlyMode),
            hidesQuickDimensions: hidesQuickFilterDimensions,
            hasIncludedAccounts: !viewModel.selectedAccounts.isEmpty,
            hasIncludedCategoriesOrSubcategories: !viewModel.selectedCategories.isEmpty
                || !viewModel.selectedSubcategories.isEmpty
        )
    }

    /// Las cápsulas partidas en líneas, sin carrusel: ninguna queda fuera de la pantalla, y «Quitar todo» siempre a la
    /// vista. Sin `GlassEffectContainer`: con cápsulas que cambian de ancho rompe la animación (swiftui-ds.md).
    private var band: some View {
        FilterBand(
            showsRemoveAll: FilterBandLogic.showsRemoveAll(bandFilterCount: bandFilterCount),
            onRemoveAll: {
                viewModel.clearFilters()
                onFilterChange?()
            }
        ) {
            chipsContent
        }
    }

    // MARK: - Abrir Filtros (UX 2.2 · L8-17)

    /// Tocar una cápsula de «Filtros aplicados» abre la hoja de Filtros del host. Todos los hosts de esta barra
    /// cuelgan su hoja de `showFiltersSheet` (`FiltersSheetPresenting`); uno que no lo haga deja la cápsula como
    /// estaba, sin toque. El tipo de registro (Registros) no se elige en Filtros y su cápsula sigue igual.
    private var openFilters: (() -> Void)? {
        guard let presenter = viewModel as? FiltersSheetPresenting else { return nil }
        return { presenter.showFiltersSheet = true }
    }

    // MARK: - Chips Content (shared entre branches)

    @ViewBuilder
    private var chipsContent: some View {
        // Sin pila propia: cada cápsula es un hijo de la banda, que las reparte en líneas.
        if !hidesQuickFilterDimensions {
            includedAccountAndCategoryChips
        }
        otherChipsContent
    }

    @ViewBuilder
    private var includedAccountAndCategoryChips: some View {
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
                .filterMembership(.included)
                .opensFilters(openFilters)
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
                .filterMembership(.included)
                .opensFilters(openFilters)
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
                    .filterMembership(.included)
                    .opensFilters(openFilters)
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
                .filterMembership(.included)
                .opensFilters(openFilters)
                .glassEffectID("chip.subcategory", in: chipNamespace)
            }
    }

    @ViewBuilder
    private var otherChipsContent: some View {
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
                .filterMembership(.included)
                .opensFilters(openFilters)
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
                .filterMembership(.included)
                .opensFilters(openFilters)
                .glassEffectID("chip.need.\(chipData.need.rawValue)", in: chipNamespace)
            }

            // Lo oculto («Sin X»), una cápsula por valor, junto a lo de «Solo X» de arriba.
            ExcludedFilterChips(
                sessionState: sessionState,
                accounts: accounts,
                categories: categories,
                subcategories: allSubcategories,
                tags: tags,
                onOpenFilters: openFilters,
                onFilterChange: onFilterChange,
                namespace: chipNamespace
            )

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
                .opensFilters(openFilters)
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
                .filterMembership(.included)
                .opensFilters(openFilters)
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
                .opensFilters(openFilters)
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
                .opensFilters(openFilters)
                .glassEffectID("chip.note", in: chipNamespace)
            }
            // «Quitar todo» lo pone la banda (antes, una ✕ que VoiceOver llamaba «Borrar filtros»).
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
        inlinePeriodSelector: Bool = true,
        hidesQuickFilterDimensions: Bool = false
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
        self.hidesQuickFilterDimensions = hidesQuickFilterDimensions
        self.trailingContent = { EmptyView() }
    }
}
