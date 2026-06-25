//
//  GroupTrendChartAdapter.swift
//  Yala
//
//  Adapta la tendencia mensual de un grupo ([GroupMonthlyTrend]) a los inputs
//  que consume el componente compartido `TrendChartView`, para que la gráfica de
//  tendencia del grupo sea idéntica (línea, área, ejes y hover) a las tendencias
//  del resto de la app.
//

import Foundation

enum GroupTrendChartAdapter {

    /// Inputs listos para `TrendChartView` derivados de la tendencia mensual del grupo.
    struct Input: Equatable {
        let points: [BarPoint]
        let yDomain: ClosedRange<Double>
        let interval: DateInterval
        /// Fechas en las que mostrar la etiqueta de valor (subconjunto inteligente).
        let dataLabelDates: Set<Date>
    }

    /// Convierte la tendencia mensual del grupo en los inputs del chart.
    /// Devuelve `nil` con menos de 2 meses (no hay línea que dibujar).
    static func makeInput(from trend: [GroupMonthlyTrend]) -> Input? {
        guard trend.count >= 2 else { return nil }

        // `trend` ya viene ordenado ascendente por mes desde el ViewModel.
        let points = trend.map { BarPoint(date: $0.month, value: $0.totalSpent) }
        let values = points.map(\.value)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0

        // yDomain idéntico al de las tendencias de la app (PanelViewModel /
        // StatisticsViewModel): padding del 10% del rango. Caso degenerado
        // (todos los meses con el mismo total → rango 0, que rompería
        // `chartYScale` y el anclaje del tooltip): se expande con un padding
        // mínimo para mantener un rango válido.
        let yDomain: ClosedRange<Double>
        if maxV > minV {
            let padding = (maxV - minV) * 0.1
            yDomain = (minV - padding)...(maxV + padding)
        } else {
            let pad = max(abs(maxV) * 0.1, 1)
            yDomain = (maxV - pad)...(maxV + pad)
        }

        guard let firstDate = points.first?.date, let lastDate = points.last?.date else { return nil }
        let interval = DateInterval(start: firstDate, end: lastDate)

        return Input(
            points: points,
            yDomain: yDomain,
            interval: interval,
            dataLabelDates: smartLabelDates(points: points)
        )
    }

    /// Fechas en las que mostrar la etiqueta de valor sobre el punto. Con pocos
    /// meses se etiquetan todos; con muchos, un subconjunto distribuido
    /// uniformemente que SIEMPRE incluye el primero y el último (el más reciente),
    /// para no saturar el chart.
    static func smartLabelDates(points: [BarPoint], maxLabels: Int = 6) -> Set<Date> {
        guard !points.isEmpty else { return [] }
        if points.count <= maxLabels {
            return Set(points.map(\.date))
        }
        let lastIndex = points.count - 1
        let step = max(1, Int((Double(points.count) / Double(maxLabels)).rounded(.up)))
        var indices = Set(Swift.stride(from: 0, through: lastIndex, by: step))
        indices.insert(lastIndex) // el más reciente siempre etiquetado
        return Set(indices.map { points[$0].date })
    }
}
