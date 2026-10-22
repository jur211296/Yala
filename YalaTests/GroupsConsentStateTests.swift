//
//  GroupsConsentStateTests.swift
//  YalaTests
//
//  La CACHÉ local sellada del consent de Grupos (chip C1) y la decisión que se lee de ella.
//
//  Lo que hay que tener presente al leer estos tests: la caché ya no es la fuente de verdad — el registro
//  vive en la cuenta (`groups_consents`, append-only por grant) y esto es un snapshot sellado con el
//  `userID` DENTRO, cuya seguridad NO viene de ninguna purga (no existe dominio de `UserDefaults` por
//  sesión) sino del sello.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupsConsentStateTests {

    /// Instala unos `UserDefaults` aislados y un `sub` de sesión, y los restaura.
    private func withState(
        userID: String?, _ body: (UserDefaults) throws -> Void
    ) rethrows {
        let d = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let previousDefaults = GroupsConsentState.defaults
        let previousProvider = GroupsConsentState.currentUserIDProvider
        GroupsConsentState.defaults = d
        GroupsConsentState.currentUserIDProvider = { userID }
        defer {
            GroupsConsentState.defaults = previousDefaults
            GroupsConsentState.currentUserIDProvider = previousProvider
        }
        try body(d)
    }

    @Test func isAccepted_defaultFalse_trueOnceSnapshotWritten() {
        withState(userID: "sub-A") { _ in
            #expect(!GroupsConsentState.isAccepted)
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-A", textVersion: GroupsConsentText.version, acceptedAt: .now))
            #expect(GroupsConsentState.isAccepted)
        }
    }

    @Test func isAccepted_false_whenSnapshotBelongsToAnotherAccount() {
        // La frontera M1: la caché de una VISITA cae en el dominio del DUEÑO porque no hay dominio de
        // UserDefaults por sesión. Lo que la hace segura es el sello, no una purga.
        withState(userID: "sub-VISITA") { _ in
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-DUEÑO", textVersion: GroupsConsentText.version, acceptedAt: .now))
            #expect(!GroupsConsentState.isAccepted)
        }
    }

    @Test func isAccepted_true_withoutSession_becauseNothingCanContradictTheSeal() {
        // Sin sesión el sello no se comprueba: no abre ninguna puerta (las tres tablas de routing evalúan
        // la sesión ANTES que el consent) e invalidar aquí haría que cerrar sesión OLVIDARA un consent que
        // sigue siendo válido — la mina de la §prefs.
        withState(userID: nil) { _ in
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-A", textVersion: GroupsConsentText.version, acceptedAt: .now))
            #expect(GroupsConsentState.isAccepted)
        }
    }

    // MARK: - El consent LEGACY (formato anterior a C1)

    @Test func legacyKeys_areReadAsAccepted_withoutWritingAnything() throws {
        // Sin esto, la primera lectura tras actualizar la app —que ocurre en el primer render, antes de
        // que corra ningún paso de boot— le volvería a pedir el consent a quien ya lo dio.
        try withState(userID: "sub-A") { d in
            d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
            d.set(1, forKey: GroupsConsentState.legacyTextVersionKey)

            #expect(GroupsConsentState.isAccepted)
            let snapshot = try #require(GroupsConsentState.readSnapshot())
            #expect(snapshot.userID == nil, "el legacy no tenía identidad: se adopta después, con sesión")
            #expect(snapshot.acceptedAt == Date(timeIntervalSince1970: 1_700_000_000),
                    "la hora de la ACEPTACIÓN se conserva tal cual; jamás se re-fecha")
            // Lectura pura: no materializa el snapshot nuevo (eso lo hace `adoptLegacyIfNeeded`, con `sub`).
            #expect(d.data(forKey: GroupsConsentState.snapshotKey) == nil)
        }
    }

    @Test func legacyEpochZero_isNotAConsent() {
        withState(userID: "sub-A") { d in
            d.set(0, forKey: GroupsConsentState.legacyAcceptedAtKey)
            #expect(!GroupsConsentState.isAccepted)
        }
    }

    @Test func snapshotWins_overLegacyKeys() throws {
        try withState(userID: "sub-A") { d in
            d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-A", textVersion: 1, acceptedAt: Date(timeIntervalSince1970: 1_800_000_000)))
            let snapshot = try #require(GroupsConsentState.readSnapshot())
            #expect(snapshot.acceptedAt == Date(timeIntervalSince1970: 1_800_000_000))
        }
    }

    @Test func corruptSnapshot_fallsBackToLegacy_neverToNotAccepted() {
        // Un JSON ilegible se trata como AUSENTE, jamás como «no aceptado» persistente.
        withState(userID: "sub-A") { d in
            d.set(Data("{ no soy json".utf8), forKey: GroupsConsentState.snapshotKey)
            d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
            #expect(GroupsConsentState.isAccepted)
        }
    }

    // MARK: - clear()

    @Test func clear_wipesBothFormats_andIsIdempotent() {
        withState(userID: "sub-A") { d in
            d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
            d.set(1, forKey: GroupsConsentState.legacyTextVersionKey)
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: "sub-A", textVersion: 1, acceptedAt: .now))

            GroupsConsentState.clear()
            GroupsConsentState.clear()

            #expect(!GroupsConsentState.isAccepted)
            #expect(GroupsConsentState.readSnapshot() == nil)
            #expect(!GroupsConsentState.hasLocalRecord(in: d))
        }
    }

    @Test func hasLocalRecord_coversBothFormats() {
        // El gate del boot-cleanup del wipe de sign-out lo usa: comprobar solo el snapshot nuevo dejaría
        // fuera justo a quien lleva más tiempo con el consent puesto.
        let onlyLegacy = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        onlyLegacy.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        #expect(GroupsConsentState.hasLocalRecord(in: onlyLegacy))

        let empty = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        #expect(!GroupsConsentState.hasLocalRecord(in: empty))
    }
}

