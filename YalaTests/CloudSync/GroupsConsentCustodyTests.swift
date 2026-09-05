//
//  GroupsConsentCustodyTests.swift
//  YalaTests / CloudSync
//
//  La CUSTODIA del consent de Grupos del dueño en las fronteras de la sesión secundaria
//  (decisión del owner 2026-09-03, vía 6 de `secondary-visitor-writes-owner-domain`).
//
//  ## Qué se está probando, y por qué el fondo no es «que las keys vuelvan»
//
//  La frontera de ENTRADA tiene que retirar el consent del dueño: el consent LEGACY va sin sello y
//  `GroupsConsentDecisionLogic:60` lo da por bueno para cualquiera (el `if let sealed` no entra cuando
//  el sello es `nil`), así que sin retirarlo la visita hereda un permiso que no dio. Pero borrarlo
//  tiene dos costes: el dueño vuelve a ver una pantalla que ya aceptó, y perdemos la prueba de ese
//  consentimiento. De ahí «custodiar y reponer» en vez de «borrar».
//
//  Lo que estos tests fijan de verdad son las tres cosas que se pueden romper sin que se note:
//   1. el ORDEN (custodiar ANTES de la purga, reponer DESPUÉS) — al revés se custodia un dominio ya
//      vacío, o se repone algo que la purga se lleva un instante más tarde;
//   2. la IDEMPOTENCIA por presencia — la frontera se re-ejecuta entera tras un kill, y para entonces
//      lo que hay en las keys puede ser ya de la visita;
//   3. que la reposición RETIRE lo que el dueño no tenía, en vez de dejar en pie lo de la visita.
//

import Foundation
import Testing

@testable import Yala

// MARK: - La pieza sola

@Suite("GroupsConsentState · custodia y reposición")
struct GroupsConsentCustodyUnitTests {

    /// Un consent LEGACY (el del parque que aceptó antes de C1): sin snapshot y sin sello.
    private func legacyDefaults(prefix: String) -> UserDefaults {
        let d = makeIsolatedDefaults(prefix: prefix)
        d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        d.set(1, forKey: GroupsConsentState.legacyTextVersionKey)
        return d
    }

    private func snapshotData(userID: String?, version: Int = 1) -> Data {
        // swiftlint:disable:next force_try — dato fijo del test, un fallo aquí es el test roto.
        try! JSONEncoder().encode(GroupsConsentSnapshot(
            userID: userID, textVersion: version, acceptedAt: Date(timeIntervalSince1970: 1_700_000_000)))
    }

    @Test("custodia el consent legacy y la purga deja de ser destructiva")
    func custodyThenClearThenRestore_bringsLegacyBack() {
        let d = legacyDefaults(prefix: "consent.custody.legacy")

        #expect(GroupsConsentState.custodyOwnerRecord(in: d))
        // La purga (que en producción es `SecondarySessionBoundaryPurge`) se lleva las keys.
        d.removeObject(forKey: GroupsConsentState.legacyAcceptedAtKey)
        d.removeObject(forKey: GroupsConsentState.legacyTextVersionKey)
        #expect(d.object(forKey: GroupsConsentState.legacyAcceptedAtKey) == nil)

        #expect(GroupsConsentState.restoreOwnerRecord(in: d))
        #expect(d.integer(forKey: GroupsConsentState.legacyAcceptedAtKey) == 1_700_000_000)
        #expect(d.integer(forKey: GroupsConsentState.legacyTextVersionKey) == 1)
        // Y el slot queda vacío: la visita siguiente custodia lo que encuentre entonces.
        #expect(d.data(forKey: GroupsConsentState.ownerCustodyKey) == nil)
    }

    @Test("custodia también el snapshot SELLADO, que es la mitad que el ticket no pedía")
    func custodyCoversTheSealedSnapshot() {
        // El ticket sólo nombraba las dos legacy porque para el sellado `handleSignIn` lo repone. Pero
        // ese camino es no-op sin sesión Yala viva, y Grupos va al 100 % sin exigir Modo Nube ⇒ el dueño
        // que cerró sesión perdía su snapshot con el mismo síntoma exacto que el del legacy.
        let d = makeIsolatedDefaults(prefix: "consent.custody.sealed")
        let original = snapshotData(userID: "owner-sub")
        d.set(original, forKey: GroupsConsentState.snapshotKey)

        #expect(GroupsConsentState.custodyOwnerRecord(in: d))
        d.removeObject(forKey: GroupsConsentState.snapshotKey)
        #expect(GroupsConsentState.restoreOwnerRecord(in: d))
        #expect(d.data(forKey: GroupsConsentState.snapshotKey) == original)
    }

