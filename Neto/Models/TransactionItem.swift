//
//  TransactionItem.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

// MARK: - TransactionItem

@Model
final class TransactionItem {
    var date: Date
    var amount: Double
    var currencyCode: String
    var note: String?

    var category: Category?
    var subcategory: Subcategory?
    var account: Account?
    var tags: [Tag]

    // MARK: - Standardized Currency Data
    /// Tasa de cambio aplicada (Moneda Transacción -> Moneda Preferida)
    var exchangeRate: Double = 1.0
    /// Monto convertido a la moneda preferida del usuario en el momento de la transacción
    var amountInPreferredCurrency: Double = 0.0
    /// Código de la moneda preferida utilizada para la conversión (snapshot)
    var preferredCurrencyCode: String = "PEN"

    init(
        date: Date,
        amount: Double,
        currencyCode: String,
        note: String? = nil,
        category: Category? = nil,
        subcategory: Subcategory? = nil,
        account: Account? = nil,
        tags: [Tag] = [],
        exchangeRate: Double = 1.0,
        amountInPreferredCurrency: Double = 0.0,
        preferredCurrencyCode: String = "PEN"
    ) {
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.note = note
        self.category = category
        self.subcategory = subcategory
        self.account = account
        self.tags = tags
        self.exchangeRate = exchangeRate
        self.amountInPreferredCurrency = amountInPreferredCurrency
        self.preferredCurrencyCode = preferredCurrencyCode
    }
}
