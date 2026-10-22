//
//  TrendInsightLogic.swift
//  Yala
//
//  Pure-logic helper del Trend Insight Card (final de Tendencias).
//  Devuelve enums; la localización vive en el callsite UI
//  (TrendsTabView.findingText). Sin dependencias de L10n para permitir tests
//  deterministas sin Bundle lookup.
//
//  V2 (ticket trends-insight-card-v2-bullets): la card es un resumen en bullets,
//  uno por gráfica visible — Tendencia, Comparativa, Flujo de efectivo y Día de
//  la semana. Cada bullet es una `TrendInsightBullet`; las que no tienen dato se
//  omiten (D1: adaptativo, máximo 4).
//

import Foundation

enum TrendInsightFinding: Equatable {
    case onset
    case variationUp(percent: Int, metric: TrendMetric)
    case variationDown(percent: Int, metric: TrendMetric)
    case stable(metric: TrendMetric)
    // V2 — Tendencia (Rule TREND_SOSTENIDO): racha que termina en el último
    // período COMPLETO. `periods` = longitud de la racha (pasos para ingresos y
    // gastos; períodos con neto del mismo signo para balance).
    case sustainedUp(periods: Int, unit: TrendHistoryUnit, metric: TrendMetric)
    case sustainedDown(periods: Int, unit: TrendHistoryUnit, metric: TrendMetric)
    // V2 — Flujo de efectivo. `ratio` = ingresos / gastos en %.
    case cashFlowSurplus(ratio: Int)
    case cashFlowDeficit(ratio: Int)
    case cashFlowNoIncome
    // V2 — Día de la semana con mayor gasto promedio (1 = domingo … 7 = sábado).
    case weekdayPeak(weekday: Int, average: Double, currencyCode: String)
}

/// Un hallazgo + la gráfica de la que habla. El `id` fija el orden y el icono
/// contextual del bullet.
struct TrendInsightBullet: Equatable, Identifiable {
    enum Source: String, Equatable, CaseIterable {
        case trend, comparison, cashFlow, weekday
    }
    let id: Source
    let finding: TrendInsightFinding
}

enum TrendInsightLogic {

    /// Umbral de variación por debajo del cual el cambio se considera estable.
    static let stabilityThreshold = 0.05

    /// Longitud mínima de racha para que haya bullet de Tendencia.
    static let minimumStreak = 3

    /// Decide el hallazgo de Comparativa según los inputs disponibles.
    ///
    /// Prioridad:
    ///   1. ONSET → previousTotal == nil (sin historial comparable).
    ///   2. STABILITY → previousTotal == 0 (div/0) o |variation| < 5%.
    ///   3. VARIATION significativa → up/down con porcentaje redondeado.
    static func finding(
        metric: TrendMetric,
        currentTotal: Double,
        previousTotal: Double?
    ) -> TrendInsightFinding {
        guard let prev = previousTotal else { return .onset }
        guard prev != 0 else { return .stable(metric: metric) }

        let variation = (currentTotal - prev) / abs(prev)
        if abs(variation) < stabilityThreshold { return .stable(metric: metric) }

        let percent = Int((abs(variation) * 100).rounded())
        return variation > 0
            ? .variationUp(percent: percent, metric: metric)
            : .variationDown(percent: percent, metric: metric)
    }

