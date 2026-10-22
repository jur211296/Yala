//
//  TransactionService.swift
//  Yala
//
//  Service for common transaction operations.
//  Fase C.3: Arquitectura - Services para ModelContext
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - TransactionService

/// Service for managing common transaction operations
@MainActor
@Observable
final class TransactionService {

    // MARK: - Singleton

    static let shared = TransactionService()

    // MARK: - Properties

    private var modelContext: ModelContext?

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    /// Sets the model context (call this from views that use the service)
    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    // MARK: - Private Helpers

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw TransactionServiceError.noContext
        }
        return context
    }

    // MARK: - Create Operations

    /// Inserts and saves a new transaction
    /// - Parameter transaction: The transaction to insert
    func create(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        // Modo Nube I2: born-cloud identity capture (gateado DARK; no-op en producción hoy).
        SyncIdentityService.captureIfEnabled(transaction)
        context.insert(transaction)
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()

        // Check budget alerts
        Task {
            await BudgetAlertService.shared.checkBudgetsAndNotify()
        }
    }

    // MARK: - Update Operations

    /// Saves changes to a transaction (just save, transaction is already in context)
    func save(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Delete Operations

    /// Deletes a transaction and saves
    /// - Parameter transaction: The transaction to delete
    func delete(_ transaction: TransactionItem) throws {
        let context = try requireContext()
        context.delete(transaction)
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Deletes multiple transactions and saves
    /// - Parameter transactions: The transactions to delete
    func deleteMultiple(_ transactions: [TransactionItem]) throws {
        let context = try requireContext()
        for transaction in transactions {
            context.delete(transaction)
        }
        try context.save()

        // Update widgets
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    // MARK: - Bulk Update Operations

    // **Aquí había un `bulkUpdateAccount` y se BORRÓ el 2026-09-08, no se arregló**
    // (`bulk-update-account-leaves-converted-amount-stale`). Reasignaba la cuenta y con ella
    // `currencyCode` —el input de la conversión— y guardaba sin recomputar las derivadas, así que las
    // cuatro columnas DERIVADAS del grupo `money` se quedaban con la divisa anterior (el grupo tiene
    // CINCO: la quinta es `amount`, que esta operación no tocaba). La nota vale la línea porque **la
    // papelera no se lee y este método invitaba a llamarlo**:
    //
    // - **Nunca tuvo un llamador, en toda la historia del repo** (`git log -S`, todas las ramas, cero
    //   commits). Nació especulativo en el refactor C.3 (`461cc0ea`, 29-ene) para "estandarizar
    //   operaciones", y la UI nunca migró: `BulkEditSheet.swift` llama a `RecordsViewModel` para las
    //   seis operaciones bulk. Un mes más tarde `2eb7acc6` arregló la integridad del bulk edit **en el
    //   ViewModel**, y esta copia se quedó atrás sin que nadie lo notara.
    // - **Tenía DOS divergencias con la ruta viva, no la una que se reportó.** Además del recalculo
    //   faltaba el bloqueo de transferencias que `RecordsViewModel.bulkUpdateAccount` sí hace: una
    //   transferencia tiene dos cuentas inherentes ligadas por `transferPairID`, y colapsarlas a una
    //   sola parte el par y descuadra ambos balances. Añadir solo la línea del recalculo habría dejado
    //   ese segundo daño dentro y —peor— el método con aspecto de revisado.
    // - **El canario no lo habría cazado, y el mecanismo no es el que parece.** Ni `currency_code` ni
    //   `account_ref` pertenecen a ningún grupo de coherencia en `EntityEmissionMap` (el grupo `money`
    //   lo forman `amount`, `amount_in_preferred_currency`, `preferred_currency_code`, `exchange_rate`
    //   e `is_exchange_rate_provisional`). Como `DeltaEmitter` construye `touchedGroups` **a partir de
    //   las columnas cambiadas que tienen grupo**, tocar solo esas dos lo deja VACÍO: no expande el
    //   grupo, no lo mete en `fields`, no avanza su `field_hlcs` y el guard `coherenceGroupPartial`
    //   itera sobre el conjunto vacío. O sea que no es que emitiera un grupo `money` aparentemente
    //   coherente —eso invitaría a buscar el fallo en el guard—: **es que el guard no llegaba a
    //   evaluarse nunca**, y el PATCH viajaba con la divisa nueva junto al monto convertido viejo.
    //
    // ⇒ Si algún día hace falta esta operación desde el servicio, la referencia es
    // `RecordsViewModel.bulkUpdateAccount` —no este hueco— y cualquier reimplementación debe hacer las
    // dos cosas: bloquear transferencias y llamar `recalculatePreferredCurrency` tras reasignar la
    // divisa. Quien vigila que este fichero siga cumpliéndolo es el source-scan
    // `BulkAccountCurrencyRecalcSourceScanTests` (mutante comprobado: repegar el método de arriba tal
    // cual lo pone rojo). El comportamiento de la ruta viva lo fija, aparte,
    // `RecordsViewModelBulkAccountCurrencyTests`.

    /// Updates subcategory for multiple transactions.
    /// Throws si la selección contiene transferencias — usan subcat sistema obligatoria.
    func bulkUpdateSubcategory(_ transactions: [TransactionItem], subcategory: Subcategory) throws {
        let context = try requireContext()
        if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
            throw TransactionServiceError.transferSubcategoryNotEditable
        }
        for transaction in transactions {
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
        }
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }

    /// Adds tags to multiple transactions.
    /// Propaga al partner — MERGE con tags propios del partner (no clobber). Skip collision.
    /// CSV-first read (resolvedTagIDs) con auto-heal: evita clobber cuando M2M lazy nil.
    func bulkAddTags(_ transactions: [TransactionItem], tags: [Tag]) throws {
        let context = try requireContext()
        let toAddIDs = Set(tags.map(\.id))
        var processedPairIDs: Set<String> = []

        // Si el fetch lanza, propaga el error (no clobber silent — el old code
        // tampoco perdía tags ante fetch failure porque no fetcheaba).
        func applyAdd(to tx: TransactionItem) throws {
            let currentIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            let newIDs = currentIDs.union(toAddIDs)
            guard newIDs != currentIDs else { return }   // idempotent
            let resolved = try TagResolver.fetch(ids: newIDs, in: context)
            tx.setTags(from: resolved)
        }

        for transaction in transactions {
            try applyAdd(to: transaction)
            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                try applyAdd(to: partner)
            }
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Removes tags from multiple transactions.
    /// Propaga al partner. Skip collision.
    /// CSV-first read with auto-heal (idem bulkAddTags).
    func bulkRemoveTags(_ transactions: [TransactionItem], tags: [Tag]) throws {
        let context = try requireContext()
        let toRemoveIDs = Set(tags.map(\.id))
        var processedPairIDs: Set<String> = []

        func applyRemove(from tx: TransactionItem) throws {
            let currentIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            let newIDs = currentIDs.subtracting(toRemoveIDs)
            guard newIDs != currentIDs else { return }   // idempotent
            let resolved = try TagResolver.fetch(ids: newIDs, in: context)
            tx.setTags(from: resolved)
        }

        for transaction in transactions {
            try applyRemove(from: transaction)
            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                try applyRemove(from: partner)
            }
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
        WidgetDataCache.updateCache(context: context)
    }

    /// Updates note for multiple transactions.
    /// Propaga al partner SOLO si su nota actual ya coincide con tx (preserva divergencia).
    func bulkUpdateNote(_ transactions: [TransactionItem], note: String) throws {
        let context = try requireContext()
        let finalNote = note.isEmpty ? nil : note
        var processedPairIDs: Set<String> = []
        for transaction in transactions {
            let originalNote = transaction.note
            transaction.note = finalNote

            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                if (originalNote ?? "") == (partner.note ?? "") {
                    partner.note = finalNote
                }
            }
        }
        try context.save()
        SessionState.shared.incrementDataVersion()
    }

    /// Updates amount for multiple transactions.
    /// Propaga al partner con signo opuesto para mantener balance del transfer. Throws si la
    /// selección contiene cross-currency transfers (preservar exchange rate).
    func bulkUpdateAmount(_ transactions: [TransactionItem], amount: Double) throws {
        let context = try requireContext()
        // Preserve exchange rate: throw si transfer cross-currency.
        for tx in transactions {
            if let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: tx, in: context),
               tx.currencyCode != partner.currencyCode {
                throw TransactionServiceError.transferAmountCrossCurrencyNotEditable
            }
        }
        var processedPairIDs: Set<String> = []
        for transaction in transactions {
            // Preserve sign (expense = negative, income = positive)
            let sign: Double = transaction.amount < 0 ? -1 : 1
            transaction.amount = sign * abs(amount)
            // Grupo de coherencia "money" (Modo Nube §d.4bis): al tocar `amount` SIEMPRE recomputar
            // las derivadas (amountInPreferredCurrency/exchangeRate/preferredCurrencyCode), o el
            // drain de sync emitiría un money-group incoherente (canario cloudSyncCoherenceGroupPartial).
            transaction.recalculatePreferredCurrency(context: context)

            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                let partnerSign: Double = partner.amount < 0 ? -1 : 1
                partner.amount = partnerSign * abs(amount)
                partner.recalculatePreferredCurrency(context: context)
            }
        }
        try context.save()
        WidgetDataCache.updateCache(context: context)
        SessionState.shared.incrementDataVersion()
    }
}

// MARK: - Errors

enum TransactionServiceError: LocalizedError {
    case noContext
    case saveFailed(Error)
    case transferSubcategoryNotEditable
    case transferAmountCrossCurrencyNotEditable

    var errorDescription: String? {
        switch self {
        case .transferSubcategoryNotEditable:
            return L10n.BulkEdit.cannotEditTransferSubcategory
        case .transferAmountCrossCurrencyNotEditable:
            return L10n.BulkEdit.cannotEditTransferAmountCrossCurrency
        case .noContext:
            return "TransactionService: No ModelContext available"
        case .saveFailed(let error):
            return "TransactionService: Save failed - \(error.localizedDescription)"
        }
    }
}
