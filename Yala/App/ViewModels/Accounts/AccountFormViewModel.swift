//
//  AccountFormViewModel.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@MainActor
@Observable
final class AccountFormViewModel {

    // MARK: - Dependencies
    private var modelContext: ModelContext?
    var accountToEdit: Account?
    var existingNames: [String] = []
    private(set) var allTransactions: [TransactionItem] = []

    // MARK: - Form State
    var name: String = ""
    var selectedType: AccountType = .general
    var accountNumber: String = ""

    // Balance - new transaction-based system
    var isPositive: Bool = true  // Sign selector for balance
    var balanceText: String = ""  // Amount without sign
    var adjustmentDate: Date = Date()

    // Currency
    var selectedCurrency: CurrencyCode = .pen

    // Adjustment Mode
    var selectedAdjustmentMode: AdjustmentMode = .changeInitialBalance

    // Color
    var selectedColorHex: String = "#6366F1"
    var customColor: Color = Color(hex: "6366F1")
    var isPresentingColorPicker: Bool = false

    // Actions
    var excludeFromStatistics: Bool = false
    var isArchived: Bool = false

    // MARK: - UI State
    var isShowingDeleteError: Bool = false
    var deleteErrorMessage: String = ""
    var isShowingSaveError: Bool = false
    var hasInitializedBalance: Bool = false  // Track if balance was initialized from transactions

    // MARK: - Computed Balance Properties

    /// Current balance calculated from all transactions
    var currentBalance: Double {
        guard let account = accountToEdit else { return 0 }
        return InitialBalanceService.currentBalance(
            for: account,
            allTransactions: allTransactions
        )
    }

    /// Existing initial balance transaction amount (for editing)
    var existingInitialBalance: Double {
        guard let account = accountToEdit else { return 0 }
        // Need to get from context, but we don't have it here
        // So we calculate: current balance - sum of non-initial transactions
        let nonInitialTransactions = allTransactions.filter {
            $0.account?.persistentModelID == account.persistentModelID
                && $0.balanceAdjustmentType != InitialBalanceService.typeInitialBalance
        }
        let otherTransactionsSum = nonInitialTransactions.reduce(0.0) { $0 + $1.amount }
        return currentBalance - otherTransactionsSum
    }

