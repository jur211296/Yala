//
//  HeroBucketsCalculator.swift
//  Yala
//
//  Pure aggregator for the Panel 2.0 Hero — produce los 3 pares de
//  ingresos/gastos que consume el widget en una sola pasada O(n):
//    · mes calendario actual (pills + input del HeroMonthCalculator)
//    · mes calendario anterior (trend "vs mes anterior")
//    · período seleccionado (card "Disponible · Período")
//
//  Design choices:
//  - Solo respeta filtros de cuenta (`eligibleAccountIDs`, que ya engloba
//    `excludeFromStatistics` + cuenta seleccionada del Panel) y excluye
//    balance adjustments. Filtros finos (categoría, subcategoría, need,
//    focused date, tags, naturaleza) NO aplican al Hero por decisión de
//    producto — el Hero refleja la visión total agregada por cuenta.
//  - Una sola pasada por `transactions` para los 3 buckets.
//  - Los textos del estado del Hero (chip / KPI / subtext) y la regeneración
//    IA NO se tocan en este calculator — dependen de los inputs que aquí se
//    producen y reaccionan naturalmente cuando el filtro de cuenta cambia.
//

import Foundation
import SwiftData

enum HeroBucketsCalculator {

    struct Buckets: Equatable {
        let monthIncome: Double
        let monthExpense: Double
        let prevExpense: Double
        /// No es derivable de `prevExpense > 0`: distingue "mes anterior sin
        /// transacciones" de "mes anterior con sólo ingresos" (donde
        /// `prevExpense == 0` pero el trend "vs mes anterior" sí debe
        /// renderizar comparación).
        let prevHasAnyTx: Bool
        let periodIncome: Double
        let periodExpense: Double
        /// Gasto del PERÍODO anterior COMPARABLE (MTD-alineado) — alimenta el
        /// chip "vs período anterior" del hero en modo Solo Gastos. Mismo scope
        /// exacto que `periodExpense` (cuenta + exclusión de ajustes) para que
        /// la variación sea coherente con el número grande. `0` si el caller
        /// pasa `periodPrevInterval == nil` (p.ej. `.allTime`, sin previo
        /// acotado).
        let periodPrevExpense: Double
    }

    static func calculate(
        transactions: [TransactionItem],
        monthInterval: DateInterval,
        prevInterval: DateInterval,
        periodInterval: DateInterval,
        periodPrevInterval: DateInterval? = nil,
        eligibleAccountIDs: Set<PersistentIdentifier>,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Buckets {
        var monthIncome: Double = 0
        var monthExpense: Double = 0
        var prevExpense: Double = 0
        var prevHasAnyTx = false
        var periodIncome: Double = 0
        var periodExpense: Double = 0
        var periodPrevExpense: Double = 0

        for tx in transactions where tx.balanceAdjustmentType == nil {
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }
            // Excluir patas de préstamo derivadas del bridge (préstamo a grupos).
            guard !adjustment.isSuppressed(tx) else { continue }

            // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto).
            let amount = abs(adjustment.amountInPreferredCurrency(tx))
            let isIncome = tx.category?.isIncome == true

            if monthInterval.contains(tx.date) {
                if isIncome { monthIncome += amount } else { monthExpense += amount }
            } else if prevInterval.contains(tx.date) {
                prevHasAnyTx = true
                if !isIncome { prevExpense += amount }
            }

            // Period puede solaparse con monthInterval — sumamos en buckets
            // independientes para que la card "Disponible" sea exacta tanto
            // si el periodo coincide con el mes como si difiere.
            if periodInterval.contains(tx.date) {
                if isIncome { periodIncome += amount } else { periodExpense += amount }
            }

            // Ventana previa comparable (solo gasto). Estrictamente disjunta de
            // periodInterval: `DateInterval` es CERRADO en ambos extremos, y en
            // `.thisMonth` la ventana previa alineada CIERRA en periodInterval.start
            // (PreviousPeriodHelper NO le resta 1s a ese caso), así que una TX
            // fechada a medianoche de ese instante compartido caería en AMBOS
            // buckets → doble conteo que infla la base del comparativo. El guard
            // `!periodInterval.contains` la excluye (los buckets del mes usan
            // if/else-if mutuamente excluyente; estos son ifs independientes).
            if let periodPrevInterval, !isIncome,
               periodPrevInterval.contains(tx.date), !periodInterval.contains(tx.date) {
                periodPrevExpense += amount
            }
        }

        return Buckets(
            monthIncome: monthIncome,
            monthExpense: monthExpense,
            prevExpense: prevExpense,
            prevHasAnyTx: prevHasAnyTx,
            periodIncome: periodIncome,
            periodExpense: periodExpense,
            periodPrevExpense: periodPrevExpense
        )
    }

    /// Ventana previa COMPARABLE al `currentInterval` del período seleccionado,
    /// para el chip "vs período anterior" del hero en modo Solo Gastos.
    /// MTD-alineada: el ÚNICO caso asimétrico parcial-vs-completo es `.thisMonth`
    /// (`PreviousPeriodHelper` devuelve el mes anterior COMPLETO) y se trunca al
    /// día equivalente vía `DateAlignmentHelper.alignedPreviousInterval`; el resto
    /// ya es simétrico (ventana trailing de igual duración en `.thisWeek`/
    /// `.last7Days`/`.last30Days`/`.custom`, YTD-vs-YTD en `.thisYear`/`.lastYear`
    /// vía modo `.year`, closed-vs-closed en `.lastMonth`) → el helper es no-op ahí.
    /// `nil` para `.allTime` (sin previo acotado → sin comparación). `now`/`calendar`
    /// inyectables para determinismo en tests.
    static func periodPreviousInterval(
        period: DetailPeriod,
        currentInterval: DateInterval,
        customRange: DateInterval? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval? {
        guard period != .allTime else { return nil }
        let mode: ComparisonMode = period == .thisYear ? .year : .month
        let previous = PreviousPeriodHelper.previousInterval(
            for: period, mode: mode, customRange: customRange, now: now
        )
        return DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: currentInterval,
            previousInterval: previous,
            asOf: now,
            period: period,
            comparisonMode: mode,
            calendar: calendar
        )
    }
}
