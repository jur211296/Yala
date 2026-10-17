//
//  CashFlowPlanRevisionTests.swift
//  YalaTests
//
//  Lote 18 de la auditoría UX 2.2: borrar una línea desde su menú y guardar el horizonte cambian el plan sin
//  ninguna hoja que recalcule al cerrarse, así que la proyección se quedaba vieja (la línea borrada seguía en
//  pantalla y el horizonte no se aplicaba). El VM sube `planRevision` y `CashFlowTableView` recalcula con él.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct CashFlowPlanRevisionTests {

    private func makePlannedViewModel() throws -> (CashFlowPlanViewModel, CashFlowLine, ModelContext) {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let line = CashFlowLine(name: "Gimnasio", estimationMethod: .manual, manualAmount: 150)
        context.insert(line)
        line.plan = plan
        try context.save()

        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        return (viewModel, line, context)
    }

    @Test func removingALine_bumpsThePlanRevision() throws {
        let (viewModel, line, context) = try makePlannedViewModel()
        let before = viewModel.planRevision

        viewModel.removeLine(line)

        #expect(viewModel.planRevision == before + 1)
        let remaining = try context.fetch(FetchDescriptor<CashFlowLine>())
        #expect(remaining.isEmpty)
    }

    @Test func savingTheHorizon_bumpsThePlanRevision() throws {
        let (viewModel, _, _) = try makePlannedViewModel()
        let before = viewModel.planRevision

        viewModel.updateHorizon(monthsAhead: 3, monthsBack: 1, showAccumulatedBalance: true)

        #expect(viewModel.planRevision == before + 1)
        #expect(viewModel.plan?.defaultMonthsAhead == 3)
    }

    /// Control: lo que ya recalcula por su hoja (el saldo inicial) no sube la señal, o el plan recalcularía dos veces.
    @Test func editingTheStartingBalance_doesNotBumpThePlanRevision() throws {
        let (viewModel, _, _) = try makePlannedViewModel()
        let before = viewModel.planRevision

        viewModel.updateStartingBalance(500)

        #expect(viewModel.planRevision == before)
    }
}
