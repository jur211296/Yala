//
//  SignOutWipeHookTests.swift
//  YalaTests / CloudSync
//
//  Boot-cleanup del cierre de sesión en `.cloud` (H4) — orden kill-safe, idempotencia,
//  byte-identidad con el flag de grupos OFF y la limpieza de notificaciones de §5.2.1.
//  Variante inyectable: ni archivos reales, ni `UserDefaults.standard`, ni NotificationCenter,
//  ni el reset de prefs (que toca singletons del host). UserDefaults aislado (regla del repo).
//

import Foundation
import Testing

@testable import Yala

@Suite("SignOutWipeHook · boot-cleanup del cierre .cloud (H4)")
struct SignOutWipeHookTests {

    /// Estado de un device que acaba de cerrar sesión en `.cloud`: modo persistido `.cloud`,
    /// mirror-off armado (el par SERIO-1) y el wipe armado por el coordinador.
    private func armedDefaults(prefix: String, includesGroups: Bool = false) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.write(.cloud, defaults: defaults)
        defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
        if includesGroups {
            StorageModePersistence.markSignOutWipeIncludesGroups(defaults)
        }
        StorageModePersistence.armSignOutWipe(defaults)
        return defaults
    }

    // MARK: - Guard de arm

    @Test func notArmed_isNoOp() {
        let defaults = makeIsolatedDefaults(prefix: "sowipe.noop")
        StorageModePersistence.write(.cloud, defaults: defaults)
        var touched = false
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in touched = true; return true },
            resetPrefs: { touched = true },
            cancelNotifications: { touched = true },
            purgeInboundSurfaces: { touched = true })
        #expect(touched == false)
        // El modo persistido NO se toca sin arm.
        #expect(StorageModePersistence.read(defaults) == .cloud)
    }

    // MARK: - Abort S3

    /// El guard S3 protege el backup de iCloud: si el archivo BASE no se pudo borrar, el store de la
    /// época `.cloud` SIGUE VIVO. Cancelar ahí mataría recordatorios de datos que todavía existen.
    @Test func baseDeleteFails_abortsWithoutCancellingNorResetting() {
        let defaults = armedDefaults(prefix: "sowipe.abort")
        var resets = 0
        var cancels = 0
        var purges = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },   // kill-simulado: el BASE no se pudo borrar
            resetPrefs: { resets += 1 },
            cancelNotifications: { cancels += 1 },
            purgeInboundSurfaces: { purges += 1 })
        #expect(cancels == 0)
        #expect(resets == 0)
        // Mismo racional: si el store sobrevive, sus colas de entrada siguen siendo SUYAS —
        // vaciarlas aquí perdería un pago de Apple Pay / dictado de Siri legítimo, aún sin materializar.
        #expect(purges == 0)
        // El arm persiste (el próximo boot reintenta) y el par SERIO-1 queda intacto.
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(StorageModePersistence.read(defaults) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults))
    }

    /// **Paso 9 · con el modo `.icloud` el abort DESARMA.** Desde el paso 9 también arman este wipe los
    /// cierres de sesión PRIVADA y solo-grupos, y ahí el arranque monta el ESPEJO: con el arm colgando, la
    /// persona seguiría escribiendo y un reintento que saliera bien más tarde se llevaría cambios que nadie
    /// esperó a exportar. Desarmado, el cierre simplemente no ocurrió.
    @Test func baseDeleteFails_inICloudMode_disarmsInsteadOfRetrying() {
        let defaults = makeIsolatedDefaults(prefix: "sowipe.abort.icloud")
        StorageModePersistence.write(.icloud, defaults: defaults)
        StorageModePersistence.markSignOutWipeIncludesGroups(defaults)
        StorageModePersistence.armSignOutWipe(defaults)
        var resets = 0
        var cancels = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },
            resetPrefs: { resets += 1 },
            cancelNotifications: { cancels += 1 })
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
        #expect(!StorageModePersistence.signOutWipeIncludesGroups(defaults))
        #expect(!StorageModePersistence.isNeutralMountArmed(defaults), "el cierre no ocurrió: no hay neutro que armar")
        #expect(resets == 0)
        #expect(cancels == 0)
        #expect(StorageModePersistence.read(defaults) == .icloud)
    }

    /// El testigo «eligió privado sin iCloud» (la validación aplazada del paso 4) es de la vida que se
    /// cierra; `cloudSync.*` lo excluye del barrido de preferencias, así que es este hook quien lo retira.
    @Test func wipe_clearsThePrivateWithoutICloudWitness() {
        let defaults = makeIsolatedDefaults(prefix: "sowipe.pcwi")
        StorageModePersistence.write(.icloud, defaults: defaults)
        StorageModePersistence.markPrivateChoseWithoutICloud(defaults)
        StorageModePersistence.armSignOutWipe(defaults)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {})
        #expect(!StorageModePersistence.privateChoseWithoutICloud(defaults))
        #expect(!StorageModePersistence.isSignOutWipeArmed(defaults))
    }

    // MARK: - Orden completo

    @Test func armed_runsFullOrder_cancelsOnce_armClearedLast() {
        let defaults = armedDefaults(prefix: "sowipe.full")
        var events: [String] = []
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in events.append("delete:\(name)"); return true },
            resetPrefs: { events.append("resetPrefs") },
            cancelNotifications: { events.append("cancelNotifications") },
            purgeInboundSurfaces: { events.append("purgeInboundSurfaces") })

        #expect(events == [
            "delete:\(SwiftDataConfiguration.databaseName)",
            "delete:\(SwiftDataConfiguration.syncMetaDatabaseName)",
            "resetPrefs",
            // §5.2.1 — dentro del bloque post-guard, junto al reset de prefs/caches.
            "cancelNotifications",
            // Colas del App Group: sobreviven al borrado de archivos y se drenarían contra el
            // store de la cuenta SIGUIENTE. También post-guard, por el mismo racional.
            "purgeInboundSurfaces",
        ])
        // Par SERIO-1 a `.icloud` fresh + desarme AL FINAL.
        #expect(StorageModePersistence.read(defaults) == .icloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == false)
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults) == false)
    }

    @Test func retryAfterAbort_completesAndCancelsExactlyOnce() {
        let defaults = armedDefaults(prefix: "sowipe.retry")
        var cancels = 0
        var purges = 0
        // 1ª pasada: abort (no cancela ni purga).
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },
            resetPrefs: {},
            cancelNotifications: { cancels += 1 },
            purgeInboundSurfaces: { purges += 1 })
        #expect(cancels == 0)
        #expect(purges == 0)
        // 2ª pasada (boot siguiente): completa.
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: { cancels += 1 },
            purgeInboundSurfaces: { purges += 1 })
        #expect(cancels == 1)
        #expect(purges == 1)
        // 3ª pasada: el arm ya no está → no-op (idempotencia).
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: { cancels += 1 },
            purgeInboundSurfaces: { purges += 1 })
        #expect(cancels == 1)
        #expect(purges == 1)
    }

    // MARK: - Byte-identidad del flag de grupos

    @Test func withoutGroupsMarker_neverDeletesGroupsStore() {
        let defaults = armedDefaults(prefix: "sowipe.nogroups")
        var deleted: [String] = []
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in deleted.append(name); return true },
            resetPrefs: {},
            cancelNotifications: {})
        #expect(deleted == [
            SwiftDataConfiguration.databaseName,
            SwiftDataConfiguration.syncMetaDatabaseName,
        ])
        #expect(!deleted.contains(SwiftDataConfiguration.groupsDatabaseName))
    }

    @Test func withGroupsMarker_deletesGroupsStore_andClearsMarker() {
        let defaults = armedDefaults(prefix: "sowipe.groups", includesGroups: true)
        var deleted: [String] = []
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in deleted.append(name); return true },
            resetPrefs: {},
            cancelNotifications: {})
        #expect(deleted == [
            SwiftDataConfiguration.databaseName,
            SwiftDataConfiguration.syncMetaDatabaseName,
            SwiftDataConfiguration.groupsDatabaseName,
        ])
        #expect(StorageModePersistence.signOutWipeIncludesGroups(defaults) == false)
    }

    /// Paso 9: el latch «este dispositivo tuvo sesión de Grupos» se va con el store de grupos. Tras el borrado
    /// el dispositivo es «recién instalado», y el latch le diría a la persona siguiente «vuelve a tu cuenta».
    /// `resetPrefs` va vacío a propósito: el barrido de preferencias no lo nombra, así que lo que se prueba es
    /// la línea del hook.
    @Test func withGroupsMarker_clearsTheGroupsSessionLatch() {
        let defaults = armedDefaults(prefix: "sowipe.latch", includesGroups: true)
        defaults.set(true, forKey: GroupsSessionHistoryMarker.key)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, resetPrefs: {}, cancelNotifications: {})
        #expect(defaults.object(forKey: GroupsSessionHistoryMarker.key) == nil)
    }

    /// Y sin el marker de grupos se queda: esos grupos siguen en el dispositivo.
    @Test func withoutGroupsMarker_keepsTheGroupsSessionLatch() {
        let defaults = armedDefaults(prefix: "sowipe.latchkept")
        defaults.set(true, forKey: GroupsSessionHistoryMarker.key)
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, resetPrefs: {}, cancelNotifications: {})
        #expect(defaults.object(forKey: GroupsSessionHistoryMarker.key) != nil)
    }

    // MARK: - Consent de GRUPOS (§C5)

    /// El consent de grupos es un registro de la CUENTA y `removeUserPreferenceKeys` no lo nombra:
    /// sin este clear sobrevive al wipe y la cuenta SIGUIENTE se salta la pantalla de consent
    /// (`GroupBackendInviteEntryLogic.nextStep`) mientras el uploader de migración —gateado POR
    /// consent— sube sus grupos bajo un `user_id` que jamás consintió.
    ///
    /// El ORDEN es load-bearing, no cosmético, en las DOS direcciones:
    /// - DESPUÉS de `write(.icloud)`: ahí `PreferenceSyncService.behavior` resolvía `.icloudKeyValue`
    ///   (local + iKV, cero backend). Con el modo aún `.cloud` tomaba `.cloudOutbox` y encolaba
    ///   `.int(0)`, borrando por LWW el registro GDPR de una cuenta VIVA. **Ese riesgo murió en C1**: el
    ///   consent salió del canal de prefs y `GroupsConsentState.clear()` es local puro (además, el grant
    ///   de `groups_consents` no tiene `delete`). El orden se conserva porque sigue siendo el camino
    ///   byte-idéntico y no cuesta nada — pero ya no es lo que impide el daño.
    /// - ANTES de `resetPrefs()`: el gate de producción LEE lo que ese reset podría barrer.
    ///
    /// El modo se captura DENTRO de la closure a propósito: leerlo tras el return solo probaría que
    /// el hook terminó en `.icloud`, no que el clear corriera ya en esa rama — un mutante que moviera
    /// `write(.icloud)` por debajo del clear dejaría verde una aserción post-return.
    @Test func armed_clearsGroupsConsent_beforePrefsReset_withModeAlreadyICloud() {
        let defaults = armedDefaults(prefix: "sowipe.consent", includesGroups: true)
        defaults.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        var events: [String] = []
        var modeAtClear: StorageMode?
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: { events.append("resetPrefs") },
            cancelNotifications: { events.append("cancelNotifications") },
            purgeInboundSurfaces: { events.append("purgeInboundSurfaces") },
            clearGroupsConsent: {
                events.append("clearGroupsConsent")
                modeAtClear = StorageModePersistence.read(defaults)
            })

        #expect(events == [
            "clearGroupsConsent",
            "resetPrefs",
            "cancelNotifications",
            "purgeInboundSurfaces",
        ])
        #expect(modeAtClear == .icloud)
    }

    /// Byte-identidad con el flag OFF: el consent solo se escribe al aceptar, así que sin rastro local la
    /// closure JAMÁS se invoca.
    /// Gate por PRESENCIA y no por `signOutWipeIncludesGroups`: cubre además el hueco del
    /// kill-switch remoto (flag apagado entre el `register()` y el sign-out ⇒ marker ausente,
    /// consent presente).
    @Test func withoutConsentKey_neverInvokesClear_evenWithGroupsMarker() {
        let defaults = armedDefaults(prefix: "sowipe.noconsent", includesGroups: true)
        var cleared = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {},
            clearGroupsConsent: { cleared += 1 })
        #expect(cleared == 0)
    }

    /// Y a la inversa: consent presente SIN el marker de grupos (el store de grupos sobrevive) SÍ
    /// limpia — el device vuelve a "recién instalado" y el consent es de la cuenta que se fue.
    @Test func consentKeyPresent_clearsEvenWithoutGroupsMarker() {
        let defaults = armedDefaults(prefix: "sowipe.consentnomarker")
        defaults.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        var cleared = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {},
            clearGroupsConsent: { cleared += 1 })
        #expect(cleared == 1)
    }

    /// C1: el gate cubre las DOS formas del consent local. Con solo el snapshot nuevo —el device ya volvió
    /// a aceptar tras la actualización, así que las keys legacy ya no están— tiene que limpiar igual.
    /// Comprobar solo una de las dos dejaría fuera a media población, y en direcciones opuestas.
    @MainActor
    @Test func newSnapshotPresent_alsoTriggersTheClear() {
        let defaults = armedDefaults(prefix: "sowipe.consentsnapshot", includesGroups: true)
        let previous = GroupsConsentState.defaults
        GroupsConsentState.defaults = defaults
        defer { GroupsConsentState.defaults = previous }
        GroupsConsentState.write(GroupsConsentSnapshot(
            userID: "sub-A", textVersion: GroupsConsentText.version, acceptedAt: .now))

        var cleared = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {},
            clearGroupsConsent: { cleared += 1 })
        #expect(cleared == 1)
    }

    /// Guard abort-S3: si el archivo BASE no se borró, el store SOBREVIVE ⇒ el consent de esa sesión
    /// sigue siendo válido. Mismo racional que notificaciones y colas del App Group.
    @Test func baseDeleteFails_neverClearsGroupsConsent() {
        let defaults = armedDefaults(prefix: "sowipe.consentabort", includesGroups: true)
        defaults.set(1_700_000_000, forKey: GroupsConsentState.legacyAcceptedAtKey)
        var cleared = 0
        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },
            resetPrefs: {},
            cancelNotifications: {},
            clearGroupsConsent: { cleared += 1 })
        #expect(cleared == 0)
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults))  // arm intacto: reintenta
    }

    // MARK: - Sentinels del drenaje iKV (#37)

    @Test func sentinelsPurged_fromInjectedDefaults() {
        let defaults = armedDefaults(prefix: "sowipe.sentinel")
        let mine = "\(PrefsCutoverDrain.sentinelPrefix)sub-A"
        let other = "\(PrefsCutoverDrain.sentinelPrefix)sub-B"
        defaults.set(true, forKey: mine)
        defaults.set(true, forKey: other)
        // Key ajena al sentinel: debe sobrevivir.
        defaults.set(true, forKey: "cloudSync.someOtherKey")

        SwiftDataConfiguration.performSignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in true },
            resetPrefs: {},
            cancelNotifications: {})

        #expect(defaults.object(forKey: mine) == nil)
        #expect(defaults.object(forKey: other) == nil)   // TODOS los userIDs, por prefijo
        #expect(defaults.bool(forKey: "cloudSync.someOtherKey"))
    }
}

