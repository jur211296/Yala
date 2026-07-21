//
//  SecondaryBoundaryHooksTests.swift
//  YalaTests / CloudSync
//
//  Hooks de frontera de la sesión secundaria (M1 Inc 2) — kill-safety del wipe de SALIDA
//  (patrón S3: abort si el archivo BASE falla, arm persiste, reintento completa) y one-shot
//  idempotente de la ENTRADA (purga + healing de flags, marker AL FINAL). Variantes inyectables:
//  ni archivos reales ni NotificationCenter. UserDefaults aislado (regla del repo).
//

import Foundation
import Testing

@testable import Yala

@Suite("SecondaryBoundaryHooks · wipe de salida (M1 Inc 2)")
struct SecondaryWipeHookTests {

    private func armedDefaults(prefix: String) -> UserDefaults {
        let defaults = makeIsolatedDefaults(prefix: prefix)
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        SecondarySessionStore.markEntryPurgeDone(defaults)
        SecondarySessionStore.armWipe(defaults)
        // Estado de una sesión secundaria viva: flags de onboarding puestos.
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(true, forKey: "hasShownWelcomeChooser")
        return defaults
    }

    @Test func notArmed_isNoOp() {
        let defaults = makeIsolatedDefaults(prefix: "swipe.noop")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        var touched = false
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in touched = true; return true },
            purge: { touched = true },
            cancelNotifications: { touched = true })
        #expect(touched == false)
        #expect(SecondarySessionStore.isActive(defaults))
    }

    @Test func baseDeleteFails_abortsPreservingArmAndDescriptor() {
        let defaults = armedDefaults(prefix: "swipe.abort")
        var purged = false
        var cancels = 0
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { _, _ in false },   // kill-simulado: el BASE no se pudo borrar
            purge: { purged = true },
            cancelNotifications: { cancels += 1 })
        // NADA más se limpió: arm + descriptor persisten (el próximo boot reintenta),
        // los flags de onboarding siguen puestos y la purga no corrió.
        #expect(purged == false)
        // El abort NO cancela: la sesión secundaria sigue montada y sus recordatorios vivos.
        #expect(cancels == 0)
        #expect(SecondarySessionStore.isWipeArmed(defaults))
        #expect(SecondarySessionStore.isActive(defaults))
        #expect(defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding))
    }

    @Test func retryAfterAbort_completesFullOrder_armClearedLast() {
        let defaults = armedDefaults(prefix: "swipe.retry")
        // 1ª pasada: abort.
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in false }, purge: {})
        // 2ª pasada (reintento del boot siguiente): completa en ORDEN.
        var events: [String] = []
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in events.append("delete:\(name)"); return true },
            purge: { events.append("purge") },
            cancelNotifications: { events.append("cancelNotifications") })
        #expect(events == [
            "delete:\(SwiftDataConfiguration.secondaryDatabaseName)",
            "delete:\(SwiftDataConfiguration.secondarySyncMetaDatabaseName)",
            "delete:\(SwiftDataConfiguration.secondaryGroupsDatabaseName)",  // M1/D8 (G5-C): grupos tras syncMeta
            "purge",
            // §5.2.1: las notificaciones de la INVITADA no sobreviven a la vuelta del dueño. Dejar
            // `pending == 0` es además lo que hace al reconciler de boot reprogramar las de él.
            "cancelNotifications",
        ])
        #expect(SecondarySessionStore.isActive(defaults) == false)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults) == false)
        #expect(SecondarySessionStore.isWipeArmed(defaults) == false)
        // 3.5: flags de onboarding reseteados EN EL BOOT → el device vuelve al Welcome.
        #expect(defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) == false)
        #expect(defaults.bool(forKey: "hasShownWelcomeChooser") == false)
    }

    @Test func wipe_includesGroupsStore_neverTouchesOwnerStores() {
        // M1 / D8 (G5-C): el wipe de salida borra el store de GRUPOS secundario (tras personal y sync-meta)
        // y JAMÁS toca los stores del DUEÑO (personal ni grupos).
        let defaults = armedDefaults(prefix: "swipe.groups")
        var deleted: [String] = []
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults,
            deleteFiles: { name, _ in deleted.append(name); return true },
            purge: {})
        #expect(deleted == [
            SwiftDataConfiguration.secondaryDatabaseName,
            SwiftDataConfiguration.secondarySyncMetaDatabaseName,
            SwiftDataConfiguration.secondaryGroupsDatabaseName,
        ])
        #expect(!deleted.contains(SwiftDataConfiguration.databaseName))         // YalaModel del dueño intacto
        #expect(!deleted.contains(SwiftDataConfiguration.groupsDatabaseName))   // YalaGroups del dueño intacto
    }

    @Test func neverTouchesOwnerStorageModeKeys() {
        let defaults = armedDefaults(prefix: "swipe.owner")
        // Estado del dueño simulado: modo persistido explícito.
        StorageModePersistence.write(.icloud, defaults: defaults)
        SwiftDataConfiguration.performSecondaryWipeIfArmed(
            defaults: defaults, deleteFiles: { _, _ in true }, purge: {})
        // Las keys del dueño NI se leen ni se escriben: el modo persiste tal cual y el
        // arm del wipe del DUEÑO jamás aparece.
        #expect(StorageModePersistence.read(defaults) == .icloud)
        #expect(StorageModePersistence.isSignOutWipeArmed(defaults) == false)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults) == false)
    }
}

