//
//  PanelHeroPeriodDataTests.swift
//  YalaTests
//
//  Tests puros del payload period-scoped del Hero. Cubre:
//   • `available` = max(0, income - expense) — floor en 0 (modo normal).
//   • `spentVariation` (chip "vs período anterior" del hero en Solo Gastos):
//     % del gasto del período vs el previo comparable; nil sin previo o previo 0.
//

import Foundation
import Testing

@testable import Yala

struct PanelHeroPeriodDataTests {

    // MARK: - available (modo normal)

    @Test func available_floorsAtZero_whenExpenseExceedsIncome() {
        let data = PanelHeroPeriodData(income: 0, expense: 1250)
        #expect(data.available == 0)
    }

    @Test func available_isIncomeMinusExpense_whenPositive() {
        let data = PanelHeroPeriodData(income: 4500, expense: 900)
        #expect(data.available == 3600)
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