// MARK: - La decisión pura

@Suite("C1 · GroupsConsentDecisionLogic")
struct GroupsConsentDecisionLogicTests {

    private func snapshot(userID: String?, version: Int = 1) -> GroupsConsentSnapshot {
        GroupsConsentSnapshot(userID: userID, textVersion: version, acceptedAt: .now)
    }

    @Test func noSnapshot_isNotAccepted() {
        #expect(!GroupsConsentDecisionLogic.isAccepted(snapshot: nil, sessionUserID: "sub-A"))
    }

    @Test func sealMatchesSession_isAccepted() {
        #expect(GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A"), sessionUserID: "sub-A"))
    }

    @Test func sealContradictsSession_isNotAccepted() {
        #expect(!GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A"), sessionUserID: "sub-B"))
    }

    @Test func unsealedSnapshot_isAccepted_evenWithLiveSession() {
        // Es la forma del consent adoptado de un build anterior y la del seam `-uitest-groups-consent`.
        #expect(GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: nil), sessionUserID: "sub-A"))
    }

    @Test func noSession_doesNotCheckTheSeal() {
        #expect(GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A"), sessionUserID: nil))
    }

    // MARK: §8 — la comparación de versión que hasta C1 no hacía nadie

    @Test func versionBelowSubstantive_forcesReacceptance() {
        #expect(!GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A", version: 1),
            sessionUserID: "sub-A", requiresReacceptanceFrom: 2))
    }

    @Test func versionAtOrAboveSubstantive_holds() {
        // Bumpear `version` SIN subir `requiresReacceptanceFrom` (corrección de redacción) NO re-pregunta.
        #expect(GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A", version: 2),
            sessionUserID: "sub-A", requiresReacceptanceFrom: 2))
        #expect(GroupsConsentDecisionLogic.isAccepted(
            snapshot: snapshot(userID: "sub-A", version: 3),
            sessionUserID: "sub-A", requiresReacceptanceFrom: 2))
    }

    @Test func productionConstants_doNotForceReacceptanceToday() {
        // C1 NO bumpea el texto: mueve dónde se guarda el registro. Si esta aserción cae, alguien subió
        // `requiresReacceptanceFrom` por encima de lo que el parque tiene aceptado — todo el mundo volverá
        // a ver la pantalla, y eso es una decisión de producto, no un detalle.
        #expect(GroupsConsentText.version >= GroupsConsentText.requiresReacceptanceFrom)
    }

    // MARK: needsServerRegistration (la adopción del legacy)

    @Test func needsRegistration_whenServerKnowsNothing() {
        #expect(GroupsConsentDecisionLogic.needsServerRegistration(
            local: snapshot(userID: nil), serverTextVersion: nil, sessionUserID: "sub-A"))
    }

    @Test func needsRegistration_false_whenServerAlreadyHasIt() {
        #expect(!GroupsConsentDecisionLogic.needsServerRegistration(
            local: snapshot(userID: "sub-A", version: 1), serverTextVersion: 1, sessionUserID: "sub-A"))
    }

    @Test func needsRegistration_true_whenLocalIsNewerThanServer() {
        #expect(GroupsConsentDecisionLogic.needsServerRegistration(
            local: snapshot(userID: "sub-A", version: 2), serverTextVersion: 1, sessionUserID: "sub-A"))
    }

    @Test func needsRegistration_false_withoutSession_orWithAForeignSeal() {
        // Sin sesión no hay cuenta a la que atribuirlo; con sello ajeno, registrarlo sería atribuirle a
        // esta cuenta la aceptación de otra persona.
        #expect(!GroupsConsentDecisionLogic.needsServerRegistration(
            local: snapshot(userID: nil), serverTextVersion: nil, sessionUserID: nil))
        #expect(!GroupsConsentDecisionLogic.needsServerRegistration(
            local: snapshot(userID: "sub-B"), serverTextVersion: nil, sessionUserID: "sub-A"))
    }
}

