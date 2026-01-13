//
//  AccountFormViewModel.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

@Observable
final class AccountFormViewModel {

    // MARK: - Dependencies
    var accountToEdit: Account?
    var existingNames: [String] = []

    // MARK: - Form State
    var name: String = ""
    var selectedType: AccountType = .general
    var accountNumber: String = ""

    // Balance
    var isPositive: Bool = true
    var balanceText: String = ""

    // Currency
    var selectedCurrency: CurrencyCode = .pen

    // Adjustment
    var selectedAdjustmentMode: AdjustmentMode = .byEntry

    // Color
    var selectedColorHex: String = "#6366F1"  // electricIndigo
    var customColor: Color = Color(hex: "6366F1")
    var isPresentingColorPicker: Bool = false

    // Actions
    var excludeFromStatistics: Bool = false
    var isArchived: Bool = false

    // MARK: - UI State
    var isShowingDeleteError: Bool = false
    var deleteErrorMessage: String = ""

    // MARK: - Initialization

    init(accountToEdit: Account?, existingNames: [String]) {
        self.accountToEdit = accountToEdit
        self.existingNames = existingNames

        if let account = accountToEdit {
            self.name = account.name
            self.selectedType = AccountType(rawValue: account.type) ?? .general
            self.accountNumber = account.accountNumber ?? ""

            let balance = account.initialBalance
            self.isPositive = balance >= 0
            self.balanceText = String(format: "%.2f", abs(balance))

            self.selectedCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode)) ?? .pen
            self.selectedAdjustmentMode =
                AdjustmentMode(rawValue: account.adjustmentMode) ?? .byEntry

            self.selectedColorHex = account.colorHex
            self.customColor = colorForHex(account.colorHex)

            self.excludeFromStatistics = account.excludeFromStatistics
            self.isArchived = account.isArchived
        } else {
            // Defaults are already set in property declarations
            self.selectedColorHex = "#6366F1"
            self.customColor = Color(hex: "6366F1")
        }
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
        // If editing, exclude current name from check if it matches
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

    var parsedAmount: Double? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }

        guard let decimal = parseDecimal(from: trimmed) else { return nil }
        return (decimal as NSDecimalNumber).doubleValue
    }

    var isAmountValid: Bool {
        parsedAmount != nil
    }

    var canSave: Bool {
        isNameValid && isNameUnique && isCurrencyValid && isAmountValid
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
        guard canSave, let amount = parsedAmount else { return false }

        let finalAmount = isPositive ? amount : -amount
        let trimmedAccountNumber = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        if let account = accountToEdit {
            // Update
            account.name = trimmedName
            account.currencyCode = normalizeCurrencyCode(selectedCurrency.rawValue)
            account.colorHex = selectedColorHex
            account.iconName = iconName(for: selectedType)
            account.type = selectedType.rawValue
            account.accountNumber = trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber
            account.initialBalance = finalAmount
            account.adjustmentMode = selectedAdjustmentMode.rawValue
            account.excludeFromStatistics = excludeFromStatistics
            account.isArchived = isArchived
        } else {
            // Create
            let newAccount = Account(
                name: trimmedName,
                currencyCode: normalizeCurrencyCode(selectedCurrency.rawValue),
                colorHex: selectedColorHex,
                iconName: iconName(for: selectedType),
                type: selectedType.rawValue,
                accountNumber: trimmedAccountNumber.isEmpty ? nil : trimmedAccountNumber,
                initialBalance: finalAmount,
                adjustmentMode: selectedAdjustmentMode.rawValue,
                excludeFromStatistics: excludeFromStatistics,
                isArchived: isArchived
            )
            context.insert(newAccount)
        }

        return true
    }

    func deleteAccount(context: ModelContext) -> Bool {
        guard let account = accountToEdit else { return false }

        if account.initialBalance != 0 {
            deleteErrorMessage = L10n.Account.deleteBalanceError
            isShowingDeleteError = true
            return false
        }

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
