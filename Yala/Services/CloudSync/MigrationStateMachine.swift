//
//  MigrationStateMachine.swift
//  Yala
//
//  Pure-logic state machine for the iCloud→cloud MIGRATION path (Modo Nube §g / diagram §4.1).
//  This is the DARK, journaled, golden-tested core of I10: it decides the next `MigrationPhase`
//  and the DECLARATIVE effects the runtime MUST perform — the machine itself executes NOTHING
//  (no I/O, no ModelContext, no `Date.now`, no network). It only knows the digested claim contract
//  (`AccountClaimDecision.ClaimState`, REUSED — never duplicated), the verify outcome, and the
//  runtime's completion acks.
//
//  Design premises it encodes (§g): idempotent, resumable (app killed mid-flow), verifiable, dry-run,
//  never destroys the origin. The migration is MULTI-DEVICE coordinated by the backend (leader /
//  follower). The cutover is NOT an atomic box: it is ≥4 cross-system writes in a STRICT order with
//  journaled sub-states, the CloudKit marker as the LAST observable effect, and the KV beacon written
//  EARLY (at the claim, not at the marker — v8, §g.4-faro).
//
//  Conventions (documented decisions — the plan left the event↔effect binding to the implementer):
//  - `transition(from:event:policy:)` is a pure Mealy step: effects are attached to the EDGE and
//    describe the observable side-effects the runtime performs as it crosses into `next` (journaling
//    `next` is the durable record that the effect was authorized). Only the ordering-critical / observable
//    effects are surfaced (§g.4); routine work like "write profiles.migrated_at" or "persist storageMode"
//    carries no effect — the runtime does it and reports completion via the corresponding ack event.
//  - The cutover events (`serverConfirmedAck`/`localModePersisted`/`markerWritten`/`mirrorDisabled`/
//    `mirrorRelaunchCompleted`) are the runtime's request to advance the journal by exactly ONE
//    sub-state. `mirrorRelaunchCompleted` is added (not in the plan's initial event list) because §g.4
//    step 4 does an ASSISTED RELAUNCH between `mirrorOff` and `done` — a real process boundary — so the
//    leader re-enters `done` only after the runtime confirms it is back post-relaunch.
//  - Impossible (from, event) pairs → an EXPLICIT `.invalid(from:event:)` carrying the pair for the
//    consumer's breadcrumb. NEVER `fatalError` (pure-logic has no traps).
//
//  NO runtime wiring. Nothing instantiates this outside tests (DARK by construction) until I10-wiring,
//  which is blocked on the device spikes S5/S6/S7.
//

import Foundation

// MARK: - Phases

/// The journaled migration phase (persisted in `MigrationState`, §g.1). `Codable` for the journal;
/// `Equatable` for golden tests. Ordering-sensitive comparisons go through `CutoverSubstate`.
nonisolated enum MigrationPhase: Equatable, Codable {
    /// Idle. Offers "Simulate migration" (dry-run) and "Activate cloud mode".
    case notStarted
    /// In-memory simulation — counts what would migrate. Writes NOTHING (§g.5). Not durable progress.
    case dryRun
    /// Informed privacy consent screen (§2.8). Always PRECEDES `authenticating` (login sends identity).
    case consent
    /// Apple/Google sign-in in flight. Login failure → `notStarted` (device unchanged). Not durable.
    case authenticating
    /// Follower: another device is mid-migration for this account (§g.6). Journaled — a kill during the
    /// wait must RESUME the wait, not re-claim as leader.
    case waitingForLeader
    /// Atomic server-side reservation (`POST /account/claim`). Leader path. Idempotent for a
    /// same-device re-claim after a kill (SERIO 1 pt4).
    case claimingMigration
    /// Backfill `syncID` (PERMANENT gate) + capture `(ckRecordName, ckZoneName)` with the mirror alive.
    case assigningIdentity
    /// Upload the COMPLETE row per entity in idempotent batches (resumable by `client_mutation_id`).
    case uploadingSnapshot
    /// Counts + payload Merkle checksum, local vs backend, confirmed server-side (§g.3).
    case verifying
    /// Strict-order cutover with journaled sub-states (§g.4). See `CutoverSubstate`.
    case cutover(CutoverSubstate)
    /// Cloud is authoritative; the leader runs `reconcileFromFrozenCloudKit` on its own frozen CloudKit.
    case done
    /// Any failure BEFORE cutover → device identical to how it started (mirror never turned off).
    case failedRollback
}

