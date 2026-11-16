//
//  AccountAnalysisBuilder.swift
//  Yala
//
//  Los datos de las gráficas de la ficha de una cuenta (rediseño del 2026-11-16, ticket `analisis-por-cuenta`). La ficha
//  pinta los mismos componentes que los widgets del Panel —`TrendChartView`, `CashFlowWidget` y `CategoriesPieWidget`—
//  sin tocarlos, así que aquí se les da de comer en su propio formato con los movimientos de UNA cuenta.
//
//  Tres decisiones que no son obvias (Paso 0 del encargo, D2 y D3):
//  - **La curva sale de `AccountDetailCalculator`**, la misma suma que la tarjeta de la cuenta: su último punto es la
//    cifra de la tarjeta. Solo se le pone el suavizado de la curva del Panel en períodos largos, que no toca los últimos
//    14 puntos. `TrendDataProcessor` no vale aquí: deja fuera la cuenta archivada y valora a la tasa de cada cierre.
//  - **El flujo y las categorías salen de `CashFlowCalculator` y `TopSpendingCategoriesCalculator`**, los del Panel, en la
//    divisa de la cuenta y sin ajuste de Grupos: lo gastado de la tarta es lo gastado de la tarjeta en «solo gastos»
//    (`AccountSpendingLogic`), con su trozo «Sin categoría».
//  - **La comparación es contra el período anterior hasta hoy** (`DateAlignmentHelper.alignedPreviousInterval`, la regla
//    de Estadísticas). Con «Todo el tiempo» no hay anterior.
//

import Foundation

struct AccountAnalysis {
    struct Trend: Equatable {
        let type: TrendType
        /// Lo que se dibuja (suavizado en períodos largos).
        let points: [BarPoint]
        /// Los puntos reales: los que se dicen y los que enseña el dedo.
        let rawPoints: [BarPoint]
        let yDomain: ClosedRange<Double>
    }

    let trend: Trend
    let cashFlow: CashFlowSummary
    let cashFlowGrouping: TrendGrouping
    /// Neto (o gasto, en «solo gastos») del período anterior hasta hoy. `nil` sin período anterior.
    let previousCashFlowAmount: Double?
    let categories: [CategorySpendingSummary]
    /// Lo gastado en el período anterior hasta hoy. `nil` sin período anterior.
    let previousSpent: Double?
    let largestExpenses: [AccountDetailCalculator.Entry]
}

enum AccountAnalysisBuilder {

    static func build(
        transactions: [TransactionItem],
        entries: [AccountDetailCalculator.Entry],
        series: [AccountDetailCalculator.DayBalance],
        period: DetailPeriod,
        customRange: DateInterval?,
        interval: DateInterval,
        currencyCode: String,
        isExpensesOnlyMode: Bool,
        now: Date = .now,
        calendar: Calendar = .current,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> AccountAnalysis {
        let grouping = cashFlowGrouping(for: period)
        // `CashFlowCalculator` suma TODO lo que recibe (el Panel le pasa las filas ya recortadas al período): sin este
        // recorte, «Entradas y salidas» sumaba la historia entera de la cuenta.
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: transactions.filter { interval.contains($0.date) }, interval: interval, grouping: grouping,
            currencyCode: currencyCode, converter: converter
        )
        let categories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: transactions, interval: interval, currencyCode: currencyCode, converter: converter
        )

        var previousCashFlowAmount: Double?
        var previousSpent: Double?
        if let previous = previousInterval(
            period: period, customRange: customRange, current: interval, now: now, calendar: calendar
        ) {
            let inPrevious = transactions.filter { previous.contains($0.date) }
            let previousFlow = CashFlowCalculator.calculateCashFlow(
                transactions: inPrevious, interval: previous, grouping: grouping,
                currencyCode: currencyCode, converter: converter
            )
            previousCashFlowAmount = isExpensesOnlyMode ? previousFlow.totalExpense : previousFlow.netFlow
            previousSpent = TopSpendingCategoriesCalculator.calculateTopSpending(
                transactions: inPrevious, interval: previous, currencyCode: currencyCode, converter: converter
            ).reduce(0) { $0 + $1.amount }
        }

        return AccountAnalysis(
            trend: trend(series, period: period, type: isExpensesOnlyMode ? .expense : .balance),
            cashFlow: cashFlow,
            cashFlowGrouping: grouping,
            previousCashFlowAmount: previousCashFlowAmount,
            categories: categories,
            previousSpent: previousSpent,
            largestExpenses: AccountDetailCalculator.largestExpenses(entries: entries, interval: interval)
        )
    }

    /// La curva lista para `TrendChartView`: un punto por día y, en períodos largos, el suavizado de la curva del Panel
    /// (`TrendDataProcessor`), que deja intactos los últimos puntos: el último sigue siendo la cifra de la tarjeta.
    static func trend(
        _ series: [AccountDetailCalculator.DayBalance], period: DetailPeriod, type: TrendType
    ) -> AccountAnalysis.Trend {
        let raw = series.map { BarPoint(date: $0.day, value: $0.balance) }
        let smooths = TrendDataProcessor.smoothingPeriods.contains(period)
            && raw.count > TrendDataProcessor.smoothingThreshold
        let points = smooths
            ? TrendProcessingHelper.movingAverage(for: raw, window: TrendDataProcessor.smoothingWindowSize)
            : raw
        return AccountAnalysis.Trend(
            type: type,
            points: points,
            rawPoints: raw,
            yDomain: TrendProcessingHelper.calculateYDomain(for: raw, isExpense: type == .expense)
        )
    }

    /// La agrupación de las barras del flujo: la del widget del Panel (`PanelViewModel.determineGroupings`, privada),
    /// por día hasta un mes y por mes en adelante.
    static func cashFlowGrouping(for period: DetailPeriod) -> TrendGrouping {
        switch period {
        case .thisWeek, .last7Days, .thisMonth, .lastMonth, .last30Days: return .day
        case .thisYear, .lastYear, .allTime, .custom: return .month
        }
    }

    /// El período anterior HASTA HOY con el que se compara, o `nil` con «Todo el tiempo».
    static func previousInterval(
        period: DetailPeriod,
        customRange: DateInterval?,
        current: DateInterval,
        now: Date,
        calendar: Calendar
    ) -> DateInterval? {
        guard period != .allTime else { return nil }
        let previous = PreviousPeriodHelper.previousInterval(
            for: period, mode: .month, customRange: customRange, now: now, calendar: calendar
        )
        return DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: current, previousInterval: previous, asOf: now,
            period: period, comparisonMode: .month, calendar: calendar
        )
    }
}
