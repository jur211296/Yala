//
//  RecordsCalendarFoldTests.swift
//  YalaTests
//
//  Revisión 2.3 · Registros, decisiones 19 (C2) y 66 (iPad). Lógica pura, calendario gregoriano en UTC.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

struct RecordsCalendarFoldTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    /// Octubre de 2026 con la semana empezando en lunes: cinco filas, del 28 sep al 1 nov.
    private var october: [[Date]] {
        let month = calendar.dateInterval(of: .month, for: day(2026, 10, 15))!
        return RecordsCalendarLayout.weekRows(in: month, calendar: calendar)
    }

    // MARK: - C2: el mes se pliega a la semana del día elegido

    @Test func withoutADay_theWholeMonthStays() {
        #expect(october.count == 5)
        #expect(RecordsCalendarLayout.foldedWeeks(october, selectedDay: nil, calendar: calendar) == october)
    }

    @Test func choosingADay_leavesOnlyItsWeek() {
        let folded = RecordsCalendarLayout.foldedWeeks(october, selectedDay: day(2026, 10, 17), calendar: calendar)
        #expect(folded.count == 1)
        #expect(folded.first?.first == day(2026, 10, 12))
        #expect(folded.first?.last == day(2026, 10, 18))
    }

    /// El día elegido llega como `startOfDay`, pero una hora del día también cae en su semana.
    @Test func aTimeOfTheDay_findsTheSameWeek() {
        let folded = RecordsCalendarLayout.foldedWeeks(
            october, selectedDay: day(2026, 10, 18, hour: 23), calendar: calendar)
        #expect(folded.first?.first == day(2026, 10, 12))
    }

    /// La semana que cruza de mes (28 sep – 4 oct) se pliega entera.
    @Test func aWeekAcrossTwoMonths_foldsWhole() {
        let folded = RecordsCalendarLayout.foldedWeeks(october, selectedDay: day(2026, 10, 1), calendar: calendar)
        #expect(folded == [october[0]])
    }

    /// Un día fuera de las filas (otro mes) no pliega nada: el mes se queda entero.
    @Test func aDayOutsideTheRows_keepsTheMonth() {
        let folded = RecordsCalendarLayout.foldedWeeks(october, selectedDay: day(2026, 12, 3), calendar: calendar)
        #expect(folded == october)
    }

    // MARK: - 66: en el iPad la vista calendario monta la página en una columna

    @Test func iPadCalendar_mountsThePageCompact() {
        #expect(RecordsCalendarPageLogic.pageSizeClass(window: .regular, viewMode: .calendar) == .compact)
    }

    @Test func iPadList_keepsTheSplit() {
        #expect(RecordsCalendarPageLogic.pageSizeClass(window: .regular, viewMode: .list) == .regular)
    }

    @Test func iPhone_doesNotChange() {
        #expect(RecordsCalendarPageLogic.pageSizeClass(window: .compact, viewMode: .calendar) == .compact)
        #expect(RecordsCalendarPageLogic.pageSizeClass(window: .compact, viewMode: .list) == .compact)
        #expect(RecordsCalendarPageLogic.pageSizeClass(window: nil, viewMode: .calendar) == nil)
    }
}
