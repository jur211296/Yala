//
//  BudgetAtLimitLabelTests.swift
//  YalaTests
//
//  «En el límite» junto a la barra naranja (decisión de Jürgen, 2026-11-05): cuándo se enseña, y que la fila y el
//  detalle del presupuesto la pintan.
//

import Foundation
import Testing

@testable import Yala

struct BudgetAtLimitLabelTests {

    // MARK: - Cuándo se enseña: el umbral de `BudgetStatusCounter`, no otro

    @Test func justBelow80_hidesTheWord() {
        #expect(!BudgetAtLimitLabel.isShown(spent: 79.99, limit: 100))
    }

    @Test func at80_showsTheWord() {
        #expect(BudgetAtLimitLabel.isShown(spent: 80, limit: 100))
    }

    @Test func justBelow100_showsTheWord() {
        #expect(BudgetAtLimitLabel.isShown(spent: 99.99, limit: 100))
    }

    /// Pasado el límite ya lo dicen el rosa y el triángulo: «en el límite» sería falso.
    @Test func at100_hidesTheWord() {
        #expect(!BudgetAtLimitLabel.isShown(spent: 100, limit: 100))
        #expect(!BudgetAtLimitLabel.isShown(spent: 250, limit: 100))
    }

    @Test func zeroLimit_hidesTheWord() {
        #expect(!BudgetAtLimitLabel.isShown(spent: 50, limit: 0))
    }

    /// Escala real, no solo límite 100: 1.440 de 1.800 es el 80 %.
    @Test func realAmounts_followThePercentage() {
        #expect(BudgetAtLimitLabel.isShown(spent: 1_440, limit: 1_800))
        #expect(!BudgetAtLimitLabel.isShown(spent: 1_439, limit: 1_800))
    }

    @Test func agreesWithTheCounterEverywhere() {
        for spent in stride(from: 0.0, through: 130.0, by: 0.5) {
            let counter = BudgetStatusCounter.classify(spent: spent, limit: 100)
            #expect(BudgetAtLimitLabel.isShown(spent: spent, limit: 100) == (counter == .atLimit), "spent \(spent)")
        }
    }

    // MARK: - Cableado: la fila y el detalle la pintan (source-scan)

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test func budgetRow_showsTheLabel_andVoiceOverSaysIt() throws {
        let row = try source("Yala/App/Views/Planning/BudgetRowView.swift")
        #expect(row.contains("BudgetAtLimitLabel.isShown(spent: summary.spent, limit: summary.budget.limitAmount)"))
        #expect(row.contains("BudgetAtLimitLabel()"))
        #expect(row.contains(".accessibilityLabel(accessibilityLabelText)"))
        // Desde el lote 04 de mejoras necesarias 2.3 la etiqueta junta partes (lo que queda, los días): «En el límite»
        // sigue entrando cuando toca.
        #expect(row.contains("if isAtLimit { parts.append(L10n.UXL9.atLimit) }"))
    }

    @Test func budgetDetail_showsTheLabel() throws {
        let detail = try source("Yala/App/Views/Planning/BudgetDetailView.swift")
        #expect(detail.contains("if BudgetAtLimitLabel.isShown(spent: summary.spent, limit: budget.limitAmount) {"))
        #expect(detail.contains("BudgetAtLimitLabel(font: DS.Typography.label)"))
    }

    @Test func label_readsTheLocalizedWord() throws {
        let label = try source("Yala/App/Views/Planning/Components/BudgetAtLimitLabel.swift")
        #expect(label.contains("Text(L10n.UXL9.atLimit)"))
        #expect(label.contains("BudgetStatusCounter.classify(spent: spent, limit: limit) == .atLimit"))
    }
}