@Suite("GroupsOnlySignOutWipeHook · asimetría deliberada de notificaciones")
struct GroupsOnlySignOutWipeHookTests {

    private func armedDefaults(prefix: String) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        StorageModePersistence.armGroupsOnlyWipe(defaults)
        return defaults
    }

    /// El store PERSONAL sobrevive a este camino ⇒ solo se retiran las ENTREGADAS de grupos.
    /// Este test fija la asimetría: si alguien añadiera un `cancelAllNotifications()` aquí por
    /// simetría ciega con `performSignOutWipeIfArmed`, borraría los recordatorios VIVOS del usuario.
    @Test func armed_clearsOnlyDeliveredGroupNotifications_afterFileDeletion() {
        let defaults = armedDefaults(prefix: "golly.full")
        var events: [String] = []
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in events.append("delete:\(name)"); return true },
            clearDeliveredGroupNotifications: { events.append("clearDeliveredGroups") })
        #expect(events == [
            "delete:\(SwiftDataConfiguration.groupsDatabaseName)",
            "clearDeliveredGroups",
        ])
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults) == false)
    }

    @Test func baseDeleteFails_abortsWithoutClearing() {
        let defaults = armedDefaults(prefix: "golly.abort")
        var cleared = 0
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },
            clearDeliveredGroupNotifications: { cleared += 1 })
        #expect(cleared == 0)
        #expect(StorageModePersistence.isGroupsOnlyWipeArmed(defaults))
    }

    @Test func notArmed_isNoOp() {
        let defaults = makeIsolatedDefaults(prefix: "golly.noop")
        var touched = false
        SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in touched = true; return true },
            clearDeliveredGroupNotifications: { touched = true })
        #expect(touched == false)
    }
}

