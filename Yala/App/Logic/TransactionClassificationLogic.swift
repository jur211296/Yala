//
//  TransactionClassificationLogic.swift
//  Yala
//
//  Pure-logic de clasificación income/expense de una transacción. Sin
//  SwiftData/SwiftUI para tests sin UI ni ModelContext (evita flake R8
//  documentado en CLAUDE.md → makeTestContext).
//

import Foundation
import SwiftData

/// Clasificación income/expense de una transacción. La categoría decide; el
/// signo del monto es el fallback ÚNICAMENTE cuando `category == nil`. Regla
/// canónica compartida — paridad con `TransactionDetailSheetLogic.kind`,
/// `RecordRowView.amountColor`, `BalanceHelper` y `PivotTableCalculator`.
///
/// NOTA: este helper solo decide el BUCKET (income vs expense). La acumulación
/// del monto (signed, estilo `CashFlowCalculator`) vive en cada callsite porque
/// suman en tipos distintos (`Double` / `Decimal`): un monto de signo contrario
/// a su categoría se trata como reembolso/corrección y REDUCE el bucket, no como
/// magnitud absoluta.
enum TransactionClassificationLogic {

    /// `true` si la transacción cuenta como ingreso, `false` si gasto.
    /// La categoría manda; si no existe, el signo del monto es el fallback.
    ///
    /// El signo se lee del convertido guardado salvo cuando éste no se escribió (0 con nativo distinto
    /// de 0, `CashFlowCalculator.storedConversionIsMissing`): ese 0 decía «ingreso» y, desde que el
    /// importe se reconvierte, un gasto sin categoría sumaba en negativo a los ingresos.
    ///
    /// **Es la regla de TODA la app** (decisión de Jürgen del 2026-09-06, ticket `records-standalone-amount-discrepancy`):
    /// totales, curvas, listas, filtros, colores y formularios deciden ingreso o gasto aquí, no con
    /// `category?.isIncome == true` / `?? false` / `guard let category`, que dan tres respuestas distintas para el mismo
    /// movimiento sin categoría. Un desglose POR CATEGORÍA (tarta, Sankey, rankings, widget de inicio) también decide el
    /// lado aquí y pone el movimiento sin categoría en su trozo «Sin categoría» (decisión A de Jürgen, 2026-10-23).
    static func isIncome(_ tx: TransactionItem) -> Bool {
        let signed = CashFlowCalculator.storedConversionIsMissing(tx) ? tx.amount : tx.amountInPreferredCurrency
        return isIncome(categoryIsIncome: tx.category?.isIncome, signedAmount: signed)
    }

    /// La misma regla para quien solo tiene los datos sueltos (lógica pura sin `TransactionItem`: filas de la vista de
    /// cuenta, candidatos de un pago, el detalle). `signedAmount` vale el nativo: tiene el mismo signo que el convertido,
    /// y es el que se usa cuando la conversión no se escribió. El cero cuenta como ingreso.
    nonisolated static func isIncome(categoryIsIncome: Bool?, signedAmount: Double) -> Bool {
        categoryIsIncome ?? (signedAmount >= 0)
    }
}
