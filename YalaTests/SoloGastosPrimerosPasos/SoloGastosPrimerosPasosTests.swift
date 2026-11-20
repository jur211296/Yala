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

    /// Yala crea la cuenta de gastos, así que el paso 1 sale hecho y el mazo arranca en «Aprender a registrar», 2 de 7.
    @Test func deck_startsAtLearningToRecord_twoOfSeven() throws {
        let deck = try #require(SetupDeckLogic.deck(order: SetupStepID.deck, isResolved: { $0 == .firstAccount }))
        #expect(deck.current == .firstExpense)
        #expect(deck.position == 2)
        #expect(deck.total == 7)
        #expect(deck.upcoming == [.firstBudget, .scheduledPayment])
    }

    /// Los mismos siete pasos y en el mismo orden en los dos modos: cambiar de modo no mueve lo ya hecho. Los flujos de
    /// cada paso dicen «2 de 7», «6 de 7», «7 de 7»: un mazo de seis los contradiría.
    @Test func deck_isTheSameSevenStepsInBothModes() {
        #expect(SetupStepID.deck == [.firstAccount, .firstExpense, .firstBudget, .scheduledPayment, .groups,
                                     .whereMoneyGoes, .homeScreen])
    }

    /// En «Ver los 7 pasos» la línea del paso 1 dice a qué cuenta van los gastos; los demás pasos no cambian.
    @Test func stepsList_firstStepNamesTheExpensesAccount() {
        let detail = SetupStepsListLogic.detail(for: .firstAccount, expensesAccountName: "Gastos Soles")
        #expect(detail == L10n.SetupChecklist.Deck.firstExpenseNote("Gastos Soles"))
        #expect(detail?.contains("Gastos Soles") == true)
        for step in SetupStepID.deck where step != .firstAccount {
            #expect(SetupStepsListLogic.detail(for: step, expensesAccountName: "Gastos Soles") == nil)
        }
        // «Ingresos y gastos» (sin cuenta de gastos) o sin nombre: la línea de siempre.
        #expect(SetupStepsListLogic.detail(for: .firstAccount, expensesAccountName: nil) == nil)
        #expect(SetupStepsListLogic.detail(for: .firstAccount, expensesAccountName: "") == nil)
    }
}

@MainActor
@Suite("Solo gastos · cambiar de modo con pasos hechos")
struct SoloGastosCambioDeModoTests {

    /// Con el paso 1 hecho (la cuenta de gastos) y el 2 sin hacer: en «Solo gastos» la cuenta espera al paso 2; al pasar a
    /// «Ingresos y gastos» sale, porque ahí el paso 1 ya cuenta. Los pasos hechos no cambian.
    @Test func switchingModes_keepsTheStepsAndOnlyMovesTheAccount() {
        let soloGastos = PrimerosPasosPanelGate.make(deckInProgress: true, expensesOnly: true,
                                                     accountStepResolved: true, recordStepResolved: false,
                                                     planningShown: false)
        let completo = PrimerosPasosPanelGate.make(deckInProgress: true, expensesOnly: false,
                                                   accountStepResolved: true, recordStepResolved: false,
                                                   planningShown: false)
        #expect(!soloGastos.showsAccounts)
        #expect(completo.showsAccounts)
        #expect(soloGastos.showsLatestRecords == completo.showsLatestRecords)
    }

    /// Con el paso 2 hecho, los dos modos enseñan lo mismo.
    @Test func afterTheRecordStep_bothModesShowTheSame() {
        let soloGastos = PrimerosPasosPanelGate.make(deckInProgress: true, expensesOnly: true,
                                                     accountStepResolved: true, recordStepResolved: true,
                                                     planningShown: true)
        let completo = PrimerosPasosPanelGate.make(deckInProgress: true, expensesOnly: false,
                                                   accountStepResolved: true, recordStepResolved: true,
                                                   planningShown: true)
        #expect(soloGastos == completo)
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
        let sheet = try Self.code("Yala/App/Views/Panel/SetupStepsListSheet.swift")
        #expect(!sheet.contains("struct SetupFirstExpenseAction"))
    }

    /// La lista recibe la cuenta de gastos solo en «Solo gastos».
    @Test func panel_passesTheExpensesAccountOnlyInExpensesOnly() throws {
        let panel = try Self.code("Yala/App/Views/Panel/PanelView.swift")
        #expect(panel.contains("expensesAccountName: sessionState.isExpensesOnlyMode"))
        let card = try Self.code("Yala/App/Views/Panel/SetupChecklistCard.swift")
        #expect(card.contains("expensesAccountName: expensesAccountName)"))
    }

    /// Ningún coach mark sale con Primeros pasos a medias, salvo la guía del paso 2.
    @Test func coachMarks_waitForTheDeck_exceptTheRecordStepGuide() throws {
        let overlay = try Self.code("Yala/App/Tips/CoachMarkOverlay.swift")
        #expect(overlay.contains("partOfPrimerosPasos || !SetupChecklistManager.shared.isPrimerosPasosShown {"))
        let guide = try Self.code("Yala/App/Views/Transactions/NewRecordTutorialGuide.swift")
        #expect(guide.contains("partOfPrimerosPasos: true,"))
    }
}
