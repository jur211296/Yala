//
//  CashFlowAmountFromMonthViewModelTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · L18-8 en el ViewModel: «y los siguientes» no toca el método de la línea y retira el ajuste de ese
//  mes; cambiar el método («Cómo se calcula · Cambiar», L18-7) retira los cambios «desde este mes». Va en su propio
//  fichero: dos suites que piden `makeTestContext()` en el mismo fichero comparten store (regla de `testing.md`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - En el ViewModel

@Suite(.serialized)
@MainActor
struct CashFlowAmountFromMonthViewModelTests {

    private func monthKey(_ offset: Int) -> String {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        return CashFlowProjectionCalculator.monthKey(
            for: calendar.date(byAdding: .month, value: offset, to: start) ?? start, calendar: calendar
        )
    }

    private func makeViewModel() throws -> (CashFlowPlanViewModel, CashFlowLine, ModelContext) {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let line = CashFlowLine(name: "Salario", isIncome: true, estimationMethod: .average6m)
        context.insert(line)
        line.plan = plan
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        return (viewModel, line, context)
    }

    @Test func thisAndFollowing_keepsTheMethod_andStoresWhereItStarts() throws {
        let (viewModel, line, _) = try makeViewModel()

        viewModel.setAmountFromMonthOnward(line: line, monthKey: monthKey(1), amount: 9000)

        #expect(line.method == .average6m, "el método no cambia: los meses anteriores siguen con el suyo")
        #expect(line.manualAmount == nil)
        #expect(line.amountChanges == [.init(monthKey: monthKey(1), amount: 9000)])
    }

    @Test func thisAndFollowing_dropsTheOneMonthAdjustmentOfThatMonth_only() throws {
        let (viewModel, line, context) = try makeViewModel()
        viewModel.setOverride(line: line, monthKey: monthKey(1), amount: 111, note: "")
        viewModel.setOverride(line: line, monthKey: monthKey(3), amount: 333, note: "")

        viewModel.setAmountFromMonthOnward(line: line, monthKey: monthKey(1), amount: 9000)

        let overrides = try context.fetch(FetchDescriptor<CashFlowOverride>())
        #expect(overrides.map(\.monthKey) == [monthKey(3)], "el de ese mes taparía el cambio; el de después se queda")
    }

    @Test func changingTheMethod_dropsTheChanges() throws {
        let (viewModel, line, _) = try makeViewModel()
        viewModel.setAmountFromMonthOnward(line: line, monthKey: monthKey(1), amount: 9000)
        let before = viewModel.planRevision

        viewModel.changeEstimationMethod(line: line, to: .manual, manualAmount: 8700)

        #expect(line.method == .manual)
        #expect(line.manualAmount == 8700)
        #expect(line.amountChangesRaw == nil, "el método nuevo vale para todos los meses")
        #expect(viewModel.planRevision == before + 1, "el plan recalcula al cerrarse el selector")
    }

    @Test func changingTheMethod_toNonManual_keepsTheOldManualAmount() throws {
        let (viewModel, line, _) = try makeViewModel()
        line.manualAmount = 500
        viewModel.changeEstimationMethod(line: line, to: .average3m, manualAmount: nil)
        #expect(line.method == .average3m)
        #expect(line.manualAmount == 500)
    }

    /// Bug de la review: abrir «Cambiar» y guardar sin tocar nada retiraba los cambios «desde este mes».
    @Test func savingTheSameMethod_keepsTheChanges() throws {
        let (viewModel, line, _) = try makeViewModel()
        viewModel.setAmountFromMonthOnward(line: line, monthKey: monthKey(1), amount: 9000)
        let before = viewModel.planRevision

        viewModel.changeEstimationMethod(line: line, to: .average6m, manualAmount: nil)

        #expect(line.amountChanges == [.init(monthKey: monthKey(1), amount: 9000)], "no cambió nada")
        #expect(viewModel.planRevision == before)
    }

    @Test func savingTheSameFixedAmount_keepsTheChanges_aNewAmountDoesNot() throws {
        let (viewModel, line, _) = try makeViewModel()
        viewModel.changeEstimationMethod(line: line, to: .manual, manualAmount: 99.5)
        viewModel.setAmountFromMonthOnward(line: line, monthKey: monthKey(1), amount: 9000)

        viewModel.changeEstimationMethod(line: line, to: .manual, manualAmount: 99.5)
        #expect(!line.amountChanges.isEmpty, "mismo método y mismo monto: no es un cambio")

        viewModel.changeEstimationMethod(line: line, to: .manual, manualAmount: 120)
        #expect(line.manualAmount == 120)
        #expect(line.amountChanges.isEmpty, "un monto fijo nuevo vale para todos los meses")
    }
}
