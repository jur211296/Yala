//
//  CloudMigrationI14Tests.swift
//  YalaTests / CloudSync
//
//  Lógica PURA de I14 (Modo Nube UI): gate del runtime del dominio (P0), decisión de boot (P4), derivación
//  del estado de UI (P2), claim-store round-trip + gate de arranque con el store poblado (P6). Todo
//  determinista sin `ModelContext`/red — no requiere `.serialized` salvo el claim-store (@MainActor, defaults
//  aislados). `noNeedsTranslationMarker` / paridad l10n los cubre `LocalizationParityTests`.
//

import Foundation
import Testing

@testable import Yala

// MARK: - P0: gate de fase del runtime del dominio

@Suite("I14 · MigrationRuntimeGate (P0)")
struct MigrationRuntimeGateTests {

    @Test("estable: done y notStarted")
    func stablePhases() {
        #expect(MigrationRuntimeGate.isDomainStablePhase(.done))
        #expect(MigrationRuntimeGate.isDomainStablePhase(.notStarted))
    }

    @Test("transicionales NO son estables (el runner conduce)")
    func transitionalNotStable() {
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.cutover(.markerWritten)))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.uploadingSnapshot))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.verifying))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.reverseDrainAll))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.reverseMountMirror))
    }

    @Test("terminales de fallo NO son estables (son .icloud; el runtime no corre)")
    func failTerminalsNotStable() {
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.failedRollback))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.reverseFailedRollback))
        #expect(!MigrationRuntimeGate.isDomainStablePhase(.icloudActive))
    }

    // MARK: - C-1: canRun = fase ESTABLE **y** par de storage coherente

    @Test("notStarted + par a medio escribir → el motor NO arranca (el agujero que cierra C-1)")
    func canRun_notStarted_cloudWithMirrorOn_blocks() {
        // ESTE es el agujero real. `notStarted` es fase ESTABLE (device ADOPTADO, #30: su journal queda
        // `notStarted` tras `adoptBackendAccount`), así que con SOLO el término de fase un par a medio
        // escribir —`.cloud` persistido pero mirror-off SIN armar, p.ej. por un kill entre las dos keys del
        // adopt o por un cierre de reversa a medias— dejaba pasar el gate con el mirror de CloudKit MONTADO:
        // motor del dominio y mirror escribiendo el MISMO store, y ninguna fase que lo delatara. `UserDefaults`
        // no tiene transacción ⇒ el invariante no se puede garantizar en el escritor y se enforcea aquí.
        #expect(!MigrationRuntimeGate.canRun(phase: .notStarted, cloudWithMirrorOn: true))
    }

    @Test("notStarted + par coherente → arranca (device adoptado normal, byte-idéntico a antes)")
    func canRun_notStarted_pairCoherent_allows() {
        // La otra mitad del par de tests: el fix NO puede apagar el motor del adoptado sano. Si alguien
        // invierte el término nuevo, este test cae y no el de arriba.
        #expect(MigrationRuntimeGate.canRun(phase: .notStarted, cloudWithMirrorOn: false))
    }

    @Test("done: bloqueado con el par roto, permitido con el par coherente")
    func canRun_done_bothPairValues() {
        // `done` es la otra fase estable (el LÍDER que migró) — mismo razonamiento que `notStarted`.
        #expect(!MigrationRuntimeGate.canRun(phase: .done, cloudWithMirrorOn: true))
        #expect(MigrationRuntimeGate.canRun(phase: .done, cloudWithMirrorOn: false))
    }

    @Test("fase transicional: bloqueada con AMBOS valores del par (el término nuevo no la desbloquea)")
    func canRun_transitional_blockedRegardlessOfPair() {
        // `cutover(.markerWritten)` es justo la fase donde `.cloud` + mirror ON es LEGÍTIMO (el marcador aún
        // tiene que exportar por el mirror). Ahí manda el término de FASE: conduce el `MigrationRunner`, no el
        // motor. Pinnea que el término nuevo es una conjunción, no una disyunción — un `||` por descuido
        // arrancaría el motor a mitad del cutover.
        for cloudWithMirrorOn in [true, false] {
            #expect(!MigrationRuntimeGate.canRun(phase: .cutover(.markerWritten),
                                                 cloudWithMirrorOn: cloudWithMirrorOn),
                    "par roto=\(cloudWithMirrorOn)")
        }
    }

    @Test("con el par coherente, canRun == isDomainStablePhase para TODAS las fases (C-1 no movió la tabla)")
    func canRun_pairCoherent_matchesStablePhaseTable_allPhases() {
        // Doble pin en un solo recorrido de las 22 fases del journal:
        //  1. `isDomainStablePhase` conserva su verdad de siempre — C-1 añadió un término al gate, NO tocó la
        //     clasificación de fases (los 3 tests de arriba la cubren en muestra; aquí es exhaustiva).
        //  2. Con el par coherente (`cloudWithMirrorOn: false`) `canRun` es EXACTAMENTE la tabla de fases ⇒ el
        //     término nuevo es inerte en operación normal, incluido todo device `.icloud` de 2.x.
        // El `switch` de `expectedStable` es EXHAUSTIVO a propósito: añadir una fase al enum rompe la
        // compilación de este test y obliga a clasificarla a mano en vez de heredar el default de nadie.
        func expectedStable(_ phase: MigrationPhase) -> Bool {
            switch phase {
            case .done, .notStarted:
                return true
            case .dryRun, .consent, .authenticating, .waitingForLeader, .claimingMigration,
                 .assigningIdentity, .uploadingSnapshot, .verifying, .cutover, .failedRollback,
                 .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
                 .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
                 .icloudActive, .reverseFailedRollback:
                return false
            }
        }

        // Los sub-estados salen de `CaseIterable` para que uno nuevo entre en el recorrido solo.
        let allPhases: [MigrationPhase] =
            [.notStarted, .dryRun, .consent, .authenticating, .waitingForLeader, .claimingMigration,
             .assigningIdentity, .uploadingSnapshot, .verifying, .done, .failedRollback,
             .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
             .reverseMountMirror, .reverseUpload, .icloudActive, .reverseFailedRollback,
             .reverseConfirm(.done), .reverseConfirm(.notStarted)]
            + CutoverSubstate.allCases.map(MigrationPhase.cutover)
            + ReverseReconcileSubstate.allCases.map(MigrationPhase.reverseReconcile)

        for phase in allPhases {
            let expected = expectedStable(phase)
            #expect(MigrationRuntimeGate.isDomainStablePhase(phase) == expected, "fase \(phase)")
            #expect(MigrationRuntimeGate.canRun(phase: phase, cloudWithMirrorOn: false) == expected,
                    "fase \(phase) con par coherente")
            // Y con el par ROTO ninguna fase arranca — ni las estables (el agujero de C-1) ni las demás.
            #expect(!MigrationRuntimeGate.canRun(phase: phase, cloudWithMirrorOn: true), "fase \(phase) con par roto")
        }
    }
}

