//
//  PreviewSampleData.swift
//  Yala
//
//  Sample data sintético para los previews internos de `WidgetInfoSheet`.
//  Ningún helper aquí debe usarse en producción — son datos de demostración
//  para que el preview muestre una gráfica representativa cuando el usuario
//  todavía no tiene transacciones reales.
//

import Foundation

extension CashFlowSummary {
    /// 7 días sintéticos con income/expense alternado. Pensado para el
    /// recuadro de preview de `WidgetInfoSheet` cuando el VM no tiene datos
    /// reales aún.
    static var previewSample: CashFlowSummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // 7 días (de más antiguo a más reciente)
        let dailyPattern: [(income: Double, expense: Double)] = [
            (180,   95),
            (  0,  120),
            (240,   70),
            (  0,  140),
            ( 60,  110),
            (  0,   85),
            (320,  150),
        ]

        var chartData: [CashFlowData] = []
        for (offset, pattern) in dailyPattern.enumerated() {
            let dayDate = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
            chartData.append(
                CashFlowData(
                    date: dayDate,
                    income: pattern.income,
                    expense: pattern.expense,
                    net: pattern.income - pattern.expense
                )
            )
        }

        let totalIncome = dailyPattern.reduce(0.0) { $0 + $1.income }
        let totalExpense = dailyPattern.reduce(0.0) { $0 + $1.expense }

        return CashFlowSummary(
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            netFlow: totalIncome - totalExpense,
            chartData: chartData,
            currencyCode: "USD"
        )
    }
}

extension PanelPeriodComparisonData {
    /// 30 puntos sintéticos para el carrusel de Trend en preview. Curva en
    /// dientes de sierra suave alrededor de un balance positivo.
    static var previewSample: PanelPeriodComparisonData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var current: [BarPoint] = []
        var previous: [BarPoint] = []

        for offset in 0..<30 {
            let day = calendar.date(byAdding: .day, value: offset - 29, to: today) ?? today
            let phase = Double(offset) * 0.25
            let curr = 1200 + 220 * sin(phase) + Double((offset % 5)) * 35
            let prev = 1080 + 180 * sin(phase + 0.6) + Double((offset % 4)) * 28
            current.append(BarPoint(date: day, value: curr))
            previous.append(BarPoint(date: day, value: prev))
        }

        let yMin = (current + previous).map(\.value).min() ?? 0
        let yMax = (current + previous).map(\.value).max() ?? 1
        let lower = yMin - (yMax - yMin) * 0.1
        let upper = yMax + (yMax - yMin) * 0.1

        let currentInterval = DateInterval(
            start: calendar.date(byAdding: .day, value: -29, to: today) ?? today,
            end: today
        )
        let previousInterval = DateInterval(
            start: calendar.date(byAdding: .day, value: -59, to: today) ?? today,
            end: calendar.date(byAdding: .day, value: -30, to: today) ?? today
        )

        return PanelPeriodComparisonData(
            currentPoints: current,
            previousPoints: previous,
            yDomain: lower...upper,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            grouping: .day,
            comparisonMode: .month,
            trendType: .balance,
            period: .thisMonth,
            currentTotal: current.reduce(0.0) { $0 + $1.value },
            previousTotal: previous.reduce(0.0) { $0 + $1.value },
            supportsComparison: true
        )
    }
}

extension PanelViewModel {
    /// VM mínimo con `periodComparisonWidget` precargado a sample data.
    /// Cachear el resultado en `@State` del wrapper — `init()` es minimal
    /// (solo `loadExchangeRateCurrencySelection`), pero re-instanciarlo en
    /// cada body re-render desperdicia trabajo.
    @MainActor
    static func previewWithSampleTrend() -> PanelViewModel {
        let vm = PanelViewModel()
        vm.periodComparisonWidget = .previewSample
        return vm
    }
}

extension Array where Element == NeedTrendPoint {
    /// 14 puntos sintéticos con composición esencial/prioritario/opcional/sin-clasificar.
    /// Pensado para el preview de `expensesByNeed` cuando el VM no tiene datos.
    static var previewSample: [NeedTrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Curvas suaves para que el stacked chart tenga forma orgánica.
        let pattern: [(essential: Double, priority: Double, optional: Double, unclassified: Double)] = [
            (45, 22, 18, 0),
            (52, 28, 12, 0),
            (38, 30, 25, 5),
            (60, 25, 20, 0),
            (48, 35, 15, 0),
            (55, 20, 30, 0),
            (62, 32, 22, 8),
            (50, 28, 18, 0),
            (44, 26, 24, 0),
            (58, 30, 16, 0),
            (52, 24, 28, 4),
            (66, 36, 14, 0),
            (40, 22, 32, 0),
            (54, 28, 20, 0),
        ]

        return pattern.enumerated().map { offset, p in
            let date = calendar.date(byAdding: .day, value: offset - 13, to: today) ?? today
            return NeedTrendPoint(
                date: date,
                essential: p.essential,
                priority: p.priority,
                optional: p.optional,
                unclassified: p.unclassified
            )
        }
    }
}
