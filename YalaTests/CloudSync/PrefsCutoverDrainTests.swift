//
//  PrefsCutoverDrainTests.swift
//  YalaTests / CloudSync
//
//  Lógica pura del drenaje único iKV → outbox del cutover (§g.4 S8, DIFERIDOS #30 — I10-wiring w8).
//  El gate LÍDER-only y el plan (presente-en-iKV ∧ no-pendiente-en-outbox) son funciones puras; el
//  wiring vivo (`PreferenceSyncService.drainiKVToOutboxOnceIfNeeded`) reusa singletons no inyectables
//  (iKV/MigrationPhaseStore) y queda cubierto por el guion device + el no-op de producción (.icloud),
//  con la misma justificación documentada que el POST-PASS de I13.
//

import Foundation
import Testing

@testable import Yala

@Suite("PrefsCutoverDrain · lógica pura (I10-wiring w8)")
struct PrefsCutoverDrainTests {

    // MARK: - Gate líder post-relaunch

    @Test func gate_leaderPhases_areExactlyMirrorOffAndDone() {
        #expect(PrefsCutoverDrain.isLeaderPostRelaunchPhase(.cutover(.mirrorOff)))
        #expect(PrefsCutoverDrain.isLeaderPostRelaunchPhase(.done))
    }

    @Test func gate_nonLeaderPhases_doNotDrain() {
        // Un adoptador/follower (notStarted) o cualquier fase pre-relaunch NO drena: su iKV puede ser
        // más viejo que el backend y el HLC fresco del enqueue lo haría GANAR (regresión de prefs).
        let nonLeader: [MigrationPhase] = [
            .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader,
            .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying,
            .cutover(.pending), .cutover(.serverConfirmed), .cutover(.localModeSet),
            .cutover(.markerWritten), .failedRollback,
        ]
        for phase in nonLeader {
            #expect(!PrefsCutoverDrain.isLeaderPostRelaunchPhase(phase), "\(phase) no debe drenar")
        }
    }

    // MARK: - Plan (presente ∧ no-pendiente, ausente ≠ "")

    @Test func plan_onlyPresentKeys_neverInvented() {
        let planned = PrefsCutoverDrain.plan(
            allKeys: ["a", "b", "c"],
            presentInIKV: ["a", "c"],
            pendingInOutbox: [])
        #expect(planned == ["a", "c"], "solo keys PRESENTES en iKV (ausente ≠ \"\")")
    }

    @Test func plan_skipsKeysAlreadyPendingInOutbox() {
        // Belt: un write local post-relaunch (ya encolado) es MÁS nuevo que la réplica iKV — no se pisa.
        let planned = PrefsCutoverDrain.plan(
            allKeys: ["a", "b", "c"],
            presentInIKV: ["a", "b", "c"],
            pendingInOutbox: ["b"])
        #expect(planned == ["a", "c"])
    }

    @Test func plan_emptyIKV_drainsNothing() {
        #expect(PrefsCutoverDrain.plan(allKeys: ["a", "b"], presentInIKV: [], pendingInOutbox: []).isEmpty)
    }

    @Test func plan_preservesAllKeysOrder() {
        let planned = PrefsCutoverDrain.plan(
            allKeys: ["z", "a", "m"],
            presentInIKV: ["m", "z", "a"],
            pendingInOutbox: [])
        #expect(planned == ["z", "a", "m"], "orden estable = el de allKeys")
    }

    // MARK: - Sentinels (#37 — la reversa/el sign-out los retiran por prefijo)

    @Test func sentinelKeys_matchesAllUserIDs_ignoresForeignKeys() {
        let keys = [
            PrefsCutoverDrain.sentinelPrefix + "userA",
            PrefsCutoverDrain.sentinelPrefix + "userB",
            "cloudSync.otherKey",
            "storageMode",
            "defaultCurrencyCode",
        ]
        let matched = Set(PrefsCutoverDrain.sentinelKeys(in: keys))
        #expect(matched == [
            PrefsCutoverDrain.sentinelPrefix + "userA",
            PrefsCutoverDrain.sentinelPrefix + "userB",
        ], "solo sentinels del drenaje, CUALQUIER userID")
    }

    @Test func sentinelKeys_prefixRequiresSeparatorDot() {
        // El prefijo termina en "." — una key que solo comparte la sub-cadena SIN el punto no matchea.
        let impostor = "cloudSync.prefsCutoverDrainedX"
        #expect(PrefsCutoverDrain.sentinelKeys(in: [impostor]).isEmpty)
        #expect(PrefsCutoverDrain.sentinelPrefix.hasSuffix("."), "invariante del filtro por prefijo")
    }

    @Test func sentinelKeys_emptyInput_emptyOutput() {
        #expect(PrefsCutoverDrain.sentinelKeys(in: []).isEmpty)
    }
}