// MARK: - P4: decisión de boot

@Suite("I14 · MigrationBootDecision (P4)")
struct MigrationBootDecisionTests {

    @Test("fase transicional → resume")
    func transitional_resume() {
        #expect(MigrationBootDecision.decide(phase: .uploadingSnapshot, hasPendingEffects: false) == .resume)
        #expect(MigrationBootDecision.decide(phase: .cutover(.serverConfirmed), hasPendingEffects: false) == .resume)
        #expect(MigrationBootDecision.decide(phase: .reverseVerify, hasPendingEffects: false) == .resume)
    }

    @Test("dryRun → resume (la máquina la normaliza a su origen)")
    func dryRun_resume() {
        #expect(MigrationBootDecision.decide(phase: .dryRun, hasPendingEffects: false) == .resume)
    }

    @Test("waitingForLeader → pollLeader")
    func waiting_poll() {
        #expect(MigrationBootDecision.decide(phase: .waitingForLeader, hasPendingEffects: false) == .pollLeader)
    }

    @Test("estable sin efectos → none")
    func stable_none() {
        #expect(MigrationBootDecision.decide(phase: .notStarted, hasPendingEffects: false) == .none)
        #expect(MigrationBootDecision.decide(phase: .done, hasPendingEffects: false) == .none)
    }

