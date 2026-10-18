//
//  ExportFiltersStepViewModel.swift
//  Yala
//
//  ViewModel for ExportFiltersStepView - handles data loading for export filters.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ExportFiltersStepViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allAccounts: [Account] = []
    private(set) var allCategories: [Category] = []
    private(set) var allTags: [Tag] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var earliestTransactionDate: Date?

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            allAccounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load categories
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        do {
            allCategories = try context.fetch(categoryDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading categories: \(error)")
            #endif
            allCategories = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }

        // Load subcategories
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }

        // Load earliest transaction date for allTime period
        var earliestDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .forward)]
        )
        earliestDescriptor.fetchLimit = 1
        do {
            earliestTransactionDate = try context.fetch(earliestDescriptor).first?.date
        } catch {
            #if DEBUG
            print("ExportFiltersStepViewModel: Error fetching earliest transaction: \(error)")
            #endif
        }
    }

    // MARK: - Cuentas (tarjeta con varias divisas, entrega 4 · Paso 0 D4)

    /// Las cuentas que ofrece el filtro: cada tarjeta una vez (sin sus líneas, que entran solas al elegirla) y sin las
    /// cuentas de Grupos, como el resto de selectores. En el orden por nombre de siempre. Sin ninguna cuenta propia
    /// (solo las de Grupos), ofrece las de Grupos como antes: si no, «Siguiente» quedaría apagado sin nada que marcar.
    var offeredAccounts: [Account] {
        let own = allAccounts.filter { !$0.isSystemAccount }.accountCards(roles: allAccounts.lineRoles).map(\.head)
        return own.isEmpty ? allAccounts.filter(\.isSystemAccount) : own
    }

    /// Las líneas de cada tarjeta, por `PersistentIdentifier` (las archivadas también: siguen siendo de la tarjeta).
    private var linesByHead: [PersistentIdentifier: Set<PersistentIdentifier>] {
        AccountCardLogic.linesByHead(allAccounts, node: { AccountLineNode($0) }, id: { $0.persistentModelID })
    }

    /// La selección de partida: todo lo que se ofrece, con las líneas de cada tarjeta.
    var initialAccountSelection: Set<PersistentIdentifier> {
        AccountCardLogic.includingLines(Set(offeredAccounts.map(\.persistentModelID)), linesByHead: linesByHead)
    }

    /// La selección tras tocar el chip de `account`: poner o quitar una tarjeta pone o quita sus líneas.
    func toggling(_ account: Account, in selection: Set<PersistentIdentifier>) -> Set<PersistentIdentifier> {
        var new = selection
        let id = account.persistentModelID
        if new.contains(id) { new.remove(id) } else { new.insert(id) }
        return AccountCardLogic.normalizedSelection(old: selection, new: new, linesByHead: linesByHead)
    }

    /// Las cuentas que se exportan con esta selección. Las de Grupos no tienen chip: entran cuando están marcadas TODAS
    /// las que se ofrecen (la partida, y la copia de «Exportar antes» de vaciar datos), y no al elegir una cuenta
    /// concreta. Así la copia completa sigue siendo completa.
    func exportedAccounts(selectedAccounts: Set<PersistentIdentifier>) -> [Account] {
        let offered = offeredAccounts
        let coversAll = !offered.isEmpty && offered.allSatisfy { selectedAccounts.contains($0.persistentModelID) }
        let systemHasChips = offered.contains(where: \.isSystemAccount)
        return allAccounts.filter { account in
            account.isSystemAccount && !systemHasChips ? coversAll : selectedAccounts.contains(account.persistentModelID)
        }
    }

    // MARK: - Helper Methods

    /// Cuenta tarjetas, no líneas: con la tarjeta marcada, sus líneas van en el conjunto pero no son otra cuenta.
    func selectedAccountsText(selectedAccounts: Set<PersistentIdentifier>) -> String {
        let offered = offeredAccounts
        let marked = offered.filter { selectedAccounts.contains($0.persistentModelID) }.count
        if marked == 0 {
            return L10n.Filters.noneSelected
        }
        if marked == offered.count {
            return L10n.Filters.allAccounts
        }
        return L10n.Filters.selectedCount(marked)
    }

    func selectedCategoriesText(selectedSubcategories: Set<PersistentIdentifier>) -> String {
        let visibleSubs = allSubcategories.filter { $0.isVisible }

        if selectedSubcategories.isEmpty {
            return L10n.Filters.allCategories
        }

        if selectedSubcategories.count == visibleSubs.count {
            return L10n.Filters.allCategories
        }

        return L10n.Filters.subcategoriesSelectedCount(selectedSubcategories.count)
    }

    func selectedTagsText(selectedTags: Set<PersistentIdentifier>) -> String {
        if allTags.isEmpty {
            return L10n.Filters.noTags
        }
        if selectedTags.isEmpty || selectedTags.count == allTags.count {
            return L10n.Filters.allTags
        }
        return L10n.Filters.selectedCount(selectedTags.count)
    }

    func availableCurrencies(selectedAccounts: Set<PersistentIdentifier>) -> [CurrencyCode] {
        if selectedAccounts.isEmpty {
            return CurrencyCode.allCases
        }
        let selected = exportedAccounts(selectedAccounts: selectedAccounts)
        let accountCurrencies = Set(selected.map { CurrencyCode(rawValue: $0.currencyCode) ?? .pen })
        return CurrencyCode.allCases.filter { accountCurrencies.contains($0) }
    }

    func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    // MARK: - All-Time Date Range

    /// Returns a date interval from the earliest transaction to end of today
    func allTimeDateInterval() -> DateInterval {
        guard let earliest = earliestTransactionDate else {
            return DetailPeriod.allTime.dateInterval()
        }
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date.now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date.now
        return DateInterval(start: calendar.startOfDay(for: earliest), end: endOfToday)
    }

    // MARK: - Export Filters

    func buildExportFilters(
        selectedAccounts: Set<PersistentIdentifier>,
        selectedSubcategories: Set<PersistentIdentifier>,
        selectedTags: Set<PersistentIdentifier>,
        selectedCurrencies: Set<CurrencyCode>,
        amountCondition: AmountFilterCondition,
        selectedPeriod: DetailPeriod,
        customDateRange: DateInterval?,
        noteContains: String,
        isExcludeMode: Bool = false
    ) -> ExportFilters {
        // Resolve subcategory objects from PersistentIdentifiers
        let selectedSubcategoryObjects = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }

        // Derive categories from the selected subcategories
        let finalCategories = Set(selectedSubcategoryObjects.compactMap { $0.category })

        let selectedTagObjects = allTags.filter { selectedTags.contains($0.persistentModelID) }

        let selectedTagNames: [String]
        if !allTags.isEmpty && selectedTagObjects.count == allTags.count {
            selectedTagNames = []
        } else {
            selectedTagNames = selectedTagObjects.map { $0.name }
        }

        // Convert DetailPeriod to date interval
        let dateInterval: DateInterval
        if selectedPeriod == .custom, let customRange = customDateRange {
            dateInterval = customRange
        } else if selectedPeriod == .allTime {
            dateInterval = allTimeDateInterval()
        } else {
            dateInterval = selectedPeriod.dateInterval()
        }

        return ExportFilters(
            selectedAccounts: exportedAccounts(selectedAccounts: selectedAccounts),
            selectedCategories: Array(finalCategories),
            selectedSubcategories: selectedSubcategoryObjects,
            selectedTagNames: selectedTagNames,
            selectedCurrencies: Array(selectedCurrencies),
            amountCondition: amountCondition,
            dateFrom: dateInterval.start,
            dateTo: dateInterval.end,
            isExcludeMode: isExcludeMode,
            noteContains: noteContains.isEmpty ? nil : noteContains
        )
    }
}
