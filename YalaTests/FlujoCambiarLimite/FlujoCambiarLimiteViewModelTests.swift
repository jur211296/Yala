//
//  FlujoCambiarLimiteViewModelTests.swift
//  YalaTests
//
//  S4 del replanteo: lo que `CashFlowPlanViewModel.cambiarLimite` deja escrito en la línea con cada alcance, y que el
//  cálculo del plan (`resolvePlanned`) lee el mismo número que enseñó la hoja. Fichero propio: pide `makeTestContext()`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Flujo de caja · cambiar límite · escritura", .serialized)
@MainActor
struct FlujoCambiarLimiteViewModelTests {

    private func monthKey(_ offset: Int) -> String {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        return CashFlowProjectionCalculator.monthKey(
            for: calendar.date(byAdding: .month, value: offset, to: start) ?? start, calendar: calendar
        )
    }

    /// Una línea de gasto con monto fijo 900, un ajuste de un mes en +2 (1500) y un cambio «desde» en -2 (700).
    private func escenario() throws -> (CashFlowPlanViewModel, CashFlowLine, ModelContext) {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "", startingBalance: 0)
        context.insert(plan)
        let line = CashFlowLine(name: "Comida", isIncome: false, estimationMethod: .manual)
        line.manualAmount = 900
        context.insert(line)
        line.plan = plan
        line.amountChangesRaw = CashFlowAmountChangeLogic.encode([.init(monthKey: monthKey(-2), amount: 700)])
        try context.save()
        let viewModel = CashFlowPlanViewModel()
        viewModel.setContext(context)
        viewModel.setOverride(line: line, monthKey: monthKey(2), amount: 1500, note: "")
        return (viewModel, line, context)
    }

    /// El límite de `line` en el mes, con la precedencia del cálculo (ajuste › cambio «desde» › monto fijo).
    private func limite(_ line: CashFlowLine, _ offset: Int) -> Double? {
        let key = monthKey(offset)
        if let ajuste = line.monthOverride(for: key) { return ajuste.amount }
        if let cambio = CashFlowAmountChangeLogic.change(for: key, in: line.amountChanges) { return cambio.amount }
        return line.method == .manual ? line.manualAmount : nil
    }

    @Test func soloEsteMes_cambiaEseMes_yNadaMas() throws {
        let (viewModel, line, _) = try escenario()

        #expect(viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: 0, alcance: .soloEsteMes))

        #expect(limite(line, 0) == 0, "admite 0")
        #expect(limite(line, 1) == 700, "los siguientes siguen con lo que tenían")
        #expect(limite(line, 2) == 1500)
        #expect(limite(line, -3) == 900)
    }

    @Test func desdeEsteMes_cambiaLosSiguientes_menosLosQueTienenAjuste_yNoElPasado() throws {
        let (viewModel, line, _) = try escenario()

        #expect(viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: 1000, alcance: .desdeEsteMes))

        #expect(limite(line, 0) == 1000)
        #expect(limite(line, 1) == 1000)
        #expect(limite(line, 2) == 1500, "el ajuste propio se queda")
        #expect(limite(line, 3) == 1000)
        #expect(limite(line, -1) == 700, "el pasado no cambia")
        #expect(limite(line, -3) == 900)
        #expect(line.method == .manual && line.manualAmount == 900, "el método no cambia")
    }

    @Test func desdeEsteMes_retiraElAjusteDeEseMismoMes() throws {
        let (viewModel, line, context) = try escenario()

        #expect(viewModel.cambiarLimite(line: line, monthKey: monthKey(2), amount: 1000, alcance: .desdeEsteMes))

        #expect(limite(line, 2) == 1000, "el ajuste de ese mes taparía el cambio")
        #expect(try context.fetch(FetchDescriptor<CashFlowOverride>()).isEmpty)
    }

    @Test func todos_dejaElMismoMontoEnCadaMes() throws {
        let (viewModel, line, context) = try escenario()

        #expect(viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: 1000, alcance: .todos))

        for offset in -4...4 {
            #expect(limite(line, offset) == 1000, "mes \(offset)")
        }
        #expect(line.amountChangesRaw == nil)
        #expect(try context.fetch(FetchDescriptor<CashFlowOverride>()).isEmpty)
    }

    @Test func unMesPasado_soloEseMes() throws {
        let (viewModel, line, _) = try escenario()

        #expect(viewModel.cambiarLimite(line: line, monthKey: monthKey(-1), amount: 400, alcance: .soloEsteMes))

        #expect(limite(line, -1) == 400)
        #expect(limite(line, -2) == 700)
        #expect(limite(line, 0) == 700)
    }

    @Test func soloEsteMes_dosVeces_dejaUnSoloAjuste() throws {
        let (viewModel, line, context) = try escenario()

        viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: 100, alcance: .soloEsteMes)
        viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: 200, alcance: .soloEsteMes)

        let ajustes = try context.fetch(FetchDescriptor<CashFlowOverride>()).filter { $0.monthKey == monthKey(0) }
        #expect(ajustes.count == 1)
        #expect(limite(line, 0) == 200)
    }

    @Test func montoNegativo_noEscribeNada() throws {
        let (viewModel, line, _) = try escenario()
        let antes = line.amountChangesRaw

        #expect(!viewModel.cambiarLimite(line: line, monthKey: monthKey(0), amount: -1, alcance: .todos))

        #expect(line.amountChangesRaw == antes)
        #expect(line.manualAmount == 900)
    }

    @Test func todos_enUnPagoPlanificado_noLoPasaAMontoFijo() throws {
        let (viewModel, line, context) = try escenario()
        line.estimationMethod = EstimationMethod.scheduled.rawValue
        try context.save()

        #expect(viewModel.cambiarLimite(
            line: line, monthKey: monthKey(0), amount: 50, alcance: .todos, primerMes: monthKey(-3)))

        #expect(line.method == .scheduled, "sigue ligada a su pago")
        #expect(line.amountChanges == [.init(monthKey: monthKey(-3), amount: 50)])
        #expect(try context.fetch(FetchDescriptor<CashFlowOverride>()).isEmpty)
        for offset in -3...4 {
            #expect(CashFlowAmountChangeLogic.change(for: monthKey(offset), in: line.amountChanges)?.amount == 50)
        }
    }
}