    @Test("terminales de fallo NO auto-resumen → none")
    func failTerminals_none() {
        #expect(MigrationBootDecision.decide(phase: .failedRollback, hasPendingEffects: false) == .none)
        #expect(MigrationBootDecision.decide(phase: .reverseFailedRollback, hasPendingEffects: false) == .none)
    }

    @Test("efecto pendiente FUERZA resume aunque la fase sea estable (adopt journaleado, AJUSTE review #3)")
    func pendingEffect_forcesResume() {
        #expect(MigrationBootDecision.decide(phase: .notStarted, hasPendingEffects: true) == .resume)
        #expect(MigrationBootDecision.decide(phase: .done, hasPendingEffects: true) == .resume)
    }
}

// MARK: - #36: re-kick de foreground (H1 corrida I14)

@Suite("DIFERIDOS #36 · MigrationForegroundRekick")
struct MigrationForegroundRekickTests {

    @Test("fases transicionales (ida y reversa) → re-kick")
    func transitional_rekicks() {
        let transitional: [MigrationPhase] = [
            .dryRun, .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying,
            .cutover(.pending), .cutover(.mirrorOff),
            .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
            .reverseMountMirror, .reverseReconcile(.deletingZombies), .reverseUpload,
        ]
        for phase in transitional {
            #expect(MigrationForegroundRekick.shouldRekick(
                phase: phase, hasPendingEffects: false, isWorking: false), "\(phase) debe re-kickear")
        }
    }

    @Test("waitingForLeader → re-kick (rutea a pollLeader vía resumeIfNeeded)")
    func waitingForLeader_rekicks() {
        #expect(MigrationForegroundRekick.shouldRekick(
            phase: .waitingForLeader, hasPendingEffects: false, isWorking: false))
    }

    @Test("terminales estables y de FALLO sin efectos → NO re-kick (mismo contrato del boot)")
    func stableAndFailTerminals_noRekick() {
        let terminal: [MigrationPhase] = [
            .notStarted, .done, .icloudActive, .failedRollback, .reverseFailedRollback,
        ]
        for phase in terminal {
            #expect(!MigrationForegroundRekick.shouldRekick(
                phase: phase, hasPendingEffects: false, isWorking: false), "\(phase) NO debe re-kickear")
        }
    }

    @Test("efecto pendiente FUERZA re-kick aunque la fase sea estable (adopt journaleado)")
    func pendingEffects_forceRekick() {
        #expect(MigrationForegroundRekick.shouldRekick(
            phase: .notStarted, hasPendingEffects: true, isWorking: false))
        #expect(MigrationForegroundRekick.shouldRekick(
            phase: .done, hasPendingEffects: true, isWorking: false))
    }

    @Test("isWorking=true → JAMÁS re-kickear encima (pre-espera del boot en vuelo)")
    func working_neverRekicks() {
        #expect(!MigrationForegroundRekick.shouldRekick(
            phase: .uploadingSnapshot, hasPendingEffects: false, isWorking: true))
        #expect(!MigrationForegroundRekick.shouldRekick(
            phase: .waitingForLeader, hasPendingEffects: true, isWorking: true))
    }
}

// MARK: - P2: derivación del estado de UI

@Suite("I14 · CloudMigrationUIStateDeriver (P2)")
struct CloudMigrationUIStateDeriverTests {

    typealias Deriver = CloudMigrationUIStateDeriver

