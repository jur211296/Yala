//
//  ChartAccessibilityDescriptor.swift
//  Yala
//
//  La descripción de gráficas de iOS (decisión 26 de la revisión 2.3, V2, 9-nov). Con ella VoiceOver ofrece en el rotor
//  «Describir gráfica» (ejes, rango, series) y «Reproducir gráfica audio» (un tono que sube y baja con los valores), y deja
//  recorrer los puntos uno a uno. Hasta ese día solo la tenía la mini gráfica del flujo de caja. El resumen es la misma
//  frase que la etiqueta (`ChartSpokenSummary`), así lo que se oye en los dos sitios no se contradice.
//

import Accessibility
import SwiftUI
import Foundation

struct ChartAccessibilityDescriptor: AXChartDescriptorRepresentable, Equatable {

    /// Qué hay en el eje horizontal: fechas (una línea, unas barras por día o por mes) o nombres (categorías, días de
    /// la semana).
    enum XAxis: Equatable {
        case dates(grouping: TrendGrouping)
        case categories([String])
    }

    struct Series: Equatable {
        let name: String
        let isContinuous: Bool
        /// En `.dates`, la fecha de cada punto; en `.categories`, su posición en la lista de nombres.
        let points: [Point]
    }

    struct Point: Equatable {
        let date: Date?
        let category: String?
        let value: Double

        static func at(_ date: Date, _ value: Double) -> Point { Point(date: date, category: nil, value: value) }
        static func named(_ category: String, _ value: Double) -> Point { Point(date: nil, category: category, value: value) }
    }

    let title: String
    let summary: String
    let xTitle: String
    let xAxis: XAxis
    let yTitle: String
    let series: [Series]
    let format: ChartAmountFormat
    var locale: Locale = AppLocale.current
    var calendar: Calendar = .current

    /// Una tarta: un trozo por nombre, con la frase de las partes (`ChartSpokenSummary.parts`) como resumen. La usan las
    /// tres tartas de Distribución y del Panel (categorías, subcategorías y etiquetas).
    static func parts(
        title: String, xTitle: String, items: [(name: String, amount: Double)], format: ChartAmountFormat
    ) -> ChartAccessibilityDescriptor {
        ChartAccessibilityDescriptor(
            title: title,
            summary: ChartSpokenSummary.parts(items, format: format),
            xTitle: xTitle,
            xAxis: .categories(items.map(\.name)),
            yTitle: L10n.Accessibility.Chart.axisAmount,
            series: [.init(name: title, isContinuous: false, points: items.map { .named($0.name, $0.amount) })],
            format: format
        )
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: makeXAxis(),
            yAxis: makeYAxis(),
            additionalAxes: [],
            series: series.map(makeSeries)
        )
    }

    private func makeXAxis() -> any AXDataAxisDescriptor {
        switch xAxis {
        case .categories(let names):
            return AXCategoricalDataAxisDescriptor(title: xTitle, categoryOrder: names)
        case .dates(let grouping):
            let dates = series.flatMap { $0.points.compactMap(\.date) }
            let lower = dates.min()?.timeIntervalSinceReferenceDate ?? 0
            let upper = dates.max()?.timeIntervalSinceReferenceDate ?? lower
            let locale = locale
            let calendar = calendar
            return AXNumericDataAxisDescriptor(
                title: xTitle,
                range: lower...max(upper, lower + 1),
                gridlinePositions: []
            ) { value in
                ChartSpokenSummary.dateText(
                    Date(timeIntervalSinceReferenceDate: value), grouping: grouping, locale: locale, calendar: calendar
                )
            }
        }
    }

    private func makeYAxis() -> AXNumericDataAxisDescriptor {
        let values = series.flatMap { $0.points.map(\.value) }
        let lower = min(values.min() ?? 0, 0)
        let upper = max(values.max() ?? 0, lower + 1)
        let format = format
        return AXNumericDataAxisDescriptor(
            title: yTitle,
            range: lower...upper,
            gridlinePositions: []
        ) { value in format.spoken(value) }
    }

    private func makeSeries(_ series: Series) -> AXDataSeriesDescriptor {
        AXDataSeriesDescriptor(
            name: series.name,
            isContinuous: series.isContinuous,
            dataPoints: series.points.map { point in
                if let date = point.date {
                    return AXDataPoint(x: date.timeIntervalSinceReferenceDate, y: point.value)
                }
                return AXDataPoint(x: point.category ?? "", y: point.value)
            }
        )
    }
}
