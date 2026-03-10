//
//  SubcategoryTransferViewModel.swift
//  Yala
//
//  ViewModel for SubcategoryTransferSheet - handles subcategory/category loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class SubcategoryTransferViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allSubcategories: [Subcategory] = []
    private(set) var allCategories: [Category] = []

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        loadSubcategories()
        loadCategories()
    }

    private func loadSubcategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("SubcategoryTransferViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }
    }

    private func loadCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.sortOrder)])
        do {
            allCategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("SubcategoryTransferViewModel: Error loading categories: \(error)")
            #endif
            allCategories = []
        }
    }

    // MARK: - Computed Properties

    /// Subcategorías disponibles agrupadas por categoría (excluyendo la que se va a eliminar)
    func availableDestinations(excluding subcategoryToDelete: Subcategory) -> [(category: Category, subcategories: [Subcategory])] {
        let parentCategory = subcategoryToDelete.safeCategory

        // Filtrar subcategorías visibles, excluyendo la que se elimina
        let filtered = allSubcategories.filter { subcategory in
            guard subcategory.isVisible else { return false }
            guard subcategory.persistentModelID != subcategoryToDelete.persistentModelID else {
                return false
            }
            // Solo mostrar subcategorías del mismo tipo (ingreso/gasto)
            return subcategory.safeCategory.isIncome == parentCategory.isIncome
        }

        // Agrupar por categoría
        let grouped = Dictionary(grouping: filtered) { $0.safeCategory }

        return
            grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map {
                (category: $0.key, subcategories: $0.value.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                })
            }
    }

    // MARK: - Transfer Operations

    /// Counts transactions for the given subcategory
    func transactionCount(for subcategory: Subcategory) -> Int {
        guard let context = modelContext else { return 0 }
        let subcategoryID = subcategory.persistentModelID
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try context.fetch(descriptor)
            return allTransactions.filter { $0.subcategory?.persistentModelID == subcategoryID }.count
        } catch {
            #if DEBUG
            print("SubcategoryTransferViewModel: Error counting transactions: \(error)")
            #endif
            return 0
        }
    }

    /// Transfers all transactions to the specified subcategory
    func transferTransactions(from source: Subcategory, to destination: Subcategory) throws {
        guard let context = modelContext else { return }
        let sourceID = source.persistentModelID

        let descriptor = FetchDescriptor<TransactionItem>()
        let allTransactions = try context.fetch(descriptor)
        let transactionsToTransfer = allTransactions.filter {
            $0.subcategory?.persistentModelID == sourceID
        }

        for transaction in transactionsToTransfer {
            transaction.subcategory = destination
            transaction.category = destination.category
        }

        try context.save()
        context.processPendingChanges()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Deletes all transactions associated with the subcategory
    func deleteTransactions(for subcategory: Subcategory) throws {
        guard let context = modelContext else { return }
        let sourceID = subcategory.persistentModelID

        let descriptor = FetchDescriptor<TransactionItem>()
        let allTransactions = try context.fetch(descriptor)
        let transactionsToDelete = allTransactions.filter {
            $0.subcategory?.persistentModelID == sourceID
        }

        for transaction in transactionsToDelete {
            context.delete(transaction)
        }

        try context.save()
        context.processPendingChanges()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Gets or creates the "Unassigned" subcategory in the "Others" category
    func getOrCreateUnassignedSubcategory(for sourceSubcategory: Subcategory) -> Subcategory? {
        guard let context = modelContext else { return nil }

        let isIncome = sourceSubcategory.safeCategory.isIncome
        let othersName = L10n.Category.others
        let unassignedName = L10n.Subcategory.unassigned

        // Find or create "Others" category
        var othersCategory: Category? = allCategories.first {
            $0.name == othersName && $0.isIncome == isIncome
        }

        if othersCategory == nil {
            // Create "Others" category
            let maxSortOrder = allCategories.map { $0.sortOrder }.max() ?? -1
            let newCategory = Category(
                name: othersName,
                colorHex: AppConstants.othersColorHex,  // Gray color
                isIncome: isIncome,
                isDefaultSeed: false,
                isVisible: true,
                sortOrder: maxSortOrder + 1,
                iconName: "questionmark.folder"
            )
            context.insert(newCategory)
            othersCategory = newCategory
        }

        guard let category = othersCategory else { return nil }

        // Find or create "Unassigned" subcategory
        var unassignedSubcategory: Subcategory? = allSubcategories.first {
            $0.name == unassignedName && $0.safeCategory.persistentModelID == category.persistentModelID
        }

        if unassignedSubcategory == nil {
            // Create "Unassigned" subcategory
            let maxSortOrder = (category.subcategories ?? []).map { $0.sortOrder }.max() ?? -1
            let newSubcategory = Subcategory(
                name: unassignedName,
                colorHex: category.colorHex,
                isDefaultSeed: false,
                isVisible: true,
                sortOrder: maxSortOrder + 1,
                natureRawValue: SubcategoryNeed.unclassified.rawValue,
                iconName: "questionmark",
                category: category
            )
            context.insert(newSubcategory)
            unassignedSubcategory = newSubcategory
        }

        // Save to ensure IDs are generated
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("SubcategoryTransferViewModel: Error saving unassigned subcategory: \(error)")
            #endif
            return nil
        }

        return unassignedSubcategory
    }
}
