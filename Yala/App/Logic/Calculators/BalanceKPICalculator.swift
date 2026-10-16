//
//  BalanceKPICalculator.swift
//  Yala
//
//  SSOT del número que se muestra como KPI cuando la métrica es Balance.
//
//  El Panel ya resolvía este número dentro de `TrendDataProcessor`
//  (`finalBalance`), pero solo como subproducto de construir la curva: quien
//  quisiera el mismo KPI sin la gráfica no tenía dónde pedirlo, y Distribución
//  acabó mostrando otra cosa (el gasto del período, un FLUJO) bajo la misma
//  selección de filtros. Este helper expone ese número para que las dos
//  pantallas lean del mismo sitio.
//
//  La semántica tiene DOS regímenes, y los dos importan:
//
//  1. El período cubre hoy  → saldo VIVO: buckets por moneda nativa
//     convertidos con el TC ACTUAL (`LiveBalanceCalculator`). Es "cuánto
//     tienes hoy", no "cuánto valía cuando pasó".
//  2. El período está cerrado (mes/año pasado) → saldo HISTÓRICO al cierre:
//     el último punto de la curva acumulada.
//  3. Sin transacciones en el período → 0.
//
//  Devolver siempre el saldo vivo sería incorrecto en el caso 2: enseñaría el
//  saldo de HOY bajo una etiqueta que dice "Mes pasado". Por eso el régimen lo
//  decide `LiveBalanceCalculator.liveBalanceOverride` (nil ⇒ período cerrado) y
//  no una comparación de fechas escrita aquí.
//
//  No reimplementa ninguna de las dos reglas: delega en los mismos
//  `LiveBalanceCalculator` y `TrendDataProcessor` que usa el Panel. Si mañana
//  cambia `finalBalance`, este KPI cambia con él en vez de divergir — que es
//  justo como el número se separó la primera vez.
//

import Foundation

enum BalanceKPICalculator {

    /// El número y si el período tiene algo que enseñar.
    ///
    /// `hasDataInPeriod` existe porque el 0 del Panel es AMBIGUO: sin movimientos
    /// en el período `finalBalance` vale 0 igual que si el saldo fuera realmente
    /// cero. Al Panel no le estorba —oculta el KPI cuando no hay curva— pero una
    /// pantalla que muestre el número a secas escribiría «0» a un usuario que
    /// tiene 12.000 en el banco, solo por abrir un mes sin gastos.
    struct Result: Equatable {
        let value: Double
        let hasDataInPeriod: Bool

        /// `true` si el número salió de alguna tasa que no era la de su día.
        ///
        /// **Hoy solo se rellena en el régimen VIVO.** Ahí el número lo arma `LiveBalanceCalculator`
        /// convirtiendo cada bucket con el TC de hoy, y su `Breakdown` mide la calidad de cada
        /// conversión, así que la señal viene con el valor. En el régimen CERRADO el número es el
        /// último punto de la curva acumulada de `TrendDataProcessor`, que desde el 2026-10-16 valora
        /// el saldo nativo al cierre con la tasa de ese día (`BalanceValuation`) y se queda solo con el
        /// valor: **la curva no acumula la señal**, ni aquí ni en ninguna otra pantalla que muestre
        /// ese saldo. `false` ahí dice «no lo sé», no «es exacto».
        ///
        /// **Y que conste que es alcance, no imposibilidad** — la review adversarial del 2026-09-09
        /// tenía razón en señalarlo. El ingrediente (`tx.isExchangeRateProvisional`) está a mano:
        /// `result(...)` recibe el array entero. De hecho `WidgetDataCache.buildPeriodSummary` hace
        /// exactamente ese cálculo para el saldo del widget, en el mismo commit. La diferencia es
        /// dónde vive el bucle: allí es una suma propia de cuatro líneas; aquí el número sale de
        /// `fillBalanceBuckets`, que alimenta a la vez la curva y este KPI y tiene dos suites
        /// encima (`TrendDataProcessorTests`, `BalanceKPIParityTests`). Por eso va aparte, en
        /// `fx-historical-balance-curve-unmarked` — y por eso ese ticket lleva escrito que en el
        /// widget sí se pudo.
        let isApproximate: Bool
    }

