//
//  BugsCuentaNubeLogicTests.swift
//  YalaTests / BugsCuentaNube
//
//  Bugs de cuenta (25-nov-2026, reportados por Jürgen en Yala Dev 2.3 (9)):
//   A · tras «Vaciar datos» en una cuenta de Yala, banner «Inicia sesión para subir 7,383 cambios» y esqueleto del Panel
//       pegado, también al reabrir. Medido en el iPhone 14: 7.166 cambios en la cola, subidos todos antes de la primera
//       bajada con un solo token; el esqueleto espera esa bajada (62 s, su techo).
//   B · sin sesión, «Eliminar mi cuenta» desaparecía en modo nube.
//   C · en un teléfono que tuvo Yala antes de 2.3, una cuenta nueva no veía Primeros pasos (en ningún modo).
//

import Foundation
import Testing

@testable import Yala

// MARK: - A · la cola grande

@Suite("Bugs cuenta nube · A · altas que una baja deja sin efecto")
struct OutboxSupersededUpsertsTests {

    private typealias E = SyncOutboxBacklogLogic.Entry
    private let a = UUID(), b = UUID(), c = UUID()

    /// El caso medido: alta y baja de la misma fila, las dos pendientes. Sale el alta; la baja se queda.
    @Test func upsertThenTombstone_dropsTheUpsert_keepsTheTombstone() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: false),
                       E(key: 2, syncID: a, hlc: "h2", isTombstone: true)]
        #expect(SyncOutboxBacklogLogic.supersededUpserts(entries) == [AnyHashable(1)])
    }

    /// La última operación es un alta (una baja deshecha): no se toca nada.
    @Test func tombstoneThenUpsert_keepsBoth() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: true),
                       E(key: 2, syncID: a, hlc: "h2", isTombstone: false)]
        #expect(SyncOutboxBacklogLogic.supersededUpserts(entries).isEmpty)
    }

    /// Solo bajas, o solo altas, o filas distintas: nada sobra.
    @Test func withoutAPairOnTheSameRow_nothingIsDropped() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: false),
                       E(key: 2, syncID: b, hlc: "h2", isTombstone: true),
                       E(key: 3, syncID: c, hlc: "h3", isTombstone: false)]
        #expect(SyncOutboxBacklogLogic.supersededUpserts(entries).isEmpty)
    }

    /// Varias altas antes de la baja: salen todas; un alta POSTERIOR a la baja se queda.
    @Test func severalUpserts_onlyThoseBeforeTheLastTombstone() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: false),
                       E(key: 2, syncID: a, hlc: "h2", isTombstone: false),
                       E(key: 3, syncID: a, hlc: "h3", isTombstone: true),
                       E(key: 4, syncID: b, hlc: "h4", isTombstone: false)]
        #expect(Set(SyncOutboxBacklogLogic.supersededUpserts(entries)) == [AnyHashable(1), AnyHashable(2)])
    }

    /// Alta, baja y otra alta de la misma fila: sale la primera; la posterior a la baja se queda.
    @Test func upsertTombstoneUpsert_dropsOnlyTheOneBeforeTheTombstone() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: false),
                       E(key: 2, syncID: a, hlc: "h2", isTombstone: true),
                       E(key: 3, syncID: a, hlc: "h3", isTombstone: false)]
        #expect(SyncOutboxBacklogLogic.supersededUpserts(entries) == [AnyHashable(1)])
    }

    /// Mismo instante: la baja cuenta como la última (el borrado gana).
    @Test func sameHLC_theTombstoneWins() {
        let entries = [E(key: 1, syncID: a, hlc: "h1", isTombstone: false),
                       E(key: 2, syncID: a, hlc: "h1", isTombstone: true)]
        #expect(SyncOutboxBacklogLogic.supersededUpserts(entries) == [AnyHashable(1)])
    }
}

@Suite("Bugs cuenta nube · A · tope de subida antes de la primera bajada")
struct FirstPullPushCapTests {

    @Test func beforeTheFirstPull_onlyTwoChunks() {
        #expect(SyncOutboxBacklogLogic.uploadsChunk(0, firstPullCompleted: false))
        #expect(SyncOutboxBacklogLogic.uploadsChunk(1, firstPullCompleted: false))
        #expect(!SyncOutboxBacklogLogic.uploadsChunk(2, firstPullCompleted: false))
        #expect(!SyncOutboxBacklogLogic.uploadsChunk(143, firstPullCompleted: false))
    }

    @Test func afterTheFirstPull_noCap() {
        #expect(SyncOutboxBacklogLogic.uploadsChunk(2, firstPullCompleted: true))
        #expect(SyncOutboxBacklogLogic.uploadsChunk(143, firstPullCompleted: true))
    }
}

