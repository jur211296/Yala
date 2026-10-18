//
//  RecordsFiltersViewModel.swift
//  Yala
//
//  ViewModel for RecordsFiltersView - handles data loading for filter options.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class RecordsFiltersViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allAccounts: [Account] = []
    private(set) var allCategories: [Category] = []
    private(set) var allTags: [Tag] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var currenciesWithTransactions: [CurrencyCode] = []

    // MARK: - Computed Properties

    var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    /// Las cuentas que ofrece el filtro (tarjeta con varias divisas, entrega 3): cada tarjeta una vez, sin sus líneas, que
    /// entran solas al elegirla (`SessionState.selectedAccountIDs`). Una línea elegida SOLA —un presupuesto anterior al
    /// enlace— se sigue enseñando, detrás de su tarjeta, para que se pueda quitar.
    func filterAccounts(selected: Set<PersistentIdentifier>) -> [Account] {
        let roles = AccountLineLogic.resolve(allAccounts.map { AccountLineNode($0) })
        let active = activeAccounts
        let heads = active.filter { !(roles[$0.shortcutID]?.isLine ?? false) }
        let loneLines = active.filter { (roles[$0.shortcutID]?.isLine ?? false) && selected.contains($0.persistentModelID) }
        guard !loneLines.isEmpty else { return heads }
        return AccountCardLogic.cards(
            heads + loneLines, roles: roles, id: \.shortcutID, currencyCode: \.currencyCode
        ).flatMap(\.members)
    }

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

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
            print("RecordsFiltersViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load categories
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        do {
            allCategories = try context.fetch(categoryDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading categories: \(error)")
            #endif
            allCategories = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }

        // Load subcategories
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("RecordsFiltersViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }

        // Load currencies with transactions
        loadCurrenciesWithTransactions()
    }

    private func loadCurrenciesWithTransactions() {
        guard let context = modelContext else { return }

        // Check each unique account currency with fetchCount (~1-3 queries, no objects materialized)
        var codes = Set<String>()
        for currencyCode in Set(allAccounts.map { $0.currencyCode }) {
            let code = currencyCode
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { $0.currencyCode == code }
            )
            do {
                if try context.fetchCount(descriptor) > 0 {
                    codes.insert(code)
                }
            } catch {
                #if DEBUG
                print("RecordsFiltersViewModel: Error counting transactions for currency: \(error)")
                #endif
            }
        }
        // Maintain consistent order with CurrencyCode.allCases
        currenciesWithTransactions = CurrencyCode.allCases.filter {
            codes.contains($0.rawValue)
        }
    }

    // MARK: - Helper Methods

    // Sin nada marcado cada sección dice lo suyo («Todas las cuentas», «Ninguna oculta»): antes era «(Todos)» y
    // «(Nada)» en todas (UX 2.2 · L8-16). El texto lo decide `RecordsFiltersSection.emptyStatus`.

    func selectedAccountsText(selectedAccounts: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        let empty = RecordsFiltersSection.accounts.emptyStatus(isExcludeMode: isExcludeMode)
        if selectedAccounts.isEmpty {
            return empty
        }
        // Se cuentan tarjetas: con la tarjeta elegida, sus líneas van en el conjunto pero no son otra cuenta (entrega 3).
        // Cuenta las filas que se ven marcadas: así cuadra con la lista también con una línea elegida sola y su tarjeta.
        let offered = filterAccounts(selected: selectedAccounts)
        let marked = offered.filter { selectedAccounts.contains($0.persistentModelID) }.count
        if !isExcludeMode && marked == offered.count {
            return empty
        }
        return "\(marked)/\(offered.count)"
    }

    func selectedCategoriesText(selectedSubcategories: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        let subCount = selectedSubcategories.count
        let empty = RecordsFiltersSection.categories.emptyStatus(isExcludeMode: isExcludeMode)

        if subCount == 0 {
            return empty
        }

        let allIDs = Set(allSubcategories.map { $0.persistentModelID })
        if !isExcludeMode && selectedSubcategories == allIDs {
            return empty
        }

        let selectedSubs = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }
        if selectedSubs.isEmpty {
            return empty
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return empty
    }

    func selectedTagsText(selectedTags: Set<PersistentIdentifier>, isExcludeMode: Bool = false) -> String {
        let empty = RecordsFiltersSection.tags.emptyStatus(isExcludeMode: isExcludeMode)
        if selectedTags.isEmpty {
            return empty
        }
        if !isExcludeMode && selectedTags.count == activeTags.count {
            return empty
        }
        return "\(selectedTags.count)/\(activeTags.count)"
    }

    func subcategories(for category: Category) -> [Subcategory] {
        allSubcategories.filter { sub in
            sub.category == category && sub.isVisible
        }
    }

    func subcategorySelectionSummary(for category: Category, selectedSubcategories: Set<PersistentIdentifier>) -> String {
        let subs = subcategories(for: category)
        let total = subs.count
        let selectedCount = subs.count(where: { selectedSubcategories.contains($0.persistentModelID) })

        if total == 0 {
            return L10n.Filters.noSubcategories
        }

        if selectedCount == 0 {
            return L10n.Filters.noneSelected
        }

        if selectedCount == total {
            return L10n.Filters.allSubcategories
        }

        return "\(selectedCount) / \(total)"
    }
}
