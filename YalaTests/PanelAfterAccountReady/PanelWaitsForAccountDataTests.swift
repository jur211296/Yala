//
//  PanelWaitsForAccountDataTests.swift
//  YalaTests
//
//  Card c8i9 (recorrido de la bienvenida, iPhone 14, 13-nov): tras «¡Tu cuenta está lista!» el Panel salía en S/ 0 y
//  Registros en «Sin registros» aunque los datos ya estaban llegando. Dos piezas:
//  1. lo que baja la nube con la app delante se aplica en el acto (`RemoteChangesFanOut`): antes solo se marcaba
//     pendiente y esperaba a volver a primer plano;
//  2. mientras la cuenta llega, el Panel enseña su esqueleto (`PanelAccountDataWait`), no un Panel en cero.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Panel · tras entrar en la cuenta, los datos y no un Panel en cero", .serialized)
struct PanelWaitsForAccountDataTests {

    // MARK: - Lo que baja la nube

    @Test("Con la app delante, lo que baja la nube sube `dataVersion` en el acto")
    func remoteChanges_withAppActive_bumpDataVersionNow() {
        let session = SessionState()
        let before = session.dataVersion
        RemoteChangesFanOut.receive(isApplicationActive: true, session: session)
        #expect(session.dataVersion != before, "Sin esto el Panel y Registros no se enteraban (el bug de E04, E05 y E08)")
        #expect(!session.applyPendingChangesIfNeeded(), "Lo pendiente ya se aplicó: volver a primer plano no recarga otra vez")
    }

    @Test("Sin la app delante, se queda pendiente para cuando vuelva, como antes")
    func remoteChanges_inBackground_stayPending() {
        let session = SessionState()
        let before = session.dataVersion
        RemoteChangesFanOut.receive(isApplicationActive: false, session: session)
        #expect(session.dataVersion == before)
        #expect(session.applyPendingChangesIfNeeded())
        #expect(session.dataVersion != before)
    }

    // MARK: - La espera, en tabla

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test("Empieza solo con el Panel vacío y el motor sin su primer tirón")
    func waitStarts_onlyEmptyWithEngineBringing() {
        let idle = PanelAccountDataWait.idle
        #expect(idle.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, now: t0) == .waiting(since: t0))
        // Con datos ya en el teléfono (un arranque normal en la nube) no se espera.
        #expect(idle.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, now: t0) == .idle)
        // iCloud: no hay motor que esté bajando nada.
        #expect(idle.next(hasAccounts: false, cloudEngineActive: false, firstPullCompleted: false,
                          attestVerdictIsTerminal: false, now: t0) == .idle)
        // El motor ya bajó la cuenta: una cuenta de verdad vacía.
        #expect(idle.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: true,
                          attestVerdictIsTerminal: false, now: t0) == .idle)
        // Sin App Attest el motor no baja nada.
        #expect(idle.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false,
                          attestVerdictIsTerminal: true, now: t0) == .idle)
    }

    @Test("Empezada, sigue aunque lleguen cuentas: nada de datos a medias")
    func waitContinues_whenAccountsArriveMidPull() {
        let waiting = PanelAccountDataWait.waiting(since: t0)
        #expect(waiting.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: false,
                             attestVerdictIsTerminal: false, now: t0.addingTimeInterval(5)) == waiting)
        #expect(waiting.next(hasAccounts: true, cloudEngineActive: true, firstPullCompleted: true,
                             attestVerdictIsTerminal: false, now: t0.addingTimeInterval(6)) == .idle)
    }

    @Test("Techo: sin red no se queda en el esqueleto para siempre")
    func waitGivesUp_atTheCeiling() {
        let waiting = PanelAccountDataWait.waiting(since: t0)
        let justBefore = t0.addingTimeInterval(PanelAccountDataWait.ceiling - 1)
        let atCeiling = t0.addingTimeInterval(PanelAccountDataWait.ceiling)
        #expect(waiting.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false,
                             attestVerdictIsTerminal: false, now: justBefore) == waiting)
        #expect(waiting.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false,
                             attestVerdictIsTerminal: false, now: atCeiling) == .gaveUp)
        // Rendida no vuelve a esperar hasta que el motor termine.
        #expect(PanelAccountDataWait.gaveUp.next(hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false,
                                                 attestVerdictIsTerminal: false, now: atCeiling) == .gaveUp)
        #expect(!PanelAccountDataWait.gaveUp.isWaiting)
    }

    // MARK: - El Panel

    /// El ViewModel guarda `sessionState` en `weak`: el test la retiene.
    private let session = SessionState()

    private final class Engine {
        var cloudEngineActive = true
        var firstPullCompleted = false
    }

    private func makePanel(_ engine: Engine, context: ModelContext) -> PanelViewModel {
        let viewModel = PanelViewModel()
        viewModel.isApplicationInForeground = { true }
        viewModel.accountDataWaitInputs = { (engine.cloudEngineActive, engine.firstPullCompleted, false) }
        viewModel.setContext(context, defaultCurrencyCode: "PEN", sessionState: session)
        return viewModel
    }

    private func settle(_ viewModel: PanelViewModel, until condition: () -> Bool, tries: Int = 120) async throws {
        for _ in 0..<tries where !condition() {
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    @Test("Vacío con la cuenta bajando: esqueleto; al terminar el tirón, el Panel con los datos")
    func emptyPanel_showsSkeletonUntilFirstPull_thenTheData() async throws {
        let context = try makeTestContext()
        let engine = Engine()
        let viewModel = makePanel(engine, context: context)

        viewModel.reloadAndRecalculate()
        try await settle(viewModel, until: { viewModel.accountDataWait.isWaiting })
        #expect(viewModel.accountDataWait.isWaiting)
        #expect(!viewModel.isReady, "El esqueleto, no «Crea tu primera cuenta» con S/ 0")

        // Llega la cuenta a mitad del tirón: sigue esperando.
        _ = makeTestAccount(context: context, name: "Cuenta Principal")
        try context.save()
        viewModel.reloadAndRecalculate()
        try await Task.sleep(for: .milliseconds(400))
        #expect(!viewModel.isReady)

        // Termina el tirón: el Panel recarga solo y enseña la cuenta.
        engine.firstPullCompleted = true
        try await settle(viewModel, until: { viewModel.isReady })
        #expect(viewModel.isReady)
        #expect(viewModel.accounts.count == 1)
        #expect(viewModel.accountDataWait == .idle)
    }

    @Test("Control: en iCloud el Panel vacío sale en el acto, como siempre")
    func emptyPanel_withoutCloudEngine_isReadyAtOnce() async throws {
        let context = try makeTestContext()
        let engine = Engine()
        engine.cloudEngineActive = false
        let viewModel = makePanel(engine, context: context)

        viewModel.reloadAndRecalculate()
        try await settle(viewModel, until: { viewModel.isReady })
        #expect(viewModel.isReady)
        #expect(viewModel.accountDataWait == .idle)
    }

    @Test("Control: un arranque normal en la nube, con datos, no espera al tirón")
    func panelWithData_doesNotWait() async throws {
        let context = try makeTestContext()
        _ = makeTestAccount(context: context, name: "Ahorros")
        try context.save()
        let viewModel = makePanel(Engine(), context: context)

        viewModel.reloadAndRecalculate()
        try await settle(viewModel, until: { viewModel.isReady })
        #expect(viewModel.isReady)
    }
}
