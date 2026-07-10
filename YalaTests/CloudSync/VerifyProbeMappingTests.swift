//
//  VerifyProbeMappingTests.swift
//  YalaTests / CloudSync
//
//  Tabla COMPLETA del mapping puro `MerkleVerdict → VerifyProbe` (I10-wiring w5). Cada `reason` de
//  `.skipped` está anclado a `SyncMerkle.verifyIntegrity` — este test es el contrato de que un reason nuevo
//  cae en la rama conservadora `networkTimeout` (nunca crashea ni consume un retry de mismatch).
//

import Foundation
import Testing

@testable import Yala

@Suite("VerifyProbeMapping · mapping puro (I10-wiring w5)")
@MainActor
struct VerifyProbeMappingTests {

    @Test("converged → match")
    func converged() {
        #expect(VerifyProbeMapping.map(verdict: .converged) == .match)
        #expect(!VerifyProbeMapping.isUnknownSkip(.converged))
    }

    @Test("diverged → mismatch")
    func diverged() {
        #expect(VerifyProbeMapping.map(verdict: .diverged(entities: ["tx_items"])) == .mismatch)
        #expect(!VerifyProbeMapping.isUnknownSkip(.diverged(entities: ["tx_items"])))
    }

    @Test("skipped(outbox-pending) → newDeltaDetected (re-run, NO consume)")
    func outboxPending() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: "outbox-pending")) == .newDeltaDetected)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: "outbox-pending")))
    }

    @Test("skipped(dead-letters) → mismatch (rechazo definitivo, tope → failedRollback)")
    func deadLetters() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: "dead-letters")) == .mismatch)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: "dead-letters")))
    }

    @Test("skipped(canon-version-mismatch) → mismatch")
    func canonVersionMismatch() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: "canon-version-mismatch")) == .mismatch)
    }

    @Test("skipped(capability-set-mismatch) → mismatch")
    func capabilitySetMismatch() {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: "capability-set-mismatch")) == .mismatch)
    }

    @Test("skipped reasons de RED → networkTimeout", arguments: [
        "no-completed-pull", "fetch-failed", "outbox-fetch-failed", "quarantine-fetch-failed",
    ])
    func networkReasons(_ reason: String) {
        #expect(VerifyProbeMapping.map(verdict: .skipped(reason: reason)) == .networkTimeout)
        #expect(!VerifyProbeMapping.isUnknownSkip(.skipped(reason: reason)))
    }

    @Test("reason DESCONOCIDO → networkTimeout conservador + isUnknownSkip true (canario)")
    func unknownReason() {
        let verdict = MerkleVerdict.skipped(reason: "some-future-reason-v2")
        #expect(VerifyProbeMapping.map(verdict: verdict) == .networkTimeout)
        #expect(VerifyProbeMapping.isUnknownSkip(verdict))
    }
}
