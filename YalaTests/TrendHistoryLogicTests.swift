//
//  TrendHistoryLogicTests.swift
//  YalaTests
//
//  Histórico de períodos completos del Trend Insight Card V2: intervalos
//  (borde de medianoche cerrado con -1 s) y agregación.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct TrendHistoryLogicTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s)) ?? .distantPast
    }

    @Test func months_twelvePreviousIntervals_oldestFirst_closedOneSecondBeforeTheNext() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .thisMonth, anchor: date(2026, 10, 1), calendar: calendar
        )
        #expect(intervals.count == 12)
        #expect(intervals.first?.start == date(2025, 10, 1))
        #expect(intervals.last?.start == date(2026, 9, 1))
        #expect(intervals.last?.end == date(2026, 9, 30, 23, 59, 59))
        // Ningún instante cae en dos períodos: el borde de medianoche no se cuenta dos veces.
        for (a, b) in zip(intervals, intervals.dropFirst()) {
            #expect(a.end < b.start)
            #expect(b.start.timeIntervalSince(a.end) == 1)
        }
    }

    @Test func lastMonth_anchorsOnItsOwnStart() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .lastMonth, anchor: date(2026, 9, 1), count: 2, calendar: calendar
        )
        #expect(intervals.map(\.start) == [date(2026, 7, 1), date(2026, 8, 1)])
    }

    @Test func last7Days_stepsBySevenDays() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .last7Days, anchor: date(2026, 9, 26), count: 2, calendar: calendar
        )
        #expect(intervals.map(\.start) == [date(2026, 9, 12), date(2026, 9, 19)])
    }

    @Test func allTimeAndCustom_haveNoHistory() {
        #expect(TrendHistoryLogic.previousIntervals(for: .allTime, anchor: .now, calendar: calendar).isEmpty)
        #expect(TrendHistoryLogic.previousIntervals(for: .custom, anchor: .now, calendar: calendar).isEmpty)
    }

    @Test func units_matchTheirPeriods() {
        #expect(TrendHistoryLogic.unit(for: .thisMonth) == .months)
        #expect(TrendHistoryLogic.unit(for: .lastMonth) == .months)
        #expect(TrendHistoryLogic.unit(for: .thisWeek) == .weeks)
        #expect(TrendHistoryLogic.unit(for: .last7Days) == .weeks)
        #expect(TrendHistoryLogic.unit(for: .thisYear) == .years)
        #expect(TrendHistoryLogic.unit(for: .lastYear) == .years)
        // «Meses» sería falso para ventanas de 30 días.
        #expect(TrendHistoryLogic.unit(for: .last30Days) == nil)
        #expect(TrendHistoryLogic.unit(for: .allTime) == nil)
        #expect(TrendHistoryLogic.unit(for: .custom) == nil)
    }

    @Test func aggregate_sumsEachEntryIntoItsPeriod_signedAccumulation() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .thisMonth, anchor: date(2026, 10, 1), count: 3, calendar: calendar
        )
        let entries = [
            TrendHistoryEntry(date: date(2026, 7, 2), isIncome: false, amount: 5),     // llena la ventana desde el principio
            TrendHistoryEntry(date: date(2026, 8, 15), isIncome: false, amount: 100),
            TrendHistoryEntry(date: date(2026, 8, 20), isIncome: false, amount: -30),   // reembolso: resta
            TrendHistoryEntry(date: date(2026, 9, 1), isIncome: true, amount: 500),     // medianoche del día 1
            TrendHistoryEntry(date: date(2026, 9, 30, 23, 59, 59), isIncome: false, amount: 40),
            TrendHistoryEntry(date: date(2026, 10, 1), isIncome: false, amount: 999),   // período actual: fuera
        ]
        let points = TrendHistoryLogic.aggregate(entries: entries, intervals: intervals)
        #expect(points.map(\.start) == [date(2026, 7, 1), date(2026, 8, 1), date(2026, 9, 1)])
        #expect(points[1].expense == 70)
        #expect(points[1].income == 0)
        #expect(points[2].income == 500)
        #expect(points[2].expense == 40)
        #expect(points[2].net == 460)
    }

    @Test func aggregate_keepsEmptyPeriodsAfterTheFirstMovement() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .thisMonth, anchor: date(2026, 10, 1), count: 3, calendar: calendar
        )
        let entries = [TrendHistoryEntry(date: date(2026, 7, 10), isIncome: false, amount: 10)]
        let points = TrendHistoryLogic.aggregate(entries: entries, intervals: intervals)
        #expect(points.count == 3)
        #expect(points[1].expense == 0)
    }

    @Test func aggregate_withoutEntries_isEmpty() {
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .thisMonth, anchor: date(2026, 10, 1), calendar: calendar
        )
        #expect(TrendHistoryLogic.aggregate(entries: [], intervals: intervals).isEmpty)
    }

    @Test func aggregate_dropsLeadingEmptyPeriods_andTheFirstPartialOne() {
        // Empezó a registrar en agosto (no en el primer período de la ventana): julio sin
        // datos no es «gastaste 0», y agosto casi seguro está a medias — fuera los dos.
        let intervals = TrendHistoryLogic.previousIntervals(
            for: .thisMonth, anchor: date(2026, 10, 1), count: 3, calendar: calendar
        )
        let entries = [
            TrendHistoryEntry(date: date(2026, 8, 25), isIncome: false, amount: 300),
            TrendHistoryEntry(date: date(2026, 9, 10), isIncome: false, amount: 1000),
        ]
        let points = TrendHistoryLogic.aggregate(entries: entries, intervals: intervals)
        #expect(points.map(\.start) == [date(2026, 9, 1)])
        #expect(points[0].expense == 1000)
    }

    @Test func historyAnchor_inProgressPeriodsStopBeforeThemselves_closedOnesIncludeThemselves() {
        let thisMonth = DateInterval(start: date(2026, 10, 1), end: date(2026, 10, 4))
        #expect(TrendHistoryLogic.historyAnchor(for: .thisMonth, interval: thisMonth) == date(2026, 10, 1))
        // «Mes pasado» ya está completo: el histórico llega hasta él, o la racha y la
        // Comparativa de al lado hablarían de meses distintos.
        let lastMonth = DateInterval(start: date(2026, 9, 1), end: date(2026, 9, 30, 23, 59, 59))
        let anchor = TrendHistoryLogic.historyAnchor(for: .lastMonth, interval: lastMonth)
        #expect(anchor == date(2026, 10, 1))
        let intervals = TrendHistoryLogic.previousIntervals(for: .lastMonth, anchor: anchor, count: 1, calendar: calendar)
        #expect(intervals.first?.start == date(2026, 9, 1))
        let lastYear = DateInterval(start: date(2025, 1, 1), end: date(2025, 12, 31, 23, 59, 59))
        #expect(TrendHistoryLogic.historyAnchor(for: .lastYear, interval: lastYear) == date(2026, 1, 1))
    }
}
