//
//  BudgetEditorViewModel.swift
//  Yala
//
//  ViewModel for BudgetEditorView - handles data loading and save/delete operations.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BudgetEditorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    private(set) var categories: [Category] = []
    private(set) var allAccounts: [Account] = []
    private(set) var allTags: [Tag] = []
    private(set) var allSubcategories: [Subcategory] = []

    // MARK: - State

    private(set) var showSaveError = false

    // MARK: - Computed Properties

    var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load categories
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\Category.name)])
        do {
            categories = try context.fetch(categoryDescriptor)
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error loading categories: \(error)")
            #endif
            categories = []
        }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            allAccounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }

        // Load subcategories
        let subcategoryDescriptor = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\Subcategory.sortOrder)])
        do {
            allSubcategories = try context.fetch(subcategoryDescriptor)
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error loading subcategories: \(error)")
            #endif
            allSubcategories = []
        }
    }

    // MARK: - Helper Methods

    func selectedCategoriesText(selectedSubcategories: Set<PersistentIdentifier>) -> String {
        let subCount = selectedSubcategories.count

        if subCount == 0 {
            return NSLocalizedString("filters.all", comment: "")
        }

        let selectedSubs = allSubcategories.filter {
            selectedSubcategories.contains($0.persistentModelID)
        }
        if selectedSubs.isEmpty {
            return NSLocalizedString("filters.all", comment: "")
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return NSLocalizedString("filters.all", comment: "")
    }

    // MARK: - Save Operation

    func saveBudget(
        existing: Budget?,
        name: String,
        limitAmount: Double,
        currencyCode: String,
        periodType: BudgetPeriodType,
        startDate: Date,
        endDate: Date,
        isActive: Bool,
        selectedAccounts: Set<PersistentIdentifier>,
        selectedSubcategories: Set<PersistentIdentifier>,
        selectedTags: Set<PersistentIdentifier>,
        selectedNatures: Set<SubcategoryNature>,
        alertEnabled: Bool,
        alertThresholds: Set<Int>
    ) -> Bool {
        guard let context = modelContext else { return false }

        // Convert PersistentIdentifiers to model objects
        let accountsArray = activeAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let subcategoriesArray = allSubcategories.filter { selectedSubcategories.contains($0.persistentModelID) }
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }
        let naturesString = selectedNatures.isEmpty ? nil : selectedNatures.map { $0.rawValue }.joined(separator: ",")
        let thresholdsString = alertThresholds.isEmpty ? nil : alertThresholds.sorted().map { String($0) }.joined(separator: ",")

        if let existingBudget = existing {
            // Update existing budget
            existingBudget.name = name
            existingBudget.limitAmount = limitAmount
            existingBudget.currencyCode = currencyCode
            existingBudget.periodType = periodType.rawValue
            existingBudget.isActive = isActive
            existingBudget.startDate = periodType == .unique ? startDate : nil
            existingBudget.endDate = periodType == .unique ? endDate : nil
            existingBudget.accounts = accountsArray
            existingBudget.subcategories = subcategoriesArray
            existingBudget.tags = tagsArray
            existingBudget.natures = naturesString
            existingBudget.alertEnabled = alertEnabled
            existingBudget.alertThresholds = thresholdsString
        } else {
            // Create new budget
            let newBudget = Budget(
                currencyCode: currencyCode,
                limitAmount: limitAmount,
                name: name,
                periodType: periodType.rawValue,
                startDate: periodType == .unique ? startDate : nil,
                endDate: periodType == .unique ? endDate : nil,
                accounts: accountsArray,
                subcategories: subcategoriesArray,
                tags: tagsArray,
                natures: naturesString,
                isActive: isActive,
                alertEnabled: alertEnabled,
                alertThresholds: thresholdsString
            )
            context.insert(newBudget)
        }

        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            return true
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error saving budget: \(error)")
            #endif
            showSaveError = true
            return false
        }
    }

    // MARK: - Delete Operation

    func deleteBudget(_ budget: Budget) -> Bool {
        guard let context = modelContext, let service = deletionService else { return false }

        service.setContext(context)
        do {
            try service.deleteBudget(budget)
            return true
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error deleting budget: \(error)")
            #endif
            showSaveError = true
            return false
        }
    }

    func dismissSaveError() {
        showSaveError = false
    }
}
