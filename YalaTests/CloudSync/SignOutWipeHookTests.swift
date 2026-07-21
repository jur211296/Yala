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

    /// Los 3 wrappers que borran o abandonan el store PERSONAL cablean el barrido total.
    @Test func bootHooks_wirePersonalNotificationCleanup() throws {
        let src = try Self.source("Yala/Utils/SwiftDataConfiguration.swift")
        // performSignOutWipeIfArmed + performSecondaryWipeIfArmed (salida) + performSecondaryEntryTasksIfNeeded.
        #expect(src.components(separatedBy: "NotificationService.shared.cancelAllNotifications()").count - 1 == 3)
        #expect(src.components(separatedBy: "NotificationService.shared.clearDeliveredNotifications()").count - 1 == 3)
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
        let nextMarker = "// MARK: - Sesión secundaria (M1)"
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
        // performSignOutWipeIfArmed cablea el helper compartido; los 2 hooks M1 lo obtienen dentro
        // de `SecondarySessionBoundaryPurge.purge()` (su propio seam `purge:`, ya pinneado aparte).
        #expect(src.contains("purgeInboundSurfaces: { AppGroupInboundPurge.purgeInboundSurfaces() }"))
        #expect(src.components(separatedBy: "AppGroupInboundPurge.purgeInboundSurfaces()").count - 1 == 1)
        #expect(src.components(separatedBy: "SecondarySessionBoundaryPurge.purge()").count - 1 == 2)

        // El SSOT compartido: si alguien inlinea las colas en un caller, esta invariante lo delata.
        let purge = try Self.source("Yala/Services/CloudSync/SecondarySessionBoundaryPurge.swift")
        #expect(purge.contains("AppGroupInboundPurge.purgeInboundSurfaces()"))
        #expect(!purge.contains("ApplePayPendingStore"))
        #expect(!purge.contains("SiriPendingStore"))
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
    /// añadirla a `performPrivateReset` o a un camino solo-grupos borraría recordatorios vivos y
    /// vaciaría el widget de un store que sobrevive.
    /// 4 ocurrencias = 1 definición + 3 call-sites (cloud / secundario / cierre post-borrado de cuenta).
    @Test func inSessionLayer_wiredOnlyOnArmedPersonalWipePaths() throws {
        let src = try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(src.components(separatedBy: "clearLocalSurfacesForArmedWipe()").count - 1 == 4)
        // El widget vive en el mismo helper A PROPÓSITO: es la otra superficie del SISTEMA que sigue
        // mostrando la cuenta cerrada hasta el relanzamiento, y comparte los 3 call-sites exactos.
        #expect(src.components(separatedBy: "WidgetDataCache.clearCache()").count - 1 == 1)
        // El clear selectivo de grupos vive en el cierre solo-grupos, donde hay `await` disponible
        // (el boot-hook solo puede encolarlo en un Task que el arm ya limpiado no respalda).
        #expect(src.contains("await NotificationService.shared.clearDeliveredGroupNotifications()"))
    }

    /// El guard del choke point es lo que cierra la ventana de los `Task` no estructurados en vuelo.
    /// Debe evaluarse en AMBOS emisores (programado e inmediato) y NO incluir el arm de solo-grupos.
    @Test func chokePointGuard_coversBothEmitters_andExcludesGroupsOnlyArm() throws {
        let src = try Self.source("Yala/Services/NotificationService.swift")
        #expect(src.components(separatedBy: "guard !isPersonalWipeArmed else { return }").count - 1 == 2)
        #expect(src.contains("StorageModePersistence.isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()"))
        // El camino solo-grupos conserva los recordatorios personales: su arm JAMÁS entra al guard.
        #expect(!src.contains("isGroupsOnlyWipeArmed"))
    }
}