@Suite("Bugs cuenta nube · A · el esqueleto no espera a un motor parado hasta iniciar sesión")
struct PanelWaitSkipsEngineWaitingForSignInTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// El estado roto del bug A: modo nube, sin primera bajada, sin cuentas. Con el motor esperando la sesión no hay
    /// esqueleto; el control (motor que sí baja) espera, como antes.
    @Test func idleWaitDoesNotStart_whenTheEngineWaitsForSignIn() {
        let waiting = PanelAccountDataWait.idle.next(
            hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false, attestVerdictIsTerminal: false,
            engineWaitsForSignIn: true, now: now)
        #expect(waiting == .idle)
        let control = PanelAccountDataWait.idle.next(
            hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false, attestVerdictIsTerminal: false,
            engineWaitsForSignIn: false, now: now)
        #expect(control == .waiting(since: now))
    }

    /// Una espera ya empezada se suelta en cuanto el motor pasa a esperar la sesión (el 401 a mitad de subida).
    @Test func runningWaitEnds_whenTheEngineStartsWaitingForSignIn() {
        let next = PanelAccountDataWait.waiting(since: now).next(
            hasAccounts: false, cloudEngineActive: true, firstPullCompleted: false, attestVerdictIsTerminal: false,
            engineWaitsForSignIn: true, now: now.addingTimeInterval(5))
        #expect(next == .idle)
    }
}

// MARK: - B · «Eliminar mi cuenta» en toda cuenta en la nube

@Suite("Bugs cuenta nube · B · la fila de eliminar cuenta")
@MainActor
struct DeleteAccountRowCloudTests {

    @Test func visible_withSession_orWithTheDataInTheCloud() {
        #expect(AccountDeletionRowLogic.shouldShow(hasSession: true, storageIsCloud: false))
        #expect(AccountDeletionRowLogic.shouldShow(hasSession: true, storageIsCloud: true))
        // El caso del bug: modo nube con la sesión perdida.
        #expect(AccountDeletionRowLogic.shouldShow(hasSession: false, storageIsCloud: true))
        // Sin sesión y en iCloud privado: esta fila no (esa celda tiene la suya, `offersICloudAccountDeletion`).
        #expect(!AccountDeletionRowLogic.shouldShow(hasSession: false, storageIsCloud: false))
    }

    @Test func signInFirst_onlyInTheCloudWithoutSession() {
        #expect(AccountDeletionRowLogic.needsSignInBeforeDeleting(hasSession: false, storageIsCloud: true))
        #expect(!AccountDeletionRowLogic.needsSignInBeforeDeleting(hasSession: true, storageIsCloud: true))
        #expect(!AccountDeletionRowLogic.needsSignInBeforeDeleting(hasSession: false, storageIsCloud: false))
    }

    /// Sin proveedor guardado y sin dueño en memoria (la sesión se cerró en local), la puerta firma con el del faro, no con
    /// Apple a ciegas. Con proveedor guardado, el guardado, como siempre.
    @Test func signInDoor_withoutStoredProvider_usesTheBeaconOne() {
        #expect(SyncSignInBannerLogic.provider(stored: nil, beaconProvider: "google", beaconHash: CloudBeacon.hash("a"),
                                               ownerUserID: nil) == .google)
        #expect(SyncSignInBannerLogic.provider(stored: "apple", beaconProvider: "google", beaconHash: CloudBeacon.hash("a"),
                                               ownerUserID: nil) == .apple)
        #expect(SyncSignInBannerLogic.provider(stored: nil, beaconProvider: nil, beaconHash: nil, ownerUserID: nil) == .apple)
    }

    /// La pantalla «Tu cuenta de Yala» ofrece la salida con el mismo término.
    @Test func yalaAccountModel_offersDelete_inTheCloudWithoutSession() {
        let model = YalaAccountLogic.model(
            provider: "google", storageMode: .cloud,
            canDeleteAccount: AccountDeletionRowLogic.shouldShow(hasSession: false, storageIsCloud: true),
            hasPrivateSession: false)
        #expect(model.exits.contains(.deleteAccount))
    }
}

// MARK: - C · Primeros pasos en un teléfono que tuvo Yala antes de 2.3

@Suite("Bugs cuenta nube · C · la marca de instalación nueva", .serialized)
@MainActor
struct PrimerosPasosMarkTests {

    private func defaults() throws -> UserDefaults {
        try #require(testDefaults(suiteName: "BugsCuentaNube.C.\(UUID().uuidString)"))
    }

    /// El teléfono de Jürgen: Yala desde antes de 2.3 ⇒ `.pinnedLegacy` y sin la marca. Terminar el alta la pone.
    @Test func legacyPhone_finishingTheWelcome_marksTheInstallAsNew() throws {
        let d = try defaults()
        d.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        #expect(TabBarDefaultsMigration.runIfNeeded(defaults: d) == .pinnedLegacy)
        #expect(!TabBarDefaultsMigration.isFreshInstall(defaults: d))
        TabBarDefaultsMigration.markStartedWithWelcome23(defaults: d)
        #expect(TabBarDefaultsMigration.isFreshInstall(defaults: d))
        // La barra que el arranque dejó escrita no se toca.
        #expect(d.string(forKey: TabBarConfiguration.storageKey) == TabBarConfiguration.legacyDefault.toJSON())
    }

    /// Solo un alta nueva marca: la re-entrada (volver con sus datos) no.
    @Test func onlyAFreshEntryMarks() {
        #expect(EntryOnboardingEffects.marksNewInstall(.freshInstall))
        #expect(!EntryOnboardingEffects.marksNewInstall(.reentry))
    }
}
