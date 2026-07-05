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
    static func isIncome(_ tx: TransactionItem) -> Bool {
        tx.category?.isIncome ?? (tx.amountInPreferredCurrency >= 0)
    }
}