// MARK: - La escalera de reintentos

@Suite("C1 · GroupsConsentRetryBackoffLogic")
struct GroupsConsentRetryBackoffLogicTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func neverAttempted_attemptsNow() {
        #expect(GroupsConsentRetryBackoffLogic.shouldAttempt(attempts: 0, lastAttemptAt: nil, now: t0))
    }

    @Test func firstRetryIsImmediate() {
        // El caso dominante es «aceptó sin red y arrancó dos minutos después»: hacerle esperar solo alarga
        // la ventana en que su consent no está registrado.
        #expect(GroupsConsentRetryBackoffLogic.delay(afterAttempts: 0) == 0)
    }

    @Test func ladderClimbsAndHoldsAtSixHours() {
        #expect(GroupsConsentRetryBackoffLogic.delay(afterAttempts: 1) == 60)
        #expect(GroupsConsentRetryBackoffLogic.delay(afterAttempts: 2) == 300)
        // Por encima de la tabla se queda en el último peldaño: la escalera se estira y NUNCA se rinde
        // (no hay tope de intentos — caducar aquí sería tirar la prueba legal).
        #expect(GroupsConsentRetryBackoffLogic.delay(afterAttempts: 99) == 6 * 60 * 60)
    }

    @Test func waitsUntilTheStepElapses() {
        let last = t0
        #expect(!GroupsConsentRetryBackoffLogic.shouldAttempt(
            attempts: 1, lastAttemptAt: last, now: last.addingTimeInterval(59)))
        #expect(GroupsConsentRetryBackoffLogic.shouldAttempt(
            attempts: 1, lastAttemptAt: last, now: last.addingTimeInterval(60)))
    }

    @Test func clockGoingBackwards_attempts_insteadOfFreezing() {
        // Un reloj que retrocede (cambio de zona, ajuste manual) congelaría el reintento hasta que el reloj
        // alcanzara al valor guardado. Intentar es la dirección segura.
        #expect(GroupsConsentRetryBackoffLogic.shouldAttempt(
            attempts: 3, lastAttemptAt: t0, now: t0.addingTimeInterval(-86_400)))
    }
}
