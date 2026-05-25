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

    /// A0-Bridge: excluye cuentas sistema de pickers manuales.
    var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived && !$0.isSystemAccount }
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
        let names = resolveNamesList(from: allSubcategories, ids: selectedSubcategories, name: \.name)
        guard let first = names.first else {
            return NSLocalizedString("filters.all", comment: "")
        }
        return names.count > 1 ? "\(first) +\(names.count - 1)" : first
    }

    func filterSummaryText(
        selectedAccounts: Set<PersistentIdentifier>,
        selectedSubcategories: Set<PersistentIdentifier>,
        selectedTags: Set<PersistentIdentifier>,
        selectedNeeds: Set<SubcategoryNeed>
    ) -> String? {
        guard !selectedAccounts.isEmpty || !selectedSubcategories.isEmpty
           || !selectedTags.isEmpty || !selectedNeeds.isEmpty else { return nil }

        var phrases: [String] = []

        let accountNames = resolveNamesList(from: activeAccounts, ids: selectedAccounts, name: \.name)
        if !accountNames.isEmpty {
            let list = naturalJoin(truncatedNames(accountNames))
            let key = accountNames.count == 1 ? "guide.budgetFilter.account" : "guide.budgetFilter.accounts"
            phrases.append(String(format: NSLocalizedString(key, comment: ""), list))
        }

        let subNames = resolveNamesList(from: allSubcategories, ids: selectedSubcategories, name: \.name)
        if !subNames.isEmpty {
            let list = naturalJoin(truncatedNames(subNames))
            let key = subNames.count == 1 ? "guide.budgetFilter.subcategory" : "guide.budgetFilter.subcategories"
            phrases.append(String(format: NSLocalizedString(key, comment: ""), list))
        }

        let needNames = selectedNeeds.sorted(by: { $0.rawValue < $1.rawValue }).map(\.displayName)
        if !needNames.isEmpty {
            let list = naturalJoin(truncatedNames(needNames))
            phrases.append(String(format: NSLocalizedString("guide.budgetFilter.needs", comment: ""), list))
        }

        let tagNames = resolveNamesList(from: activeTags, ids: selectedTags, name: \.name)
        if !tagNames.isEmpty {
            let list = naturalJoin(truncatedNames(tagNames))
            let key = tagNames.count == 1 ? "guide.budgetFilter.tag" : "guide.budgetFilter.tags"
            phrases.append(String(format: NSLocalizedString(key, comment: ""), list))
        }

        guard !phrases.isEmpty else { return nil }

        let prefix = NSLocalizedString("guide.budgetFilter.prefix", comment: "")
        return prefix + " " + phrases.joined(separator: ", ")
    }

    // MARK: - Filter Summary Helpers

    private func resolveNamesList<T: PersistentModel>(
        from collection: [T],
        ids: Set<PersistentIdentifier>,
        name keyPath: KeyPath<T, String>
    ) -> [String] {
        guard !ids.isEmpty else { return [] }
        return collection.filter { ids.contains($0.persistentModelID) }.map { $0[keyPath: keyPath] }
    }

    private func naturalJoin(_ items: [String]) -> String {
        let conj = NSLocalizedString("guide.budgetFilter.conjunction", comment: "")
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) \(conj) \(items[1])"
        default:
            guard let last = items.last else { return "" }
            return items.dropLast().joined(separator: ", ") + " \(conj) \(last)"
        }
    }

    private func truncatedNames(_ names: [String], max: Int = 4) -> [String] {
        guard names.count > max else { return names }
        let andMore = String(format: NSLocalizedString("guide.budgetFilter.andMore", comment: ""), names.count - 2)
        return Array(names.prefix(2)) + [andMore]
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
        selectedNeeds: Set<SubcategoryNeed>,
        alertEnabled: Bool,
        alertThresholds: Set<Int>,
        includeSharedExpenses: Bool
    ) -> PersistentIdentifier? {
        guard let context = modelContext else { return nil }

        // Convert PersistentIdentifiers to model objects
        let accountsArray = activeAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
        let subcategoriesArray = allSubcategories.filter { selectedSubcategories.contains($0.persistentModelID) }
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }
        let naturesString = selectedNeeds.isEmpty ? nil : selectedNeeds.map { $0.rawValue }.joined(separator: ",")
        let thresholdsString = alertThresholds.isEmpty ? nil : alertThresholds.sorted().map { String($0) }.joined(separator: ",")

        var savedBudgetID: PersistentIdentifier?
        var newBudgetUUID: UUID?

        if let existingBudget = existing {
            // Update existing budget
            existingBudget.name = name
            existingBudget.limitAmount = limitAmount
            existingBudget.currencyCode = currencyCode
            existingBudget.periodType = periodType.rawValue
            existingBudget.isActive = isActive
            existingBudget.startDate = periodType == .unique ? startDate : nil
            existingBudget.endDate = periodType == .unique ? endDate : nil
            // Dual-write: setFilters keeps M2M + CSV mirror in sync.
            existingBudget.setFilters(
                accounts: accountsArray,
                subcategories: subcategoriesArray,
                tags: tagsArray
            )
            existingBudget.natures = naturesString
            existingBudget.alertEnabled = alertEnabled
            existingBudget.alertThresholds = thresholdsString
            existingBudget.includeSharedExpenses = includeSharedExpenses
        } else {
            // Create new budget (init populates M2M; setFilters then mirrors to CSV).
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
                alertThresholds: thresholdsString,
                includeSharedExpenses: includeSharedExpenses
            )
            newBudget.setFilters(
                accounts: accountsArray,
                subcategories: subcategoriesArray,
                tags: tagsArray
            )
            context.insert(newBudget)
            newBudgetUUID = newBudget.id
        }

        do {
            try context.save()

            // Re-fetch persistent ID by UUID after save (pre-save IDs may not match)
            if let uuid = newBudgetUUID {
                let descriptor = FetchDescriptor<Budget>(predicate: #Predicate { $0.id == uuid })
                savedBudgetID = try context.fetch(descriptor).first?.persistentModelID
                #if DEBUG
                if savedBudgetID == nil {
                    print("BudgetEditorViewModel: Budget not found after save for UUID: \(uuid)")
                }
                #endif
            }

            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()

            TelemetryService.track(.budgetSaved, parameters: [
                "periodType": periodType.rawValue,
                "isNew": String(existing == nil),
            ])

            return savedBudgetID ?? existing?.persistentModelID
        } catch {
            #if DEBUG
            print("BudgetEditorViewModel: Error saving budget: \(error)")
            #endif
            showSaveError = true
            return nil
        }
    }

    // MARK: - Delete Operation

    func deleteBudget(_ budget: Budget) -> Bool {
        guard let context = modelContext, let service = deletionService else { return false }

        service.setContext(context)
        do {
            try service.deleteBudget(budget)
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
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
