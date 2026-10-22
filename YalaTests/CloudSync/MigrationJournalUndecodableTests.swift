//
//  MigrationJournalUndecodableTests.swift
//  YalaTests
//
//  Ticket `an-undecodable-migration-phase-reads-as-never-started`. Su padre (`an-unreadable-migration-journal-reads-as-
//  never-started`) cerró el `fetch` que lanza. Este cierra la fila que SÍ se lee pero no se entiende: una fase, unos
//  pendientes o unos pendientes del origen que este build no decodifica —en la práctica, un downgrade desde uno con un
//  case nuevo—. Hasta este ticket los dos lectores devolvían el `.notStarted` y el `[]` de relleno de `MigrationState`,
//  la fase estable más ancha.
//
//  Cada caso va con su CONTROL positivo: la misma fila con los blobs legibles da su fase. Sin él, «es `.unreadable`» se
//  cumpliría con un lector que no leyera nunca nada. El runner se mide en `MigrationRunnerTests` §17.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Journal que no se entiende · la lectura es ilegible, no «nunca empezó»")
struct MigrationJournalUndecodableTests {

    private enum Blob: CaseIterable { case phase, pending, reverseOrigin, claimIntent, reverseOriginRaw }

    /// La forma REAL de un downgrade: JSON válido con un case que este build no conoce. No basura aleatoria.
    private let newerPhase = Data(#"{"caseDeUnBuildNuevo":{}}"#.utf8)
    private let newerEffects = Data(#"["writeCloudKitMarker","efectoDeUnBuildNuevo"]"#.utf8)

    /// Una fila TRANSITORIA con los tres blobs legibles, y opcionalmente uno de ellos cambiado por uno que no decodifica.
    private func row(breaking blob: Blob?) -> MigrationState {
        let state = MigrationState()
        state.setPhase(.verifying)
        state.setPendingEffects([.writeCloudKitMarker])
        state.setReverseOriginPendingEffects([.adoptBackendAccount])
        state.forwardClaimIntentRaw = ForwardClaimIntent.migrateOnly.rawValue
        state.reverseOriginRaw = ReverseOrigin.notStarted.rawValue
        switch blob {
        case .phase: state.phaseData = newerPhase
        case .pending: state.pendingEffectsData = newerEffects
        case .reverseOrigin: state.reverseOriginPendingEffectsData = newerEffects
        case .claimIntent: state.forwardClaimIntentRaw = "intencionDeUnBuildNuevo"
        case .reverseOriginRaw: state.reverseOriginRaw = "origenDeUnBuildNuevo"
        case nil: break
        }
        return state
    }

    // MARK: - El testigo

    @Test func isJournalUndecodable_isTrueForEachBlob_andFalseForTheReadableRow() {
        for blob in Blob.allCases {
            #expect(row(breaking: blob).isJournalUndecodable, "\(blob)")
        }
        #expect(!row(breaking: nil).isJournalUndecodable, "control: la fila legible")
        #expect(!MigrationState().isJournalUndecodable, "control: la fila sin blobs (nil ⇒ notStarted/[] de verdad)")
        let legacy = row(breaking: nil)
        legacy.forwardClaimIntentRaw = nil                       // fila anterior a la v6: su relleno SÍ es legítimo
        legacy.reverseOriginRaw = nil
        #expect(!legacy.isJournalUndecodable, "control: los raw a nil no son desconocidos")
    }

    /// Los rellenos siguen existiendo —los lee el debug— pero ahora llevan su testigo.
    @Test func pendingEffectsChecked_carriesTheWitness_andTheControlDecodes() {
        let broken = row(breaking: .pending).readPendingEffectsChecked()
        #expect(broken.effects.isEmpty)
        #expect(broken.decodeFailed)
        let good = row(breaking: nil).readPendingEffectsChecked()
        #expect(good.effects == [.writeCloudKitMarker])
        #expect(!good.decodeFailed)
        #expect(!MigrationState().readPendingEffectsChecked().decodeFailed, "nil no es un fallo")
    }

    // MARK: - Lector 1: MigrationPhaseStore (motor, BGTasks, remap, drenaje de preferencias)

    @Test func phaseStore_undecodableRow_isUnreadable_notNotStarted() {
        for blob in Blob.allCases {
            let state = row(breaking: blob)
            #expect(MigrationPhaseStore.phaseRead { state } == .unreadable, "\(blob)")
        }
    }

    @Test func phaseStore_control_theReadableRowIsItsPhase() {
        let state = row(breaking: nil)
        #expect(MigrationPhaseStore.phaseRead { state } == .phase(.verifying))
        #expect(MigrationPhaseStore.phaseRead { nil } == .phase(.notStarted), "sin fila sí es «nunca empezó»")
    }

    // MARK: - Lector 2: MigrationJournalRead (la pantalla y el coordinador de arranque)

    @Test func controller_undecodableRow_isUnreadable_andCarriesNoValues() {
        for blob in Blob.allCases {
            let state = row(breaking: blob)
            let read = MigrationJournalRead.read { state }
            #expect(read == .unreadable, "\(blob)")
            #expect(read.phaseRead == .unreadable, "\(blob)")
        }
    }

    /// Control: la misma fila legible sale con su fase y sus pendientes — y el freno de una vuelta nueva, que con un `[]`
    /// de relleno se habría soltado.
    @Test func controller_control_theReadableRowIsItsSnapshot() {
        let state = row(breaking: nil)
        state.setPendingEffects([.reverseRollback])
        guard case .read(let snapshot) = MigrationJournalRead.read(fetch: { state }) else {
            Issue.record("la fila legible salió ilegible")
            return
        }
        #expect(snapshot.phase == .verifying)
        #expect(snapshot.pendingCount == 1)
        #expect(snapshot.hasPendingReverseExit)
    }

    // MARK: - Lo que hacen los consumidores con la lectura

    /// Los consumidores ya entienden la lectura ilegible desde el ticket padre; esto ata el camino nuevo a ellos: con la
    /// fase de relleno el motor ARRANCABA (`notStarted` es estable); con la lectura, no.
    @Test func runtimeGate_undecodableRow_doesNotStartTheEngine_andTheFillerWould() {
        let broken = row(breaking: .phase)
        #expect(broken.readPhase().phase == .notStarted, "el relleno sigue siendo notStarted — la trampa que se evita")
        #expect(MigrationRuntimeGate.canRun(
            phase: broken.readPhase().phase, cloudWithMirrorOn: false, personalMountMismatch: false),
            "control: con el relleno el motor arrancaría")
        #expect(!MigrationRuntimeGate.canRun(
            read: MigrationPhaseStore.phaseRead { broken }, cloudWithMirrorOn: false, personalMountMismatch: false))
    }
}
