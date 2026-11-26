//
//  PanelVueltaSinRecalcularTests.swift
//  YalaTests
//
//  El Panel al volver a primer plano (lote 1 de eficiencia): con su firma igual no vuelve a calcular, y con lo que sí
//  cambió —un guardado, `dataVersion`, o un recálculo que el freno cortó o descartó con la app fuera— sí. Antes la vuelta
//  llamaba a `reloadAndRecalculate()` siempre; ahora llama a `reloadOnAppearIfStale()` (`VueltaAPrimerPlano`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Volver sin recalcular · Panel", .serialized)
@MainActor
struct PanelVueltaSinRecalcularTests {

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel() throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    /// Carga inicial asentada: el Panel listo y sin nada en vuelo.
    private func settle(_ viewModel: PanelViewModel) async throws {
        viewModel.reloadAndRecalculate()
        for _ in 0..<100 where !viewModel.isReady {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(viewModel.isReady)
        try await Task.sleep(for: .milliseconds(250))
    }

    /// Irse y volver como hace la vista: freno puesto, freno suelto y la firma decide.
    private func goAwayAndComeBack(_ viewModel: PanelViewModel, whileAway: () throws -> Void = {}) async throws -> Int {
        let before = viewModel.debugCalculationRuns
        viewModel.setBackground(true)
        try whileAway()
        viewModel.setBackground(false)
        viewModel.reloadOnAppearIfStale()
        try await Task.sleep(for: .milliseconds(400))
        return viewModel.debugCalculationRuns - before
    }

    @Test func volverSinQueNadaCambie_noRecalcula() async throws {
        let (viewModel, _) = try makePanel()
        try await settle(viewModel)
        let runs = try await goAwayAndComeBack(viewModel)
        #expect(runs == 0, "volver sin cambios recalculó \(runs) veces")
    }

    @Test func unGuardadoMientrasEstabaFuera_recalcula() async throws {
        let (viewModel, context) = try makePanel()
        try await settle(viewModel)
        let runs = try await goAwayAndComeBack(viewModel) {
            let account = Account(name: "Nueva", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
            context.insert(account)
            try context.save()
        }
        #expect(runs >= 1, "un guardado con la app fuera no recalculó al volver")
    }

    @Test func dataVersionQueSubioFuera_recalcula() async throws {
        let (viewModel, _) = try makePanel()
        try await settle(viewModel)
        let runs = try await goAwayAndComeBack(viewModel) { session.dataVersion += 1 }
        #expect(runs >= 1)
    }

    @Test func unRecalculoDescartadoConLaAppFuera_seRehaceAlVolver() async throws {
        // Cambiar un filtro o llegar tasas con la app fuera no mueve la firma: lo apunta el freno.
        let (viewModel, _) = try makePanel()
        try await settle(viewModel)
        let runs = try await goAwayAndComeBack(viewModel) { viewModel.recalculateData() }
        #expect(viewModel.debugRecalculationWindowsOpened > 0)
        #expect(runs >= 1, "el recálculo pedido con la app fuera se perdió")
    }

    @Test func unRecalculoEnVueloCortadoAlIrse_seRehaceAlVolver() async throws {
        let (viewModel, _) = try makePanel()
        try await settle(viewModel)
        viewModel.recalculateData()
        // Sin esperar los 150 ms: el freno lo corta en su espera.
        let runs = try await goAwayAndComeBack(viewModel)
        #expect(runs >= 1, "el recálculo cortado por el freno no se rehízo")
    }

    @Test func elFrenoApuntaLoQueDescarta() {
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        #expect(!viewModel.hasInterruptedWork)
        viewModel.setBackground(true)
        viewModel.recalculateData()
        #expect(viewModel.hasInterruptedWork)
    }
}