/// The journaled cutover sub-states, in STRICT observable order (§g.4). The raw values encode the
/// order (`pending < serverConfirmed < …`) — reordering would change the semantics, not just wire format.
nonisolated enum CutoverSubstate: Int, Codable, Equatable, CaseIterable, Comparable {
    /// About to write `profiles.migrated_at`. Nothing external has changed yet.
    case pending = 0
    /// Backend confirmed `profiles.migrated_at` (synchronous ack).
    case serverConfirmed = 1
    /// `storageMode=.cloud` persisted atomically. The engine STARTS parallel History capture here
    /// (SERIO 1 v3 primary layer) — closes the `localModeSet→mirrorOff` orphan-write window.
    case localModeSet = 2
    /// CloudKit marker written — the LAST observable effect (a 2nd device detects it on import).
    case markerWritten = 3
    /// Personal mirror disabled via assisted relaunch. Next stop: `done`.
    case mirrorOff = 4

    static func < (lhs: CutoverSubstate, rhs: CutoverSubstate) -> Bool { lhs.rawValue < rhs.rawValue }
}

// MARK: - Events

/// The verify outcome (§g.3 + the S9 refinement). A NETWORK timeout is NOT a mismatch: it has its OWN
/// retry counter and NEVER goes back to `uploadingSnapshot`. The retry counters live in the consumer's
/// journal and enter through the event (`retriesSoFar`) — the machine is a pure function of the step.
nonisolated enum VerifyOutcome: Equatable {
    /// Counts + checksum match → proceed to cutover.
    case match
    /// A divergence → re-upload. `retriesSoFar` = mismatch retries already spent.
    case mismatch(retriesSoFar: Int)
    /// Could not verify (HTTP timeout), no divergence, no kill → idempotent retry of `verifying`.
    /// `retriesSoFar` = NETWORK retries already spent (independent of `mismatch`).
    case networkTimeout(retriesSoFar: Int)
    /// A new local delta landed DURING the verify run (optimistic readers-writers) → re-run, no retry spent.
    case newDeltaDetected
}

/// Inputs to the machine. Past-tense names are runtime completions (acks). `Equatable` so `.invalid`
/// can carry the offending event. NOT `Codable` — events are not journaled, only phases are.
nonisolated enum MigrationEvent: Equatable {
    /// User activated cloud mode. `dryRun == true` → simulate first; `false` → proceed for real.
    case userActivated(dryRun: Bool)
    case consentAccepted
    case consentDeclined
    case signInSucceeded
    case signInFailed
    /// The digested `POST /account/claim` result (§f.1). `sameDeviceReclaim` = the backend says THIS
    /// device is already the leader (idempotent re-claim after a kill).
    case claimResult(AccountClaimDecision.ClaimState, sameDeviceReclaim: Bool)
    case identityAssigned
    case snapshotUploaded
    case verifyOutcome(VerifyOutcome)
    /// Cutover step 1 acked: backend confirmed `profiles.migrated_at`. (Steps 1-2 carry no effect:
    /// the runtime performs the write and reports completion via this ack.)
    case serverConfirmedAck
    /// Cutover step 2 done: `storageMode=.cloud` persisted. CAUTION for the wiring: the RETURNED
    /// effect of this edge (`.startParallelHistoryCapture`) is the ORDER to start capture — journal
    /// `localModeSet` first, then execute the effect. Do not run the effect before emitting the event.
    case localModePersisted
    /// Request to advance to `cutover(.markerWritten)`. The returned effect `.writeCloudKitMarker`
    /// is the ORDER to write the marker (journal-then-execute) — NOT an ack that it was written.
    case markerWritten
    /// Request to advance to `cutover(.mirrorOff)`. The returned effect `.disableMirrorAndRelaunch`
    /// is the ORDER to disable the mirror via assisted relaunch (journal-then-execute).
    case mirrorDisabled
    /// Post-relaunch: the runtime is back and the mirror is confirmed off → enter `done`.
    case mirrorRelaunchCompleted
    /// Follower: the leader reached `done`. This device adopts the backend account (returning-user §k.4).
    case leaderCompleted
    /// Follower: the leader's lease appears expired/gone → re-claim (the backend arbitrates).
    case leaderVanished
    /// A non-recoverable failure BEFORE cutover.
    case fatalError
}

