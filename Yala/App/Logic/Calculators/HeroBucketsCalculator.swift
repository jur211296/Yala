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
    }

    static func calculate(
        transactions: [TransactionItem],
        monthInterval: DateInterval,
        prevInterval: DateInterval,
        periodInterval: DateInterval,
        eligibleAccountIDs: Set<PersistentIdentifier>
    ) -> Buckets {
        var monthIncome: Double = 0
        var monthExpense: Double = 0
        var prevExpense: Double = 0
        var prevHasAnyTx = false
        var periodIncome: Double = 0
        var periodExpense: Double = 0

        for tx in transactions where tx.balanceAdjustmentType == nil {
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            let amount = abs(tx.amountInPreferredCurrency)
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
        }

        return Buckets(
            monthIncome: monthIncome,
            monthExpense: monthExpense,
            prevExpense: prevExpense,
            prevHasAnyTx: prevHasAnyTx,
            periodIncome: periodIncome,
            periodExpense: periodExpense
        )
    }
}
