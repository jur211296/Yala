//
//  CategoryDetailViewModel.swift
//  Yala
//
//  ViewModel for CategoryDetailView - handles category editing and subcategory management.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class CategoryDetailViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    let category: Category
    let isNewCategory: Bool
    private(set) var allSubcategories: [Subcategory] = []

    // MARK: - Form State (editable)

    var name: String
    var isVisible: Bool
    var iconName: String
    var colorHex: String

    // Initial values for change detection
    private let initialName: String
    private let initialIsVisible: Bool
    private let initialIconName: String
    private let initialColorHex: String

    // MARK: - Computed Properties

    var subcategories: [Subcategory] {
        allSubcategories
            .filter { $0.category == category }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var visibleSubcategories: [Subcategory] {
        subcategories.filter { $0.isVisible }
    }

    var hiddenSubcategories: [Subcategory] {
        subcategories.filter { !$0.isVisible }
    }

    var hasUnsavedChanges: Bool {
        let trimmedCurrentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName
            || isVisible != initialIsVisible
            || iconName != initialIconName
            || colorHex != initialColorHex
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasUnsavedChanges
    }

    var displayName: String {
        name.isEmpty ? L10n.Category.newCategory : name
    }

    var isSystemCategory: Bool {
        // `isSystem` cubre las categorías sistema del bridge de grupos ("Grupos",
        // "Cobros de grupos"). Se preserva la protección legacy de "Otros" y de las
        // categorías de ingreso, que ya eran read-only por esta vía.
        category.isSystem || category.isIncome || category.name == "Otros"
    }

    // MARK: - Init

    init(category: Category, isNewCategory: Bool = false) {
        self.category = category
        self.isNewCategory = isNewCategory
        self.initialName = category.name
        self.initialIsVisible = category.isVisible
        self.initialIconName = category.iconName ?? "tag"
        self.initialColorHex = category.colorHex
        self.name = category.name
        self.isVisible = category.isVisible
        self.iconName = category.iconName ?? "tag"
        self.colorHex = category.colorHex
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        deletionService.setContext(context)
        loadSubcategories()
    }

    // MARK: - Data Loading

    func loadSubcategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }
    }

    // MARK: - Category Operations

    func countTransactionsInCategory() -> Int {
        guard let service = deletionService else { return 0 }
        return service.transactionCount(forCategory: category)
    }

    func saveCategory() -> Bool {
        guard let context = modelContext else { return false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        if isNewCategory && subcategories.isEmpty {
            return false
        }

        category.name = trimmedName
        category.isVisible = isVisible
        category.iconName = iconName
        category.colorHex = colorHex

        // Enforce color inheritance for all subcategories
        for subcategory in category.subcategories ?? [] {
            subcategory.colorHex = colorHex
        }

        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error saving category: \(error)")
            #endif
            return false
        }
    }

    func deleteCategory() -> Bool {
        guard let service = deletionService else { return false }
        do {
            try service.deleteCategory(category, withSubcategories: subcategories)
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error deleting category: \(error)")
            #endif
            return false
        }
    }

    func discardNewCategory() {
        guard let context = modelContext, isNewCategory else { return }
        context.delete(category)
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error discarding new category: \(error)")
            #endif
        }
    }

    // MARK: - Subcategory Operations

    func countTransactionsForSubcategory(_ subcategory: Subcategory) -> Int {
        guard let service = deletionService else { return 0 }
        return service.transactionCount(forSubcategory: subcategory)
    }

    func deleteSubcategory(_ subcategory: Subcategory) -> Bool {
        guard let service = deletionService else { return false }
        do {
            try service.deleteSubcategory(subcategory)
            loadSubcategories()
            return true
        } catch {
            #if DEBUG
            print("CategoryDetailViewModel: Error deleting subcategory: \(error)")
            #endif
            return false
        }
    }
}
