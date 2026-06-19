//
//  TransactionItem+ChatAmount.swift
//  Yala
//
//  Compartido entre `FullFinancialContextBuilder` y `AnomalyDetectionCalculator`.
//  Convierte `tx.amount` a la moneda del chat (preferida) usando los snapshots
//  pre-calculados cuando coinciden, o el converter como fallback.
//

import Foundation

extension TransactionItem {

    /// Returns `abs(amount)` converted to `currencyCode`. Uses pre-calculated
    /// `amountInPreferredCurrency` when `preferredCurrencyCode` matches; otherwise
    /// invokes the converter. Always returns a finite value (0 on conversion failure).
    func chatAmount(in currencyCode: String, converter: CurrencyConverting) -> Double {
        if self.currencyCode == currencyCode { return abs(amount) }
        if preferredCurrencyCode == currencyCode { return abs(amountInPreferredCurrency) }
        let converted = converter.convert(
            Decimal(abs(amount)),
            from: self.currencyCode,
            to: currencyCode,
            on: date
        )
        let value = NSDecimalNumber(decimal: converted).doubleValue
        return value.isFinite ? value : 0
    }
}
