//
//  BootSaveGateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for `BootSaveGateLogic` — el gate de los `save()` del store PERSONAL en el arranque.
//  Vivían dentro de `SplitSyncStartGateTests.swift`, el fichero del gate del transporte CloudKit de
//  Grupos: al retirar ese transporte se habrían borrado con él y el crash-loop de restore
//  (H-2026-07-18-8) volvería sin un solo test en rojo. `qa/coverage-index.json` ya citaba
//  `unit:YalaTests/BootSaveGateLogicTests`; aquí la cita es literal.
//

import Foundation
import Testing

@testable import Yala

// MARK: - BootSaveGateLogic (early-boot personal-store save gate — H-2026-07-18-8)

/// Pure-logic table for the boot-save gate. Same crash-loop invariant as the group gate, but the
/// hard cap must NEVER promote for boot-saves (forcing a mainContext save over a hung import is the
/// restore crash). Reuses `resolveWaitByQuiescence` internally with `reachedHardCap: false`.
@Suite("Boot Save Gate Logic")
struct BootSaveGateLogicTests {

    @Test func noAccount_runsImmediately() {
        // No CloudKit mirror → no half-imported personal graph can exist → save always safe.
        // (The other flags are stale/irrelevant when there's no account.)
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: false, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: false, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .runNoAccount)
        #expect(d.isRun)
    }

    @Test func firstImportSettledAndQuiet_runs() {
        // The real import fired and went quiet → save safe (fast-path, INTACT).
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: true,
            hasObservedImportActivity: true, isQuiescent: true, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .runImportSettled)
        #expect(d.isRun)
    }

    @Test func emptyStore_graceElapsedNoActivityQuiet_runs() {
        // THE H-8 FIX: a store that imports nothing (fresh-start wipe, data already all on the server)
        // never fires `.import`, so `hasCompletedFirstImport` stays false forever. After the grace with
        // NO import activity ever + quiet + fully idle → open the gate via the empty-store escape.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(d == .runEmptyStore)
        #expect(d.isRun)
    }

    @Test func setupPhaseActive_waits_evenPastGraceNoActivity() {
        // ADVERSARIAL HARDENING CELL: a long `.syncing(.setup)` at the grace boundary — no `.import`
        // fired yet (activity false) and `isQuiescent` TRUE, because `isImportQuiescent` only checks
        // `.syncing(.importing)`, not `.setup`. Without `isSyncingAnyPhase` the empty-store escape would
        // open the gate while the restore handshake is still in flight. With it → wait. An idle empty
        // store is never in `.syncing`, so this guard does not reintroduce the H-8 hang.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func graceNotElapsed_waits() {
        // At cold launch `isQuiescent` is true BEFORE any import starts. Until the grace elapses we
        // must WAIT — a populated restore's import may be imminent (promoting here is the premature-
        // promotion crash). This is the cell that protects a slow-starting real restore.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func activityObservedButNotSettled_waits_realRestoreInFlight() {
        // THE INVARIANT CELL: a real restore whose import has STARTED (activity observed) but hasn't
        // completed — even momentarily quiescent, past the grace and with no phase currently in flight —
        // must NEVER open the gate. Keying the empty-store escape on `!hasObservedImportActivity` is
        // exactly what excludes a real restore: its import event flipped the activity flag, so
        // `.runEmptyStore` cannot fire, and without a completed first import `.runImportSettled` cannot
        // fire either → wait. A save here would land on a half-imported personal graph → SwiftData
        // `_assertionFailure` → crash-loop.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: true, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func hungImportNotQuiescent_waits_evenPastGrace() {
        // A genuinely-hung/active import → `isQuiescent == false`. Every run branch ANDs with quiescence
        // and there's NO hard-cap promotion for boot-saves → keep waiting even past the grace (the caller's
        // total poll cap then ends the wait → DEFER, retried next launch). Forcing the save here would be
        // the crash.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func settledButNotQuiet_waits() {
        // First import completed but a subsequent batch is importing (not quiet) → wait until it quiets.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: true,
            hasObservedImportActivity: true, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
    }

    @Test func hardCapIsNeverConsulted_forBootSaves() {
        // Boot-saves have NO hard-cap promotion by construction: `decide` passes `reachedHardCap: false`
        // to `resolveWaitByQuiescence` internally. A state that the GROUP gate would force-promote on the
        // cap (nothing settled, not quiet, past grace, activity in flight) stays `.wait` here — proving a
        // hung import can never be force-saved. Contrast: the group gate promotes the SAME inputs on cap.
        let bootDecision = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: true, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(bootDecision == .wait)
        let groupWouldForce = BootSaveGateLogic.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: true, isQuiescent: false,
            noImportGraceElapsed: true, reachedHardCap: true
        )
        #expect(groupWouldForce == .start)  // The group ENGINE gate DOES promote on cap — harmless there.
    }
}