    @Test("la reposición RETIRA lo que la visita dejó y el dueño no tenía")
    func restoreRemovesWhatTheOwnerNeverHad() {
        // El dueño sólo tenía legacy; la visita aceptó y dejó un snapshot sellado con SU `sub`.
        // Reponer sólo lo que había dejaría el suyo en pie, y `readSnapshot()` lo prefiere al legacy.
        let d = legacyDefaults(prefix: "consent.custody.visitor")
        #expect(GroupsConsentState.custodyOwnerRecord(in: d))
        d.removeObject(forKey: GroupsConsentState.legacyAcceptedAtKey)
        d.removeObject(forKey: GroupsConsentState.legacyTextVersionKey)
        d.set(snapshotData(userID: "visitor-sub"), forKey: GroupsConsentState.snapshotKey)

        #expect(GroupsConsentState.restoreOwnerRecord(in: d))
        #expect(d.data(forKey: GroupsConsentState.snapshotKey) == nil, "el snapshot de la visita sobrevivió")
        #expect(d.integer(forKey: GroupsConsentState.legacyAcceptedAtKey) == 1_700_000_000)
    }

    @Test("idempotente por PRESENCIA: una segunda custodia no pisa la del dueño")
    func secondCustodyDoesNotOverwrite() {
        // Un kill entre la custodia y el final de la frontera re-ejecuta la entrada entera. Para
        // entonces lo que hay en las keys puede ser ya de la visita: sobrescribir el slot con eso
        // perdería el registro del dueño por el camino que existe para conservarlo.
        let d = legacyDefaults(prefix: "consent.custody.idem")
        #expect(GroupsConsentState.custodyOwnerRecord(in: d))

        d.removeObject(forKey: GroupsConsentState.legacyAcceptedAtKey)
        d.set(snapshotData(userID: "visitor-sub"), forKey: GroupsConsentState.snapshotKey)
        #expect(GroupsConsentState.custodyOwnerRecord(in: d) == false, "la segunda custodia pisó la primera")

        #expect(GroupsConsentState.restoreOwnerRecord(in: d))
        #expect(d.integer(forKey: GroupsConsentState.legacyAcceptedAtKey) == 1_700_000_000)
        #expect(d.data(forKey: GroupsConsentState.snapshotKey) == nil)
    }

    @Test("sin consent que custodiar no se crea slot, y la salida no toca nada")
    func nothingToCustodyLeavesNoSlot() {
        // Sin este guard, un slot VACÍO haría que la reposición retirase las tres keys al salir —
        // exactamente el daño que la custodia viene a impedir, entrando por la puerta de al lado.
        let d = makeIsolatedDefaults(prefix: "consent.custody.empty")
        #expect(GroupsConsentState.custodyOwnerRecord(in: d) == false)
        #expect(d.data(forKey: GroupsConsentState.ownerCustodyKey) == nil)

        d.set(snapshotData(userID: "visitor-sub"), forKey: GroupsConsentState.snapshotKey)
        #expect(GroupsConsentState.restoreOwnerRecord(in: d) == false)
        #expect(d.data(forKey: GroupsConsentState.snapshotKey) != nil, "la salida borró algo sin custodia")
    }

    @Test("un slot ilegible no repone nada y NO se queda atascado")
    func unreadableCustodyIsDiscarded() {
        let d = makeIsolatedDefaults(prefix: "consent.custody.corrupt")
        d.set(Data([0x00, 0x01]), forKey: GroupsConsentState.ownerCustodyKey)
        #expect(GroupsConsentState.restoreOwnerRecord(in: d) == false)
        #expect(d.data(forKey: GroupsConsentState.ownerCustodyKey) == nil,
                "un slot ilegible atascaría la custodia de la visita siguiente")
    }

    // `@MainActor` porque `readSnapshot()` lo está (el target compila con
    // `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); las funciones de custodia, no.
    @Test("nadie lee el slot como si fuera un consent")
    @MainActor
    func theCustodySlotIsNotAConsent() {
        // La mitad del diseño: `readSnapshot()` no mira el slot, así que una custodia viva no le
        // presta al que está dentro un permiso que no dio.
        let d = makeIsolatedDefaults(prefix: "consent.custody.opaque")
        let saved = GroupsConsentState.defaults
        GroupsConsentState.defaults = d
        defer { GroupsConsentState.defaults = saved }

        d.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        #expect(GroupsConsentState.custodyOwnerRecord(in: d))
        d.removeObject(forKey: GroupsConsentState.legacyAcceptedAtKey)

        #expect(GroupsConsentState.readSnapshot() == nil, "el slot de custodia se está leyendo como consent")
    }
}

// MARK: - El ORDEN en las dos fronteras

