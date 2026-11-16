//
//  StatisticsChartGranularityLogic.swift
//  Yala
//
//  Cuánto agrupan las gráficas de Estadísticas › Tendencias según cuánto tiempo enseñan (G2 de la decisión 28, revisión
//  2.3 problema 7). Con diez años de datos, la curva pintaba un punto por día (~3.650) y «Entradas y salidas» una barra
//  por mes (120), con etiquetas que se pisaban («abr 24oct 26»). Ahora:
//  - la curva va por día hasta unos tres meses de datos y por mes a partir de ahí;
//  - «Entradas y salidas» va como antes (día en los períodos cortos, mes en los largos) y por año cuando los datos
//    cubren más de tres años.
//  El tiempo que cuenta es el de los DATOS dentro del período, no el del período: «Todo el tiempo» son diez años de
//  calendario aunque los registros empiecen hace dos meses, y agrupar esos dos meses por mes dejaría dos puntos.
//

import Foundation

enum StatisticsChartGranularityLogic {

    /// Hasta cuántos días de datos la curva va por día (un trimestre largo).
    static let dailyCurveMaxDays: Double = 92
    /// A partir de cuántos días de datos «Entradas y salidas» va por año: tres años, como el eje en años.
    static let yearlyBarsMinDays: Double = SmartAxisHelper.yearsOnlyAxisMinDays

    /// Días que cubren los datos dentro del intervalo: del primer registro del intervalo al final del intervalo, sin
    /// pasar de `now`. `nil` sin registros en el intervalo.
    static func dataSpanDays(earliestDate: Date?, interval: DateInterval, now: Date = .now) -> Double? {
        guard let earliestDate else { return nil }
        let start = max(earliestDate, interval.start)
        let end = min(interval.end, now)
        guard end > start else { return 0 }
        return end.timeIntervalSince(start) / 86_400
    }

    /// El registro más antiguo dentro del intervalo.
    static func earliestDate(of dates: some Sequence<Date>, in interval: DateInterval) -> Date? {
        var earliest: Date?
        for date in dates where interval.contains(date) {
            if let current = earliest, current <= date { continue }
            earliest = date
        }
        return earliest
    }

    /// Agrupación de la curva de tendencia. Un período que acaba después de hoy (un rango propio hacia el futuro) sigue
    /// por día: el punto del mes en curso juntaría lo fechado más adelante en el mes, y la proyección, que arranca de
    /// ese punto, lo volvería a sumar (lo cazó la revisión del lote).
    static func curveGrouping(dataSpanDays: Double?, intervalEndsAfterToday: Bool = false) -> TrendGrouping {
        guard !intervalEndsAfterToday, let dataSpanDays, dataSpanDays > dailyCurveMaxDays else { return .day }
        return .month
    }

    /// Agrupación de «Entradas y salidas». Los períodos cortos siguen por día; los largos, por mes y, con más de tres
    /// años de datos, por año.
    static func cashFlowGrouping(period: DetailPeriod, dataSpanDays: Double?) -> TrendGrouping {
        switch period {
        case .thisWeek, .last7Days, .thisMonth, .lastMonth, .last30Days:
            return .day
        case .thisYear, .lastYear, .allTime, .custom:
            if let dataSpanDays, dataSpanDays > yearlyBarsMinDays { return .year }
            return .month
        }
    }
}
