//
//  StorageModePersistenceTests.swift
//  YalaTests / CloudSync
//
//  Persistencia del `StorageMode` (I10-wiring w6) + la decisión PURA de montaje del store personal
//  (`personalStoreDecision`) — la rama `.cloud` del §g.4 sin construir el config (isRunningTests fuerza
//  in-memory y ocultaría la rama real). UserDefaults aislado (regla del repo).
//

import Foundation
import Testing

@testable import Yala

@Suite("StorageMode · persistencia + decisión de montaje (I10-wiring w6)")
struct StorageModePersistenceTests {

    // MARK: - StorageModePersistence round-trip + default

    @Test func read_default_isICloud() {
        let defaults = makeIsolatedDefaults(prefix: "sm.default")
        #expect(StorageModePersistence.read(defaults) == .icloud)
    }

    @Test func write_thenRead_roundTrips() {
        let defaults = makeIsolatedDefaults(prefix: "sm.rt")
        StorageModePersistence.write(.cloud, defaults: defaults)
        #expect(StorageModePersistence.read(defaults) == .cloud)
        StorageModePersistence.write(.icloud, defaults: defaults)
        #expect(StorageModePersistence.read(defaults) == .icloud)
    }

    @Test func read_unknownRawValue_isICloud() {
        let defaults = makeIsolatedDefaults(prefix: "sm.unknown")
        defaults.set("marte", forKey: StorageModePersistence.key)
        #expect(StorageModePersistence.read(defaults) == .icloud)
    }

    // MARK: - C-1: el par (.cloud + mirror-off ARMADO) — escritor único e INVARIANTE

    @Test func writeCloudArmed_writesBothKeys_inASingleCall() {
        let defaults = makeIsolatedDefaults(prefix: "sm.armed")
        // Punto de partida = device virgen: ninguna de las dos keys existe.
        #expect(StorageModePersistence.read(defaults) == .icloud)
        #expect(!StorageModePersistence.isMirrorOffArmed(defaults))

        StorageModePersistence.writeCloudArmed(defaults: defaults)

        // Pinnea que el escritor ÚNICO deja el par COMPLETO con UNA llamada. Antes de C-1 el adopt escribía
        // las dos keys por separado, así que un olvido en un camino nuevo (o un refactor que moviera una
        // sola) dejaba `.cloud` con el mirror vivo — el estado de doble escritura.
        #expect(StorageModePersistence.read(defaults) == .cloud)
        #expect(StorageModePersistence.isMirrorOffArmed(defaults))
        // Y por tanto el invariante queda SANO tras la llamada (no hay ventana observable de par a medias).
        #expect(!StorageModePersistence.isCloudWithMirrorOn(defaults))
    }

    @Test func isCloudWithMirrorOn_icloudMode_isFalse_regardlessOfArmedFlag() {
        // NO-REGRESIÓN del vector C: con el modo persistido `.icloud` —el estado de TODO device de 2.x— el
        // invariante es `false` con el flag de armado en `true` Y en `false`. Es la prueba de que el gate
        // nuevo del motor (`MigrationRuntimeGate.canRun`) JAMÁS puede dispararse en un device 2.x: su
        // segundo término nace `false` por construcción, así que el gate es INERTE y el comportamiento de
        // los usuarios actuales no cambia. Si alguien reescribe `isCloudWithMirrorOn` mirando solo el flag
        // de armado (residuo de un intento previo de migración), este test es el que lo caza.
        for armed in [true, false] {
            let defaults = makeIsolatedDefaults(prefix: "sm.inv.icloud")
            StorageModePersistence.write(.icloud, defaults: defaults)
            defaults.set(armed, forKey: StorageModePersistence.mirrorOffArmedKey)
            #expect(!StorageModePersistence.isCloudWithMirrorOn(defaults), "armado=\(armed)")
        }
        // Device virgen (ninguna key escrita ⇒ `.icloud` por ausencia): también `false`.
        #expect(!StorageModePersistence.isCloudWithMirrorOn(makeIsolatedDefaults(prefix: "sm.inv.virgin")))
    }

