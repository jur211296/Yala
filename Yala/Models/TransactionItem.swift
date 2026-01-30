//
//  TransactionItem.swift
//  Yala
//
//  Created by Yala Refactoring.
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

    @Relationship(inverse: \Category.transactions)
    var category: Category?

    @Relationship(inverse: \Subcategory.transactions)
    var subcategory: Subcategory?

    @Relationship(inverse: \Account.transactions)
    var account: Account?

    var tags: [Tag]

    // MARK: - Standardized Currency Data
    /// Tasa de cambio aplicada (Moneda Transacción -> Moneda Preferida)
    var exchangeRate: Double = 1.0
    /// Monto convertido a la moneda preferida del usuario en el momento de la transacción
    var amountInPreferredCurrency: Double = 0.0
    /// Código de la moneda preferida utilizada para la conversión (snapshot)
    var preferredCurrencyCode: String = "PEN"
    /// Indica si el tipo de cambio es provisional (fallback) o oficial (exacto para la fecha)
    var isExchangeRateProvisional: Bool = false

    // MARK: - Nature Override
    /// Override manual de naturaleza (nil = usar la de subcategoría)
    var natureOverride: String?

    // MARK: - Balance Adjustment Type
    /// Type of balance adjustment transaction: "initial_balance" | "adjustment" | nil (normal)
    var balanceAdjustmentType: String?

    // MARK: - Metadata
    /// Timestamp de creación del registro (usado para ordenar registros del mismo día)
    var createdAt: Date = Date()

    /// Naturaleza efectiva del registro (usa override si existe, sino la de subcategoría)
    var effectiveNature: SubcategoryNature {
        if let override = natureOverride {
            return SubcategoryNature(rawValue: override) ?? .unclassified
        }
        return subcategory?.nature ?? .unclassified
    }

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
        preferredCurrencyCode: String = "PEN",
        isExchangeRateProvisional: Bool = false
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
        self.isExchangeRateProvisional = isExchangeRateProvisional
    }
}
