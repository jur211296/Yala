//
//  SyncCadencePolicyTests.swift
//  YalaTests / CloudSync
//
//  Golden de la política PURA de cadencia (I9): escalera de backoff + cap, AND del Merkle, mapeo de
//  stop-states. Sin motor, sin red, `now` inyectado.
//

import Foundation
import Testing

@testable import Yala

@Suite("SyncCadencePolicy · cadencia/backoff/Merkle I9")
struct SyncCadencePolicyTests {

    // MARK: - Backoff exponencial

    @Test func backoff_ladder_scalesAndCaps() {
        // base 5s × 2^(n-1), cap 300s. n=1→5, 2→10, 3→20, 4→40, 5→80, 6→160, 7→320→cap 300, 8→cap.
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 1) == 5)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 2) == 10)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 3) == 20)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 4) == 40)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 5) == 80)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 6) == 160)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 7) == 300)  // 320 capado a 300
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 8) == 300)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 20) == 300)
    }

    @Test func backoff_nonPositiveN_returnsBase() {
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: 0) == 5)
        #expect(SyncCadencePolicy.backoffDelay(consecutiveTransients: -3) == 5)
    }

    // MARK: - nextAction

    @Test func nextAction_completed_schedulesPullInterval() {
        #expect(SyncCadencePolicy.nextAction(outcome: .completed, consecutiveTransients: 0)
                == .scheduleNext(SyncCadencePolicy.pullInterval))
    }

    @Test func nextAction_transient_backsOffByCount() {
        #expect(SyncCadencePolicy.nextAction(outcome: .transient, consecutiveTransients: 3)
                == .backoff(20))
    }

    @Test func nextAction_sessionExpired_stopsUntilSignIn() {
        #expect(SyncCadencePolicy.nextAction(outcome: .sessionExpired, consecutiveTransients: 0)
                == .stopUntilSignIn)
    }

    @Test func nextAction_accountUnavailable_stopsUntilRelaunch() {
        // S6: 403 → SIN loop de reintentos.
        #expect(SyncCadencePolicy.nextAction(outcome: .accountUnavailable, consecutiveTransients: 9)
                == .stopUntilRelaunch)
    }

    @Test func nextAction_coalesced_schedulesNormally_regardlessOfTransientCount() {
        // Fix MENOR del review: un ciclo coalescido/abortado NO es un fallo de red — cadencia normal
        // aunque el contador de transitorios (que el caller deja INTACTO) traiga arrastre.
        #expect(SyncCadencePolicy.nextAction(outcome: .coalesced, consecutiveTransients: 0)
                == .scheduleNext(SyncCadencePolicy.pullInterval))
        #expect(SyncCadencePolicy.nextAction(outcome: .coalesced, consecutiveTransients: 5)
                == .scheduleNext(SyncCadencePolicy.pullInterval))
    }

    // MARK: - Merkle (AND de dos condiciones)

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func merkle_belowPullThreshold_never() {
        #expect(SyncCadencePolicy.shouldRunMerkle(
            completedPullsSinceMerkle: 19, lastMerkleAt: nil, now: t0) == false)
    }

    @Test func merkle_thresholdMet_firstEver_runs() {
        // lastMerkleAt == nil satisface la condición temporal.
        #expect(SyncCadencePolicy.shouldRunMerkle(
            completedPullsSinceMerkle: 20, lastMerkleAt: nil, now: t0) == true)
    }

    @Test func merkle_pullsMet_butIntervalTooSoon_skips() {
        // 20 pulls pero solo 10min desde la última → AND falla.
        let last = t0.addingTimeInterval(-10 * 60)
        #expect(SyncCadencePolicy.shouldRunMerkle(
            completedPullsSinceMerkle: 25, lastMerkleAt: last, now: t0) == false)
    }

    @Test func merkle_pullsAndIntervalMet_runs() {
        let last = t0.addingTimeInterval(-31 * 60)  // > 30min
        #expect(SyncCadencePolicy.shouldRunMerkle(
            completedPullsSinceMerkle: 20, lastMerkleAt: last, now: t0) == true)
    }

    @Test func merkle_intervalMet_butPullsShort_skips() {
        let last = t0.addingTimeInterval(-60 * 60)
        #expect(SyncCadencePolicy.shouldRunMerkle(
            completedPullsSinceMerkle: 5, lastMerkleAt: last, now: t0) == false)
    }
}
