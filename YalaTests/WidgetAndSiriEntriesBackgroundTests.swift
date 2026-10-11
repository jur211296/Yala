//
//  WidgetAndSiriEntriesBackgroundTests.swift
//  YalaTests
//
//  Voz, imagen o nuevo registro pedidos desde un widget, Siri o el Centro de Control se perdían si la app pasaba a
//  segundo plano antes de presentarlos (ticket `widget-and-siri-entries-lost-on-background`): el Panel los retiene con
//  una hoja abierta u otra pestaña delante, y `AppRouter.resetTransients` los tiraba al salir. Ahora los aparca en el
//  `DeferredIntentBuffer`, que se drena en la siguiente vuelta a primer plano.
//

import Foundation
import Testing
@testable import Yala

@Suite("Entradas de widget y Siri · segundo plano", .serialized)
@MainActor
struct WidgetAndSiriEntriesBackgroundTests {

    private func makeBuffer() -> DeferredIntentBuffer {
        DeferredIntentBuffer(defaults: UserDefaults(suiteName: "test.\(UUID().uuidString)")!)
    }

    private func freshRouter() -> AppRouter {
        let router = AppRouter.shared
        router._testReset()
        return router
    }

    // MARK: - El ciclo entero

    /// El caso del ticket: la entrada espera en cola, la app sale y vuelve. Antes, al volver no quedaba nada que drenar.
    @Test(arguments: [RouterIntent.presentVoiceEntry, .presentImageEntry, .presentNewTransaction,
                      .requestAIConsent(.voice), .requestAIConsent(.image)])
    func entradaEnCola_sobreviveAlSegundoPlano_yElPanelLaPresentaAlVolver(_ entry: RouterIntent) {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = makeBuffer()

        router.enqueue(entry)
        router.resetTransients(parkingIn: buffer)
        #expect(router._testQueue.isEmpty, "Al salir, la cola en memoria se vacía como siempre.")

        // Vuelta a primer plano: `handleBecameActive` drena el buffer por `RouterEntryGate.submit`, que estas entradas
        // pasan sin aplazar (no son de notificación).
        for intent in buffer.drainAll() { router.enqueue(intent) }
        router.markReady(.panel, in: nil)
        #expect(router.drainNext(for: .panel, in: nil) == entry,
                "Al volver, el Panel tenía que tener la entrada que la persona pidió antes de salir.")
    }

    /// Varias entradas pendientes vuelven todas y en el orden de la cola.
    @Test func variasEntradas_vuelvenEnElOrdenDeLaCola() {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = makeBuffer()

        router.enqueue(.presentVoiceEntry)
        router.enqueue(.presentNewTransaction)
        router.resetTransients(parkingIn: buffer)

        #expect(buffer.drainAll() == [.presentVoiceEntry, .presentNewTransaction])
    }

    /// Lo que no es una entrada pedida desde fuera se sigue tirando: la hoja de Pro, la Bandeja, una navegación.
    @Test func loQueNoEsUnaEntrada_noSeAparca() {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = makeBuffer()

        router.enqueue(.presentUpgradeSheet(.voice))
        router.enqueue(.presentInboxSheet)
        router.enqueue(.navigate(.statistics))
        router.enqueue(.presentTrialOffer)
        router.resetTransients(parkingIn: buffer)

        #expect(buffer.isEmpty)
        #expect(router._testQueue.isEmpty)
    }

    /// Los avisos que ya sobrevivían en memoria siguen ahí y no se duplican en el buffer.
    @Test func losNoTransitorios_sigenEnLaColaYNoSeAparcan() {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = makeBuffer()

        router.enqueue(.iCloudMismatch)
        router.enqueue(.presentVoiceEntry)
        router.resetTransients(parkingIn: buffer)

        #expect(router._testQueue == [.iCloudMismatch])
        #expect(buffer.drainAll() == [.presentVoiceEntry])
    }

    /// Lo que ya se presentó (salió de la cola) no vuelve: solo se aparca lo que seguía esperando.
    @Test func entradaYaPresentada_noVuelveAlVolver() {
        let router = freshRouter()
        defer { router._testReset() }
        let buffer = makeBuffer()

        router.enqueue(.presentVoiceEntry)
        router.markReady(.panel, in: nil)
        #expect(router.drainNext(for: .panel, in: nil) == .presentVoiceEntry)
        router.resetTransients(parkingIn: buffer)

        #expect(buffer.isEmpty)
    }

    // MARK: - Caducidad

    /// Quince minutos fuera de la app, con los dos vecinos del borde.
    @Test(arguments: [(899.0, true), (900.0, false), (901.0, false)])
    func entradaAparcada_caducaALosQuinceMinutosFuera(_ secondsAway: Double, _ kept: Bool) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = DeferredEntry(payload: .presentVoiceEntry, createdAt: now.addingTimeInterval(-secondsAway))
        let survivors = DeferredIntentBufferLogic.purgeExpired([entry], now: now)
        #expect(survivors.isEmpty == !kept)
    }

    /// La caducidad corta es solo de las entradas aparcadas: una navegación aplazada sigue con sus 24 h.
    @Test func laCaducidadCorta_noAlcanzaAlRestoDelBuffer() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let hourAgo = now.addingTimeInterval(-3600)
        let entries = [
            DeferredEntry(payload: .navigate(routerKey: "panel"), createdAt: hourAgo),
            DeferredEntry(payload: .presentNewTransaction, createdAt: hourAgo),
            DeferredEntry(payload: .requestAIConsent(input: "image"), createdAt: hourAgo),
            DeferredEntry(payload: .presentImageEntry, createdAt: hourAgo),
        ]
        #expect(DeferredIntentBufferLogic.purgeExpired(entries, now: now).map(\.payload) == [.navigate(routerKey: "panel")])
    }

    @Test func laCaducidadCorta_noAlargaUnTopeMenor() {
        #expect(DeferredIntentBufferLogic.ttl(for: .presentVoiceEntry, fallback: 60) == 60)
        #expect(DeferredIntentBufferLogic.ttl(for: .presentVoiceEntry, fallback: 24 * 3600) == 15 * 60)
    }

    // MARK: - Serialización

    @Test func lasEntradas_sobrevivenAlDiscoYVuelvenIguales() {
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let payloads: [SerializableIntent] = [
            .presentVoiceEntry, .presentImageEntry, .presentNewTransaction,
            .requestAIConsent(input: "voice"), .requestAIConsent(input: "image"),
        ]
        let entries = payloads.map { DeferredEntry(payload: $0, createdAt: createdAt) }
        #expect(DeferredIntentBufferLogic.decode(DeferredIntentBufferLogic.encode(entries)) == entries)
        #expect(payloads.compactMap { DeferredIntentBufferLogic.deserialize($0) } == [
            .presentVoiceEntry, .presentImageEntry, .presentNewTransaction,
            .requestAIConsent(.voice), .requestAIConsent(.image),
        ])
    }

    /// Un consentimiento de un tipo que este build no conoce (lo escribió otro más nuevo) se descarta, no revienta.
    @Test func consentimientoDesconocido_seDescarta() {
        #expect(DeferredIntentBufferLogic.deserialize(.requestAIConsent(input: "video")) == nil)
    }

    /// El buffer real, con su `UserDefaults`: aparcar y drenar deja el buffer vacío.
    @Test func elBufferReal_guardaLaEntradaYSeVaciaAlDrenar() {
        let buffer = makeBuffer()
        buffer.deferIntent(.presentImageEntry)
        #expect(!buffer.isEmpty)
        #expect(buffer.drainAll() == [.presentImageEntry])
        #expect(buffer.isEmpty)
    }
}
