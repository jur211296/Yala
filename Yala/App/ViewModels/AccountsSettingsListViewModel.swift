//
//  AccountsSettingsListViewModel.swift
//  Yala
//
//  ViewModel for AccountsSettingsListView - handles account list state and reordering.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AccountsSettingsListViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var accounts: [Account] = []
    private(set) var transactions: [TransactionItem] = []

    // MARK: - UI State

    var isPresentingCreateAccount = false
    var accountToEdit: Account?
    var isEditMode = false

    // MARK: - Sort Order (synced from AppStorage via View)

    var accountsSortOrderNamesRaw: String = "" {
        didSet {
            accountSortIndexCache = nil
        }
    }

    // MARK: - Computed Properties

    private var accountSortIndexCache: [String: Int]?

    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }

    private var accountSortIndex: [String: Int] {
        if let cache = accountSortIndexCache {
            return cache
        }
        let index = Dictionary(uniqueKeysWithValues: accountsSortOrderNames.enumerated().map { ($1, $0) })
        accountSortIndexCache = index
        return index
    }

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var orderedActiveAccounts: [Account] {
        let indexByName = accountSortIndex

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    var archivedAccounts: [Account] {
        accounts.filter { $0.isArchived }
    }

    var isEmpty: Bool {
        accounts.isEmpty
    }

    var existingNames: [String] {
        accounts.map { $0.name }
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
            accounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("AccountsSettingsListViewModel: Error loading accounts: \(error)")
            #endif
            accounts = []
        }

        // Load transactions (for balance calculation)
        let transactionDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
        )
        do {
            transactions = try context.fetch(transactionDescriptor)
        } catch {
            #if DEBUG
            print("AccountsSettingsListViewModel: Error loading transactions: \(error)")
            #endif
            transactions = []
        }
    }

    // MARK: - Balance Calculation

    func formattedBalance(for account: Account) -> String {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let info = currencyInfo(for: currency)

        let currentDecimal = AccountBalanceCalculator.currentBalance(
            for: account,
            allTransactions: transactions
        )
        let nsNumber = currentDecimal as NSDecimalNumber
        let amountDouble = nsNumber.doubleValue

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formattedAmount = formatter.string(from: NSNumber(value: amountDouble)) ?? "0.00"
        return "\(info.code) \(formattedAmount)"
    }

    // MARK: - Reorder Logic

    func moveAccount(from source: IndexSet, to destination: Int) -> String {
        var currentOrder = orderedActiveAccounts.map { $0.name }
        currentOrder.move(fromOffsets: source, toOffset: destination)
        let newRaw = currentOrder.joined(separator: "|")
        accountsSortOrderNamesRaw = newRaw
        return newRaw
    }

    // MARK: - Helper for Edit

    func existingNamesExcluding(_ account: Account) -> [String] {
        accounts.map { $0.name }.filter { $0 != account.name }
    }
}