    @Test func isCloudWithMirrorOn_onlyTrueForCloudAndNotArmed() {
        // Tabla completa (modo × armado). El ÚNICO `true` es `.cloud` + NO armado = "el mirror de CloudKit
        // sigue vivo en modo nube": legítimo y transitorio durante la ventana de export del cutover (pasos
        // 2→4) y toda la reversa post-mount, PROHIBIDO en fase estable. "No armado" se modela como key
        // AUSENTE porque así es en producción (el desarme real es `removeObject`, nadie escribe `false`).
        for mode in [StorageMode.icloud, .cloud] {
            for armed in [true, false] {
                let defaults = makeIsolatedDefaults(prefix: "sm.inv.table")
                StorageModePersistence.write(mode, defaults: defaults)
                if armed {
                    defaults.set(true, forKey: StorageModePersistence.mirrorOffArmedKey)
                } else {
                    defaults.removeObject(forKey: StorageModePersistence.mirrorOffArmedKey)
                }
                #expect(StorageModePersistence.isCloudWithMirrorOn(defaults) == (mode == .cloud && !armed),
                        "modo=\(mode.rawValue) armado=\(armed)")
            }
        }
        // Un `false` EXPLÍCITO en la key equivale a la ausencia (`bool(forKey:)` colapsa ambos) — por si un
        // camino futuro desarma escribiendo `false` en vez de borrando.
        let explicitFalse = makeIsolatedDefaults(prefix: "sm.inv.explicitFalse")
        StorageModePersistence.write(.cloud, defaults: explicitFalse)
        explicitFalse.set(false, forKey: StorageModePersistence.mirrorOffArmedKey)
        #expect(StorageModePersistence.isCloudWithMirrorOn(explicitFalse))
    }

    // MARK: - personalStoreDecision (rama pura, R9 + SERIO 1)

    @Test func decision_cloudArmed_winsBeforeICloudCheck() {
        // `.cloud` ARMADO gana AUNQUE haya iCloud (Grupos la usa, pero el store personal ya no lo espeja).
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true) == .cloudMirrorOff)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: false) == .cloudMirrorOff)
    }

    @Test func decision_cloudNotArmed_keepsMirrorOn_killWindowRecovery() {
        // SERIO 1 (review adversarial): `.cloud` SIN armar (kill involuntario entre persistLocalMode y
        // el export del marcador) → el mirror REMONTA — el marcador puede exportar en el resume; sin
        // esto la migración quedaba enclavada en markerWritten para siempre.
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: false, iCloudAvailable: true) == .iCloudMirror)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: false, iCloudAvailable: false) == .localNoMirror)
    }

    @Test func decision_icloud_dependsOnAvailability_armedIrrelevant() {
        // En `.icloud` el flag de armado es irrelevante (residuo de un intento anterior no cambia nada).
        for armed in [true, false] {
            #expect(SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: armed, iCloudAvailable: true) == .iCloudMirror)
            #expect(SwiftDataConfiguration.personalStoreDecision(
                storageMode: .icloud, mirrorOffArmed: armed, iCloudAvailable: false) == .localNoMirror)
        }
    }

    // MARK: - M1 sesión secundaria (gana ANTES que todo; jamás `.private`)

    @Test func decision_secondaryActive_winsOverEverything() {
        // Las 8 combinaciones de (storageMode × mirrorOffArmed × iCloudAvailable): el descriptor
        // secundario gana SIEMPRE — el archivo del dueño ni se toca y el mirror jamás se adjunta.
        for mode in [StorageMode.icloud, .cloud] {
            for armed in [true, false] {
                for icloud in [true, false] {
                    #expect(SwiftDataConfiguration.personalStoreDecision(
                        storageMode: mode, mirrorOffArmed: armed, iCloudAvailable: icloud,
                        secondarySessionActive: true) == .secondaryCloudSession)
                }
            }
        }
    }

    @Test func decision_secondaryInactive_legacyTableIntact() {
        // Con el param explícito en `false`, la tabla legacy es EXACTAMENTE la de siempre
        // (regresión del dueño — los otros tests cubren el default omitido).
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: true, iCloudAvailable: true,
            secondarySessionActive: false) == .cloudMirrorOff)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .cloud, mirrorOffArmed: false, iCloudAvailable: true,
            secondarySessionActive: false) == .iCloudMirror)
        #expect(SwiftDataConfiguration.personalStoreDecision(
            storageMode: .icloud, mirrorOffArmed: false, iCloudAvailable: false,
            secondarySessionActive: false) == .localNoMirror)
    }

    @Test func secondaryStoreNames_deriveFromOwnerNames() {
        // Nombre FIJO (1 slot) derivado del databaseName ⇒ hereda la variante -Dev del build.
        #expect(SwiftDataConfiguration.secondaryDatabaseName
            == SwiftDataConfiguration.databaseName + "-Secondary")
        #expect(SwiftDataConfiguration.secondarySyncMetaDatabaseName
            == SwiftDataConfiguration.syncMetaDatabaseName + "-Secondary")
        // Los tríos de archivos jamás colisionan con los del dueño.
        #expect(SwiftDataConfiguration.secondaryDatabaseName != SwiftDataConfiguration.databaseName)
        #expect(SwiftDataConfiguration.secondarySyncMetaDatabaseName
            != SwiftDataConfiguration.syncMetaDatabaseName)
        #expect(SwiftDataConfiguration.secondarySyncMetaDatabaseName.contains("YalaSyncMeta"))
    }

    // MARK: - GroupsStoreDecision (M1 / D8 — G5-C, tabla flag × secundaria)

    @Test func groupsDecision_secondaryOnlyWhenFlagOnAndSecondaryActive() {
        // Único caso `.secondary`: flag ON Y sesión secundaria activa.
        #expect(SwiftDataConfiguration.GroupsStoreDecision.decide(
            flagOn: true, secondaryActive: true) == .secondary)
        // Los otros 3 casos → `.primary` (byte-idéntico a hoy; flag OFF = TODO device prod).
        #expect(SwiftDataConfiguration.GroupsStoreDecision.decide(
            flagOn: false, secondaryActive: true) == .primary)
        #expect(SwiftDataConfiguration.GroupsStoreDecision.decide(
            flagOn: true, secondaryActive: false) == .primary)
        #expect(SwiftDataConfiguration.GroupsStoreDecision.decide(
            flagOn: false, secondaryActive: false) == .primary)
    }

    @Test func secondaryGroupsStoreName_derivesFromGroupsName() {
        #expect(SwiftDataConfiguration.secondaryGroupsDatabaseName
            == SwiftDataConfiguration.groupsDatabaseName + "-Secondary")
        // Jamás colisiona con el store de grupos del dueño ni con el personal secundario.
        #expect(SwiftDataConfiguration.secondaryGroupsDatabaseName
            != SwiftDataConfiguration.groupsDatabaseName)
        #expect(SwiftDataConfiguration.secondaryGroupsDatabaseName
            != SwiftDataConfiguration.secondaryDatabaseName)
        #expect(SwiftDataConfiguration.secondaryGroupsDatabaseName.contains("YalaGroups"))
    }
}
