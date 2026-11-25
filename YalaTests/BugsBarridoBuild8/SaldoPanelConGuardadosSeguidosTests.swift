//
//  SaldoPanelConGuardadosSeguidosTests.swift
//  YalaTests / BugsBarridoBuild8
//
//  Barrido de la build 8 (24-nov-2026): mientras la semilla pesada escribía, el Panel enseñaba todo menos el saldo grande,
//  que salió 46 s después de parar. El hero esperaba a su pase por tramos, y cada guardado lo corta (el aviso de cambio del
//  almacén, que lo protege de leer filas borradas) y lo vuelve a empezar. Medido en el iPhone 14 con `-uitest-seed pesado`.
//  Ahora, fuera de «Solo gastos», el saldo grande sale en cuanto el saldo está calculado (`PanelHeroFigureLogic.showsHero`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Barrido build 8 · cuándo sale el hero del Panel")
struct PanelHeroShowsTests {

    @Test func withTheBalanceCalculated_theHeroShows_evenWithoutItsPass() {
        #expect(PanelHeroFigureLogic.showsHero(hasHeroData: false, isExpensesOnlyMode: false, hasCalculatedBalance: true))
    }

    @Test func beforeAnything_itWaits() {
        #expect(!PanelHeroFigureLogic.showsHero(hasHeroData: false, isExpensesOnlyMode: false, hasCalculatedBalance: false))
    }

    /// En «Solo gastos» la cifra es el gasto del período, que sale del pase: sin él, nada que enseñar.
    @Test func inExpensesOnly_itWaitsForThePass() {
        #expect(!PanelHeroFigureLogic.showsHero(hasHeroData: false, isExpensesOnlyMode: true, hasCalculatedBalance: true))
        #expect(PanelHeroFigureLogic.showsHero(hasHeroData: true, isExpensesOnlyMode: true, hasCalculatedBalance: true))
    }

    @Test func wiring_theSectionAsksTheLogic_andTheBalanceRaisesTheMark() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let section = try String(
            contentsOf: root.appendingPathComponent("Yala/App/Views/Panel/Sections/PanelHeroSection.swift"), encoding: .utf8)
        #expect(section.contains("PanelHeroFigureLogic.showsHero("))
        #expect(section.contains("hasCalculatedBalance: viewModel.hasCalculatedBalance"))
        #expect(!section.contains("if let data = viewModel.heroWidget.data"))
        let viewModel = try String(
            contentsOf: root.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift"), encoding: .utf8)
        // La marca sube justo donde se asigna el saldo grande.
        #expect(viewModel.contains("""
                if self.panelTotalBalance != newBalance { self.panelTotalBalance = newBalance }
                if !self.hasCalculatedBalance { self.hasCalculatedBalance = true }
        """))
    }
}

@Suite("Barrido build 8 · el saldo del Panel sale con guardados seguidos", .serialized)
@MainActor
struct SaldoPanelConGuardadosSeguidosTests {

    private let session = SessionState()

    @Test func withSavesNonStop_theBigBalanceComesOut() async throws {
        let dir = CuelguesFixture.freshDir(); defer { discardTestStoreDirectory(dir) }
        let container = try CuelguesFixture.makeContainer(dir)
        try CuelguesFixture.seed(container, count: 4_000, now: .now, spacing: 1_800)
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        // Tramos de 10: el pase dura más que el hueco entre dos guardados, como con diez años en el iPhone.
        viewModel.heroSliceSize = 10
        viewModel.setContext(ModelContext(container), defaultCurrencyCode: "PEN", sessionState: session)
        viewModel.reloadAndRecalculate()

        // Otro contexto guarda cada 60 ms durante hasta 8 s, como la semilla o un import, y avisa al Panel como la app.
        let writer = ModelContext(container)
        writer.autosaveEnabled = false
        let account = try #require(try writer.fetch(FetchDescriptor<Account>()).first)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(8)
        var shown = false
        var i = 0
        while clock.now < deadline {
            i += 1
            writer.insert(TransactionItem(date: .now.addingTimeInterval(-Double(i) * 60), amount: -1, currencyCode: "PEN",
                                          category: nil, account: account,
                                          amountInPreferredCurrency: -1, preferredCurrencyCode: "PEN"))
            try writer.save()
            viewModel.reloadAndRecalculate()
            if PanelHeroFigureLogic.showsHero(
                hasHeroData: viewModel.heroWidget.data != nil,
                isExpensesOnlyMode: false,
                hasCalculatedBalance: viewModel.hasCalculatedBalance
            ) {
                shown = true
                break
            }
            try await Task.sleep(for: .milliseconds(60))
        }
        #expect(shown, "el saldo grande no salió mientras llegaban guardados (\(i) guardados)")
    }
}
