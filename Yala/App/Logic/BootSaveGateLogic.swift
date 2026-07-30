//
//  BootSaveGateLogic.swift
//  Yala
//
//  Pure gate for early-boot **personal-store** `save()`s. Extracted from `SplitSyncStartGate.swift`.
//
//  Why it needs its own file: the CloudKit transport of Groups is being retired and
//  `SplitSyncStartGate` (the gate that starts the group CKSyncEngines) goes with it. This gate does
//  NOT — it protects the PERSONAL store, has no relation to group sync, and its consumer
//  (`AppBootstrapper.awaitPersonalImportForBootSave`) survives. Buried in the transport's file it
//  would be deleted along with it, silently reintroducing the H-2026-07-18-8 crash-loop with not one
//  test turning red (the cells that pin it lived in `SplitSyncStartGateTests.swift`, which the same
//  deletion takes down).
//
//  `WaitResolution` + `resolveWaitByQuiescence` live here for the same reason: they are SHARED with
//  `SplitSyncStartGate` while both channels coexist, and only this side survives.
//

import Foundation

/// Pure gate for the ~8 boot tasks funneled through `AppBootstrapper.awaitPersonalImportForBootSave`
/// (retryPendingBridges, migrateShareGroupZoneIDs, scheduled-payment / exchange-rate / provisional-tx
/// drains, reconciles, sendDueReports, …). A `save()` of the shared `mainContext` while
/// NSPersistentCloudKitContainer is still importing trips SwiftData's internal `_assertionFailure`
/// (SIGTRAP, NOT catchable → crash-loop on an iCloud restore).
///
/// This composes the correct branches for boot-saves as ONE testable truth, reusing
/// `resolveWaitByQuiescence` (hosted here — see the file header) for the promote/wait decision, but with
/// **`reachedHardCap` HARDCODED to `false`**. That asymmetry is the whole point: the group ENGINE gate may
/// promote on the hard cap because promoting an export-only engine is harmless (it just enables
/// auto-fetch), whereas forcing a mainContext `save()` while a genuinely-hung import is in flight
/// (`isSyncing` → `isQuiescent == false`) is exactly the restore crash. So the caller's total poll cap
/// only ENDS THE WAIT (→ DEFER, retried next launch); it never forces a save.
///
/// Why a wrapper (not just calling `resolveWaitByQuiescence` inline in the caller): `resolveWaitByQuiescence`
/// does NOT model the no-account short-circuit, and the caller (`awaitPersonalImportForBootSave`) is the
/// untested runtime shell. Folding no-account + hard-cap-off + path naming here keeps the entire boot-save
/// composition unit-tested in one place (`BootSaveGateLogicTests`).
enum BootSaveGateLogic {

    enum WaitResolution: Equatable {
        /// Create the engines now.
        case start
        /// Keep waiting for the import to settle.
        case keepWaiting
    }

    // MARK: - Promote by QUIESCENCE (not first import)

    /// Decides, on each periodic poll while deferred, whether to PROMOTE the engines to auto-sync —
    /// gating on **import quiescence** + **observed import activity** instead of the first `importEvent`.
    ///
    /// SHARED with `SplitSyncStartGate` (the group-engine gate) while the CloudKit transport of Groups
    /// still lives: `SplitSyncManager.evaluateQuiescentPromotion` calls this too, with a real
    /// `reachedHardCap`. It is hosted HERE because this side is the one that survives the transport's
    /// retirement — see the file header.
    ///
    /// The first import is a PREMATURE signal on a multi-batch restore: NSPersistentCloudKitContainer
    /// keeps importing after the first event fires, so promoting there turns off the delegate-save gate
    /// (`shouldDeferDelegateSave`) while the personal graph is still half-imported → the next delegate
    /// `save()` trips SwiftData's `_assertionFailure`. Waiting for quiescence (no import in flight AND
    /// past a quiet window — `iCloudSyncService.isImportQuiescent`, itself `SubcategoryDedupGate.decide`)
    /// keeps the engines export-only through the WHOLE active import. In export-only there's no
    /// auto-fetch, so deferring loses nothing: fetched changes only arrive after promotion = after the
    /// store is quiet.
    ///
    /// - `reachedHardCap=true` → absolute last-resort cap reached → promote anyway (a warning is logged;
    ///   a stuck-`.syncing` import must not hang group sync forever). The per-save breadcrumb + the
    ///   delegate's own gating remain as the last line of defense in that rare case.
    /// - `hasCompletedFirstImport && isQuiescent` → the import actually started, finished, and went
    ///   quiet → promote. Both are required: `isQuiescent` alone is `true` BEFORE any import starts
    ///   (`lastImportDate == nil`), which would promote prematurely on a restore where the import is
    ///   still pending; gating also on `hasCompletedFirstImport` ensures we waited for it to happen.
    /// - `noImportGraceElapsed && !hasObservedImportActivity && isQuiescent` → EMPTY store: the grace window
    ///   passed and NO `.import` ever appeared (a populated account would have fired an import event by now),
    ///   and the store is quiet → safe to promote. This is what unblocks a user with no personal data (e.g.
    ///   groups-only) whose empty `.private` store never fires `.import`, so `hasCompletedFirstImport` stays
    ///   `false` forever. Keying on *absence of observed import activity* (not the onboarding mode) is the
    ///   safe distinguisher: a populated store on restore sets `hasObservedImportActivity` as soon as the
    ///   import starts → this branch never fires for it → it waits for the real import via the branch above.
    /// - otherwise → keep waiting.
    static func resolveWaitByQuiescence(
        hasCompletedFirstImport: Bool,
        hasObservedImportActivity: Bool,
        isQuiescent: Bool,
        noImportGraceElapsed: Bool,
        reachedHardCap: Bool
    ) -> WaitResolution {
        if reachedHardCap { return .start }
        if hasCompletedFirstImport && isQuiescent { return .start }
        if noImportGraceElapsed && !hasObservedImportActivity && isQuiescent { return .start }
        return .keepWaiting
    }