/// Source-scan del CABLEADO DE PRODUCCIÓN (§5.2.1 + colas del App Group). Los tests de arriba ejercen
/// las variantes inyectables y observan seams: vaciar la closure `cancelNotifications:` o
/// `purgeInboundSurfaces:` de un wrapper reintroduce el bug ÍNTEGRO sin que ninguno se ponga rojo. Y los
/// wrappers abren con `guard !isRunningTests`, así que son inejecutables en unit test POR CONSTRUCCIÓN
/// — ningún test de comportamiento puede cubrirlos.
/// Mismo patrón y misma razón que `GroupsSyncHardeningTests.signOut_allThreePaths_wireGroupsTeardown`.
@Suite("SignOutWipeHook · cableado de producción (source-scan)")
struct SignOutNotificationWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El fuente SIN las líneas que son comentario entero. Molde `AttestWiringTests`, y aquí no es
    /// cosmética: los scans de abajo CUENTAN ocurrencias de `GroupsConsentState.clear()`, y este repo
    /// explica sus invariantes nombrando el símbolo del que hablan — así que documentar por qué el clear
    /// vive donde vive ponía el conteo en 2 y el test en rojo sin que nada cambiara en producción. Pasó
    /// literalmente al escribir C1. Los comentarios de FINAL de línea se conservan a propósito: recortar
    /// desde el primer `//` destrozaría cualquier `URL(string: "https://…")`.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// El wrapper que borra el store PERSONAL cablea el barrido total de avisos.
    ///
    /// **Era 3 hasta el 2026-09-13**: los otros dos eran las dos fronteras de la sesión de visita, que
    /// cancelaban los avisos del dueño al entrar y los de la invitada al salir. Queda
    /// `performSignOutWipeIfArmed`, que es el cierre de sesión de verdad.
    @Test func bootHook_wiresPersonalNotificationCleanup() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        #expect(src.components(separatedBy: "NotificationService.shared.cancelAllNotifications()").count - 1 == 1)
        #expect(src.components(separatedBy: "NotificationService.shared.clearDeliveredNotifications()").count - 1 == 1)
    }

    /// ASIMETRÍA del hook solo-grupos: ahí el store personal SOBREVIVE. El cuerpo de la función debe
    /// invocar SOLO el clear selectivo de grupos — un `cancelAllNotifications` colado por simetría ciega
    /// borraría los recordatorios vivos del usuario que NO cerró sesión, y el test de comportamiento no
    /// lo vería (solo registra los seams inyectados).
    @Test func groupsOnlyHook_neverWiresPersonalCleanup() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        let marker = "static func performGroupsOnlySignOutWipeIfArmed()"
        // Corte en el MARK, no en la firma siguiente: el doc-comment de `performSecondaryWipeIfArmed`
        // describe la purga M1 y nombrarla ahí pondría este test rojo sin bug alguno.
        let nextMarker = "// MARK: - Retirada de la sesión secundaria (ADR 2026-09-09)"
        guard let start = src.range(of: marker), let end = src.range(of: nextMarker) else {
            Issue.record("No se localizaron los marcadores del hook solo-grupos — ¿se renombró?")
            return
        }
        let body = String(src[start.lowerBound..<end.lowerBound])
        #expect(body.contains("clearDeliveredGroupNotifications"))
        #expect(!body.contains("cancelAllNotifications"))
        #expect(!body.contains("clearDeliveredNotifications()"))
        // MISMA asimetría para las colas del App Group: aquí el store personal sobrevive, así que
        // Apple Pay / Siri / imágenes pendientes son SUYAS y deben materializarse cuando abra.
        #expect(!body.contains("purgeInboundSurfaces"))
    }

    /// Colas del App Group: cableadas SOLO donde el store personal muere o cambia de dueño.
    /// Vaciar la closure `purgeInboundSurfaces:` del wrapper personal reintroduce el bug completo
    /// (un pago de Apple Pay de la cuenta saliente se materializa como borrador en la entrante) con
    /// todos los tests de comportamiento en verde — de ahí este scan.
    @Test func bootHooks_wireAppGroupInboundPurge_onlyWherePersonalStoreDies() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        // performSignOutWipeIfArmed cablea el helper compartido.
        #expect(src.contains("purgeInboundSurfaces: { AppGroupInboundPurge.purgeInboundSurfaces() }"))
        #expect(src.components(separatedBy: "AppGroupInboundPurge.purgeInboundSurfaces()").count - 1 == 1)
    }

    /// El contenido de la purga compartida. Perder una de estas superficies es invisible para los
    /// tests de arriba (todos observan la closure, no su cuerpo).
    @Test func inboundPurge_coversEveryAppGroupEntrySurface() throws {
        let src = try Self.source("Yala/Services/CloudSync/AppGroupInboundPurge.swift")
        #expect(src.contains("ApplePayPendingStore.remove(keys:"))
        #expect(src.contains("SiriPendingStore.remove(keys:"))
        #expect(src.contains("SiriIntentContextCache.clear()"))
        #expect(src.contains("SharedContainerService.removePendingImage(at:"))
    }

    /// La capa in-session es DIRECCIONAL y ninguna dirección estaba pinneada: quitarla de un camino
    /// armado deja sonar la cuenta saliente —y deja el widget pintando sus saldos— durante el cover
    /// terminal, que puede durar minutos o para siempre (el usuario puede no volver a abrir la app);
    /// añadirla a un camino donde el store personal SOBREVIVE borraría recordatorios vivos y vaciaría el
    /// widget de un store que sigue ahí.
    /// 6 ocurrencias = 1 definición + 5 call-sites (cloud / secundario / salida forzada de la visita /
    /// cierre post-borrado de cuenta en la nube / tramo común de los cierres por archivos del paso 9).
    ///
    /// El cuarto entró el 2026-09-05 con `exitSecondaryDiscardingPending`, el «salir igualmente» de la
    /// sesión de visita. Cuenta como camino armado por la misma razón que su hermano: arma el wipe
    /// secundario, así que sin esta capa las notificaciones de la invitada seguirían sonando y el widget
    /// seguiría pintando sus saldos durante todo el cover terminal — en el móvil de OTRA persona.
    ///
    /// El quinto es del paso 9 (`finalizeSessionExit`): la sesión privada, la «equipo» y la solo-grupos
    /// cierran ahora por el MISMO boot-wipe de archivos que la nube, así que las tres dejan de conservar
    /// nada personal. Por eso el clear SELECTIVO de avisos de grupo que tenía el cierre solo-grupos se fue
    /// con él: aquel camino conservaba el store personal y éste lo borra.
    @Test func inSessionLayer_wiredOnlyOnArmedPersonalWipePaths() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let code = Self.codeOnly(src)
        // **Eran 6 hasta el 2026-09-13**: los dos que faltan son los caminos de salida de la sesión de
        // visita. El conteo incluye la declaración de la propia función (3 call-sites + 1 `func`).
        #expect(code.components(separatedBy: "clearLocalSurfacesForArmedWipe()").count - 1 == 4)
        // El widget vive en el mismo helper A PROPÓSITO: es la otra superficie del SISTEMA que sigue
        // mostrando la cuenta cerrada hasta el relanzamiento, y comparte sus call-sites exactos.
        #expect(code.components(separatedBy: "WidgetDataCache.clearCache()").count - 1 == 1)
        // Ningún cierre de este fichero conserva ya lo personal y a la vez limpia avisos: el selectivo de
        // grupos solo sobrevive en el boot-hook solo-grupos, que es el del cierre tras borrar la cuenta.
        #expect(!code.contains("clearDeliveredGroupNotifications"))

        // La dirección contraria: tras borrar la cuenta de GRUPOS (celda «equipo») lo personal sobrevive,
        // así que ese cierre NO puede llevar la capa entera.
        // Los marcadores se buscan en el fuente ENTERO —uno es un `// MARK:` y `codeOnly` se lo llevaría—;
        // lo que se afirma, sobre el cuerpo sin comentarios.
        let marker = "func closeLocalAfterAccountDeletionGroupsOnly("
        let nextMarker = "// MARK: - Helpers del canal de Grupos"
        guard let start = src.range(of: marker),
              let end = src.range(of: nextMarker, range: start.upperBound..<src.endIndex) else {
            Issue.record("No se localizaron los marcadores del cierre tras borrar la cuenta de grupos — ¿se renombró?")
            return
        }
        let body = Self.codeOnly(String(src[start.lowerBound..<end.lowerBound]))
        #expect(body.contains("StorageModePersistence.armGroupsOnlyWipe()"))
        #expect(!body.contains("clearLocalSurfacesForArmedWipe()"))
        #expect(!body.contains("armSignOutWipe()"))
    }

    /// El consent de GRUPOS muere donde muere el store PERSONAL, y SOLO ahí. Vaciar la closure
    /// `clearGroupsConsent:` del wrapper reintroduce el gap ÍNTEGRO con todos los tests de
    /// comportamiento en verde (observan el seam, no el cableado).
    ///
    /// La ASIMETRÍA con el hook solo-grupos es a CONSERVAR, no a "arreglar" por simetría: allí el
    /// consent ya se limpió in-session en `closeLocalAfterAccountDeletionGroupsOnly` (y en `finalizeGroupsOnlyClose` hasta el paso 9) y el store personal sobrevive.
    @Test func consentCleanup_wiredOnlyWherePersonalStoreDies() throws {
        let full = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        // El CONTEO va sobre el código sin comentarios; los MARCADORES se buscan en el fuente entero,
        // porque uno de ellos ES un comentario (`// MARK:`) y `codeOnly` se lo llevaría por delante.
        let code = Self.codeOnly(full)
        #expect(code.contains("clearGroupsConsent: { GroupsConsentState.clear() }"))
        #expect(code.components(separatedBy: "GroupsConsentState.clear()").count - 1 == 1)

        let marker = "static func performGroupsOnlySignOutWipeIfArmed()"
        let nextMarker = "// MARK: - Retirada de la sesión secundaria (ADR 2026-09-09)"
        guard let start = full.range(of: marker), let end = full.range(of: nextMarker) else {
            Issue.record("No se localizaron los marcadores del hook solo-grupos — ¿se renombró?")
            return
        }
        let body = Self.codeOnly(String(full[start.lowerBound..<end.lowerBound]))
        #expect(!body.contains("GroupsConsentState.clear()"))
    }

    /// Los clears IN-SESSION siguen atados a caminos que corren con el modo `.icloud` persistido
    /// (los 3 de `CloudSessionSignOut` + la frontera M1). Migrar uno al camino `.cloud` lo pondría
    /// bajo `behavior == .cloudOutbox`, encolando `.int(0)` al backend: borraría por LWW el registro
    /// GDPR de una cuenta VIVA y lo propagaría a sus otros devices. Por eso el wipe personal lo hace
    /// en el BOOT-HOOK (ya en `.icloud`) y no aquí.
    @Test func inSessionConsentClears_neverOnCloudModePaths() throws {
        let src = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
        // finalizeSessionExit (los cierres con grupos: «equipo» y solo grupos) + closeLocalAfterAccountDeletionGroupsOnly.
        #expect(src.components(separatedBy: "GroupsConsentState.clear()").count - 1 == 2)

        // Cada clear debe vivir en una de esas 3 funciones: la firma `func` más cercana hacia atrás
        // es la que lo contiene. Colarlo en `performCloudSecureSignOut` o en
        // `closeLocalAfterAccountDeletionCloud` pone este test rojo con el nombre del culpable.
        let allowed: Set<String> = [
            "finalizeSessionExit",
            "closeLocalAfterAccountDeletionGroupsOnly",
        ]
        var searchStart = src.startIndex
        while let hit = src.range(of: "GroupsConsentState.clear()", range: searchStart..<src.endIndex) {
            let before = src[src.startIndex..<hit.lowerBound]
            guard let funcKeyword = before.range(of: "func ", options: .backwards) else {
                Issue.record("GroupsConsentState.clear() fuera de toda función")
                break
            }
            let name = String(before[funcKeyword.upperBound...]
                .prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }))
            #expect(
                allowed.contains(name),
                "GroupsConsentState.clear() en `\(name)`: el consent solo se OLVIDA en los cierres solo-grupos. Hasta C1 la razón era mecánica (ese camino corre con `.cloud` persistido ⇒ `.cloudOutbox` ⇒ encolaba .int(0) y borraba el registro de una cuenta viva); hoy el clear es local puro y el grant del servidor no tiene delete, así que la razón es de PRODUCTO y sigue valiendo: un sign-out normal es «hasta luego», y olvidar el consent ahí obligaría a re-preguntarlo sin motivo.")
            searchStart = hit.upperBound
        }

    }

    /// **D-R1 paso 2: los paths de TEARDOWN leen la capacidad COMPILADA, nunca el getter compuesto.**
    /// El compuesto añade el kill remoto, y un kill apaga el CANAL sin borrar lo que ya subió al
    /// servidor ni retirar la copia local: un teardown gateado por él deja datos del usuario saliente en
    /// el device tras cerrar sesión y filas suyas en Supabase tras un borrado de cuenta. Peor aún, el
    /// término remoto ni siquiera es testigo de ese corpus — es fail-closed ante snapshot ausente o
    /// corrupto y depende del bucket de rollout.
    ///
    /// Es un source-scan y no un test de comportamiento a propósito: la decisión vive en QUÉ getter se
    /// lee, y los tests funcionales de estos caminos inyectan seams o fijan overrides, así que
    /// re-componer cualquiera de estas lecturas los dejaría a todos en verde.
    @Test func teardownPaths_readCompiledCapability_neverTheComposedGetter() throws {
        let signOut = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        // Los 5: dispatch del path, marker de los cierres por archivos (`finalizeSessionExit`), marker en
        // `.cloud`, marker post-borrado, pre-drain.
        #expect(signOut.components(separatedBy: "CloudSyncFlags.groupsBackendCompiledCapability").count - 1 == 5)
        #expect(!signOut.contains("CloudSyncFlags.groupsBackendEnabled"))

        // La UI que ofrece las filas tiene que resolver el path con la MISMA fuente que el dispatch, o
        // la hoja de alcance promete lo contrario de lo que va a pasar y desaparece la fila de escape.
        let profile = try Self.source("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains("groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability"))

        // Borrado de cuenta: el paso `groups_forget_user` es el que cumple la obligación GDPR.
        let deletion = try Self.source("Yala/Services/CloudSync/AccountDeletionService.swift")
        #expect(deletion.contains("groupsBackendEnabled: { CloudSyncFlags.groupsBackendCompiledCapability }"))
        #expect(!deletion.contains("{ CloudSyncFlags.groupsBackendEnabled }"))

        // Y su gate en el service: `forgetUser` por capacidad, TODO lo demás (las ENTRADAS) compuesto.
        let membership = try Self.source(
            "Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift")
        // UN solo call-site: `forgetUser`. Si aparece un segundo, alguien abrió otra ruta al kill.
        #expect(membership.components(separatedBy: "try ensureEligibleForTeardown()").count - 1 == 1)
        #expect(membership.contains("guard CloudSyncFlags.groupsBackendCompiledCapability, sessionCheck()"))
        #expect(membership.contains("guard CloudSyncFlags.groupsBackendEnabled, sessionCheck()"))
    }

    /// El guard del choke point es lo que cierra la ventana de los `Task` no estructurados en vuelo.
    /// Debe evaluarse en TODOS los emisores — programado (`scheduleNotification`), inmediato
    /// (`sendNotification`, → Bool) y resumen agendado (`replaceScheduledPaymentSummaries`,
    /// por-iteración) — y NO incluir el arm de solo-grupos. Cada emisor se pinnea con su forma
    /// de salida exacta: si uno cambia de forma (o aparece otro), este conteo lo delata.
    @Test func chokePointGuard_coversBothEmitters_andExcludesGroupsOnlyArm() throws {
        let src = try Self.source("Yala/Services/NotificationService.swift")
        #expect(src.components(separatedBy: "guard !isPersonalWipeArmed else { return }").count - 1 == 1)
        #expect(src.components(separatedBy: "guard !isPersonalWipeArmed else { return false }").count - 1 == 1)
        #expect(src.components(separatedBy: "guard !isPersonalWipeArmed else { break }").count - 1 == 1)
        #expect(src.contains("StorageModePersistence.isSignOutWipeArmed()"))
        // El camino solo-grupos conserva los recordatorios personales: su arm JAMÁS entra al guard.
        #expect(!src.contains("isGroupsOnlyWipeArmed"))
    }
}
