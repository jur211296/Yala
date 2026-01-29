//
//  AccountSelectorViewModel.swift
//  Yala
//
//  ViewModel for AccountSelectorSheet - handles account list loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AccountSelectorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var accounts: [Account] = []

    // MARK: - Computed Properties

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadAccounts()
    }

    // MARK: - Data Loading

    func loadAccounts() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            accounts = try context.fetch(descriptor)
        } catch {
            print("AccountSelectorViewModel: Error loading accounts: \(error)")
            accounts = []
        }
    }
}
