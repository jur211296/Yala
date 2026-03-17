//
//  CategoriesSettingsListViewModel.swift
//  Yala
//
//  ViewModel for CategoriesSettingsListView - handles category list state and operations.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CategoriesSettingsListViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    private(set) var categories: [Category] = []

    // MARK: - UI State

    var isEditing = false
    var isNavigatingToNewCategory = false
    var newCategory: Category?
    var showCannotDeleteAlert = false
    var categoryToDeleteName = ""
    var transactionCountForAlert = 0

    // MARK: - Computed Properties

    var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var activeCategories: [Category] {
        orderedCategories.filter { $0.isVisible }
    }

    var hiddenCategories: [Category] {
        orderedCategories.filter { !$0.isVisible }
    }

    var isEmpty: Bool {
        categories.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        deletionService.setContext(context)
        loadCategories()
    }

    // MARK: - Data Loading

    func loadCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.name)])
        do {
            categories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error loading categories: \(error)")
            #endif
            categories = []
        }
    }

    // MARK: - Category Creation

    func createAndOpenNewCategory() {
        guard let context = modelContext else { return }

        let nextSortOrder = (categories.map { $0.sortOrder }.max() ?? 0) + 1

        let category = Category(
            name: "",
            colorHex: AppConstants.defaultColorHex,
            isIncome: false,
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            subcategories: []
        )
        context.insert(category)

        newCategory = category
        isNavigatingToNewCategory = true
    }

    // MARK: - Category Deletion

    func handleCategoryDelete(_ category: Category) {
        guard let context = modelContext else { return }

        let count = countTransactionsInCategory(category)
        if count > 0 {
            categoryToDeleteName = category.name
            transactionCountForAlert = count
            showCannotDeleteAlert = true
            return
        }

        // Delete subcategories first to avoid SwiftUI @Query conflicts
        for subcategory in category.subcategories ?? [] {
            context.delete(subcategory)
        }
        context.delete(category)

        do {
            try context.save()
            context.processPendingChanges()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            loadCategories()
        } catch {
            #if DEBUG
            print("CategoriesSettingsListViewModel: Error deleting category: \(error)")
            #endif
        }
    }

    private func countTransactionsInCategory(_ category: Category) -> Int {
        guard let service = deletionService else { return 0 }
        return service.transactionCount(forCategory: category)
    }
}