// MARK: - Effects

/// Declarative side-effects the RUNTIME must perform (the machine executes none of these).
nonisolated enum MigrationEffect: Equatable {
    /// Write the iCloud-KV beacon (`cloudAccountLinked` + provider), EARLY — at the claim, not the marker
    /// (v8, §g.4-faro). Closes the provider-mismatch hole across the whole cutover window.
    case writeBeacon
    /// Start the engine's parallel History capture (author=nil, enqueue to outbox, DON'T push yet).
    /// Emitted exactly on entering `cutover(.localModeSet)` (SERIO 1 v3 primary layer).
    case startParallelHistoryCapture
    /// Write the CloudKit marker — the LAST observable effect. ONLY from `cutover(.localModeSet)`.
    case writeCloudKitMarker
    /// Disable the personal mirror via assisted relaunch (no in-runtime container recreation).
    case disableMirrorAndRelaunch
    /// The leader reconciles its OWN frozen CloudKit, uploading orphan writes from the cutover window
    /// (SERIO 1 v3 backstop). Emitted on entering `done`.
    case runLeaderReconcileFromFrozenCloudKit
    /// Roll back to the pre-migration state (device identical to how it started).
    case rollback
    /// Adopt an already-existing backend account (returning-user §k.4) — the adoption flow lives OUTSIDE
    /// this machine; the machine bows out to `notStarted`.
    case adoptBackendAccount
}

// MARK: - Outcome & Policy

/// The result of a step: a valid transition (next phase + edge effects) or an explicit rejection.
nonisolated enum TransitionOutcome: Equatable {
    case transition(next: MigrationPhase, effects: [MigrationEffect])
    /// The (from, event) pair was not a legal transition — the consumer logs a breadcrumb and ignores it.
    case invalid(from: MigrationPhase, event: MigrationEvent)
}

/// Reconciliation decision for a CloudKit marker seen at boot (§g.4 pt3, SERIO 1).
nonisolated enum MarkerDecision: Equatable {
    /// No marker → nothing to reconcile.
    case none
    /// Marker present AND a trace of THIS device's own cutover in the journal → self-authored; resume
    /// the cutover from its journaled sub-state, do NOT auto-block.
    case resumeOwnCutover
    /// Marker present but NO trace of an own cutover → a legitimate secondary device; route to cloud login.
    case secondaryDeviceCloudLogin
}

/// Injectable retry policy. The two counters are INDEPENDENT (a mix of timeouts and mismatches does
/// not sum).
nonisolated struct MigrationPolicy: Equatable {
    var maxMismatchRetries: Int = 3
    var maxNetworkRetries: Int = 8

    static let `default` = MigrationPolicy()

    init(maxMismatchRetries: Int = 3, maxNetworkRetries: Int = 8) {
        self.maxMismatchRetries = maxMismatchRetries
        self.maxNetworkRetries = maxNetworkRetries
    }
}

// MARK: - Machine

