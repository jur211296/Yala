//
//  RetryAfterFailedMigrationWipeMarkTests.swift
//  YalaTests / CloudSync
//
//  Ticket `retry-after-a-failed-migration-resumes-the-pending-icloud-wipe-blindly` (opción A de Jürgen, 2026-10-12).
//  El ciclo de vida de la marca «este borrado armado sobrevivió a una ida fallida»: sub-estado del arm, se escribe solo
//  con él y se va con él o cuando la persona vuelve a confirmar. Quién la escribe (la salida de `failedRollback`) lo fija
//  la §9d de `MigrationRunnerTests`; que el arranque la lea, el scan de `PendingICloudWipeCloudTests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("«Reintentar» y el borrado pendiente · la marca")
struct RetryAfterFailedMigrationWipeMarkTests {

    @Test func withoutAnArm_nothingIsMarked() {
        let d = makeIsolatedDefaults()
        StorageModePersistence.markICloudCorpusWipeCrossedFailedMigration(d)
        #expect(!StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d))
    }

    @Test func withAnArm_itIsMarked() {
        let d = makeIsolatedDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeCrossedFailedMigration(d)
        #expect(StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d))
    }

    /// Cada salida del arm se la lleva: «Déjalo así», quedar «a medias», retirarlo en la nube con o sin renuncia.
    @Test(arguments: ["clear", "halfway", "disarmFailed", "cancelInCloud", "retireWaived"])
    func everyExitOfTheArm_dropsTheMark(exit: String) {
        let d = makeIsolatedDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeCrossedFailedMigration(d)
        switch exit {
        case "clear": StorageModePersistence.clearICloudCorpusWipeArm(d)
        case "halfway": StorageModePersistence.leaveICloudCorpusWipeHalfway(d)
        case "disarmFailed": StorageModePersistence.disarmFailedICloudCorpusWipe(d)
        case "cancelInCloud": StorageModePersistence.cancelPendingICloudCorpusWipeInTheCloud(d)
        default: StorageModePersistence.retirePendingICloudCorpusWipeAsWaived(d)
        }
        #expect(!StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d), "\(exit)")
    }

    /// Volver a armar es la persona confirmando AHORA («Borrar» del aviso, la puerta): un kill a mitad de ESE borrado se
    /// reanuda como cualquier otro, así que la marca de la ida vieja no sobrevive.
    @Test func reArming_dropsTheMark_andTheLaunchResumesAgain() {
        let d = makeIsolatedDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.markICloudCorpusWipeCrossedFailedMigration(d)
        StorageModePersistence.armICloudCorpusWipe(d)
        #expect(!StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d))
        #expect(WelcomePrivateICloudGateLogic.lateWipeLaunch(
            armed: true, leftHalfway: false, cancelledInCloudNoticePending: false, waivedForCloud: false,
            migrationAtRest: true, migrationFailedAndSettled: false,
            armCrossedFailedMigration: StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d),
            storageMode: .icloud) == .resume)
    }

    /// La caducidad de la renuncia no toca la marca: tras «Reintentar», caduca la renuncia y la marca sigue preguntando.
    @Test func waiverLapse_keepsTheMark() {
        let d = makeIsolatedDefaults()
        StorageModePersistence.armICloudCorpusWipe(d)
        StorageModePersistence.waivePendingICloudCorpusWipeForTheCloud(d)
        StorageModePersistence.markICloudCorpusWipeCrossedFailedMigration(d)
        StorageModePersistence.clearICloudCorpusWipeWaiver(d)
        #expect(StorageModePersistence.hasICloudCorpusWipeCrossedFailedMigration(d))
    }
}
