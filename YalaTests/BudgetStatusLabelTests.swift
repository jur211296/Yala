//
//  BudgetStatusLabelTests.swift
//  YalaTests
//
//  Un estado, una palabra, un color (decisión 23 de la revisión 2.3, Jürgen 2026-11-09): qué palabra lleva cada estado,
//  de qué color, y que la fila, el detalle, la barra y el historial leen el mismo estado. Hasta 2.3 era
//  `BudgetAtLimitLabelTests` y solo cubría «En el límite» (decisión del 2026-11-05).
//

import Foundation
import SwiftUI
import Testing

@testable import Yala

struct BudgetStatusLabelTests {

    private func word(spent: Double, limit: Double = 100) -> String? {
        BudgetStatusLabel.word(for: BudgetStatusCounter.classify(spent: spent, limit: limit))
    }

    // MARK: - Una palabra por estado

    @Test func below80_hasNoWord() {
        #expect(word(spent: 0) == nil)
        #expect(word(spent: 79.99) == nil)
    }

    @Test func from80to99_saysAtLimit() {
        #expect(word(spent: 80) == L10n.UXL9.atLimit)
        #expect(word(spent: 99.99) == L10n.UXL9.atLimit)
        // Escala real: 1.440 de 1.800 es el 80 %.
        #expect(word(spent: 1_440, limit: 1_800) == L10n.UXL9.atLimit)
        #expect(word(spent: 1_439, limit: 1_800) == nil)
    }

    /// El 100 % justo es «Llegaste al límite»: no se pasó. Con la regla de antes no salía ninguna palabra y la fila se
    /// iba a «Excedidos» con «Te quedan S/ 0.00».
    @Test func exactly100_saysReachedLimit() {
        #expect(word(spent: 100) == L10n.UXL9.reachedLimit)
        #expect(word(spent: 1_000, limit: 1_000) == L10n.UXL9.reachedLimit)
    }

    @Test func above100_saysWentOver() {
        #expect(word(spent: 100.01) == L10n.UXL9.overLimitWord)
        #expect(word(spent: 1_180, limit: 1_000) == L10n.UXL9.overLimitWord)
    }

    @Test func zeroLimit_hasNoWord() {
        #expect(word(spent: 50, limit: 0) == nil)
    }

    /// Las tres palabras son distintas, y «Te pasaste» no es la cifra («Te pasaste por»).
    @Test func theThreeWords_areDistinct() {
        let words = [L10n.UXL9.atLimit, L10n.UXL9.reachedLimit, L10n.UXL9.overLimitWord]
        #expect(Set(words).count == 3)
        #expect(!words.contains(L10n.UXL9.overLabel))
    }

    // MARK: - Un color: naranja de aviso, rosa solo al pasarse

    @Test func color_isWarningUntilYouGoOver() {
        #expect(BudgetStatusLabel.color(for: .atLimit) == DS.Semantic.warningForeground)
        #expect(BudgetStatusLabel.color(for: .reachedLimit) == DS.Semantic.warningForeground)
        #expect(BudgetStatusLabel.color(for: .overLimit) == Color.overBudgetText)
    }

    /// La barra es rosa solo con `.overLimit` y naranja desde el 80 %; en ningún punto contradice a la palabra.
    @MainActor @Test func barAndWord_agreeForEveryPercent() {
        for tenths in 0...1_500 {
            let spent = Double(tenths) / 10
            let status = BudgetStatusCounter.classify(spent: spent, limit: 100)
            let barIsPink = status == .overLimit
            let barIsWarning = !barIsPink && BudgetStatusCounter.isAtOrPastLimit(percent: spent)
            #expect(barIsWarning == BudgetStatusCounter.isWarning(status), "Barra y palabra no coinciden al \(spent) %")
        }
    }

    // MARK: - El historial usa el mismo estado

    @Test func historyBar_followsTheStatus() {
        #expect(BudgetChartsView.historyBarColor(spent: 50, limit: 100) == Color.budgetBarNeutral)
        #expect(BudgetChartsView.historyBarColor(spent: 90, limit: 100) == DS.Semantic.warningForeground)
        #expect(BudgetChartsView.historyBarColor(spent: 100, limit: 100) == DS.Semantic.warningForeground)
        #expect(BudgetChartsView.historyBarColor(spent: 118, limit: 100) == Color.hotPink)
    }

    // MARK: - Cableado: la fila y el detalle pintan barra y palabra del mismo estado (source-scan)

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test func budgetRow_paintsBarAndWordFromOneStatus_andVoiceOverSaysIt() throws {
        let row = try source("Yala/App/Views/Planning/BudgetRowView.swift")
        #expect(row.contains("BudgetStatusCounter.classify(spent: summary.spent, limit: summary.budget.limitAmount)"))
        #expect(row.contains("isExceeded: budgetStatus == .overLimit,"))
        #expect(row.contains("BudgetStatusLabel(status: budgetStatus)"))
        #expect(row.contains("if let word = BudgetStatusLabel.word(for: budgetStatus) { parts.append(word) }"))
    }

    @Test func budgetDetail_paintsBarAndWordFromOneStatus() throws {
        let detail = try source("Yala/App/Views/Planning/BudgetDetailView.swift")
        #expect(detail.contains("let status = BudgetStatusCounter.classify(spent: summary.spent, limit: budget.limitAmount)"))
        #expect(detail.contains("isExceeded: status == .overLimit"))
        #expect(detail.contains("BudgetStatusLabel(status: status, font: DS.Typography.label)"))
    }
}
