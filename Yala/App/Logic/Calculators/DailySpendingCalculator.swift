//
//  DailySpendingCalculator.swift
//  Yala
//
//  Agrega el gasto diario para las barras del calendario de Registros.
//

import Foundation

/// Calcula el gasto por día (en la divisa preferida) para el calendario de Registros.
///
/// Replica el criterio de `RecordsViewModel.calculateSummary` para que la suma de
/// las barras cuadre con el chip "gasto" del hero: excluye cuentas marcadas como
/// `excludeFromStatistics`, ajustes de saldo y transferencias
/// (`balanceAdjustmentType != nil`), y trata como gasto los montos con
/// `amountInPreferredCurrency < 0`. Usa el snapshot ya convertido (no reconvierte),
/// igual que el resumen — así ambos coinciden incluso si la divisa preferida cambió.
///
/// Sin gap-filling: los días sin gasto no aparecen en `spendingByDay` (barra 0 al render).
struct DailySpendingCalculator {

    struct Result: Equatable {
        /// Gasto por día. La clave es `startOfDay` (igual que `RecordsViewModel.groupedRecords`).
        let spendingByDay: [Date: Double]
        /// Mayor gasto diario del periodo — define la escala del gradiente.
        let maxSpending: Double
    }

    /// - Parameter groups: los grupos ya agrupados por día (`groupedRecords`).
    /// - Parameter adjustment: proyecta un gasto de grupo Caso A a "mi parte" (neto) y excluye
    ///   las patas de préstamo derivadas — así el calendario cuadra con el chip del hero neteado.
    static func compute(
        groups: [(date: Date, records: [TransactionItem])],
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Result {
        var spendingByDay: [Date: Double] = [:]

        for group in groups {
            var dayExpense: Double = 0
            for record in group.records {
                guard let account = record.account, !account.excludeFromStatistics else { continue }
                if record.balanceAdjustmentType != nil { continue }  // excluye ajustes y transferencias
                guard !adjustment.isSuppressed(record) else { continue }

                let amount = adjustment.amountInPreferredCurrency(record)
                if amount < 0 {
                    dayExpense += abs(amount)
                }
            }
            if dayExpense > 0 {
                spendingByDay[group.date] = dayExpense
            }
        }

        return Result(spendingByDay: spendingByDay, maxSpending: spendingByDay.values.max() ?? 0)
    }
}
