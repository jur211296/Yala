//
//  TrendInsightLogic.swift
//  Yala
//
//  Pure-logic helper para el hallazgo principal del Trend Insight Card.
//  Devuelve un enum con el caso correspondiente; la localización vive en el
//  callsite UI (TrendsTabView.findingText). Sin dependencias de L10n para
//  permitir tests deterministas sin Bundle lookup.
//
//  V1 cubre 3 reglas: ONSET → STABILITY → VARIATION. Skip Rule 2 TREND
//  SOSTENIDO del spec (requiere historicalTotals[N] aún no expuesto por
//  StatisticsViewModel). V2 amplía cuando data layer crezca.
//

import Foundation

enum TrendInsightFinding: Equatable {
    case onset
    case variationUp(percent: Int, metric: TrendMetric)
    case variationDown(percent: Int, metric: TrendMetric)
    case stable(metric: TrendMetric)
}

enum TrendInsightLogic {
    /// Decide el hallazgo según los inputs disponibles.
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
        if abs(variation) < 0.05 { return .stable(metric: metric) }

        let percent = Int((abs(variation) * 100).rounded())
        return variation > 0
            ? .variationUp(percent: percent, metric: metric)
            : .variationDown(percent: percent, metric: metric)
    }
}
