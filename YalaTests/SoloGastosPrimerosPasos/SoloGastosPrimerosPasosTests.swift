//
//  SoloGastosPrimerosPasosTests.swift
//  YalaTests
//
//  «Solo gastos» tiene Primeros pasos (Jürgen, 19-nov-2026): los mismos siete pasos que «Ingresos y gastos». Hasta
//  entonces el Panel cambiaba el mazo por un botón suelto «Anotar el primer gasto» mientras durara la llegada, y el
//  mazo solo salía después del primer gasto, ya en el paso 3.
//

import Foundation
import Testing

@testable import Yala

@Suite("Solo gastos · Primeros pasos")
struct SoloGastosPrimerosPasosTests {

    /// Desde el 25-nov-2026 (Jürgen) Yala ya no crea la cuenta de gastos: el mazo arranca en el paso 1, 1 de 7, como con
    /// «Ingresos y gastos». Hasta entonces arrancaba en «Aprender a registrar», 2 de 7, con el paso 1 hecho por Yala.
    @Test func deck_startsAtTheFirstAccount_oneOfSeven() throws {
        let deck = try #require(SetupDeckLogic.deck(order: SetupStepID.deck, isResolved: { _ in false }))
        #expect(deck.current == .firstAccount)
        #expect(deck.position == 1)
        #expect(deck.total == 7)
        #expect(deck.upcoming == [.firstExpense, .firstBudget])
    }

    /// Los mismos siete pasos y en el mismo orden en los dos modos: cambiar de modo no mueve lo ya hecho. Los flujos de
    /// cada paso dicen «2 de 7», «6 de 7», «7 de 7»: un mazo de seis los contradiría.
    @Test func deck_isTheSameSevenStepsInBothModes() {
        #expect(SetupStepID.deck == [.firstAccount, .firstExpense, .firstBudget, .scheduledPayment, .groups,
                                     .whereMoneyGoes, .homeScreen])
    }
}

@Suite("Solo gastos · cableado (source-scan)")
struct SoloGastosPrimerosPasosWiringTests {

    private static func code(_ relativePath: String, file: StaticString = #filePath) throws -> String {
        let repoRoot = URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appending(path: relativePath), encoding: .utf8)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("//") && !$0.hasPrefix("///") }
            .joined(separator: "\n")
    }

    /// El Panel pinta el mazo en los dos modos: ya no hay rama de «Solo gastos» que lo cambie por un botón.
    @Test func panel_showsTheDeckInBothModes() throws {
        let panel = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(!panel.contains("SetupFirstExpenseAction"))
        #expect(!panel.contains("if isQuietArrival && sessionState.isExpensesOnlyMode"))
        #expect(panel.contains("private var setupDeckSlot: some View {\nSetupChecklistCard("))
        let progress = try Self.code("Yala/App/Views/Panel/SetupDeckProgress.swift")
        #expect(!progress.contains("struct SetupFirstExpenseAction"))
    }

    /// Ya no hay línea «Tus gastos van a…» ni cuenta de gastos que pasar a la lista (25-nov-2026): el paso 1 se hace de
    /// cero en los dos modos, y el Panel progresivo es el mismo (`PrimerosPasosPanelGate.make` ya no recibe el modo).
    @Test func panel_noLongerPassesAnExpensesAccount() throws {
        let panel = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(!panel.contains("expensesAccountName"))
        #expect(panel.contains("SetupChecklistManager.shared.panelGate()"))
        let card = try Self.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(!card.contains("expensesAccountName"))
        let progress = try Self.code("Yala/App/Views/Panel/SetupDeckProgress.swift")
        #expect(!progress.contains("firstExpenseNote"))
    }

    /// Ningún coach mark sale con Primeros pasos a medias, salvo la guía del paso 2.
    @Test func coachMarks_waitForTheDeck_exceptTheRecordStepGuide() throws {
        let overlay = try Self.code("Yala/App/Tips/CoachMarkOverlay.swift")
        #expect(overlay.contains("partOfPrimerosPasos || !SetupChecklistManager.shared.isPrimerosPasosShown {"))
        let guide = try Self.code("Yala/App/Views/Transactions/NewRecordTutorialGuide.swift")
        #expect(guide.contains("partOfPrimerosPasos: true,"))
    }
}
