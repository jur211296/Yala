//
//  ScheduledPaymentAmountConversion.swift
//  Yala
//
//  El importe de un pago programado, en la divisa en la que se pinta.
//

import Foundation

/// Única conversión del importe de un `ScheduledPayment` a otra divisa.
///
/// Nació del molde de `PlannedOccurrenceBuilder` (ticket
/// `cashflow-scheduled-line-ignores-payment-currency`): el flujo de caja sumaba `abs(payment.amount)`
/// sin mirar `payment.currencyCode`, así que un alquiler de 1.000 USD entraba en un plan en soles
/// como 1.000 PEN. Todo el que pinte el importe de un pago programado en una divisa que no es la
/// suya pasa por aquí, para que la tasa y la regla sean las mismas en todas partes.
///
/// **Tasa: la última disponible.** Un pago programado es una previsión, no tiene fecha histórica a
/// la que anclar la tasa; es la misma elección que el Sankey y el Financial Score.
enum ScheduledPaymentAmountConversion {

    struct Result: Equatable {
        /// Magnitud (siempre ≥ 0) en la divisa pedida.
        let amount: Double
        /// `true` cuando la tasa no fue exacta: quien lo pinta pone «≈».
        let isApproximate: Bool
    }

    static func magnitude(
        of payment: ScheduledPayment,
        in targetCurrencyCode: String,
        converter: any CurrencyConverting
    ) -> Result {
        let magnitude = abs(payment.amount)
        if payment.currencyCode == targetCurrencyCode {
            return Result(amount: magnitude, isApproximate: false)
        }
        let checked = converter.convertCheckedWithLatestRate(
            Decimal(magnitude),
            from: payment.currencyCode,
            to: targetCurrencyCode
        )
        return Result(
            amount: NSDecimalNumber(decimal: checked.amount).doubleValue,
            isApproximate: !checked.quality.isExact
        )
    }
}
