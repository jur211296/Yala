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
    // CloudKit: defaults required
    var date: Date = Date.now
    var amount: Double = 0
    var currencyCode: String = "USD"
    var note: String?

    @Relationship(deleteRule: .nullify, inverse: \Category.transactions)
    var category: Category?

    @Relationship(deleteRule: .nullify, inverse: \Subcategory.transactions)
    var subcategory: Subcategory?

    @Relationship(deleteRule: .nullify, inverse: \Account.transactions)
    var account: Account?

    /// CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var tags: [Tag]?

    /// Inverse relationship: draft that created this transaction (CloudKit requirement)
    @Relationship(deleteRule: .nullify)
    var approvedDraft: InboxDraft?

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
    var needOverride: String?

    // MARK: - Scheduled Payment Link
    /// ID of the scheduled payment this transaction is associated with (manual association)
    var scheduledPaymentID: String?

    // MARK: - Balance Adjustment Type
    /// Type of balance adjustment transaction: "initial_balance" | "adjustment" | "transfer" | nil (normal)
    var balanceAdjustmentType: String?

    // MARK: - Balance Adjustment Type Constants
    static let adjustmentTypeTransfer = "transfer"

    // MARK: - Transfer Pair
    /// Shared UUID between both sides of a transfer (outflow + inflow)
    var transferPairID: String?

    // MARK: - Split Calculator
    /// Monto total original antes de dividir (nil = no split)
    var splitTotalAmount: Double?
    /// Tipo de split: "equal" | "percentage" | "exact" | "shares"
    var splitType: String?
    /// Valor contextual: porcentaje, personas, partes propias, o monto exacto
    var splitMyValue: Double?
    /// Divisor total (nil para exact)
    var splitDivisor: Double?

    // MARK: - Metadata
    /// Timestamp de creación del registro (usado para ordenar registros del mismo día)
    var createdAt: Date = Date.now

    /// Naturaleza efectiva del registro (usa override si existe, sino la de subcategoría)
    var effectiveNeed: SubcategoryNeed {
        if let override = needOverride {
            return SubcategoryNeed(rawValue: override) ?? .unclassified
        }
        return subcategory?.need ?? .unclassified
    }

    // MARK: - Currency Recalculation

    /// Recalculates exchangeRate, amountInPreferredCurrency, and preferredCurrencyCode
    /// based on the transaction's current amount and currencyCode.
    func recalculatePreferredCurrency(context: ModelContext) {
        let preferredCode = CurrencyDefaults.currentPreferred
        let amountInPreferred = CurrencyConverter.shared.convert(
            Decimal(amount),
            from: currencyCode,
            to: preferredCode,
            on: date,
            context: context
        )
        let effectiveRate: Double
        if abs(amount) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
        } else {
            effectiveRate = 1.0
        }
        exchangeRate = abs(effectiveRate)
        amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        preferredCurrencyCode = preferredCode
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
