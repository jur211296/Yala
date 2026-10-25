//
//  PeriodEndsBeforeTomorrowMidnightTests.swift
//  YalaTests
//
//  Los períodos en curso cierran a las 23:59:59 de hoy (ticket `period-totals-count-a-row-dated-at-tomorrows-midnight`,
//  lote 12.5). `DateInterval` es cerrado: acabar en la medianoche de mañana contaba en «Este mes» lo fechado mañana a las
//  00:00, la hora que guarda el selector de fecha. Y los sitios que construían el mismo borde a mano.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Los períodos en curso dejan fuera la medianoche de mañana")
struct PeriodEndsBeforeTomorrowMidnightTests {

    private let calendar = Calendar.current

    /// 25-oct-2026 a las 15:00 (un día cualquiera a media tarde).
    private var now: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 25; c.hour = 15
        return calendar.date(from: c) ?? .now
    }

    private var startOfToday: Date { calendar.startOfDay(for: now) }
    private var tomorrowMidnight: Date { calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now }

    @Test(arguments: [DetailPeriod.thisWeek, .last7Days, .last30Days, .thisMonth, .thisYear, .allTime])
    func inCoursePeriod_excludesTomorrowMidnight_andKeepsAllOfToday(_ period: DetailPeriod) {
        let interval = period.dateInterval(now: now, calendar: calendar)
        #expect(!interval.contains(tomorrowMidnight), "\(period) cuenta lo fechado mañana a las 00:00")
        #expect(interval.contains(startOfToday))
        #expect(interval.contains(tomorrowMidnight.addingTimeInterval(-1)), "\(period) ya no cuenta el final de hoy")
    }

    /// Los cerrados ya acababan en 23:59:59: no cambian.
    @Test func closedPeriods_keepTheirLastSecond() {
        let lastMonth = DetailPeriod.lastMonth.dateInterval(now: now, calendar: calendar)
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 1
        let firstOfThisMonth = calendar.date(from: c) ?? now
        #expect(lastMonth.end == firstOfThisMonth.addingTimeInterval(-1))
        #expect(!lastMonth.contains(firstOfThisMonth))
    }

    /// El único daño que medió la auditoría: el anterior de «Últimos 7/30 días» se anclaba por duración, y con el fin en
    /// 23:59:59 arrancaba a las 00:00:01 y dejaba fuera lo fechado a medianoche de su primer día.
    @Test(arguments: [(DetailPeriod.last7Days, 7), (.last30Days, 30)])
    func previousOfARollingPeriod_startsAtMidnight_andIsAdjacent(_ period: DetailPeriod, _ days: Int) {
        let current = period.dateInterval(now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: period, mode: .month, now: now)
        let expectedStart = calendar.date(byAdding: .day, value: -days, to: current.start)
        #expect(previous.start == expectedStart, "El anterior de \(period) no arranca a medianoche")
        #expect(previous.end == current.start.addingTimeInterval(-1))
        #expect(!previous.contains(current.start))
    }

    /// Un rango propio que cierra en 23:59:59 se desplaza por días enteros, no por un segundo de menos.
    @Test func previousOfACustomRangeClosingAt235959_startsAtMidnight() throws {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 10
        let start = try #require(calendar.date(from: c))
        let endExclusive = try #require(calendar.date(byAdding: .day, value: 5, to: start))
        let custom = DateInterval(start: start, end: endExclusive.addingTimeInterval(-1))
        let previous = PreviousPeriodHelper.previousInterval(for: .custom, mode: .month, customRange: custom, now: now)
        #expect(previous.start == calendar.date(byAdding: .day, value: -5, to: start))
    }

    /// Compromisos de «Este mes»: el mes natural de `Calendar` acaba en el día 1 del siguiente a las 00:00.
    @Test func commitmentsOfThisMonth_excludeTheFirstOfNextMonth() {
        let fallback = DetailPeriod.thisMonth.dateInterval(now: now, calendar: calendar)
        let interval = FinancialScoreCalculator.commitmentsInterval(period: .thisMonth, fallback: fallback, now: now, calendar: calendar)
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 1
        let firstOfNext = calendar.date(from: c) ?? now
        #expect(!interval.contains(firstOfNext))
        #expect(interval.contains(firstOfNext.addingTimeInterval(-1)))
    }

    /// El informe diario lanzado a medianoche cubre ayer y deja fuera lo de hoy a las 00:00.
    @Test func dailyReportAtMidnight_excludesTodaysMidnight() {
        let interval = ReportNotificationService.getIntervalForReportType(
            .default, type: .dailyReport, now: startOfToday, calendar: calendar)
        #expect(interval.start == calendar.date(byAdding: .day, value: -1, to: startOfToday))
        #expect(!interval.contains(startOfToday))
    }

    /// El widget no se compila en esta suite: su espejo de `DetailPeriod.dateInterval` se fija leyendo su fuente (la réplica
    /// de `WidgetDataServiceIntervalTests` es una copia y no lo vería cambiar).
    @Test func widgetMirror_closesAt235959() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(contentsOf: root.appendingPathComponent("YalaWidgets/Services/WidgetDataService.swift"), encoding: .utf8)
        let function = try #require(code.range(of: "func dateInterval() -> DateInterval {"))
        let end = try #require(code.range(of: "\n    }\n", range: function.upperBound..<code.endIndex))
        let body = code[function.upperBound..<end.lowerBound]
        #expect(body.contains("let endOfToday = calendar.date(byAdding: .second, value: -1, to: startOfTomorrow) ?? startOfTomorrow"))
        #expect(!body.contains("let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now"))
        // Los seis períodos en curso acaban en `endOfToday`, y ninguno en la medianoche de mañana.
        #expect(body.components(separatedBy: "end: endOfToday)").count == 7)
        #expect(!body.contains("end: startOfTomorrow"))
    }

    /// El intervalo de «Todo» del Panel y el mes del hero se construían a mano con el mismo borde.
    @Test func panelHandBuiltIntervals_closeAt235959() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let code = try String(contentsOf: root.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift"), encoding: .utf8)
        #expect(!code.contains("let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now"))
        #expect(code.contains("let endOfToday = calendar.date(byAdding: .second, value: -1, to: startOfTomorrow) ?? startOfTomorrow"))
        #expect(code.contains("end: max(calendarMonth.start, calendarMonth.end.addingTimeInterval(-1)))"))
        // Y es ese mes cerrado el que llega al calculador, no el natural.
        let call = try #require(code.range(of: "let buckets = HeroBucketsCalculator.calculate("))
        #expect(code[call.upperBound...].prefix(200).contains("monthInterval: monthInterval,"))
        #expect(!code[call.upperBound...].prefix(200).contains("monthInterval: calendarMonth"))
    }

    /// Los planificados de «Este mes» y «Esta semana» (Sankey) dejan fuera el día 1 siguiente y el lunes siguiente.
    @Test func plannedInterval_excludesTheNextMidnight() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = calendar.timeZone
        cal.firstWeekday = 2
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 21; c.hour = 12
        let wednesday = try #require(cal.date(from: c))
        let month = try #require(DetailPeriod.thisMonth.plannedInterval(calendar: cal, now: wednesday))
        c.month = 11; c.day = 1; c.hour = 0
        let firstOfNovember = try #require(cal.date(from: c))
        #expect(!month.contains(firstOfNovember))
        #expect(month.contains(firstOfNovember.addingTimeInterval(-1)))
        let week = try #require(DetailPeriod.thisWeek.plannedInterval(calendar: cal, now: wednesday))
        c.month = 10; c.day = 26
        let nextMonday = try #require(cal.date(from: c))
        #expect(!week.contains(nextMonday))
        #expect(week.contains(nextMonday.addingTimeInterval(-1)))
    }
}
