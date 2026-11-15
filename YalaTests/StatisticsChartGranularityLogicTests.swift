//
//  StatisticsChartGranularityLogicTests.swift
//  YalaTests
//
//  G2 de la decisión 28 (revisión 2.3, Estadísticas con diez años): en períodos largos las gráficas de Tendencias van por
//  mes y, con más de tres años de datos, «Entradas y salidas» va por año y el eje dice solo el año. Antes la curva iba
//  siempre por día (~3.650 puntos) y el eje decía «nov 2016 · nov 2021».
//

import Foundation
import Testing
@testable import Yala

@Suite("Estadísticas · agrupación de gráficas largas (G2)")
struct StatisticsChartGranularityLogicTests {

    private static let now = Date(timeIntervalSince1970: 1_793_000_000)   // 2026-10-26, a mitad de mes
    private static let tenYears = DateInterval(start: now.addingTimeInterval(-3_650 * 86_400), end: now)

    @Test("Diez años de datos: la curva por mes y las barras por año")
    func tenYearsOfData_curveByMonth_barsByYear() {
        let span = StatisticsChartGranularityLogic.dataSpanDays(
            earliestDate: Self.tenYears.start, interval: Self.tenYears, now: Self.now)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: span) == .month)
        #expect(StatisticsChartGranularityLogic.cashFlowGrouping(period: .allTime, dataSpanDays: span) == .year)
    }

    @Test("«Todo el tiempo» con dos meses de datos sigue por día y por mes: cuenta lo que cubren los datos, no el período")
    func allTimeWithTwoMonthsOfData_keepsDayCurveAndMonthBars() {
        let earliest = Self.now.addingTimeInterval(-60 * 86_400)
        let span = StatisticsChartGranularityLogic.dataSpanDays(
            earliestDate: earliest, interval: Self.tenYears, now: Self.now)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: span) == .day)
        #expect(StatisticsChartGranularityLogic.cashFlowGrouping(period: .allTime, dataSpanDays: span) == .month)
    }

    @Test("Este año: la curva por mes y las barras por mes")
    func thisYear_monthCurveAndMonthBars() {
        let start = Self.now.addingTimeInterval(-298 * 86_400)
        let span = StatisticsChartGranularityLogic.dataSpanDays(
            earliestDate: start, interval: DateInterval(start: start, end: Self.now), now: Self.now)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: span) == .month)
        #expect(StatisticsChartGranularityLogic.cashFlowGrouping(period: .thisYear, dataSpanDays: span) == .month)
    }

    @Test("Los períodos cortos no cambian: por día", arguments: [DetailPeriod.thisMonth, .lastMonth, .thisWeek, .last30Days])
    func shortPeriods_stayDaily(period: DetailPeriod) {
        #expect(StatisticsChartGranularityLogic.cashFlowGrouping(period: period, dataSpanDays: 3_650) == .day)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: 30) == .day)
    }

    @Test("Un rango que acaba después de hoy sigue por día: la proyección no puede sumar dos veces lo de este mes")
    func intervalEndingAfterToday_keepsTheDailyCurve() {
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: 400, intervalEndsAfterToday: true) == .day)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: 400, intervalEndsAfterToday: false) == .month)
    }

    @Test("Sin registros en el período, por día")
    func noData_isDaily() {
        #expect(StatisticsChartGranularityLogic.dataSpanDays(
            earliestDate: nil, interval: Self.tenYears, now: Self.now) == nil)
        #expect(StatisticsChartGranularityLogic.curveGrouping(dataSpanDays: nil) == .day)
        #expect(StatisticsChartGranularityLogic.cashFlowGrouping(period: .allTime, dataSpanDays: nil) == .month)
    }

    @Test("El registro más antiguo se busca dentro del período")
    func earliestDate_isInsideTheInterval() {
        let inside = Self.now.addingTimeInterval(-10 * 86_400)
        let before = Self.tenYears.start.addingTimeInterval(-86_400)
        let found = StatisticsChartGranularityLogic.earliestDate(
            of: [Self.now, before, inside], in: Self.tenYears)
        #expect(found == inside)
    }

    @Test("Una barra por año arranca el uno de enero")
    func yearGrouping_bucketsByCalendarYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        let mid = calendar.date(from: DateComponents(year: 2021, month: 7, day: 15, hour: 10)) ?? Self.now
        let key = TrendGrouping.year.dateKey(for: mid, calendar: calendar)
        #expect(calendar.dateComponents([.year, .month, .day], from: key) == DateComponents(year: 2021, month: 1, day: 1))
        #expect(TrendGrouping.year.calendarComponent == .year)
    }

    @MainActor
    @Test("Con más de tres años en el eje, las marcas dicen solo el año")
    func axisLabels_overThreeYears_sayOnlyTheYear() {
        let start = Self.tenYears.start
        let label = SmartAxisHelper.formatAxisLabel(for: start, startDate: start, endDate: Self.now, forceGrouping: nil)
        #expect(label.count == 4)
        #expect(Int(label) != nil)
        let monthly = SmartAxisHelper.formatAxisLabel(for: start, startDate: start, endDate: Self.now, forceGrouping: .month)
        #expect(Int(monthly) != nil)
    }

    @MainActor
    @Test("Con un año en el eje, sigue el mes")
    func axisLabels_oneYear_keepTheMonth() {
        let start = Self.now.addingTimeInterval(-300 * 86_400)
        let label = SmartAxisHelper.formatAxisLabel(for: start, startDate: start, endDate: Self.now, forceGrouping: .month)
        #expect(Int(label) == nil)
    }
}
