//
//  CurrencyChangeService.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

/// Service responsible for updating all transactions when the user changes their preferred currency.
@MainActor
final class CurrencyChangeService {
    static let shared = CurrencyChangeService()

    private init() {}

    /// Updates all transactions in the database to reflect the new preferred currency.
    /// This involves re-fetching historical rates and recalculating `amountInPreferredCurrency`.
    ///
    /// - Parameters:
    ///   - newCurrencyCode: The new preferred currency code (e.g. "USD").
    ///   - context: The ModelContext to perform updates in.
    ///   - onProgress: Closure called with progress (0.0 to 1.0).
    func updateAllTransactions(
        to newCurrencyCode: String,
        context: ModelContext,
        onProgress: ((Double) -> Void)? = nil
    ) async throws {
        // 1. Fetch all transactions
        let descriptor = FetchDescriptor<TransactionItem>(sortBy: [SortDescriptor(\.date)])
        let allTransactions = try context.fetch(descriptor)

        guard !allTransactions.isEmpty else {
            onProgress?(1.0)
            return
        }

        // 2. Identify date range to ensure rates are available
        let dates = allTransactions.map { $0.date }
        if let minDate = dates.min(), let maxDate = dates.max() {
            let dateInterval = DateInterval(start: minDate, end: maxDate)
            // Ensure we have rates for the new target currency for this range
            // (ExchangeRateService handles fetching missing rates from API)
            await ExchangeRateService.shared.ensureRates(for: dateInterval, context: context)
        }

        let total = Double(allTransactions.count)

        // 3. Iterate and Update
        for (index, transaction) in allTransactions.enumerated() {
            // Update progress every 20 items or so to avoid UI thrashing
            if index % 20 == 0 {
                onProgress?(Double(index) / total)
            }

            // Calculate new values
            // `convertChecked` y no `convert`: este bucle reescribe el monto convertido de TODAS las
            // transacciones ya persistidas, y `convert` devuelve `Decimal` a secas. Sin la calidad,
            // una tasa arrastrada de otro día —o salida de la tabla estática— se guardaba dejando
            // `isExchangeRateProvisional` intacto en su `false`: sellada como definitiva y fuera del
            // alcance del reparador, cuyo `#Predicate` solo busca `== true`.
            let outcome = CurrencyConverter.shared.convertChecked(
                Decimal(transaction.amount),
                from: transaction.currencyCode,
                to: newCurrencyCode,
                on: transaction.date,
                context: context
            )
            let amountInPreferred = outcome.amount

            // Derive new rate
            let amountDouble = transaction.amount
            let effectiveRate: Double
            if abs(amountDouble) > 0.0001 {
                effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
            } else {
                effectiveRate = 1.0
            }

            // Apply updates
            transaction.amountInPreferredCurrency =
                (amountInPreferred as NSDecimalNumber).doubleValue
            transaction.exchangeRate = abs(effectiveRate)
            transaction.preferredCurrencyCode = newCurrencyCode
            // El flag describe la calidad del número que hay AHORA, no un historial — por eso se
            // decide incondicionalmente, igual que en `recalculatePreferredCurrency`. Subirlo cuando
            // la tasa no fue exacta devuelve la transacción a la cola del reparador; bajarlo cuando
            // sí lo fue es correcto, porque el monto acaba de reescribirse con la tasa buena. La
            // asimetría importa: el bug era que una TX exacta en la divisa vieja se quedaba en
            // `false` tras reconvertirse con una tasa aproximada a la nueva.
            transaction.isExchangeRateProvisional = !outcome.quality.isExact
        }

        // Save changes
        try context.save()
        onProgress?(1.0)
    }
}
