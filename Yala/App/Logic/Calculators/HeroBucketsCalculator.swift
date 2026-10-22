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

        /// Si algún importe del bucket de PERÍODO —el que se pinta en el hero— trae su monto
        /// convertido con una tasa que no era la de su día. **Separado por lado**: en modo Solo
        /// Gastos el hero pinta únicamente `periodExpense`, y una señal común le ponía «≈» por
        /// culpa de un ingreso antiguo que no entra en ese número.
        ///
        /// La magnitud dudosa sale de `CashFlowCalculator.resolvedAmount`, la misma regla que el
        /// importe: si la fila se guardó en esta divisa, la sirve `GroupBridgeStatsAdjustment` (que en
        /// un gasto de grupo suma la de TODAS las patas, la de préstamo incluida aunque esté
        /// suprimida del recorrido); si se guardó en otra divisa principal y se reconvierte, es la
        /// calidad de ESA conversión.
        ///
        /// **No es un OR desde el 2026-09-08**: se enciende cuando el importe aproximado PESA sobre
        /// su lado — el criterio vive en `ApproximateMarkThreshold`, no aquí. Antes bastaba una
        /// transacción entre mil para marcar el mes entero.
        let periodIncomeApproximate: Bool
        let periodExpenseApproximate: Bool
        /// Para «Disponible» (`periodIncome - periodExpense`), que **resta un lado del otro**.
        ///
        /// No es el OR de los dos de arriba, y esa era una regresión real: con umbrales por lado, un
        /// ingreso grande con un 4,9 % aproximado no marca y un gasto exacto casi igual tampoco, y el
        /// «Disponible» que queda puede ser más pequeño que la propia incertidumbre. Aquí el
        /// numerador es la incertidumbre de los dos lados SUMADA y el denominador es el número que
        /// de verdad se pinta.
        let periodNetApproximate: Bool
    }

    static func calculate(
        transactions: [TransactionItem],
        monthInterval: DateInterval,
        prevInterval: DateInterval,
        periodInterval: DateInterval,
        periodPrevInterval: DateInterval? = nil,
        eligibleAccountIDs: Set<PersistentIdentifier>,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Buckets {
        var monthIncome: Double = 0
        var monthExpense: Double = 0
        var prevExpense: Double = 0
        var prevHasAnyTx = false
        var periodIncome: Double = 0
        var periodExpense: Double = 0
        var periodPrevExpense: Double = 0
        // Numerador del umbral, por lado. Aquí `amount` ya es `abs(...)` (línea de abajo), así que
        // `periodIncome`/`periodExpense` son sumas de magnitudes y sirven de denominador tal cual —
        // a diferencia de `CashFlowCalculator`, que acumula con signo y necesita los suyos aparte.
        var periodIncomeApproximateAmount: Double = 0
        var periodExpenseApproximateAmount: Double = 0

        for tx in transactions where tx.balanceAdjustmentType == nil {
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }
            // Excluir patas de préstamo derivadas del bridge (préstamo a grupos).
            guard !adjustment.isSuppressed(tx) else { continue }

            // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto); `resolvedAmount`
            // lo lleva a `currencyCode` aunque la fila se guardara en otra divisa principal.
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
            let amount = abs(resolved.value)
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
                // La magnitud dudosa NO la da la fila: en un gasto de grupo `amount` es el NETO de
                // varias patas y el flag de la fila describe solo una (ver `resolvedAmount`).
                let approximate = resolved.approximateMagnitude
                if isIncome {
                    periodIncome += amount
                    periodIncomeApproximateAmount += approximate
                } else {
                    periodExpense += amount
                    periodExpenseApproximateAmount += approximate
                }
            }

            // Ventana previa comparable (solo gasto). Estrictamente disjunta de
            // periodInterval: `DateInterval` es CERRADO en ambos extremos, así que una TX
            // fechada en el instante de cierre del previo caería en AMBOS buckets → doble
            // conteo que infla la base del comparativo.
            //
            // Desde el 2026-09-02 `PreviousPeriodHelper` SÍ resta 1s en todas sus ramas
            // (`.thisMonth` era la última sin hacerlo), así que hoy este guard es
            // REDUNDANTE para el camino normal. NO se retira: es la única red que
            // detectaría una regresión de esa fuente, el caller puede pasar un intervalo
            // artesanal, y su coste es una comparación. Su test (`:371`) sigue siendo un
            // test de contrato, no de implementación.
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
            periodPrevExpense: periodPrevExpense,
            periodIncomeApproximate: ApproximateMarkThreshold.marks(
                approximate: periodIncomeApproximateAmount, total: periodIncome
            ),
            periodExpenseApproximate: ApproximateMarkThreshold.marks(
                approximate: periodExpenseApproximateAmount, total: periodExpense
            ),
            periodNetApproximate: ApproximateMarkThreshold.marks(
                approximate: periodIncomeApproximateAmount + periodExpenseApproximateAmount,
                total: periodIncome - periodExpense
            )
        )
    }

    /// Ventana previa COMPARABLE al `currentInterval` del período seleccionado,
    /// para el chip "vs período anterior" del hero en modo Solo Gastos.
    ///
    /// Quién manda de verdad aquí es el gate `aggregatePreviousNeedsAlignment` de
    /// `DateAlignmentHelper` — consúltalo ahí, no confíes en esta lista. Hoy:
    ///
    /// - **Se truncan** los períodos EN CURSO cuyo previo llega completo:
    ///   `.thisMonth` (previo = mes anterior entero → se corta al día equivalente,
    ///   MTD-vs-MTD) y `.thisWeek` (previo = semana calendario anterior entera → se
    ///   corta al weekday equivalente, WTD-vs-WTD). `.thisYear` cruza el gate pero
    ///   sale no-op: su previo ya es YTD simétrico.
    /// - **No se tocan** los que ya son simétricos: `.last7Days`/`.last30Days`/
    ///   `.custom` (ventana trailing de igual duración) y `.lastMonth`/`.lastYear`
    ///   (cerrado contra cerrado).
    /// - `nil` para `.allTime` (sin previo acotado → sin comparación).
    ///
    /// OJO: `.lastYear` recibe modo `.month`, no `.year` — el `mode` de abajo sólo
    /// separa `.thisYear`. Hoy da igual (ambos modos caen en
    /// `sameIntervalPreviousYear` y el gate devuelve false), pero si alguna vez se
    /// mete `.lastYear` en el gate, la estrategia sería `.proportional` en vez de
    /// `.calendarYear`.
    ///
    /// Hasta `f6d4101d` (2026-08-17) `.thisWeek` tenía ventana trailing y aquí no se
    /// tocaba; esa frase sobrevivió en este docstring dos semanas y media y dejó un
    /// test rojo afirmándola. Si cambias el gate, cambia también este párrafo.
    /// `now`/`calendar` inyectables para determinismo en tests.
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
