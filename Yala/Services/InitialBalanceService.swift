//
//  InitialBalanceService.swift
//  Yala
//
//  Manages initial balance and adjustment transactions for accounts.
//  Centralizes the logic for creating, finding, and updating balance-related transactions.
//

import Foundation
import SwiftData

/// Service for managing initial balance and adjustment transactions
struct InitialBalanceService {

    // MARK: - Balance Adjustment Types

    static let typeInitialBalance = "initial_balance"
    static let typeAdjustment = "adjustment"

    // MARK: - Find Operations

    /// Finds the initial balance transaction for an account
    static func findInitialBalanceTransaction(
        for account: Account,
        in context: ModelContext
    ) -> TransactionItem? {
        let accountID = account.persistentModelID
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { transaction in
                transaction.balanceAdjustmentType == "initial_balance"
            }
        )

        do {
            let transactions = try context.fetch(descriptor)
            return transactions.first { $0.account?.persistentModelID == accountID }
        } catch {
            #if DEBUG
            print("Error fetching initial balance transaction: \(error)")
            #endif
            return nil
        }
    }

    /// Calculates the current balance of an account from transactions
    static func currentBalance(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Double {
        let accountTransactions = allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID
        }
        return accountTransactions.reduce(0.0) { $0 + $1.amount }
    }

    // MARK: - Date Calculation

    /// Calculates the appropriate date for an initial balance transaction
    /// - Returns: 1st of the month of the earliest transaction, or 1st of current month if no transactions
    static func calculateInitialBalanceDate(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Date {
        let calendar = Calendar.current
        let accountID = account.persistentModelID

        // Get non-adjustment transactions for this account
        let accountTransactions = allTransactions.filter {
            $0.account?.persistentModelID == accountID
                && $0.balanceAdjustmentType == nil
        }

        if let earliestDate = accountTransactions.map({ $0.date }).min() {
            // First day of the month of the earliest transaction
            let components = calendar.dateComponents([.year, .month], from: earliestDate)
            return calendar.date(from: components) ?? Date()
        } else {
            // No transactions - first day of current month
            let components = calendar.dateComponents([.year, .month], from: Date())
            return calendar.date(from: components) ?? Date()
        }
    }

    // MARK: - Transaction Creation/Update

    /// Creates or updates an initial balance transaction for an account
    /// Note: We delete and recreate instead of modifying in-place to ensure
    /// SwiftData's @Query observers detect the change.
    static func setInitialBalance(
        amount: Double,
        for account: Account,
        subcategory: Subcategory,
        allTransactions: [TransactionItem],
        context: ModelContext
    ) -> TransactionItem {
        let date = calculateInitialBalanceDate(for: account, allTransactions: allTransactions)

        // Delete existing initial balance if present
        // (deleting + inserting ensures @Query detects the change)
        if let existing = findInitialBalanceTransaction(for: account, in: context) {
            context.delete(existing)
        }

        // Create new initial balance transaction
        let transaction = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: account.currencyCode,
            note: L10n.Account.initialBalanceNote,
            amountInPreferredCurrency: amount,  // Will be updated by recalculation
            preferredCurrencyCode: account.currencyCode
        )
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.balanceAdjustmentType = typeInitialBalance

        context.insert(transaction)
        return transaction
    }

    /// Creates an adjustment transaction to reach a target balance
    static func createAdjustment(
        targetBalance: Double,
        currentBalance: Double,
        for account: Account,
        subcategory: Subcategory,
        date: Date,
        context: ModelContext
    ) -> TransactionItem {
        let adjustmentAmount = targetBalance - currentBalance

        let dateFormatter = DateFormatter()
        dateFormatter.locale = AppLocale.current
        dateFormatter.dateFormat = "d MMM yyyy"
        let dateString = dateFormatter.string(from: date)

        let note = "\(L10n.Account.adjustmentNote) - \(dateString)"

        let transaction = TransactionItem(
            date: date,
            amount: adjustmentAmount,
            currencyCode: account.currencyCode,
            note: note,
            amountInPreferredCurrency: adjustmentAmount,
            preferredCurrencyCode: account.currencyCode
        )
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.balanceAdjustmentType = typeAdjustment

        context.insert(transaction)
        return transaction
    }

    // MARK: - Helper

    /// Finds the "Ajustes de saldo" subcategory from the seed data
    static func findBalanceAdjustmentSubcategory(context: ModelContext) -> Subcategory? {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.name == "Ajustes de saldo"
            }
        )

        do {
            let subcategories = try context.fetch(descriptor)
            return subcategories.first
        } catch {
            #if DEBUG
            print("Error fetching balance adjustment subcategory: \(error)")
            #endif
            return nil
        }
    }

    /// Updates initial balance date when older transactions are imported
    static func updateInitialBalanceDateIfNeeded(
        for account: Account,
        allTransactions: [TransactionItem],
        context: ModelContext
    ) {
        guard let initialBalanceTx = findInitialBalanceTransaction(for: account, in: context)
        else {
            return
        }

        let newDate = calculateInitialBalanceDate(for: account, allTransactions: allTransactions)

        if newDate < initialBalanceTx.date {
            initialBalanceTx.date = newDate
        }
    }
}
