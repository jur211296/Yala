//
//  PanelEarlyMonthAndAccountsGridTests.swift
//  YalaTests
//
//  Decisión 10 de la revisión 2.3 (PN-3): los días 1 y 2 de «Este mes» el hero dice «Día N de 31» con dos atajos y los
//  porcentajes contra el período anterior se ocultan; desde el día 3, como siempre. El período manda: en cualquier otro
//  período no cambia nada.
//  Decisión 12 (PN-5, solo D): en ventana ancha las cuentas van en cuadrícula de dos columnas si caben; el iPhone y una
//  columna estrecha siguen con el carrusel.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct PanelEarlyMonthLogicTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test("Día 1 de diciembre: «Día 1 de 31» y sin porcentajes")
    func day1_showsTheLineAndHidesVariations() {
        let start = PanelEarlyMonthLogic.monthStart(period: .thisMonth, now: date(2026, 12, 1), calendar: cal)
        #expect(start == .init(day: 1, daysInMonth: 31))
        #expect(PanelEarlyMonthLogic.hidesVariations(period: .thisMonth, now: date(2026, 12, 1), calendar: cal))
    }

    @Test("Día 2 todavía; el día 3 vuelve todo")
    func day2_stillEarly_day3_back() {
        #expect(PanelEarlyMonthLogic.monthStart(period: .thisMonth, now: date(2027, 2, 2), calendar: cal)
                == .init(day: 2, daysInMonth: 28))
        #expect(PanelEarlyMonthLogic.monthStart(period: .thisMonth, now: date(2026, 12, 3, hour: 0), calendar: cal) == nil)
        #expect(!PanelEarlyMonthLogic.hidesVariations(period: .thisMonth, now: date(2026, 12, 3), calendar: cal))
    }

    @Test("El período manda: con otro período elegido, el día 1 no cambia nada", arguments: [
        DetailPeriod.last30Days, .lastMonth, .thisWeek, .thisYear, .allTime,
    ])
    func otherPeriods_neverChange(period: DetailPeriod) {
        #expect(PanelEarlyMonthLogic.monthStart(period: period, now: date(2026, 12, 1), calendar: cal) == nil)
        #expect(!PanelEarlyMonthLogic.hidesVariations(period: period, now: date(2026, 12, 1), calendar: cal))
    }

    @Test("El atajo nombra el mes anterior, también al cambiar de año")
    func previousMonthName() {
        let es = Locale(identifier: "es_PE")
        #expect(PanelEarlyMonthLogic.previousMonthName(now: date(2026, 12, 1), calendar: cal, locale: es) == "noviembre")
        // En enero el mes anterior es del año pasado: lleva el año, como en la Comparativa.
        #expect(PanelEarlyMonthLogic.previousMonthName(now: date(2027, 1, 2), calendar: cal, locale: es).hasPrefix("diciembre"))
        #expect(PanelEarlyMonthLogic.previousMonthName(now: date(2027, 1, 2), calendar: cal, locale: es).contains("2026"))
        let en = Locale(identifier: "en_US")
        #expect(PanelEarlyMonthLogic.previousMonthName(now: date(2026, 12, 1), calendar: cal, locale: en) == "November")
    }
}

struct PanelAccountsGridLogicTests {

    @Test("iPad Pro 13 en vertical: la columna de «Tus finanzas» cabe dos tarjetas → cuadrícula")
    func wideAndRoomy_usesGrid() {
        #expect(PanelAccountCardLogic.usesGrid(
            isWideScreen: true, isAccessibilityText: false, containerWidth: 490, spacing: 16))
    }

    @Test("El iPhone sigue con el carrusel, aunque mida lo mismo")
    func compact_keepsTheCarousel() {
        #expect(!PanelAccountCardLogic.usesGrid(
            isWideScreen: false, isAccessibilityText: false, containerWidth: 490, spacing: 16))
    }

    @Test("Columna estrecha (iPad mini en vertical) o texto de accesibilidad: carrusel")
    func narrowOrAccessibility_keepsTheCarousel() {
        #expect(!PanelAccountCardLogic.usesGrid(
            isWideScreen: true, isAccessibilityText: false, containerWidth: 344, spacing: 16))
        #expect(!PanelAccountCardLogic.usesGrid(
            isWideScreen: true, isAccessibilityText: true, containerWidth: 490, spacing: 16))
    }

    @Test("De dos en dos, nunca tres; un impar se queda solo a la izquierda")
    func gridRows_pairs() {
        #expect(PanelAccountCardLogic.gridRows(cardCount: 5) == [[0, 1], [2, 3], [4]])
        #expect(PanelAccountCardLogic.gridRows(cardCount: 4) == [[0, 1], [2, 3]])
        #expect(PanelAccountCardLogic.gridRows(cardCount: 1) == [[0]])
    }
}
