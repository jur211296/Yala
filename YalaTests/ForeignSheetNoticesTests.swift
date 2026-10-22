//
//  ForeignSheetNoticesTests.swift
//  YalaTests
//
//  Invitaciones y avisos de la app con una hoja abierta en OTRA pestaña (ticket
//  `invite-and-app-notices-present-over-other-tab-sheets`). `.contentView` y `.mainTab` presentaban encima y tumbaban un
//  formulario a medias. Ahora los diferibles esperan a que se cierre y los críticos salen como siempre. La clasificación
//  y su tabla viven en `RouterConsumerGateLogic.waitsForForeignPresentation` y `docs/entry-points.md`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Avisos con una hoja de otra pestaña · clasificación y candado")
struct ForeignSheetNoticesLogicTests {

    // MARK: - Clasificación

    /// Los críticos de la tabla: cuenta o datos en juego. No esperan a nadie.
    @Test(arguments: [
        RouterIntent.remoteWipe(skipOnboarding: false), .iCloudMismatch, .appleIDChangedClosePrivate,
        .presentRemoteWipeNotice, .presentLateICloudMirrorNotice(.wipeCancelledInCloud),
        .remoteOnboardingCompleted,
    ])
    func critico_noEspera(_ intent: RouterIntent) {
        #expect(!RouterConsumerGateLogic.waitsForForeignPresentation(intent))
    }

    /// Los dudosos se tratan como críticos (anotados en el PR).
    @Test(arguments: [RouterIntent.showGroupSyncError("x"), .presentFullModeActivation, .presentGroupsOrganizerStep])
    func dudoso_seTrataComoCritico(_ intent: RouterIntent) {
        #expect(!RouterConsumerGateLogic.waitsForForeignPresentation(intent))
    }

    /// Los diferibles: invitaciones, ofertas, celebraciones y avisos informativos.
    @Test(arguments: [
        RouterIntent.showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0)),
        .presentTrialOffer, .presentWhatsNew(features: [], version: "2.1"),
        .showInviteError("x"), .showGroupArchivedNotice(groupID: "g", groupName: "Viaje"),
        .presentGroupsConsent(pendingJoin: "g"), .presentGroupsSignIn(pendingJoin: "g"),
        .presentGroupBackendInviteOnboarding(pendingJoin: "g"), .presentGroupsInviteNeutralGate(pendingJoin: "g"),
        .presentDowngradeResolution, .presentTrialExpired, .presentMilestoneUpgrade(50),
    ])
    func diferible_espera(_ intent: RouterIntent) {
        #expect(RouterConsumerGateLogic.waitsForForeignPresentation(intent))
    }

    /// Lo que no presenta una hoja de Yala, o es de otro consumidor con su propio candado, no entra aquí.
    @Test(arguments: [RouterIntent.navigate(.statistics), .requestAppStoreReview, .presentInboxSheet,
                      .presentNewTransaction, .autoOpenBudgetEditor])
    func sinHojaDeEsteConsumidor_noEspera(_ intent: RouterIntent) {
        #expect(!RouterConsumerGateLogic.waitsForForeignPresentation(intent))
    }

    // MARK: - Candado de `.contentView`

    @Test func contentView_diferibleConHojaDeOtraPestana_seRetiene() {
        #expect(RouterConsumerGateLogic.contentViewHoldsForForeignPresentation(
            .showInviteError("x"), shellClear: true, windowPresentationVisible: true))
    }

    @Test func contentView_criticoConHojaDeOtraPestana_sale() {
        #expect(!RouterConsumerGateLogic.contentViewHoldsForForeignPresentation(
            .iCloudMismatch, shellClear: true, windowPresentationVisible: true))
    }

    @Test func contentView_sinHoja_sale() {
        #expect(!RouterConsumerGateLogic.contentViewHoldsForForeignPresentation(
            .showInviteError("x"), shellClear: true, windowPresentationVisible: false))
    }

    /// Con la matriz tapada no se mira la ventana: es la invitación que derriba la cadena del Welcome (B4-04), y lo que
    /// la ventana tiene presentado es ese cover yéndose. Retener ahí colgaría la invitación que lo cerró.
    @Test func contentView_conLaMatrizTapada_noRetienePorLaVentana() {
        #expect(!RouterConsumerGateLogic.contentViewHoldsForForeignPresentation(
            .presentGroupsSignIn(pendingJoin: "g"), shellClear: false, windowPresentationVisible: true))
    }

    // MARK: - Candado de `.mainTab`

    @Test(arguments: [RouterIntent.presentTrialExpired, .presentDowngradeResolution, .presentMilestoneUpgrade(10)])
    func mainTab_avisoConHojaDeOtraPestana_seRetiene(_ intent: RouterIntent) {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: intent, shellBlocker: nil, ownModalVisible: false, windowPresentationVisible: true) == .hold)
        #expect(RouterConsumerGateLogic.mainTabHoldsOnlyForUnpublishedPresentation(
            intent: intent, shellBlocker: nil, ownModalVisible: false, windowPresentationVisible: true))
    }

    @Test func mainTab_avisoSinHoja_sale() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .presentTrialExpired, shellBlocker: nil, ownModalVisible: false, windowPresentationVisible: false)
            == .drain)
        #expect(!RouterConsumerGateLogic.mainTabHoldsOnlyForUnpublishedPresentation(
            intent: .presentTrialExpired, shellBlocker: nil, ownModalVisible: false, windowPresentationVisible: false))
    }

    /// Cambiar de pestaña no cierra la hoja: `navigate` no espera.
    @Test func mainTab_navegar_noEspera() {
        #expect(RouterConsumerGateLogic.mainTabDecision(
            intent: .navigate(.planning), shellBlocker: nil, ownModalVisible: false, windowPresentationVisible: true)
            == .drain)
    }

    /// Con el shell o una hoja propia tapando, quien re-drena es su flag publicado: el reintento no hace falta.
    @Test func mainTab_retenidoPorUnFlagPublicado_noEsSoloLaVentana() {
        #expect(!RouterConsumerGateLogic.mainTabHoldsOnlyForUnpublishedPresentation(
            intent: .presentTrialExpired, shellBlocker: "whatsNew", ownModalVisible: false,
            windowPresentationVisible: true))
        #expect(!RouterConsumerGateLogic.mainTabHoldsOnlyForUnpublishedPresentation(
            intent: .presentTrialExpired, shellBlocker: nil, ownModalVisible: true, windowPresentationVisible: true))
    }
}

