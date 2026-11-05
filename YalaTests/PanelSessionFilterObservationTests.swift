//
//  PanelSessionFilterObservationTests.swift
//  YalaTests
//
//  Lote P3 de 2.3 · ticket `panel-stayed-filtered-after-removing-the-account-chip`.
//
//  Los filtros de sesión recalculan el Panel desde el ViewModel (`PanelViewModel.observeSessionFilters`), no desde un
//  `onChange` de la vista: tras volver a primer plano SwiftUI dejaba de reevaluar ese modificador cuando cambiaba solo
//  el filtro de cuentas, y quitar el chip no recalculaba (medido en el simulador, 3 de 7 corridas de 10 rondas). Lo que
//  esto fija es que el ViewModel se entera solo, sin vista: con el código de antes no se enteraba nunca.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Panel · los filtros de sesión recalculan desde el ViewModel", .serialized)
struct PanelSessionFilterObservationTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel() throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    private func waitForRuns(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<100 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Deja pasar la espera de 150 ms con margen, para afirmar que NO hubo cálculo.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(400))
    }

    private func loaded(_ viewModel: PanelViewModel) async throws -> Int {
        let before = viewModel.debugCalculationRuns
        viewModel.reloadAndRecalculate()
        try await waitForRuns(viewModel, reaching: before + 1)
        return viewModel.debugCalculationRuns
    }

    @Test("Filtrar por una cuenta y quitar el filtro recalculan, cada vez")
    func accountFilter_onAndOff_recalculatesEachTime() async throws {
        let (viewModel, context) = try makePanel()
        let account = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(account)
        try context.save()
        var runs = try await loaded(viewModel)
        defer { session.selectedAccountIDs = [] }

        for round in 0..<3 {
            session.selectedAccountIDs = [account.persistentModelID]
            try await waitForRuns(viewModel, reaching: runs + 1)
            #expect(viewModel.debugCalculationRuns == runs + 1, "ronda \(round): filtrar no recalculó")
            runs = viewModel.debugCalculationRuns

            session.selectedAccountIDs = []
            try await waitForRuns(viewModel, reaching: runs + 1)
            #expect(viewModel.debugCalculationRuns == runs + 1, "ronda \(round): quitar el filtro no recalculó")
            runs = viewModel.debugCalculationRuns
        }
    }

    @Test("Control: escribir el mismo valor no recalcula")
    func sameValueWrite_doesNotRecalculate() async throws {
        let (viewModel, _) = try makePanel()
        let runs = try await loaded(viewModel)
        session.selectedAccountIDs = []
        session.searchText = session.searchText
        try await settle()
        #expect(viewModel.debugCalculationRuns == runs)
    }

    @Test("Elegir solo categorías de gasto deja la naturaleza en gastos")
    func expenseCategoryOnly_setsExpenseNature() async throws {
        let (viewModel, context) = try makePanel()
        let category = Category(name: "Comida", colorHex: "#64748B", isIncome: false)
        context.insert(category)
        try context.save()
        _ = try await loaded(viewModel)   // carga las categorías
        defer {
            session.selectedCategoryIDs = []
            session.selectedTransactionNatures = []
        }
        session.selectedTransactionNatures = []

        session.selectedCategoryIDs = [category.persistentModelID]
        for _ in 0..<50 where session.selectedTransactionNatures != [.expense] {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(session.selectedTransactionNatures == [.expense])
    }
}