    /// The parsed balance amount from user input
    var parsedBalanceAmount: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let decimal = parseDecimal(from: trimmed) else { return nil }
        let magnitude = (decimal as NSDecimalNumber).doubleValue
        return isPositive ? magnitude : -magnitude
    }

    /// For "Cambiar saldo inicial" mode: what the final balance will be
    var calculatedFinalBalance: Double? {
        guard selectedAdjustmentMode == .changeInitialBalance else { return nil }
        guard let newInitial = parsedBalanceAmount else { return nil }
        // Final = Current - OldInitial + NewInitial
        let oldInitial = existingInitialBalance
        return currentBalance - oldInitial + newInitial
    }

    /// For "Ajustar por registro" mode: the adjustment amount needed
    var adjustmentAmount: Double? {
        guard selectedAdjustmentMode == .byEntry else { return nil }
        guard let targetBalance = parsedBalanceAmount else { return nil }
        return targetBalance - currentBalance
    }

    /// Whether an adjustment is needed
    var needsAdjustment: Bool {
        if selectedAdjustmentMode == .changeInitialBalance {
            guard let newInitial = parsedBalanceAmount else { return false }
            return abs(newInitial - existingInitialBalance) > 0.01
        } else {
            guard let adjustment = adjustmentAmount else { return false }
            return abs(adjustment) > 0.01
        }
    }

    // MARK: - Initialization

    init(accountToEdit: Account?, existingNames: [String], allTransactions: [TransactionItem] = [])
    {
        self.accountToEdit = accountToEdit
        self.existingNames = existingNames
        self.allTransactions = allTransactions

        if let account = accountToEdit {
            self.name = account.name
            self.selectedType = AccountType(rawValue: account.type) ?? .general
            self.accountNumber = account.accountNumber ?? ""

            self.selectedCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode)) ?? .pen

            // Default to "Ajustar por registro" when editing
            self.selectedAdjustmentMode = .byEntry

            self.selectedColorHex = account.colorHex
            self.customColor = colorForHex(account.colorHex)

            self.excludeFromStatistics = account.excludeFromStatistics
            self.isArchived = account.isArchived

            // Don't pre-fill balance here - will be done in initializeBalanceIfNeeded()
            // after transactions are loaded
            self.isPositive = true
            self.balanceText = ""
        } else {
            // Creation mode - default to "Cambiar saldo inicial"
            self.selectedAdjustmentMode = .changeInitialBalance
            self.selectedColorHex = "#6366F1"
            self.customColor = Color(hex: "6366F1")
            self.isPositive = true
            self.balanceText = ""
        }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadTransactions()
        initializeBalanceIfNeeded()
    }

    func loadTransactions() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<TransactionItem>()
        do {
            allTransactions = try context.fetch(descriptor)
        } catch {
            print("AccountFormViewModel: Error loading transactions: \(error)")
            allTransactions = []
        }
    }

    /// Call this after transactions are loaded to pre-fill the initial balance
    func initializeBalanceIfNeeded() {
        guard isEditing, !hasInitializedBalance, !allTransactions.isEmpty else { return }

        let existingInitial = existingInitialBalance
        isPositive = existingInitial >= 0
        balanceText = String(format: "%.2f", abs(existingInitial))
        hasInitializedBalance = true
    }

    // MARK: - Computed Properties (Validation)

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isNameValid: Bool {
        !trimmedName.isEmpty
    }

    var isNameUnique: Bool {
        let lower = trimmedName.lowercased()
        if let account = accountToEdit, account.name.lowercased() == lower {
            return true
        }
        return
            !existingNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .contains(lower)
    }

    var isCurrencyValid: Bool {
        CurrencyCode.allCases.contains(where: { $0.rawValue == selectedCurrency.rawValue })
    }

    var isBalanceValid: Bool {
        // For new accounts, must have an initial balance
        // For existing accounts, balance change is optional
        if isEditing {
            return balanceText.isEmpty || parsedBalanceAmount != nil
        } else {
            return parsedBalanceAmount != nil
        }
    }

    var canSave: Bool {
        isNameValid && isNameUnique && isCurrencyValid && isBalanceValid
    }

    var isEditing: Bool {
        accountToEdit != nil
    }

    var colorOptions: [String] {
        ["#FF0080", "#D62246", "#FF7F11", "#4CB963", "#6366F1", "#1B065E", "#0F172A"]
    }

    // MARK: - Actions

    func updateColorFromCustom() {
        selectedColorHex = hexString(from: customColor)
        isPresentingColorPicker = false
    }

    func saveAccount(context: ModelContext) -> Bool {
        guard canSave else { return false }

        let trimmedAccountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the balance adjustment subcategory
        let subcategory = InitialBalanceService.findBalanceAdjustmentSubcategory(context: context)

        if let account = accountToEdit {
            // Update account properties
            account.name = trimmedName
            account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)
            account.colorHex = selectedColorHex
            account.iconName = iconName(for: selectedType)
            account.type = selectedType.rawValue
            account.accountNumber = trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber
            account.adjustmentMode = selectedAdjustmentMode.rawValue
            account.excludeFromStatistics = excludeFromStatistics
            account.isArchived = isArchived

            // Handle balance adjustment if specified
            if let balanceValue = parsedBalanceAmount, needsAdjustment, let sub = subcategory {
                if selectedAdjustmentMode == .changeInitialBalance {
                    // Update or create initial balance transaction with the new initial balance value
                    _ = InitialBalanceService.setInitialBalance(
                        amount: balanceValue,
                        for: account,
                        subcategory: sub,
                        allTransactions: allTransactions,
                        context: context
                    )
                } else {
                    // Create adjustment transaction to reach target balance
                    _ = InitialBalanceService.createAdjustment(
                        targetBalance: balanceValue,
                        currentBalance: currentBalance,
                        for: account,
                        subcategory: sub,
                        date: adjustmentDate,
                        context: context
                    )
                }
            }
        } else {
            // Create new account
            let newAccount = Account(
                name: trimmedName,
                currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
                colorHex: selectedColorHex,
                iconName: iconName(for: selectedType),
                type: selectedType.rawValue,
                accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
                adjustmentMode: selectedAdjustmentMode.rawValue,
                excludeFromStatistics: excludeFromStatistics,
                isArchived: isArchived
            )
            context.insert(newAccount)

            // Create initial balance transaction if amount specified
            if let initialAmount = parsedBalanceAmount, let sub = subcategory {
                _ = InitialBalanceService.setInitialBalance(
                    amount: initialAmount,
                    for: newAccount,
                    subcategory: sub,
                    allTransactions: [],
                    context: context
                )
            }
        }

        // Force save to ensure @Query observers are notified of changes
        do {
            try context.save()
        } catch {
            isShowingSaveError = true
            return false
        }

        return true
    }

    func deleteAccount(context: ModelContext) -> Bool {
        guard let account = accountToEdit else { return false }
        context.delete(account)
        return true
    }

    // MARK: - Helpers

    private func hexString(from color: Color) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var success = false

        #if canImport(UIKit)
            let uiColor = UIColor(color)
            success = uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
            let nsColor = NSColor(color)
            if let rgbColor = nsColor.usingColorSpace(.sRGB) {
                rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                success = true
            }
        #endif

        if success {
            let r = Int(red * 255)
            let g = Int(green * 255)
            let b = Int(blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return selectedColorHex
        }
    }
}
