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
/// (`balanceAdjustmentType != nil`), y clasifica con la regla canónica
/// (`TransactionClassificationLogic.isIncome`): **la categoría decide el bucket** y el
/// signo del monto solo es fallback cuando `category == nil`. La acumulación es signed,
/// igual que el resumen (`RecordsViewModel.calculateSummary`): un monto de signo contrario
/// a su categoría —un reembolso— REDUCE el gasto del día en vez de sumar magnitud.
/// Resuelve cada importe con la misma regla que el resumen (`CashFlowCalculator.resolvedAmount`):
/// el monto guardado si se guardó en `currencyCode`, y reconvertido desde el nativo si se guardó
/// en otra divisa preferida. Antes del 2026-10-10 los dos leían el monto guardado sin mirar en qué
/// divisa estaba, y sumaban escalas distintas (`records-summary-mixes-preferred-currencies`).
///
/// Sin gap-filling: los días sin gasto no aparecen en `spendingByDay` (barra 0 al render).
///
/// RESIDUAL CONOCIDO (decisión de producto, 2026-09-02): un día cuyo gasto neto queda en
/// cero o en negativo —solo hubo un reembolso— NO se pinta, porque el guard `dayExpense > 0`
/// lo descarta (y `RecordsCalendarView` repite la condición). El chip del hero sí arrastra
/// ese negativo al total, así que en esos días concretos la suma de barras queda por encima
/// del chip. Se decidió no representar días negativos para no introducir UI nueva; queda
/// anotado en `tickets/backlog/registros-calendario-cuenta-gastos-por-signo.md`.
///
/// Antes del 2026-09-02 este calculador clasificaba por signo puro mientras el resumen ya
/// usaba la categoría (desde `13f2cbb0`, 2026-07-05): el calendario inflaba los días con una
/// devolución de ingreso e ignoraba los reembolsos de gasto. Al tocar esta clasificación,
/// mantener la paridad con `RecordsViewModel.calculateSummary` — son la misma pantalla.
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
    /// - Parameter currencyCode: la divisa principal en que se pintan las barras (la del resumen).
    static func compute(
        groups: [(date: Date, records: [TransactionItem])],
        adjustment: GroupBridgeStatsAdjustment = .none,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Result {
        var spendingByDay: [Date: Double] = [:]

        for group in groups {
            var dayExpense: Double = 0
            for record in group.records {
                guard let account = record.account, !account.excludeFromStatistics else { continue }
                if record.balanceAdjustmentType != nil { continue }  // excluye ajustes y transferencias
                guard !adjustment.isSuppressed(record) else { continue }

                // La categoría decide el bucket; acumulación signed (paridad literal con
                // `RecordsViewModel.calculateSummary`): un monto de signo contrario a su
                // categoría reduce el gasto del día (reembolso), no suma magnitud.
                let amount = CashFlowCalculator.resolvedAmount(
                    record, currencyCode: currencyCode, adjustment: adjustment, converter: converter
                ).value
                if !TransactionClassificationLogic.isIncome(record) {
                    dayExpense -= amount
                }
            }
            if dayExpense > 0 {
                spendingByDay[group.date] = dayExpense
            }
        }

        return Result(spendingByDay: spendingByDay, maxSpending: spendingByDay.values.max() ?? 0)
    }
}
