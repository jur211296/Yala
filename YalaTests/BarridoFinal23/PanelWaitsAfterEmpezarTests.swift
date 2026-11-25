//
//  PanelWaitsAfterEmpezarTests.swift
//  YalaTests
//
//  Card c8i9, barrido final de 2.3 (iPhone 14, 16-nov): tras «¡Tu cuenta está lista!» › «Empezar», el Panel salía 8-18 s en
//  S/ 0 con «Crear categorías». Medido con trazas: al tocar «Empezar» ya habían llegado 2 de las 6 cuentas y ningún
//  movimiento, y la espera del Panel solo arrancaba «sin ninguna cuenta». Ahora la entrada recién hecha
//  (`AccountEntryPanelWait`) enciende la espera aunque ya haya cuentas, hasta que el motor termina su primer tirón.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Barrido final 2.3 · tras «Empezar», el esqueleto hasta que llega la cuenta, nunca S/ 0", .serialized)
struct PanelWaitsAfterEmpezarTests {

    private let t0 = Date(timeIntervalSince1970: 2_000_000)

    // MARK: - La espera, en tabla

    @Test("Con la entrada recién hecha espera aunque ya haya cuentas; sin ella, no (el arranque normal)")
    func justEntered_waitsWithAccounts() {
        let idle = PanelAccountDataWait.idle
        #expect(idle.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, justEnteredAccount: true, now: t0) == .waiting(since: t0))
        #expect(idle.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, justEnteredAccount: false, now: t0) == .idle)
        // Con el motor ya terminado, o sin motor, la entrada no cambia nada.
        #expect(idle.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: true,
                          attestVerdictIsTerminal: false, justEnteredAccount: true, now: t0) == .idle)
        #expect(idle.next(hasAccounts: true, cloudEngineActive: false, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, justEnteredAccount: true, now: t0) == .idle)
        #expect(idle.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: true, justEnteredAccount: true, now: t0) == .idle)
    }

    @Test("La entrada caduca con el techo de la espera")
    func entry_expiresWithTheCeiling() {
        AccountEntryPanelWait.arm(now: t0)
        defer { AccountEntryPanelWait.disarm() }
        #expect(AccountEntryPanelWait.isArmed(now: t0.addingTimeInterval(PanelAccountDataWait.ceiling - 1)))
        #expect(!AccountEntryPanelWait.isArmed(now: t0.addingTimeInterval(PanelAccountDataWait.ceiling)))
        AccountEntryPanelWait.disarm()
        #expect(!AccountEntryPanelWait.isArmed(now: t0))
    }

    // MARK: - El Panel

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private final class Engine {
        var cloudEngineActive = true
        var firstPullCompleted = false
        /// El motor parado hasta volver a iniciar sesión (bugs de cuenta nube, 2026-11-25). Fijo en el test: con el real,
        /// el caso dependería del estado que otra suite dejó en `CloudSyncRuntime.shared`.
        var waitsForSignIn = false
    }

    private func makePanel(_ engine: Engine, context: ModelContext) -> PanelViewModel {
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.accountDataWaitInputs = { (engine.cloudEngineActive, engine.firstPullCompleted, false) }
        viewModel.accountDataWaitEngineWaitsForSignIn = { engine.waitsForSignIn }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    private func settle(until condition: () -> Bool, tries: Int = 120) async throws {
        for _ in 0..<tries where !condition() {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test("«Empezar» con dos cuentas ya llegadas y sin movimientos: esqueleto hasta el tirón, luego los datos")
    func afterEmpezar_withSomeAccounts_waitsForTheFirstPull() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Gastos Soles")
        _ = makeTestAccount(context: context, name: "General")
        try context.save()
        let engine = Engine()
        let viewModel = makePanel(engine, context: context)
        AccountEntryPanelWait.arm()
        defer { AccountEntryPanelWait.disarm() }

        viewModel.reloadAndRecalculate()
        try await settle(until: { viewModel.accountDataWait.isWaiting })
        #expect(viewModel.accountDataWait.isWaiting, "Con la entrada recién hecha, el Panel espera aunque ya haya cuentas")
        #expect(!viewModel.isReady, "El esqueleto, no S/ 0 con «Crear categorías»")
        #expect(!AccountEntryPanelWait.isArmed(), "La entrada se consume al empezar a esperar")

        engine.firstPullCompleted = true
        try await settle(until: { viewModel.isReady })
        #expect(viewModel.isReady)
        #expect(viewModel.accountDataWait == .idle)
        #expect(viewModel.accounts.count == 2)
    }

    @Test("Control: sin entrada reciente, el mismo Panel con cuentas sale en el acto (arranque normal en la nube)")
    func withoutEntry_panelWithAccounts_isReadyAtOnce() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Gastos Soles")
        try context.save()
        AccountEntryPanelWait.disarm()
        let viewModel = makePanel(Engine(), context: context)

        viewModel.reloadAndRecalculate()
        try await settle(until: { viewModel.isReady })
        #expect(viewModel.isReady)
        #expect(viewModel.accountDataWait == .idle)
    }

    @Test("Con el motor parado hasta iniciar sesión no espera nada: la entrada se consume y el Panel sale en el acto")
    func afterEmpezar_engineWaitsForSignIn_consumesTheEntry() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Gastos Soles")
        try context.save()
        let engine = Engine()
        engine.waitsForSignIn = true
        let viewModel = makePanel(engine, context: context)
        AccountEntryPanelWait.arm()
        defer { AccountEntryPanelWait.disarm() }

        viewModel.reloadAndRecalculate()
        try await settle(until: { viewModel.isReady })
        #expect(viewModel.isReady, "Ahí no baja nada hasta entrar: esperar solo taparía el aviso de «Iniciar sesión»")
        #expect(viewModel.accountDataWait == .idle)
        #expect(!AccountEntryPanelWait.isArmed(), "Una entrada sin nada que traer no se queda armada hasta el techo")
    }

    // MARK: - Cableado

    @Test("«Empezar» arma la entrada antes de pedir la recarga, y el Panel la lee y la consume")
    func wiring() throws {
        let content = try BarridoFinal23Source.code("Yala/App/ContentView.swift")
        #expect(content.contains("AccountEntryPanelWait.arm() SessionState.shared.incrementDataVersion() showWelcomeCloudSignIn = false"))
        let panel = try BarridoFinal23Source.code("Yala/App/ViewModels/PanelViewModel.swift")
        #expect(panel.contains("let justEntered = AccountEntryPanelWait.isArmed(now: now)"))
        #expect(panel.contains("justEnteredAccount: justEntered, now: now)"))
        // Se desarma al empezar a esperar o cuando el motor ya no trae nada: el primer tirón hecho, el veredicto terminal
        // del attest o, desde los bugs de cuenta nube (2026-11-25), el motor parado hasta volver a iniciar sesión.
        #expect(panel.contains("let waitsForSignIn = accountDataWaitEngineWaitsForSignIn()"))
        #expect(panel.contains("engineWaitsForSignIn: waitsForSignIn, justEnteredAccount: justEntered, now: now)"))
        #expect(panel.contains("if justEntered, next.isWaiting || inputs.firstPullCompleted || inputs.attestVerdictIsTerminal || waitsForSignIn { AccountEntryPanelWait.disarm() }"))
        #expect(panel.components(separatedBy: "AccountEntryPanelWait.disarm()").count - 1 == 1,
                "La entrada se desarma en un solo sitio")
    }
}
