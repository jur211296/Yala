//
//  BudgetsFavoritesSettingsViewModel.swift
//  Yala
//
//  ViewModel for BudgetsFavoritesSettingsView - handles favorite budgets management.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BudgetsFavoritesSettingsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var sessionState: SessionState?

    // MARK: - Data

    private(set) var activeBudgets: [Budget] = []

    // MARK: - UI State

    var isEditMode = false
    var showSaveError = false

    // MARK: - Computed Properties

    var budgetsByPeriod: [(periodType: BudgetPeriodType, budgets: [Budget])] {
        let grouped = Dictionary(grouping: activeBudgets) { budget in
            BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        }

        return BudgetPeriodType.allCases.compactMap { periodType in
            guard let budgets = grouped[periodType], !budgets.isEmpty else { return nil }
            let sorted = budgets.sorted { a, b in
                if a.isFavorite && b.isFavorite {
                    return a.favoriteOrder < b.favoriteOrder
                } else if a.isFavorite {
                    return true
                } else if b.isFavorite {
                    return false
                } else {
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
            return (periodType, sorted)
        }
    }

    var favoriteBudgets: [Budget] {
        activeBudgets
            .filter { $0.isFavorite }
            .sorted { $0.favoriteOrder < $1.favoriteOrder }
    }

    var isEmpty: Bool {
        activeBudgets.isEmpty
    }

    var hasFavorites: Bool {
        !favoriteBudgets.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, sessionState: SessionState) {
        self.modelContext = context
        self.sessionState = sessionState
        loadBudgets()
    }

    // MARK: - Data Loading

    func loadBudgets() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.isActive }
        )
        do {
            activeBudgets = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BudgetsFavoritesSettingsViewModel: Error loading budgets: \(error)")
            #endif
            activeBudgets = []
        }
    }

    // MARK: - Favorite Operations

    func toggleFavorite(_ budget: Budget) {
        guard let context = modelContext else { return }

        if budget.isFavorite {
            budget.isFavorite = false
            budget.favoriteOrder = 0
            reindexFavorites()
        } else {
            let maxOrder = favoriteBudgets.map { $0.favoriteOrder }.max() ?? -1
            budget.isFavorite = true
            budget.favoriteOrder = maxOrder + 1
        }

        do {
            try context.save()
            loadBudgets()
        } catch {
            #if DEBUG
            print("BudgetsFavoritesSettingsViewModel: Error saving: \(error)")
            #endif
            showSaveError = true
        }

        sessionState?.needsBudgetsWidgetRefresh = true
    }

    func moveBudget(from source: IndexSet, to destination: Int) {
        guard let context = modelContext else { return }

        var ordered = favoriteBudgets
        ordered.move(fromOffsets: source, toOffset: destination)

        for (index, budget) in ordered.enumerated() {
            budget.favoriteOrder = index
        }

        do {
            try context.save()
            loadBudgets()
        } catch {
            #if DEBUG
            print("BudgetsFavoritesSettingsViewModel: Error moving: \(error)")
            #endif
            showSaveError = true
        }

        sessionState?.needsBudgetsWidgetRefresh = true
    }

    private func reindexFavorites() {
        let sorted = favoriteBudgets.sorted { $0.favoriteOrder < $1.favoriteOrder }
        for (index, budget) in sorted.enumerated() {
            budget.favoriteOrder = index
        }
    }
}
