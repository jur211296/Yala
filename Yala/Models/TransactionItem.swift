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
    /// LEGACY: kept only for cascade .nullify when a Tag is deleted.
    /// DO NOT read from this for filtering logic. Read via resolvedTagIDs() helper.
    /// Writers MUST use setTags(from:) to keep both sides (M2M + CSV) in sync.
    @Relationship(deleteRule: .nullify)
    var tags: [Tag]?

    /// CSV mirror of `tags` M2M — SSOT for read (eager, travels in the TX record).
    /// Solves CloudKit lazy hydration race where M2M can appear nil post cold start.
    var tagIDs: String?

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

    // MARK: - Shared Expense Link
    /// ID del SplitExpense vinculado (nil = gasto personal normal)
    var splitExpenseID: String?
    /// Zone ID del grupo para queries rápidos
    var splitGroupZoneID: String?
    /// ID del SplitSettlement vinculado (nil = gasto personal o expense bridgeado)
    /// Permite distinguir TX de liquidaciones para `unbridgeSettlement` y bloqueo de edición.
    var splitSettlementID: String?

    // MARK: - Metadata
    /// Timestamp de creación del registro (usado para ordenar registros del mismo día)
    var createdAt: Date = Date.now

    // MARK: - Sync Identity (Modo Nube, I2)
    /// Identidad estable de sync. OPCIONAL SIN DEFAULT a propósito: si fuera `= UUID()` y CloudKit
    /// entregara un record sin el campo, el default se evaluaría UNA vez y quedaría COMPARTIDO entre
    /// todas esas filas (gotcha de UUID colapsado, ver CLAUDE.md). Un record sin el campo DEBE verse
    /// `nil`, no un UUID compartido. Lo puebla `SyncIdentityService` (born-cloud vía hub gateado, o
    /// backfill de migración). `.preserveValueOnDeletion` lo conserva en el tombstone para sync.
    @Attribute(.preserveValueOnDeletion) var syncID: UUID?

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
    ///
    /// **Es el punto de paso de la escritura de montos convertidos: 21 llamadas en 5 ficheros**, once
    /// de ellas del bridge de Grupos. Por eso marca aquí `isExchangeRateProvisional` en vez de dejarlo
    /// a cada llamador: hasta el 2026-09-03 no lo tocaba ninguno de los 21, así que toda transacción
    /// que pasara por aquí nacía con el flag en su default `false` —o sea, sellada como definitiva—
    /// aunque la conversión no hubiera podido hacerse. Y el reparador
    /// (`TransactionUpdateService`, cuyo `#Predicate` solo busca `== true`) no volvía a mirarla nunca.
    /// Marcarlo es lo que le devuelve una ruta de auto-cura (`fx-partial-rate-rows-silent-1to1`).
    @MainActor
    func recalculatePreferredCurrency(context: ModelContext) {
        let preferredCode = CurrencyDefaults.currentPreferred
        let outcome = CurrencyConverter.shared.convertChecked(
            Decimal(amount),
            from: currencyCode,
            to: preferredCode,
            on: date,
            context: context
        )
        let amountInPreferred = outcome.amount
        let effectiveRate: Double
        if abs(amount) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amount
        } else {
            effectiveRate = 1.0
        }
        exchangeRate = abs(effectiveRate)
        amountInPreferredCurrency = (amountInPreferred as NSDecimalNumber).doubleValue
        preferredCurrencyCode = preferredCode
        // Solo una tasa EXACTA puede sellarse como definitiva. Una arrastrada de otro día o salida de
        // la tabla estática da un número del orden correcto, pero sigue esperando la tasa real: dejar
        // el flag en `false` es lo que hacía que un monto aproximado se quedara para siempre.
        isExchangeRateProvisional = !outcome.quality.isExact
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
        isExchangeRateProvisional: Bool = false,
        tagIDs: String? = nil
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
        // Auto-mirror: derivar tagIDs desde `tags` si el caller no lo pasó explícito.
        self.tagIDs = tagIDs ?? CSVMirrorCodec.encode(tags.map(\.id))
    }
}
