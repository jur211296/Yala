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
    ///
    /// Un convertido guardado a 0 con nativo distinto de 0 es una conversión que no se escribió
    /// (`CashFlowCalculator.storedConversionIsMissing`) y va al converter, como en `resolvedAmount`:
    /// si no, la app reconvertía y Yala IA recibía 0 por el mismo movimiento.
    func chatAmount(in currencyCode: String, converter: CurrencyConverting) -> Double {
        if self.currencyCode == currencyCode { return abs(amount) }
        if preferredCurrencyCode == currencyCode, !CashFlowCalculator.storedConversionIsMissing(self) {
            return abs(amountInPreferredCurrency)
        }
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
