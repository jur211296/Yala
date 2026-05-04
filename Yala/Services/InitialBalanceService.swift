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
@MainActor struct InitialBalanceService {

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
            return calendar.date(from: components) ?? Date.now
        } else {
            // No transactions - first day of current month
            let components = calendar.dateComponents([.year, .month], from: Date.now)
            return calendar.date(from: components) ?? Date.now
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

        // Delete ALL existing initial balance transactions for this account.
        // Defensivo ante eventuales duplicados ("zombies") creados por bugs
        // anteriores; también garantiza idempotencia en re-ejecuciones.
        let zombies = allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && $0.balanceAdjustmentType == typeInitialBalance
        }
        for zombie in zombies {
            context.delete(zombie)
        }

        // Create new initial balance transaction.
        // amountInPreferredCurrency / preferredCurrencyCode son placeholders —
        // se sobrescriben con valores correctos via recalculatePreferredCurrency
        // post-insert (necesario en multi-divisa: si la moneda preferida del
        // usuario != moneda nativa de la cuenta, el snapshot debe estar en
        // moneda preferida con TC del día).
        let transaction = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: account.currencyCode,
            note: L10n.Account.initialBalanceNote,
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: account.currencyCode
        )
        transaction.account = account
        transaction.subcategory = subcategory
        transaction.balanceAdjustmentType = typeInitialBalance

        context.insert(transaction)
        transaction.recalculatePreferredCurrency(context: context)
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

        // amountInPreferredCurrency / preferredCurrencyCode son placeholders —
        // se sobrescriben via recalculatePreferredCurrency post-insert (mismo
        // motivo que setInitialBalance).
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
        transaction.recalculatePreferredCurrency(context: context)
        return transaction
    }

    // MARK: - Helper

    /// Finds the balance adjustment subcategory from the seed data (localized)
    static func findBalanceAdjustmentSubcategory(context: ModelContext) -> Subcategory? {
        let localizedName = L10n.Subcategory.balanceAdjustment
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate<Subcategory> { subcategory in
                subcategory.name == localizedName
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

    /// Ensures a balance adjustment subcategory exists, creating minimal "Otros" category if needed.
    /// Used when user skips seed categories but needs initial balance support.
    @discardableResult
    static func ensureBalanceAdjustmentSubcategoryExists(context: ModelContext) -> Subcategory? {
        if let existing = findBalanceAdjustmentSubcategory(context: context) {
            return existing
        }

        let otherName = L10n.Category.other
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { cat in
                cat.name == otherName
            }
        )

        do {
            let existingCategories = try context.fetch(categoryDescriptor)
            let category: Category

            if let existing = existingCategories.first {
                category = existing
            } else {
                category = Category(
                    name: otherName,
                    colorHex: "#64748B",
                    isIncome: false,
                    iconName: "ellipsis.circle.fill"
                )
                context.insert(category)
            }

            let subcategory = Subcategory(
                name: L10n.Subcategory.balanceAdjustment,
                colorHex: "#64748B",
                natureRawValue: "sin_clasificacion",
                iconName: "plusminus",
                category: category
            )
            context.insert(subcategory)
            return subcategory
        } catch {
            #if DEBUG
            print("InitialBalanceService: Error creating balance adjustment subcategory: \(error)")
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
