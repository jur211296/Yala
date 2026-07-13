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
}