    // MARK: - Boot-save gate

    /// Resolution of the boot-save gate. `isRun` opens the save; each run case names WHY (for path-
    /// specific breadcrumbs at the call site).
    enum Decision: Equatable {
        /// No CloudKit account → no mirror → no half-imported personal graph can exist → save is safe.
        case runNoAccount
        /// The real personal import fired AND went quiet (fast-path). Protects a genuine restore: while
        /// it's still importing (`hasObservedImportActivity == true`, `hasCompletedFirstImport` not yet),
        /// `isQuiescent` is `false` → this does NOT fire → the gate keeps waiting.
        case runImportSettled
        /// EMPTY store escape (H-2026-07-18-8): the grace passed, NO `.import` was EVER observed, the
        /// store is quiet, AND no sync phase of ANY kind is in flight (`!isSyncingAnyPhase` — covers
        /// `.setup`/`.exporting`, which `isQuiescent` does NOT: it only checks `.syncing(.importing)`).
        /// A store that imports nothing (e.g. a fresh-start wipe whose data is already all on the
        /// server → `hasCompletedFirstImport` stays `false` forever) sits idle, so the extra guard does
        /// not reintroduce the H-8 hang. SUPUESTO (not a guarantee): a populated restore *usually* fires
        /// its `.import` within the grace (flipping `hasObservedImportActivity`) or is at least in a
        /// `.syncing` phase at the boundary — both keep this branch closed. RESIDUAL EXPLÍCITO: a restore
        /// whose FIRST `.import` arrives >60s in with NOTHING active at the tick (no `.setup`, no
        /// `.import` yet, fully idle) would open the gate pre-import. That save lands on the LOCAL
        /// pre-import graph — NOT the crash condition, which is a save DURING an active import over a
        /// half-imported graph (invariante device-confirmed 2026-06-22, build 32).
        case runEmptyStore
        /// Keep waiting: grace not elapsed, a real restore is still importing, or an import is hung
        /// (`isSyncing` → not quiescent). The caller polls until this flips or its total cap ends the wait.
        case wait

        var isRun: Bool { self != .wait }
    }

    /// Decides whether an early-boot personal-store save is safe RIGHT NOW.
    ///
    /// Decision table (mutually exclusive by construction — `hasCompletedFirstImport == true` implies
    /// `hasObservedImportActivity == true`, since the activity flag is set at the top of the import
    /// event handler before the completion check. SEAM EXCEPTION: `_uiTestSimulateAvailableAccount()`
    /// breaks the implication — it sets `hasCompletedFirstImport` directly without the activity flag.
    /// Harmless: the fast-path fires first for it, so the classification below never mislabels):
    ///   - `!isAccountAvailable`                                                 → `.runNoAccount`
    ///   - `hasCompletedFirstImport && isQuiescent`                              → `.runImportSettled`
    ///   - `noImportGraceElapsed && !hasObservedImportActivity && isQuiescent
    ///      && !isSyncingAnyPhase`                                               → `.runEmptyStore`
    ///   - otherwise (incl. `isSyncing`/hung import: `isQuiescent == false`)     → `.wait`
    ///
    /// - Parameter isSyncingAnyPhase: `true` while the container is in ANY `.syncing` phase — incl.
    ///   `.setup` and `.exporting`, which `isQuiescent` does NOT see (it only checks
    ///   `.syncing(.importing)`). Hardens ONLY the empty-store escape: a long `.setup` at the grace
    ///   boundary (restore still handshaking, `.import` not fired yet) must keep waiting. The fast-path
    ///   is intentionally NOT gated on it — identical to the pre-fix behavior.
    /// - Note: `reachedHardCap` is intentionally passed `false` to `resolveWaitByQuiescence` — see the
    ///   type doc. There is NO hard-cap promotion for boot-saves.
    static func decide(
        isAccountAvailable: Bool,
        hasCompletedFirstImport: Bool,
        hasObservedImportActivity: Bool,
        isQuiescent: Bool,
        noImportGraceElapsed: Bool,
        isSyncingAnyPhase: Bool
    ) -> Decision {
        guard isAccountAvailable else { return .runNoAccount }
        let resolution = resolveWaitByQuiescence(
            hasCompletedFirstImport: hasCompletedFirstImport,
            hasObservedImportActivity: hasObservedImportActivity,
            isQuiescent: isQuiescent,
            noImportGraceElapsed: noImportGraceElapsed,
            reachedHardCap: false  // boot-saves NEVER force on the cap — that would be the restore crash.
        )
        guard resolution == .start else { return .wait }
        // With `reachedHardCap == false`, `.start` means exactly one of the two run branches fired.
        // They're mutually exclusive (see the note above), so this cleanly identifies which.
        if hasCompletedFirstImport && isQuiescent { return .runImportSettled }
        // Empty-store escape — HARDENED: any in-flight `.syncing` phase (setup/export) closes it.
        return isSyncingAnyPhase ? .wait : .runEmptyStore
    }
}