nonisolated enum MigrationStateMachine {

    // MARK: Transition

    /// Pure transition step. Returns the next phase + the edge effects, or `.invalid` for an illegal pair.
    static func transition(
        from phase: MigrationPhase,
        event: MigrationEvent,
        policy: MigrationPolicy = .default
    ) -> TransitionOutcome {
        switch (phase, event) {

        // notStarted → simulate or proceed to consent.
        case let (.notStarted, .userActivated(dryRun)):
            return .transition(next: dryRun ? .dryRun : .consent, effects: [])

        // dryRun is pure UI: re-simulate, or proceed for real to consent. Never durable.
        case let (.dryRun, .userActivated(dryRun)):
            return .transition(next: dryRun ? .dryRun : .consent, effects: [])

        // consent
        case (.consent, .consentAccepted):
            return .transition(next: .authenticating, effects: [])
        case (.consent, .consentDeclined):
            return .transition(next: .notStarted, effects: [])

        // authenticating
        case (.authenticating, .signInSucceeded):
            return .transition(next: .claimingMigration, effects: [])
        case (.authenticating, .signInFailed):
            return .transition(next: .notStarted, effects: [])

        // claimingMigration — the §f.1 claim contract routes leader / follower / returning-user.
        case let (.claimingMigration, .claimResult(state, sameDeviceReclaim)):
            return claimTransition(state: state, sameDeviceReclaim: sameDeviceReclaim)

        // waitingForLeader (follower)
        case (.waitingForLeader, .leaderCompleted):
            // The leader finished → adopt the backend account (returning-user §k.4, outside this machine).
            return .transition(next: .notStarted, effects: [.adoptBackendAccount])
        case (.waitingForLeader, .leaderVanished):
            // The lease looks gone → re-claim; the backend arbitrates whether it truly expired.
            return .transition(next: .claimingMigration, effects: [])

        // assigningIdentity → uploadingSnapshot
        case (.assigningIdentity, .identityAssigned):
            return .transition(next: .uploadingSnapshot, effects: [])

        // uploadingSnapshot → verifying
        case (.uploadingSnapshot, .snapshotUploaded):
            return .transition(next: .verifying, effects: [])

        // verifying — S9 split of "diverge" vs "couldn't verify".
        case let (.verifying, .verifyOutcome(outcome)):
            return verifyTransition(outcome: outcome, policy: policy)

        // cutover — STRICT order, one journaled sub-state per event.
        case (.cutover(.pending), .serverConfirmedAck):
            return .transition(next: .cutover(.serverConfirmed), effects: [])
        case (.cutover(.serverConfirmed), .localModePersisted):
            return .transition(next: .cutover(.localModeSet), effects: [.startParallelHistoryCapture])
        case (.cutover(.localModeSet), .markerWritten):
            return .transition(next: .cutover(.markerWritten), effects: [.writeCloudKitMarker])
        case (.cutover(.markerWritten), .mirrorDisabled):
            return .transition(next: .cutover(.mirrorOff), effects: [.disableMirrorAndRelaunch])
        case (.cutover(.mirrorOff), .mirrorRelaunchCompleted):
            return .transition(next: .done, effects: [.runLeaderReconcileFromFrozenCloudKit])

        // fatalError INSIDE cutover → hold the state (idempotent resume covers recovery), NEVER rollback
        // (§g.4: a kill/failure inside cutover retakes by sub-state; the marker means the migration is real).
        case let (.cutover(sub), .fatalError):
            return .transition(next: .cutover(sub), effects: [])

        // fatalError BEFORE cutover → failedRollback (device identical to how it started).
        // notStarted/dryRun have nothing durable to roll back → falls through to `.invalid`.
        case (.consent, .fatalError),
             (.authenticating, .fatalError),
             (.waitingForLeader, .fatalError),
             (.claimingMigration, .fatalError),
             (.assigningIdentity, .fatalError),
             (.uploadingSnapshot, .fatalError),
             (.verifying, .fatalError):
            return .transition(next: .failedRollback, effects: [.rollback])

        default:
            return .invalid(from: phase, event: event)
        }
    }

    private static func claimTransition(
        state: AccountClaimDecision.ClaimState,
        sameDeviceReclaim: Bool
    ) -> TransitionOutcome {
        switch state {
        case .created:
            // Fresh row, this device leads → assign identity. Beacon written EARLY here (§g.4-faro v8).
            return .transition(next: .assigningIdentity, effects: [.writeBeacon])
        case .claimingInProgress:
            if sameDeviceReclaim {
                // Idempotent re-claim by the SAME leader (kill between ack & local persist). The backend
                // collapses it to `created` → advance, never block on self (SERIO 1 pt4).
                return .transition(next: .assigningIdentity, effects: [.writeBeacon])
            }
            // Another device leads → follow / wait.
            return .transition(next: .waitingForLeader, effects: [])
        case .existingStable:
            // Already migrated & stable → returning-user (§k.4). NEVER re-migrate/re-seed; this machine
            // bows out to the adoption flow.
            return .transition(next: .notStarted, effects: [.adoptBackendAccount])
        }
    }

    private static func verifyTransition(outcome: VerifyOutcome, policy: MigrationPolicy) -> TransitionOutcome {
        switch outcome {
        case .match:
            return .transition(next: .cutover(.pending), effects: [])
        case .newDeltaDetected:
            // Optimistic readers-writers: re-run verify; does NOT consume a retry.
            return .transition(next: .verifying, effects: [])
        case let .mismatch(retriesSoFar):
            if retriesSoFar >= policy.maxMismatchRetries {
                return .transition(next: .failedRollback, effects: [.rollback])
            }
            return .transition(next: .uploadingSnapshot, effects: [])
        case let .networkTimeout(retriesSoFar):
            if retriesSoFar >= policy.maxNetworkRetries {
                return .transition(next: .failedRollback, effects: [.rollback])
            }
            // Idempotent retry — NEVER back to uploadingSnapshot, NEVER failedRollback before the network cap.
            return .transition(next: .verifying, effects: [])
        }
    }

    // MARK: Resume (kill-recovery, §g.2/§g.4)

    /// Where to resume from a journaled phase after a process kill. Every DURABLE state resumes IN
    /// ITSELF (all idempotent), including each cutover sub-state exactly. The non-durable UI states
    /// (`dryRun`/`consent`/`authenticating`) re-enter from `notStarted`.
    ///
    /// Invariant: `resume` NEVER regresses or skips a cutover sub-state (it is the identity on cutover).
    static func resume(fromJournaled phase: MigrationPhase) -> MigrationPhase {
        switch phase {
        case .dryRun, .consent, .authenticating:
            return .notStarted
        default:
            return phase
        }
    }

    // MARK: Marker reconciliation (§g.4 pt3, SERIO 1)

    /// Decides what a CloudKit marker seen at boot means, distinguishing "leader that aborted its own
    /// cutover" from "legitimate secondary device".
    ///
    /// - No marker → `.none`.
    /// - Marker + the journal shows an OWN cutover (any sub-state, incl. `< markerWritten` = aborted, or
    ///   `>= markerWritten` = resuming) → `.resumeOwnCutover` (do NOT auto-block).
    /// - Marker + own migration already `done` → `.none` (this device migrated; operate in cloud).
    /// - Marker + NO trace of own cutover → `.secondaryDeviceCloudLogin`.
    static func markerReconciliation(markerFound: Bool, journaledPhase: MigrationPhase) -> MarkerDecision {
        guard markerFound else { return .none }
        switch journaledPhase {
        case .cutover:
            return .resumeOwnCutover
        case .done:
            return .none
        default:
            return .secondaryDeviceCloudLogin
        }
    }

    // MARK: Write-window invariant (SERIO 1 v3)

    /// The parallel-history-capture window: `phase >= cutover(.localModeSet) && phase < done`. During it,
    /// every new local write MUST be captured to the outbox or it is lost functionally (the mirror still
    /// owns CloudKit, the engine does not push yet). The runtime consumes this predicate; the golden test
    /// fixes the contract.
    static func requiresParallelHistoryCapture(phase: MigrationPhase) -> Bool {
        switch phase {
        case let .cutover(sub):
            return sub >= .localModeSet
        default:
            // `done` and everything before `localModeSet` → no active capture window.
            return false
        }
    }
}
