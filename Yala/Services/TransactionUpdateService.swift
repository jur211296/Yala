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

        // 4. Update each transaction with the now-available rates
        let preferredCode = CurrencyDefaults.currentPreferred
        var updatedCount = 0

        for transaction in transactions {
            // Check if exact rate now exists
            if CurrencyConverter.shared.hasExactRate(for: transaction.date, context: context) {
                // Recalculate with exact rate
                let amount = Decimal(transaction.amount)
                let amountInPreferred = CurrencyConverter.shared.convert(
                    amount,
                    from: transaction.currencyCode,
                    to: preferredCode,
                    on: transaction.date,
                    context: context
                )

                // Derive rate
                let amountDouble = transaction.amount
                let effectiveRate: Double
                if abs(amountDouble) > 0.0001 {
                    effectiveRate =
                        (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
                } else {
                    effectiveRate = 1.0
                }

                // Update transaction
                transaction.exchangeRate = abs(effectiveRate)
                transaction.amountInPreferredCurrency =
                    (amountInPreferred as NSDecimalNumber).doubleValue
                transaction.preferredCurrencyCode = preferredCode
                transaction.isExchangeRateProvisional = false

                updatedCount += 1
            }
        }

        // 5. Save all updates at once
        if updatedCount > 0 {
            do {
                try context.save()
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
