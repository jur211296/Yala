//
//  PanelSessionFilters.swift
//  Yala
//
//  Puente entre la hoja de filtros (`RecordsFiltersView`, la de Estadísticas e Informes) y el Panel.
//
//  Los filtros del Panel no son suyos: viven en `SessionState` y los comparten Registros, Estadísticas e Informes.
//  Esta clase solo los expone con la forma de `Filterable` que pide la hoja, sin guardar nada propio. El Panel ya
//  recalcula al cambiar cualquiera de ellos (`PanelSessionObservers`), así que aplicar la hoja basta.
//
//  `PanelViewModel` no se hace `Filterable` a propósito: ya tiene su propio vocabulario de filtro
//  (`selectedAccountID` en singular para el menú contextual y el chip, `selectedCategoryID` para los widgets) y el protocolo le sumaría
//  una segunda superficie de escritura sobre el mismo estado.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class PanelSessionFilters: Filterable {

    private let session: SessionState

    init() {
        self.session = .shared
    }

    /// Para los tests: un `SessionState` propio en vez del global.
    init(session: SessionState) {
        self.session = session
    }

    var selectedAccounts: Set<PersistentIdentifier> {
        get { session.selectedAccountIDs }
        set { session.selectedAccountIDs = newValue }
    }

    var selectedCategories: Set<PersistentIdentifier> {
        get { session.selectedCategoryIDs }
        set { session.selectedCategoryIDs = newValue }
    }

    var selectedSubcategories: Set<PersistentIdentifier> {
        get { session.selectedSubcategoryIDs }
        set { session.selectedSubcategoryIDs = newValue }
    }

    var selectedNeeds: Set<SubcategoryNeed> {
        get { session.selectedNeeds }
        set { session.selectedNeeds = newValue }
    }

    var selectedTags: Set<PersistentIdentifier> {
        get { session.selectedTags }
        set { session.selectedTags = newValue }
    }

    var selectedCurrencies: Set<CurrencyCode> {
        get { session.selectedCurrencies }
        set { session.selectedCurrencies = newValue }
    }

    var amountCondition: AmountFilterCondition {
        get { session.amountCondition }
        set { session.amountCondition = newValue }
    }

    var searchText: String {
        get { session.searchText }
        set { session.searchText = newValue }
    }

    var isExcludeMode: Bool {
        get { session.isExcludeMode }
        set { session.isExcludeMode = newValue }
    }

    var selectedTransactionNatures: Set<TransactionNature> {
        get { session.selectedTransactionNatures }
        set { session.selectedTransactionNatures = newValue }
    }

    /// El Panel no filtra por gasto compartido y la hoja no lo ofrece; está porque el protocolo lo pide, igual que en
    /// `StatisticsViewModel`.
    var sharedExpenseFilter: SharedExpenseFilter = .all

    var hasActiveFilters: Bool { filterCriteria.hasActiveFilters }

    /// Mismo conteo que el botón de filtros de Estadísticas.
    var activeFilterCount: Int { filterCriteria.activeFilterCount }

    /// Lo que enciende el punto del botón de filtros del Panel. En modo «solo gastos» la app fija ella misma la
    /// naturaleza en «gasto» (`SessionState.isExpensesOnlyMode`); eso no es un filtro del usuario, y contarlo dejaba el
    /// punto encendido siempre.
    var hasUserFilters: Bool {
        Self.hasUserFilters(
            activeFilterCount: activeFilterCount,
            isExpensesOnlyMode: session.isExpensesOnlyMode,
            natures: session.selectedTransactionNatures
        )
    }

    nonisolated static func hasUserFilters(
        activeFilterCount: Int,
        isExpensesOnlyMode: Bool,
        natures: Set<TransactionNature>
    ) -> Bool {
        let forced = isExpensesOnlyMode && natures == [.expense] ? 1 : 0
        return activeFilterCount - forced > 0
    }

    func clearFilters() {
        clearFiltersDefault()
    }
}