    @Test("iCloud + notStarted → idle")
    func idle() {
        #expect(Deriver.derive(storageMode: .icloud, phase: .notStarted,
                               mirrorOffArmed: false, mountedMode: .icloud) == .idle)
    }

    @Test("cloud + done/notStarted → cloudActive (adoptado estable)")
    func cloudActive() {
        #expect(Deriver.derive(storageMode: .cloud, phase: .done,
                               mirrorOffArmed: false, mountedMode: .cloud) == .cloudActive)
        #expect(Deriver.derive(storageMode: .cloud, phase: .notStarted,
                               mirrorOffArmed: false, mountedMode: .cloud) == .cloudActive)
    }

    @Test("cloud + fase forward transicional → migrating")
    func migrating() {
        guard case .migrating = Deriver.derive(storageMode: .cloud, phase: .uploadingSnapshot,
                                               mirrorOffArmed: false, mountedMode: .icloud) else {
            Issue.record("esperaba .migrating"); return
        }
    }

    @Test("cloud + fase reversa transicional → reverting")
    func reverting() {
        guard case .reverting = Deriver.derive(storageMode: .cloud, phase: .reverseDrainAll,
                                               mirrorOffArmed: false, mountedMode: .cloud) else {
            Issue.record("esperaba .reverting"); return
        }
    }

    @Test("mirror-off ARMADO + mount .icloud → needsRelaunch(.toCloud) — cutover y adopt")
    func needsRelaunchToCloud() {
        #expect(Deriver.derive(storageMode: .cloud, phase: .cutover(.mirrorOff),
                               mirrorOffArmed: true, mountedMode: .icloud) == .needsRelaunch(.toCloud))
        // Adopt: journal notStarted + .cloud armado + mount .icloud.
        #expect(Deriver.derive(storageMode: .cloud, phase: .notStarted,
                               mirrorOffArmed: true, mountedMode: .icloud) == .needsRelaunch(.toCloud))
    }

    @Test("reverseMountMirror + mount .cloud → needsRelaunch(.toICloud)")
    func needsRelaunchToICloud() {
        #expect(Deriver.derive(storageMode: .cloud, phase: .reverseMountMirror,
                               mirrorOffArmed: false, mountedMode: .cloud) == .needsRelaunch(.toICloud))
    }

    @Test("terminales de fallo → failed(kind)")
    func failed() {
        #expect(Deriver.derive(storageMode: .icloud, phase: .failedRollback,
                               mirrorOffArmed: false, mountedMode: .icloud) == .failed(.migration))
        #expect(Deriver.derive(storageMode: .cloud, phase: .reverseFailedRollback,
                               mirrorOffArmed: false, mountedMode: .cloud) == .failed(.reverse))
    }

    @Test("waitingForLeader")
    func waiting() {
        #expect(Deriver.derive(storageMode: .cloud, phase: .waitingForLeader,
                               mirrorOffArmed: false, mountedMode: .cloud) == .waitingForLeader)
    }

    @Test("icloudActive (terminal reversa) → idle")
    func icloudActiveIdle() {
        #expect(Deriver.derive(storageMode: .icloud, phase: .icloudActive,
                               mirrorOffArmed: false, mountedMode: .icloud) == .idle)
    }
}

// MARK: - P6: claim-store round-trip + gate de arranque

@Suite("I14 · CloudClaimActionStore (P6)", .serialized)
@MainActor
struct CloudClaimActionStoreTests {

    @Test("round-trip de las 5 acciones (codec estable)")
    func roundTrip() {
        let store = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "claim.rt"))
        let all: [AccountClaimDecision.AuthAction] = [
            .seedBornCloud, .proceedMigration, .routeReturningUser, .waitForLeader, .showProviderMismatch,
        ]
        for action in all {
            store.record(action, forUserID: "u")
            #expect(store.action(forUserID: "u") == action)
        }
    }

    @Test("userID sin registro → nil (identidad no-claimeada)")
    func missing_nil() {
        let store = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "claim.missing"))
        #expect(store.action(forUserID: "nobody") == nil)
    }

    @Test("keyed por userID: registrar A no afecta a B")
    func keyedByUser() {
        let store = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "claim.keyed"))
        store.record(.routeReturningUser, forUserID: "A")
        #expect(store.action(forUserID: "A") == .routeReturningUser)
        #expect(store.action(forUserID: "B") == nil)
    }

    @Test("store poblado → shouldStartSync coherente con la acción (gate de arranque P6)")
    func storePopulated_gate() {
        let store = CloudClaimActionStore(defaults: makeIsolatedDefaults(prefix: "claim.gate"))
        store.record(.routeReturningUser, forUserID: "u")
        #expect(CloudSyncRuntime.shouldStartSync(after: store.action(forUserID: "u")!))
        store.record(.waitForLeader, forUserID: "u")
        #expect(!CloudSyncRuntime.shouldStartSync(after: store.action(forUserID: "u")!))
    }
}
