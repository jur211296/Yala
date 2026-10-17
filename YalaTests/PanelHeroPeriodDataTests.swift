//
//  PanelHeroPeriodDataTests.swift
//  YalaTests
//
//  Tests puros del payload period-scoped del Hero. Cubre:
//   • La cifra del hero: balance con signo, o el lado que filtra la píldora (UX 2.2 · L3-1/L3-3).
//   • `spentVariation` (chip "vs período anterior" del hero en Solo Gastos):
//     % del gasto del período vs el previo comparable; nil sin previo o previo 0.
//

import Foundation
import Testing

@testable import Yala

struct PanelHeroPeriodDataTests {

    // MARK: - Cifra del hero (UX 2.2 · L3-1 y L3-3)

    /// Desde el lote 3 de la auditoría UX la cifra es el BALANCE y puede ser negativo: la línea «Entró − salió» de
    /// debajo tiene que cuadrar con ella. «Disponible» se quedaba en 0.
    @Test func balance_isSigned_whenExpenseExceedsIncome() {
        #expect(PanelHeroFigure.balance.value(income: 0, expense: 1250) == -1250)
    }

    @Test func balance_isIncomeMinusExpense_whenPositive() {
        #expect(PanelHeroFigure.balance.value(income: 4500, expense: 900) == 3600)
    }

    @Test func filteredFigure_countsWhatThePillFilters() {
        #expect(PanelHeroFigure.expense.value(income: 4500, expense: 900) == 900)
        #expect(PanelHeroFigure.income.value(income: 4500, expense: 900) == 4500)
    }

    @Test func figure_followsTheNatureFilter() {
        #expect(PanelHeroFigureLogic.figure(natures: []) == .balance)
        #expect(PanelHeroFigureLogic.figure(natures: [.income, .expense]) == .balance)
        #expect(PanelHeroFigureLogic.figure(natures: [.expense]) == .expense)
        #expect(PanelHeroFigureLogic.figure(natures: [.income]) == .income)
    }

    @Test func namedMonth_onlyForCalendarMonths() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Lima"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        let last = PanelHeroFigureLogic.namedMonth(for: .lastMonth, now: now, calendar: calendar)
        #expect(last.map { calendar.component(.month, from: $0) } == 9)
        #expect(PanelHeroFigureLogic.namedMonth(for: .thisMonth, now: now, calendar: calendar) == now)
        #expect(PanelHeroFigureLogic.namedMonth(for: .thisYear, now: now, calendar: calendar) == nil)
        #expect(PanelHeroFigureLogic.namedMonth(for: .allTime, now: now, calendar: calendar) == nil)
    }

    // MARK: - spentVariation (Solo Gastos)

    @Test func spentVariation_nil_whenNoPrevExpense() {
        let data = PanelHeroPeriodData(income: 0, expense: 1250, periodPrevExpense: nil)
        #expect(data.spentVariation == nil)
    }

    @Test func spentVariation_nil_whenPrevExpenseZero() {
        // calculateVariation devuelve nil si el previo es 0 → chip oculto.
        let data = PanelHeroPeriodData(income: 0, expense: 1250, periodPrevExpense: 0)
        #expect(data.spentVariation == nil)
    }

    @Test func spentVariation_positive_whenSpentMore() {
        let data = PanelHeroPeriodData(income: 0, expense: 1250, periodPrevExpense: 1000)
        #expect(data.spentVariation == 25)
    }

    @Test func spentVariation_negative_whenSpentLess() {
        let data = PanelHeroPeriodData(income: 0, expense: 800, periodPrevExpense: 1000)
        #expect(data.spentVariation == -20)
    }

    @Test func spentVariation_minus100_whenCurrentZeroWithPrev() {
        // Gastó 0 este período pero había gasto en el previo → -100% (honesto).
        let data = PanelHeroPeriodData(income: 0, expense: 0, periodPrevExpense: 500)
        #expect(data.spentVariation == -100)
    }
}