@Suite("Fronteras M1 · el consent del dueño va a custodia y vuelve")
struct GroupsConsentBoundaryOrderTests {

    @Test("ENTRADA: se custodia ANTES de la purga")
    func entryCustodiesBeforePurging() {
        // El orden ES el mecanismo: `SecondarySessionBoundaryPurge.purge()` incluye
        // `GroupsConsentState.clear()`. Custodiar después es custodiar un dominio ya vacío.
        let d = makeIsolatedDefaults(prefix: "consent.boundary.entry")
        SecondarySessionStore.activate(userID: "guest-1", d)

        var pasos: [String] = []
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: d,
            purge: { pasos.append("purge") },
            cancelNotifications: {},
            seedSessionDomain: { _, _ in },
            republishWidgetSeal: { _ in },
            custodyOwnerConsent: { _ in pasos.append("custody") })

        #expect(pasos == ["custody", "purge"], "el orden de la frontera de entrada cambió: \(pasos)")
    }

    @Test("ENTRADA: en el re-arranque one-shot no se vuelve a custodiar")
    func entryDoesNotCustodyTwice() {
        // Cuelga del mismo guard `entryPurgeDone` que la purga: van juntas o no van. (La red de
        // seguridad de verdad es la idempotencia por presencia del slot, probada arriba.)
        let d = makeIsolatedDefaults(prefix: "consent.boundary.entry.twice")
        SecondarySessionStore.activate(userID: "guest-1", d)
        SecondarySessionStore.markEntryPurgeDone(d)

        var custodias = 0
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: d,
            purge: {},
            cancelNotifications: {},
            seedSessionDomain: { _, _ in },
            republishWidgetSeal: { _ in },
            custodyOwnerConsent: { _ in custodias += 1 })

        #expect(custodias == 0)
    }

    @Test("SALIDA: se repone DESPUÉS de la purga")
    func exitRestoresAfterPurging() {
        // Al revés, el `clear()` que la purga hace en esta frontera —para llevarse el consent de la
        // VISITA— borraría justo lo que se acaba de devolver al dueño.
        let d = makeIsolatedDefaults(prefix: "consent.boundary.exit")
        SecondarySessionStore.activate(userID: "guest-1", d)
        SecondarySessionStore.markEntryPurgeDone(d)
        SecondarySessionStore.armWipe(d)

        var pasos: [String] = []
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: d,
            deleteFiles: { _, _ in true },
            purge: { pasos.append("purge") },
            cancelNotifications: {},
            destroySessionDomain: { _ in },
            republishWidgetSeal: { _ in },
            restoreOwnerConsent: { _ in pasos.append("restore") })

        #expect(pasos == ["purge", "restore"], "el orden de la frontera de salida cambió: \(pasos)")
    }

    @Test("SALIDA: un wipe que ABORTA no repone (el arranque siguiente reintenta entero)")
    func abortedExitDoesNotRestore() {
        // Reponer en un wipe abortado devolvería el consent del dueño con la sesión de la visita
        // todavía viva y el descriptor puesto — le prestaría su permiso a quien sigue dentro.
        let d = makeIsolatedDefaults(prefix: "consent.boundary.exit.abort")
        SecondarySessionStore.activate(userID: "guest-1", d)
        SecondarySessionStore.markEntryPurgeDone(d)
        SecondarySessionStore.armWipe(d)

        var repuso = false
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: d,
            deleteFiles: { _, _ in false },
            purge: {},
            cancelNotifications: {},
            destroySessionDomain: { _ in },
            republishWidgetSeal: { _ in },
            restoreOwnerConsent: { _ in repuso = true })

        #expect(repuso == false)
        #expect(SecondarySessionStore.isWipeArmed(d), "el arm se perdió: el reintento no correría")
    }

    @Test("el `clear()` de la purga sigue en su sitio (la entrada TIENE que retirarlo)")
    func thePurgeStillClearsTheConsent() {
        // Source-scan, no comportamiento: si alguien retirase el `clear()` creyendo que la custodia lo
        // sustituye, la visita heredaría el consent legacy del dueño — que es la mitad del bug que la
        // custodia NO arregla. Custodiar y borrar son las dos mitades, no alternativas.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/YalaTests/CloudSync
            .deletingLastPathComponent()   // …/YalaTests
            .deletingLastPathComponent()   // …/  (raíz)
            .appendingPathComponent("Yala/Services/CloudSync/SecondarySessionBoundaryPurge.swift")
        let src = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        #expect(src.contains("GroupsConsentState.clear()"),
                "la purga de frontera dejó de retirar el consent local; ¿se leyó la custodia como sustituto?")
    }
}
