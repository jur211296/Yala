//
//  TransactionUpdateService.swift
//  Yala
//
//  Service to update transactions with provisional exchange rates.
//  Called on app launch to update transactions that were imported
//  without exact exchange rates for their dates.
//

import Foundation
import SwiftData

// MARK: - Transaction Update Service

/// Service that updates transactions with provisional exchange rates.
/// Called on app launch to fill in missing exchange rate data.
@MainActor
enum TransactionUpdateService {

    /// Updates all transactions that have provisional exchange rates.
    /// This function:
    /// 1. Finds all transactions where isExchangeRateProvisional == true
    /// 2. For each unique date, fetches exchange rates from API if missing
    /// 3. Recalculates and updates the transactions
    /// 4. Sets isExchangeRateProvisional = false
    ///
    /// - Parameter context: SwiftData ModelContext
    static func updateProvisionalTransactions(context: ModelContext) async {
        // Gate de quiescencia: actualiza `TransactionItem` (store personal) + `save()`; diferir durante
        // el import del restore (idempotente: las provisionales se re-procesan en el próximo arranque).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("TransactionUpdateService.updateProvisional", "import not quiescent")
            return
        }
        // 1. Find transactions with provisional exchange rates
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.isExchangeRateProvisional == true }
        )

        let transactions: [TransactionItem]
        do {
            transactions = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("TransactionUpdateService: Error fetching provisional transactions: \(error)")
            #endif
            return
        }
        guard !transactions.isEmpty else {
            return
        }

        // 2. Get unique dates that need exchange rates
        let dates = Set(transactions.map { $0.date })

        // 3. Ensure exchange rates exist for these dates
        if let minDate = dates.min(), let maxDate = dates.max() {
            let dateRange = DateInterval(start: minDate, end: maxDate)
            await ExchangeRateService.shared.ensureRates(for: dateRange, context: context)
        }

        // 4. Recalcular cada transacción provisional.
        //
        // Antes esto preguntaba `hasExactRate(for:)` y, si decía que sí, reimplementaba a mano las
        // mismas cinco líneas de `TransactionItem.recalculatePreferredCurrency`. Dos problemas, los
        // dos del ticket `fx-partial-rate-rows-silent-1to1`: (a) `hasExactRate` responde por que la
        // FILA EXISTA, no por que traiga la divisa que hace falta, así que sobre una fila parcial
        // decía `true`, la conversión devolvía el monto crudo y la línea final sellaba
        // `isExchangeRateProvisional = false` — un 1:1 marcado como oficial y ya nunca revisitado,
        // porque el `#Predicate` de arriba solo busca `== true`; y (b) el cálculo duplicado se
        // desincroniza del punto de paso en cuanto uno de los dos cambia.
        //
        // Ahora se delega, y quien decide si sigue provisional es la CALIDAD de la tasa. El efecto
        // para el usuario es que una transacción con tasa aproximada se corrige sola en cuanto llegan
        // las tasas reales, en vez de quedarse con el número malo para siempre.
        var updatedCount = 0

        for transaction in transactions {
            transaction.recalculatePreferredCurrency(context: context)
            // Solo cuenta como reparada la que ya NO es provisional; las demás siguen en la cola para
            // el próximo arranque, que es justo lo que se quiere.
            if !transaction.isExchangeRateProvisional {
                updatedCount += 1
            }
        }

        // 5. Save all updates at once
        if updatedCount > 0 {
            do {
                SaveBreadcrumb.willSave("TransactionUpdateService.updateProvisional")
                try context.save()
                SaveBreadcrumb.didSave("TransactionUpdateService.updateProvisional")
                #if DEBUG
                print(
                    "TransactionUpdateService: Updated \(updatedCount) transactions with official exchange rates"
                )
                #endif
            } catch {
                #if DEBUG
                print("TransactionUpdateService: Failed to save updates: \(error)")
                #endif
            }
        }
    }
}
