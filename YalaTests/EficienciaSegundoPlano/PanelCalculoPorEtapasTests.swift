//
//  PanelCalculoPorEtapasTests.swift
//  YalaTests
//
//  Lote 3 de eficiencia (26-nov-2026): el cálculo del Panel va por etapas que ceden el hilo principal, y se corta entre
//  una y otra si la app deja de estar en primer plano. Con 16.004 movimientos en el iPhone 14 el cálculo entero ocupaba
//  el hilo 7-16 s de una vez, y iOS cerró Yala en segundo plano (`0x8BADF00D`) porque no podía tomar la foto de la escena.
//
//  También «tirar para actualizar»: solo recarga si cambió la firma del Panel.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Segundo plano · el cálculo del Panel se corta entre etapas", .serialized)
@MainActor
struct PanelCalculoPorEtapasTests {

    /// Lo que la consulta de primer plano lee y el test cambia a mitad (una clase: el cierre la captura sin copiarla).
    @MainActor private final class Mando {
        var calls = 0
        var leaveAtCall = Int.max
        var armed = false
        weak var viewModel: PanelViewModel?
    }

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private func makePanel(foreground: @escaping @MainActor () -> Bool) throws -> (PanelViewModel, ModelContext) {
        let context = try makeTestContext()
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = foreground
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return (viewModel, context)
    }

    private func waitForCompleted(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<100 where viewModel.debugCalculationRuns < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func waitForStarted(_ viewModel: PanelViewModel, reaching target: Int) async throws {
        for _ in 0..<100 where viewModel.debugCalculationsStarted < target {
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    /// Carga asentada: un cálculo entero terminado y nada en vuelo.
    private func settle(_ viewModel: PanelViewModel) async throws {
        let before = viewModel.debugCalculationRuns
        viewModel.reloadAndRecalculate()
        try await waitForCompleted(viewModel, reaching: before + 1)
        try #require(viewModel.debugCalculationRuns == before + 1)
        try await Task.sleep(for: .milliseconds(250))
    }

    @Test("La app deja de estar en primer plano a mitad del cálculo → se corta y la vuelta lo rehace")
    func cutBetweenStages_whenTheAppLeaves_andTheReturnRedoesIt() async throws {
        // La consulta de primer plano: la primera la hace la petición; las siguientes, cada etapa.
        let mando = Mando()
        let (viewModel, _) = try makePanel(foreground: {
            mando.calls += 1
            return mando.calls < mando.leaveAtCall
        })
        try await settle(viewModel)

        mando.calls = 0
        mando.leaveAtCall = 2   // la petición pasa; tras la primera etapa (la tendencia) la app ya se fue
        let started = viewModel.debugCalculationsStarted
        let completed = viewModel.debugCalculationRuns
        viewModel.recalculateData()
        try await waitForStarted(viewModel, reaching: started + 1)
        try await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.debugCalculationsStarted == started + 1, "el cálculo empezó")
        #expect(viewModel.debugCalculationRuns == completed, "con la app fuera no terminó: se cortó entre etapas")
        #expect(viewModel.hasInterruptedWork, "lo cortado queda apuntado para la vuelta")

        // La vuelta: la firma ve el trabajo cortado y recalcula entero.
        mando.leaveAtCall = .max
        viewModel.setBackground(false)
        viewModel.reloadOnAppearIfStale()
        try await waitForCompleted(viewModel, reaching: completed + 1)
        #expect(viewModel.debugCalculationRuns == completed + 1)
        #expect(!viewModel.hasInterruptedWork)
    }

    @Test("El freno puesto a mitad del cálculo (setBackground) lo corta")
    func setBackgroundMidCalculation_cutsIt() async throws {
        let mando = Mando()
        let (viewModel, _) = try makePanel(foreground: {
            mando.calls += 1
            // Tras la primera etapa llega el paso a segundo plano, como lo entregaría la escena entre dos etapas.
            if mando.armed && mando.calls == 2 { mando.viewModel?.setBackground(true) }
            return true
        })
        mando.viewModel = viewModel
        try await settle(viewModel)
        mando.calls = 0
        mando.armed = true
        let completed = viewModel.debugCalculationRuns

        viewModel.recalculateData()
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.isInBackground)
        #expect(viewModel.debugCalculationRuns == completed, "el freno no cortó el cálculo en vuelo")
        #expect(viewModel.hasInterruptedWork)
    }

    @Test("Control: con la app delante el cálculo por etapas termina")
    func inForeground_theStagedCalculationCompletes() async throws {
        let (viewModel, _) = try makePanel(foreground: { true })
        try await settle(viewModel)
        let completed = viewModel.debugCalculationRuns
        viewModel.recalculateData()
        try await waitForCompleted(viewModel, reaching: completed + 1)
        #expect(viewModel.debugCalculationRuns == completed + 1)
        #expect(!viewModel.hasInterruptedWork)
    }

    @Test("Un recálculo pedido a mitad de las etapas corre detrás, no se pierde")
    func requestDuringStages_runsAfterwards() async throws {
        let mando = Mando()
        let (viewModel, _) = try makePanel(foreground: {
            mando.calls += 1
            // Un filtro cambia mientras el cálculo va por su segunda etapa.
            if mando.armed && mando.calls == 2 { mando.viewModel?.recalculateData() }
            return true
        })
        mando.viewModel = viewModel
        try await settle(viewModel)
        mando.calls = 0
        mando.armed = true
        let completed = viewModel.debugCalculationRuns

        viewModel.recalculateData()
        try await waitForCompleted(viewModel, reaching: completed + 2)
        try await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.debugCalculationRuns == completed + 2,
                "el recálculo pedido a mitad no corrió detrás (las etapas hechas leyeron los filtros de antes)")
    }

    // MARK: - Tirar para actualizar

    @Test("Tirar para actualizar sin nada nuevo no recalcula")
    func pullToRefresh_withNothingNew_doesNotRecalculate() async throws {
        let (viewModel, _) = try makePanel(foreground: { true })
        try await settle(viewModel)
        let started = viewModel.debugCalculationsStarted

        #expect(viewModel.refreshIfStale() == false)
        try await Task.sleep(for: .milliseconds(400))

        #expect(viewModel.debugCalculationsStarted == started)
    }

    @Test("Tirar para actualizar tras un guardado sí recarga")
    func pullToRefresh_afterASave_reloads() async throws {
        let (viewModel, context) = try makePanel(foreground: { true })
        try await settle(viewModel)
        let completed = viewModel.debugCalculationRuns

        let account = Account(name: "Soles", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "bank")
        context.insert(account)
        try context.save()

        #expect(viewModel.refreshIfStale() == true)
        try await waitForCompleted(viewModel, reaching: completed + 1)
        #expect(viewModel.debugCalculationRuns == completed + 1)
    }
}