@Suite("SecondaryBoundaryHooks · tareas de entrada (M1 Inc 2)")
struct SecondaryEntryTasksTests {

    @Test func inactive_isNoOp() {
        let defaults = makeIsolatedDefaults(prefix: "sentry.noop")
        var purges = 0
        var cancels = 0
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: { purges += 1 }, cancelNotifications: { cancels += 1 })
        #expect(purges == 0)
        #expect(cancels == 0)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults) == false)
    }

    /// El invariante kill-safe (no el orden purge↔cancel, que son efectos independientes): la
    /// cancelación corre ANTES de `markEntryPurgeDone`, de modo que un kill entre ambos la re-ejecuta
    /// en el siguiente boot. Si el marker se pusiera primero, las notificaciones del dueño sobrevivirían
    /// a la entrada de la invitada sin que nada lo reintentara.
    @Test func cancelRunsBeforeEntryMarker() {
        let defaults = makeIsolatedDefaults(prefix: "sentry.order")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        var markerWasSetAtCancel = true
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults,
            purge: {},
            cancelNotifications: { markerWasSetAtCancel = SecondarySessionStore.isEntryPurgeDone(defaults) })
        #expect(markerWasSetAtCancel == false)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults))
    }

    @Test func active_runsOnce_marksAtEnd_andIsIdempotent() {
        let defaults = makeIsolatedDefaults(prefix: "sentry.once")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        var purges = 0
        var cancels = 0
        let run = {
            SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
                defaults: defaults, purge: { purges += 1 }, cancelNotifications: { cancels += 1 })
        }
        run()
        #expect(purges == 1 && cancels == 1)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults))
        // Re-boot: el marker lo hace no-op.
        run()
        #expect(purges == 1 && cancels == 1)
    }

    @Test func killBeforeMarker_rerunsFullPurge() {
        let defaults = makeIsolatedDefaults(prefix: "sentry.kill")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        var purges = 0
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: { purges += 1 }, cancelNotifications: {})
        // Kill-simulado ANTES del marker: lo borramos como si el proceso hubiera muerto
        // entre la purga y el marker → el boot siguiente re-purga completo.
        SecondarySessionStore.clearEntryPurgeMark(defaults)
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: { purges += 1 }, cancelNotifications: {})
        #expect(purges == 2)
    }

    @Test func healing_writesFlags_onlyWhenMissing() {
        // Kill entre descriptor y flags (ventana 2→3 de la entrada): el healing los escribe.
        let defaults = makeIsolatedDefaults(prefix: "sentry.heal")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: {}, cancelNotifications: {})
        #expect(defaults.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding))
        #expect(defaults.bool(forKey: "hasShownWelcomeChooser"))
    }

    @Test func healing_skipsWhenFlagsPresent() {
        // Entrada normal (los flags los puso el paso 3): el healing NO re-escribe nada —
        // hasShownWelcomeChooser conserva su valor real.
        let defaults = makeIsolatedDefaults(prefix: "sentry.nohealing")
        SecondarySessionStore.activate(userID: "guest-1", defaults)
        defaults.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        defaults.set(false, forKey: "hasShownWelcomeChooser")
        SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded(
            defaults: defaults, purge: {}, cancelNotifications: {})
        #expect(defaults.bool(forKey: "hasShownWelcomeChooser") == false)
    }
}
