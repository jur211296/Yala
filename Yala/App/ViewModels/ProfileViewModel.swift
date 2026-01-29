//
//  ProfileViewModel.swift
//  Yala
//
//  ViewModel for ProfileView - handles data loading for import/export.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProfileViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTransactions: [TransactionItem] = []
    private(set) var accounts: [Account] = []
    private(set) var categories: [Category] = []

    // MARK: - Computed Properties

    var hasTransactions: Bool {
        !allTransactions.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        loadTransactions()
        loadAccounts()
        loadCategories()
    }

    private func loadTransactions() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TransactionItem>()
        do {
            allTransactions = try context.fetch(descriptor)
        } catch {
            print("ProfileViewModel: Error loading transactions: \(error)")
            allTransactions = []
        }
    }

    private func loadAccounts() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Account>()
        do {
            accounts = try context.fetch(descriptor)
        } catch {
            print("ProfileViewModel: Error loading accounts: \(error)")
            accounts = []
        }
    }

    private func loadCategories() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Category>()
        do {
            categories = try context.fetch(descriptor)
        } catch {
            print("ProfileViewModel: Error loading categories: \(error)")
            categories = []
        }
    }
}