    /// Rule TREND_SOSTENIDO sobre el histórico de períodos COMPLETOS (el actual
    /// queda fuera: va a mitad y compararlo con períodos enteros sesga a la baja).
    ///
    /// - Ingresos / gastos: cuenta los pasos consecutivos, desde el más reciente,
    ///   en los que el total sube (o baja) al menos un 5 %. Un paso desde 0 corta
    ///   la racha: no hay porcentaje.
    /// - Balance: cuenta los períodos consecutivos, desde el más reciente, con
    ///   neto del mismo signo — neto positivo es balance que crece.
    ///
    /// `history` va del más antiguo al más reciente. Devuelve `nil` sin unidad o
    /// si la racha no llega a `minimumStreak`.
    static func findingForTrend(
        metric: TrendMetric,
        history: [TrendHistoryPoint],
        unit: TrendHistoryUnit?
    ) -> TrendInsightFinding? {
        guard let unit else { return nil }

        switch metric {
        case .balance:
            let nets = history.map(\.net)
            guard let last = nets.last, last != 0 else { return nil }
            let positive = last > 0
            var streak = 0
            for net in nets.reversed() {
                guard net != 0, (net > 0) == positive else { break }
                streak += 1
            }
            guard streak >= minimumStreak else { return nil }
            return positive
                ? .sustainedUp(periods: streak, unit: unit, metric: metric)
                : .sustainedDown(periods: streak, unit: unit, metric: metric)

        case .expense, .income:
            let values = history.map { metric == .expense ? $0.expense : $0.income }
            guard values.count >= 2 else { return nil }
            var direction = 0   // +1 sube, -1 baja
            var streak = 0
            for index in stride(from: values.count - 1, to: 0, by: -1) {
                let current = values[index]
                let previous = values[index - 1]
                guard previous > 0 else { break }
                let variation = (current - previous) / previous
                let step: Int
                if variation >= stabilityThreshold {
                    step = 1
                } else if variation <= -stabilityThreshold {
                    step = -1
                } else {
                    break
                }
                if direction == 0 { direction = step }
                guard step == direction else { break }
                streak += 1
            }
            guard streak >= minimumStreak else { return nil }
            return direction > 0
                ? .sustainedUp(periods: streak, unit: unit, metric: metric)
                : .sustainedDown(periods: streak, unit: unit, metric: metric)
        }
    }

    /// Flujo de efectivo: dirección del neto + cobertura ingresos/gastos.
    /// Sin gasto no hay bullet (no hay cobertura que contar).
    static func findingForCashFlow(summary: CashFlowSummary) -> TrendInsightFinding? {
        guard summary.totalExpense > 0 else { return nil }
        guard summary.totalIncome > 0 else { return .cashFlowNoIncome }
        let coverage = summary.totalIncome / summary.totalExpense * 100
        // En déficit se trunca: 996 de 1000 no puede decir «cubrieron el 100 %».
        return summary.netFlow >= 0
            ? .cashFlowSurplus(ratio: Int(coverage.rounded()))
            : .cashFlowDeficit(ratio: min(99, Int(coverage.rounded(.down))))
    }

    /// Día de la semana con mayor gasto promedio — el mismo `topDay` que pinta
    /// la gráfica de días (TrendsTabView.weekdayCardBody).
    static func findingForWeekday(
        spending: [WeekdaySpending],
        currencyCode: String
    ) -> TrendInsightFinding? {
        guard let top = spending.filter({ $0.average > 0 })
            .max(by: { $0.average < $1.average }) else { return nil }
        return .weekdayPeak(weekday: top.weekday, average: top.average, currencyCode: currencyCode)
    }

    /// Lista adaptativa de la card (D1). Orden fijo: tendencia, comparativa,
    /// flujo, día. Lo que no tiene dato se omite.
    ///
    /// - Parameter comparisonAvailable: `false` en «Todo el tiempo», donde la
    ///   gráfica de Comparativa no se muestra y su bullet tampoco.
    static func bullets(
        metric: TrendMetric,
        currentTotal: Double,
        previousTotal: Double?,
        comparisonAvailable: Bool,
        history: [TrendHistoryPoint],
        historyUnit: TrendHistoryUnit?,
        cashFlowSummary: CashFlowSummary?,
        weekdaySpending: [WeekdaySpending],
        currencyCode: String
    ) -> [TrendInsightBullet] {
        var result: [TrendInsightBullet] = []
        if let trend = findingForTrend(metric: metric, history: history, unit: historyUnit) {
            result.append(.init(id: .trend, finding: trend))
        }
        if comparisonAvailable {
            result.append(.init(
                id: .comparison,
                finding: finding(metric: metric, currentTotal: currentTotal, previousTotal: previousTotal)
            ))
        }
        if let summary = cashFlowSummary, let cashFlow = findingForCashFlow(summary: summary) {
            result.append(.init(id: .cashFlow, finding: cashFlow))
        }
        if let weekday = findingForWeekday(spending: weekdaySpending, currencyCode: currencyCode) {
            result.append(.init(id: .weekday, finding: weekday))
        }
        return result
    }
}