@Suite("Avisos con una hoja de otra pestaña · cola y segundo plano", .serialized)
@MainActor
struct ForeignSheetNoticesQueueTests {

    private func freshRouter() -> AppRouter {
        let router = AppRouter.shared
        router._testReset()
        return router
    }

    private let heldWithForeignSheet: (RouterIntent) -> Bool = {
        RouterConsumerGateLogic.contentViewHoldsForForeignPresentation($0, shellClear: true, windowPresentationVisible: true)
    }

    /// El caso del ticket en la cola: con la hoja abierta, la invitación espera y el aviso crítico que llega después sale
    /// igual. Al cerrarse la hoja, la invitación sale.
    @Test func diferibleRetenido_noTapaAlCriticoQueLlegaDespues() {
        let router = freshRouter()
        defer { router._testReset() }
        router.markReady(.contentView, in: nil)
        router.enqueue(.showInboxAlert(.init(scheduledPayments: 1, subscriptions: 0, automations: 0)))
        router.enqueue(.presentRemoteWipeNotice)

        #expect(router.drainNext(for: .contentView, in: nil, skipping: heldWithForeignSheet) == .presentRemoteWipeNotice)
        #expect(router.drainNext(for: .contentView, in: nil, skipping: heldWithForeignSheet) == nil,
                "El aviso de la Bandeja tenía que seguir esperando a que se cerrara la hoja.")
        #expect(router.peekNext(for: .contentView, in: nil, where: heldWithForeignSheet) != nil,
                "Retenido, pero en la cola: si no, nadie volvería a mirarlo.")

        // La hoja se cierra.
        let drained = router.drainNext(for: .contentView, in: nil)
        guard case .showInboxAlert = drained else {
            Issue.record("Al cerrarse la hoja tenía que salir el aviso de la Bandeja; salió \(String(describing: drained))")
            return
        }
        #expect(router._testQueue.isEmpty)
    }

    /// Sin nada retenido, `drainNext(skipping:)` es el `drainNext` de siempre: el primero de la cola.
    @Test func sinRetenidos_drenaElPrimero() {
        let router = freshRouter()
        defer { router._testReset() }
        router.markReady(.contentView, in: nil)
        router.enqueue(.presentTrialOffer)
        router.enqueue(.presentWhatsNew(features: [], version: "2.1"))
        #expect(router.drainNext(for: .contentView, in: nil, skipping: { _ in false }) == .presentTrialOffer)
    }

    /// Los diferibles sin fuente que los vuelva a pedir se aparcan al salir de la app y vuelven al volver.
    @Test(arguments: [RouterIntent.showInviteError("El enlace no vale"),
                      .showGroupArchivedNotice(groupID: "g-1", groupName: "Viaje"), .presentMilestoneUpgrade(50)])
    func diferibleSinFuente_sobreviveAlSegundoPlano(_ notice: RouterIntent) {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = DeferredIntentBuffer(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)

        router.enqueue(notice)
        router.resetTransients(parkingIn: buffer)
        #expect(router._testQueue.isEmpty)
        #expect(buffer.drainAll() == [notice], "Al volver, el aviso que esperaba a la hoja tenía que seguir ahí.")
    }

    /// Caducan como las entradas aparcadas: un aviso de hace horas al abrir Yala sorprende.
    @Test func diferibleAparcado_caducaALosQuinceMinutos() {
        #expect(DeferredIntentBufferLogic.ttl(for: .showInviteError(detail: "x"), fallback: 24 * 3600) == 15 * 60)
        #expect(DeferredIntentBufferLogic.ttl(for: .presentMilestoneUpgrade(milestone: 50), fallback: 24 * 3600) == 15 * 60)
        #expect(DeferredIntentBufferLogic.ttl(
            for: .showGroupArchivedNotice(groupID: "g", groupName: "n"), fallback: 24 * 3600) == 15 * 60)
    }

    /// Lo que tiene fuente propia se sigue tirando al salir: vuelve desde ella.
    @Test func diferibleConFuente_noSeAparca() {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = DeferredIntentBuffer(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)

        router.enqueue(.presentTrialExpired)
        router.enqueue(.presentDowngradeResolution)
        router.enqueue(.presentGroupBackendInviteOnboarding(pendingJoin: "g"))
        router.resetTransients(parkingIn: buffer)
        #expect(buffer.isEmpty)
    }
}
