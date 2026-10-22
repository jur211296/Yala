//
//  DetailPeriodDateIntervalTests.swift
//  YalaTests
//
//  Unit tests for DetailPeriod.dateInterval() boundary behavior (.lastMonth/.lastYear).
//  Deterministic via injected `now`. Las fechas esperadas se derivan con el MISMO
//  `Calendar.current` que usa `dateInterval()` internamente (userConfiguredCalendar) —
//  NO se fija UTC, porque la función usa el timezone local; hardcodear UTC desfasaría
//  las comparaciones de igualdad exacta.
//

import Foundation
import Testing

@testable import Yala

struct DetailPeriodDateIntervalTests {

    // MARK: - Fixtures

    /// Reference `now`: 2026-07-15 12:00 (timezone local). Mediodía para evitar
    /// cualquier borde de medianoche/DST. Mes actual = julio, año actual = 2026.
    private var now: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 15; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    // MARK: - .lastMonth

    @Test func dateInterval_lastMonth_endsOneSecondBeforeStartOfThisMonth() {
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        let expectedEnd = cal.date(byAdding: .second, value: -1, to: startOfThisMonth)!

        let interval = DetailPeriod.lastMonth.dateInterval(now: now)
        #expect(interval.start == startOfLastMonth)
        #expect(interval.end == expectedEnd)
    }

    @Test func dateInterval_lastMonth_excludesMidnightOfCurrentMonth() {
        // Reproduce el bug reportado: transacción elegida manualmente como "día 1 del
        // mes actual" vía DatePicker (displayedComponents: .date) normaliza a medianoche
        // exacta = startOfThisMonth. Ese instante debe quedar en "Este mes", no en "Mes pasado".
        let cal = Calendar.current
        let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        let lastMonth = DetailPeriod.lastMonth.dateInterval(now: now)
        let thisMonth = DetailPeriod.thisMonth.dateInterval(now: now)

        #expect(lastMonth.contains(startOfThisMonth) == false)
        #expect(thisMonth.contains(startOfThisMonth) == true)
    }

    // MARK: - .lastYear

    @Test func dateInterval_lastYear_endsOneSecondBeforeStartOfThisYear() {
        let cal = Calendar.current
        let startOfThisYear = cal.date(from: cal.dateComponents([.year], from: now))!
        let startOfLastYear = cal.date(byAdding: .year, value: -1, to: startOfThisYear)!
        let expectedEnd = cal.date(byAdding: .second, value: -1, to: startOfThisYear)!

        let interval = DetailPeriod.lastYear.dateInterval(now: now)
        #expect(interval.start == startOfLastYear)
        #expect(interval.end == expectedEnd)
    }

    @Test func dateInterval_lastYear_excludesMidnightOfCurrentYear() {
        let cal = Calendar.current
        let startOfThisYear = cal.date(from: cal.dateComponents([.year], from: now))!

        let lastYear = DetailPeriod.lastYear.dateInterval(now: now)
        let thisYear = DetailPeriod.thisYear.dateInterval(now: now)

        #expect(lastYear.contains(startOfThisYear) == false)
        #expect(thisYear.contains(startOfThisYear) == true)
    }
}
