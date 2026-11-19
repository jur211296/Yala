//
//  ComparisonChangeTests.swift
//  YalaTests
//
//  La marca de cambio de la Comparativa de Reportes (pedido de Jürgen del 17-nov): qué dirección, si es buena o mala
//  según sea ingreso o gasto, los casos sin dato anterior o sin cambio, el porcentaje y lo que lee VoiceOver.
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

@Suite("Comparativa simple · la marca de cambio")
struct ComparisonChangeTests {

    // MARK: - Bueno o malo

    @Test func moreIncome_isGood() {
        #expect(ComparisonChange.make(variation: 16.1, hasPrevious: true, currentAmount: 9872, isExpense: false)
            == .up(percent: 16.1, isGood: true))
    }

    @Test func lessIncome_isBad() {
        #expect(ComparisonChange.make(variation: -20, hasPrevious: true, currentAmount: 800, isExpense: false)
            == .down(percent: 20, isGood: false))
    }

    /// El cambio de un gasto se calcula sobre los valores absolutos: positivo es «gastaste más», y eso es malo.
    @Test func moreSpending_isBad() {
        #expect(ComparisonChange.make(variation: 27, hasPrevious: true, currentAmount: -12642, isExpense: true)
            == .up(percent: 27, isGood: false))
    }

    @Test func lessSpending_isGood() {
        #expect(ComparisonChange.make(variation: -3.3, hasPrevious: true, currentAmount: -7206, isExpense: true)
            == .down(percent: 3.3, isGood: true))
    }

    /// «Te quedó»: más que antes es verde, menos es rosa.
    @Test func whatWasLeft_followsIncome() {
        #expect(ComparisonChange.make(variation: 154, hasPrevious: true, currentAmount: 2666, isExpense: false).isGood == true)
        #expect(ComparisonChange.make(variation: -50, hasPrevious: true, currentAmount: 500, isExpense: false).isGood == false)
    }

    // MARK: - Casos borde

    /// Sin nada en el período anterior (Mascotas el primer mes): «nuevo», nunca un % infinito.
    @Test func noPrevious_isNew() {
        let change = ComparisonChange.make(variation: nil, hasPrevious: false, currentAmount: -101, isExpense: true)
        #expect(change == .new)
        #expect(change.isGood == nil)
        #expect(change.arrowSymbol == nil)
    }

    /// Hubo movimientos antes pero sumaron cero (una devolución que anuló el gasto): no hay % que dar.
    @Test func previousSummedToZero_isNew() {
        #expect(ComparisonChange.make(variation: nil, hasPrevious: true, currentAmount: 50, isExpense: true) == .new)
    }

    @Test func nothingBeforeNorNow_isEmpty() {
        let change = ComparisonChange.make(variation: nil, hasPrevious: false, currentAmount: 0, isExpense: true)
        #expect(change == .empty)
        #expect(change.text() == "—")
    }

    @Test func infiniteVariation_isNew() {
        #expect(ComparisonChange.make(variation: .infinity, hasPrevious: true, currentAmount: 10, isExpense: false) == .new)
    }

    @Test(arguments: [0.0, 0.04, -0.04])
    func zero_isSame_andNeutral(_ variation: Double) {
        let change = ComparisonChange.make(variation: variation, hasPrevious: true, currentAmount: 180, isExpense: true)
        #expect(change == .same)
        #expect(change.isGood == nil)
    }

    /// Por debajo del 1 % la flecha sale, pero en gris: ni bueno ni malo.
    @Test func underOnePercent_isMinor_andNeutral() {
        let up = ComparisonChange.make(variation: 0.6, hasPrevious: true, currentAmount: 100, isExpense: true)
        let down = ComparisonChange.make(variation: -0.9, hasPrevious: true, currentAmount: 100, isExpense: false)
        #expect(up == .minorUp(percent: 0.6))
        #expect(down == .minorDown(percent: 0.9))
        #expect(up.isGood == nil && down.isGood == nil)
        #expect(up.arrowSymbol == "arrow.up" && down.arrowSymbol == "arrow.down")
    }

    /// Justo en el umbral ya cuenta como cambio, con su color.
    @Test func atOnePercent_hasColor() {
        #expect(ComparisonChange.make(variation: 1, hasPrevious: true, currentAmount: 100, isExpense: true)
            == .up(percent: 1, isGood: false))
    }

    // MARK: - El porcentaje

    @Test func percent_withoutSign_andRounded() {
        let en = Locale(identifier: "en_US")
        #expect(ComparisonChange.percentText(27.4, locale: en) == "27%")
        #expect(ComparisonChange.percentText(140.7, locale: en) == "141%")
        #expect(ComparisonChange.percentText(3.33, locale: en) == "3.3%")
        #expect(ComparisonChange.percentText(0.6, locale: en) == "0.6%")
    }

    @Test func percent_overNineHundredNinetyNine_isCapped() {
        #expect(ComparisonChange.percentText(4200, locale: Locale(identifier: "en_US")) == "> 999%")
    }

    @Test func percent_followsTheLocale() {
        let text = ComparisonChange.percentText(3.25, locale: Locale(identifier: "de_DE"))
        #expect(text.contains("3,2") || text.contains("3,3"))
        #expect(text.contains("%"))
    }

    // MARK: - VoiceOver

    @Test func voiceOver_saysDirectionAndPeriod() {
        let versus = ComparativaSimpleText.versus("octubre", isDayRange: false)
        let spoken = ComparisonChange.up(percent: 27, isGood: false).accessibilityText(versus: versus)
        #expect(spoken.contains("27"))
        #expect(spoken.contains("octubre"))
        #expect(!spoken.hasPrefix("comparativaSimple."))
        let down = ComparisonChange.down(percent: 3.3, isGood: true).accessibilityText(versus: versus)
        #expect(down != spoken)
        #expect(!down.hasPrefix("comparativaSimple."))
    }

    @Test func voiceOver_newAndSame_haveWords() {
        let versus = ComparativaSimpleText.versus("octubre", isDayRange: false)
        #expect(!ComparisonChange.new.accessibilityText(versus: versus).hasPrefix("comparativaSimple."))
        #expect(ComparisonChange.same.accessibilityText(versus: versus).contains("octubre"))
        #expect(!ComparisonChange.empty.accessibilityText(versus: versus).hasPrefix("comparativaSimple."))
    }

    // MARK: - Texto grande

    /// Desde XXL la fila se apila; hasta XL, la tabla.
    @Test func rowStacks_fromXXL() {
        #expect(!PivotColumnWidths.stacks(.large))
        #expect(!PivotColumnWidths.stacks(.xLarge))
        #expect(PivotColumnWidths.stacks(.xxLarge))
        #expect(PivotColumnWidths.stacks(.accessibility1))
    }
}