    /// KPI de Balance para un período, con la misma semántica que el Panel.
    ///
    /// - Parameters:
    ///   - transactions: set de saldo — **sin filtro de fecha**. El saldo vivo
    ///     necesita todo el histórico para acumular; recortarlo al período daría
    ///     el flujo del período, que es exactamente el bug que esto corrige.
    ///   - accounts: cuentas elegibles (ya sin las excluidas de estadísticas).
    ///   - interval: período mostrado. Decide qué régimen aplica.
    ///   - period/grouping: solo alimentan la curva del caso histórico. Para
    ///     Balance el acumulado final es invariante al `grouping` (el último
    ///     bucket cierra en la última transacción sea cual sea su tamaño).
    ///   - converter: inyectable para test. En producción, el TC actual.
    static func result(
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        period: DetailPeriod,
        grouping: TrendGrouping = .day,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Result {
        let liveOverride = LiveBalanceCalculator.liveBalanceOverride(
            for: .balance,
            interval: interval,
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            converter: converter
        )

        // `rawPoints.isEmpty` ⟺ no hay ninguna transacción dentro del intervalo.
        // Los otros dos caminos por los que `processTrendData` podría quedarse sin
        // puntos no lo consiguen: su segundo guard es inalcanzable con ≥1
        // transacción dentro (`startOfDay(primera) ≤ primera < interval.end`), y el
        // recorte de ceros a la cabeza no vacía el array (si `firstIndex` es nil,
        // no entra en el `if let`).
        let hasDataInPeriod = transactions.contains { interval.contains($0.date) }

        // Atajo del caso común. Cuando hay override, `processTrendData` construye
        // la curva entera y luego la DESCARTA: `finalBalance` sale del anchor, no
        // de la serie. Medido con 5.475 transacciones (3 años a 5/día): 21 ms en
        // "Este mes" y 43 ms en "Todo" por llamada — con el atajo, 15 y 15. No corre
        // por pulsación de tecla (el buscador de esta pantalla es un `@State` local
        // que solo se vuelca al pulsar «Aplicar»), pero sí en cada cambio de período
        // y en cada entrada a la pestaña.
        //
        // `BalanceKPIParityTests` compara este camino contra el completo en los ocho
        // períodos y en los bordes; si el atajo divergiera, se ponen rojos.
        if let info = liveOverride, hasDataInPeriod {
            return Result(
                value: info.value,
                hasDataInPeriod: true,
                isApproximate: info.amountsAreApproximate
            )
        }

        let finalBalance = TrendDataProcessor.processTrendData(
            transactions: transactions,
            accounts: accounts,
            metric: .balance,
            period: period,
            grouping: grouping,
            interval: interval,
            currencyCode: currencyCode,
            adjustment: adjustment,
            liveBalanceOverride: liveOverride,
            // La curva del período cerrado reconvierte las filas guardadas en otra divisa
            // principal: con el mismo converter que el saldo vivo de arriba.
            converter: converter
        ).finalBalance

        // Régimen cerrado (o sin datos): `finalBalance` sale de la curva histórica, que no lleva
        // señal. Ver el docblock de `Result.isApproximate`.
        return Result(value: finalBalance, hasDataInPeriod: hasDataInPeriod, isApproximate: false)
    }

    /// Solo el número, para comparar contra el KPI del Panel.
    static func value(
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        period: DetailPeriod,
        grouping: TrendGrouping = .day,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Double {
        result(
            transactions: transactions,
            accounts: accounts,
            interval: interval,
            period: period,
            grouping: grouping,
            currencyCode: currencyCode,
            adjustment: adjustment,
            converter: converter
        ).value
    }
}
