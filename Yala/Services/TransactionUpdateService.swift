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
    /// Clave del flag idempotente del barrido de reparación. Se corre UNA vez por dispositivo.
    private static let repairSweepKey = "fxOneToOneRepairSweep.v1"

    /// Devuelve a la cola de reparación las transacciones que quedaron con un 1:1 envenenado **antes**
    /// de que existiera el fix (`fx-partial-rate-rows-silent-1to1`, paso 2).
    ///
    /// No reconvierte nada: solo levanta `isExchangeRateProvisional`, y de eso ya se ocupa
    /// `updateProvisionalTransactions` unas líneas después, en el mismo arranque. Así hay UNA sola
    /// implementación de la conversión, no dos que se desincronizan — y el barrido se limita a
    /// deshacer el sellado, que es el daño que hay que revertir.
    ///
    /// **One-shot a propósito.** El estado que busca solo lo produce el código viejo; repetirlo en cada
    /// arranque sería recorrer todas las transacciones para siempre a cambio de nada. Y `exchangeRate`
    /// viaja por el canal nube en el grupo de coherencia `money`, así que cada fila marcada emite:
    /// conviene que ocurra una vez y no en bucle.
    static func repairLegacyOneToOneRatesIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        guard !defaults.bool(forKey: repairSweepKey) else { return }

        let preferred = CurrencyDefaults.currentPreferred
        // El predicado filtra por `exchangeRate == 1.0` y la comparación de divisas se hace en Swift:
        // un `#Predicate` que compara dos propiedades del mismo modelo entre sí es terreno resbaladizo
        // en SwiftData, y aquí no compensa el riesgo (ver la regla de `#Predicate` en las rules).
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.exchangeRate == 1.0 }
        )

        do {
            let candidates = try context.fetch(descriptor).filter {
                ExchangeRateRepairLogic.needsRepair(
                    exchangeRate: $0.exchangeRate,
                    currencyCode: $0.currencyCode,
                    preferredCurrencyCode: preferred
                )
            }
            for transaction in candidates {
                transaction.isExchangeRateProvisional = true
            }
            if !candidates.isEmpty {
                SaveBreadcrumb.willSave("TransactionUpdateService.repairLegacyOneToOne")
                try context.save()
                SaveBreadcrumb.didSave("TransactionUpdateService.repairLegacyOneToOne")
            }
            // El flag se marca aunque no hubiera candidatas: el barrido HIZO su trabajo.
            defaults.set(true, forKey: repairSweepKey)
            #if DEBUG
            print("TransactionUpdateService: repair sweep reopened \(candidates.count) transactions")
            #endif
        } catch {
            // Sin marcar el flag: si el fetch falló, el barrido no ha corrido y debe reintentarse en el
            // próximo arranque.
            #if DEBUG
            print("TransactionUpdateService: repair sweep failed: \(error)")
            #endif
        }
    }

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
