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

    // MARK: Reverse (§h — cloud→CloudKit) — DARK in I11-1 (nothing in production drives it; the panel
    // wires it in I11-5, the real UI is I14). Ordering premise (§h.1 REORDERED): the mirror is mounted
    // BEFORE deleting anything. The rollback boundary is the mirror mount: PRE-mount failures roll back
    // (local intact, storageMode still `.cloud`); POST-mount failures HOLD + idempotent resume (the
    // mirror is already alive) — symmetric to the cutover.
    /// Double-confirmation UI. NON-durable (resume → origin). `ReverseOrigin` records where a decline/kill
    /// returns: `.done` (the original migration leader) or `.notStarted` (a device that ADOPTED the cloud
    /// account — its journal is `notStarted` after `adoptBackendAccount`). Without the origin, a decline
    /// from `done` would reset the journal to `notStarted` and `markerReconciliation` would falsely fire
    /// `secondaryDeviceCloudLogin` (live marker + no trace). The "is this device in cloud mode?" guard is
    /// NOT the machine's (pure): the wiring/panel gates by `storageMode == .cloud`.
    case reverseConfirm(ReverseOrigin)
    /// Server-side reservation (`reverse_in_progress` + leader). Durable.
    case reverseClaimLeader
    /// Final pull + drain of this device's own outbox. Durable.
    case reverseDrainAll
    /// Pull to server_seq top + Merkle local==backend. Durable. (Reuses `VerifyOutcome` + the S9 counters,
    /// which are INDEPENDENT of the forward migration's — the runner resets them on `reverseClaimLeader`.)
    case reverseVerify
    /// Mark the backend account "reverting". Durable.
    case reverseFreezeBackend
    /// RE-LIGHTS the `.private` mirror via assisted relaunch — CROSSES the process boundary (like the
    /// cutover's mirror-off). Resolved by OBSERVATION on resume, never blind re-execution. Durable.
    case reverseMountMirror
    /// Journaled §h.3 sub-states (`ReverseReconcileSubstate`). Durable. The "done" of the reconcile is NOT
    /// a sub-state: leaving to `reverseUpload` IS the done (same pattern as cutover→done).
    case reverseReconcile(ReverseReconcileSubstate)
    /// The mirror exports the complete store (the History token survives, spike S2). Durable.
    case reverseUpload
    /// STABLE terminal: private mode; the backend is frozen as a safety net.
    case icloudActive
    /// STABLE terminal: the reverse aborted PRE-mount; the device stays in clean cloud mode (the mirror
    /// was never re-lit).
    case reverseFailedRollback
}

/// Where a `reverseConfirm` decline/kill returns. `String, Codable` for the journal (the I11-2 runner
/// persists `MigrationState.reverseOriginRaw` on the `reverseConfirm→reverseClaimLeader` edge — the
/// machine does NOT thread the origin past `reverseConfirm`). A leader that migrated returns to `.done`;
/// an adopter returns to `.notStarted`.
nonisolated enum ReverseOrigin: String, Codable, Equatable {
    case done
    case notStarted
}

/// The journaled reverse-reconcile sub-states (§h.3), in STRICT order. The raw values encode the order
/// (`awaitingQuiescence < deletingZombies < …`). `Comparable` so resume never regresses/skips (invariant).
nonisolated enum ReverseReconcileSubstate: Int, Codable, Equatable, CaseIterable, Comparable {
    /// Gate `isImportQuiescent` BEFORE the first delete+save (SERIO 3 v3).
    case awaitingQuiescence = 0
    /// Backend tombstones → `CKRecord.ID` via `SyncIdentity` → delete through the mirror.
    case deletingZombies = 1
    /// `SyncIdentity.lastReboundAt` → delete the stale record + upload the new one.
    case rebindingUUIDs = 2
    /// Auto-heal Account/Tag (I11-4).
    case dedupHealed = 3

    static func < (lhs: ReverseReconcileSubstate, rhs: ReverseReconcileSubstate) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
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

/// C-1: por qué el marcador del cutover no exporta, y por tanto qué presupuesto de tiempo merece el
/// paso 4. `.definitive` = CloudKit YA dictó que el write no entra (cuota agotada, cuenta inutilizable) ⇒
/// esperar no cambia nada. `.unknown` = aún no sabemos (offline, mirror encolado, export lento) ⇒
/// presupuesto largo: un snapshot completo ya subido y verificado no se tira por una mala racha de red.
nonisolated enum MarkerExportStall: Equatable, Sendable {
    case unknown
    case definitive
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

    // MARK: C-1 — el canal iCloud no puede cerrar el cutover (§g.4)

    /// El canal iCloud está sabido-roto (cuota agotada, cuenta ausente con copia viva en CloudKit, CloudKit
    /// inutilizable). Emitido SOLO en la ENTRADA (`verifying` rama `.match`, y `cutover(.pending)`), donde
    /// nada durable ha cambiado todavía ⇒ rollback limpio. El runner obtiene el veredicto de
    /// `MigrationWorkExecuting.probeICloudChannel()`; la máquina no hace I/O.
    case icloudCutoverPreconditionFailed
    /// Observación del atasco del paso 4: el marcador sigue sin exportar. `elapsedSeconds` lo mide el
    /// RUNNER (`now()` menos `MigrationState.markerWrittenSince`) — la máquina es pura y solo aplica el
    /// presupuesto de `MigrationPolicy`, idéntico idiom al `retriesSoFar` de `VerifyOutcome`. El tope es por
    /// TIEMPO y no por intentos porque la cadencia real del runner es boot + cada foreground + tap: un
    /// contador castigaría a quien abre la app muchas veces y premiaría a quien no la abre.
    case markerExportStalled(elapsedSeconds: Double, cause: MarkerExportStall)

    // MARK: Reverse events (§h) — command-vs-ack like the cutover events. DARK in I11-1.
    /// User asked to go back to iCloud (the wiring gates by `storageMode == .cloud`). Legal from `done`
    /// (the migration leader) AND from `notStarted` (an adopter — returning-user §k.4), and from
    /// `icloudActive` as `.userActivated` re-cutover (via consent; §h.4, flow I14).
    case reverseActivated
    /// Double-confirmation accepted → `reverseClaimLeader`.
    case reverseConfirmed
    /// Double-confirmation declined → back to the origin (from `reverseConfirm`'s associated value).
    case reverseDeclined
    /// Ack: the backend accepted the reservation (`reverse_in_progress` + leader).
    case reverseLeaderClaimed
    /// The reverse-claim found ANOTHER device already reverse-leader (§h). UN-STICKS `reverseClaimLeader`
    /// (a TRANSIENT phase): without this exit the journal would sit in `reverseClaimLeader` forever →
    /// BGTasks (reports) suppressed indefinitely. The RUNNER injects `returnTo` from the journal's
    /// `reverseOriginRaw` (fallback `.done`). v1 is single-device → no reverse-follower is modeled; this
    /// simply bows out to the origin (a re-activation is legal later). NOT journaled (an event, like the rest).
    case reverseOtherLeader(returnTo: ReverseOrigin)
    /// Ack: the final pull + own outbox drain finished.
    case reverseDrainCompleted
    /// The reverse verify outcome. REUSES `VerifyOutcome` (S9): a mismatch re-drains (authority in the
    /// reverse is backend→local, so the fix is a PULL, not a re-upload); a timeout retries the verify.
    case reverseVerifyOutcome(VerifyOutcome)
    /// Ack: the account is marked `reverting`.
    case reverseBackendFrozen
    /// OBSERVATION post-relaunch: the `.private` mirror mounted (witness
    /// `personalStoreMountedDecision.attachesCloudKitMirror`) — analogous to `mirrorRelaunchCompleted`.
    /// CONTRACT (I11-2): this observation MUST be injectable/fake-able in tests
    /// (`personalStoreMountedDecision` defaults to `.iCloudMirror` and is only captured on the production
    /// path → a real read would report "mounted" ALWAYS = false green). Seam like `isMirrorConfirmedOff`
    /// of the fake.
    case reverseMirrorMounted
    /// `awaitingQuiescence` → `deletingZombies`.
    case reverseQuiescenceReached
    /// `deletingZombies` → `rebindingUUIDs`.
    case reverseZombiesDeleted
    /// `rebindingUUIDs` → `dedupHealed`.
    case reverseUUIDsRebound
    /// `dedupHealed` → `reverseUpload`.
    case reverseDedupHealed
    /// → `icloudActive` (with the closing effects, S2).
    case reverseUploadCompleted
}

// MARK: - Effects

/// Declarative side-effects the RUNTIME must perform (the machine executes none of these).
///
/// `String, Codable` (ADITIVO for I10-wiring): the raw value = the case name and is WIRE-STABLE —
/// `MigrationRunner` journals the PENDING effects of a transition (`MigrationState.pendingEffectsData`,
/// journal-then-execute, N1) so a kill re-executes exactly what was authorized. The cases are
/// APPEND-ONLY once shipped: renaming/removing one would break the decode of an in-flight journal.
nonisolated enum MigrationEffect: String, Equatable, Codable {
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

    // MARK: Reverse effects (§h) — String/Codable APPEND-ONLY. DARK in I11-1: the executor receives them
    // and throws `notWired` (I11-2/3 wire them). Only the ordering-critical / observable ones are surfaced.
    /// Un-reserve the server (`reverse_abort`) — reachable ONLY PRE-mount (local unchanged).
    case reverseRollback
    /// ORDER: disarm `mirrorOffArmedKey` (keeping `.cloud` → decision iCloudMirror) + request an assisted
    /// relaunch. Resolved by OBSERVATION on resume (like `disableMirrorAndRelaunch`, never blind re-exec).
    case mountMirrorAndRelaunch
    /// Delete `CD_CloudMigrationMarker` from the personal store (the LIVE mirror exports the delete). S2 of
    /// the I10-pre review: without it, a re-migrate would falsely fire `secondaryDeviceCloudLogin`.
    case deleteCloudKitMarker
    /// Clear the `cloudAccountLinked` beacon from iCloud KV (§g.4-faro, v6 A26).
    case clearCloudBeacon
    /// Persist `storageMode=.icloud` + `mirrorOffArmed=false` TOGETHER (invariant SERIO 1).
    case persistICloudMode
    /// `migration_progress` `reverse_complete` (`reverse_in_progress=false`).
    case completeReverseServer
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

    /// C-1: presupuesto del paso 4 cuando CloudKit YA dictó que el write no entra (cuota agotada, cuenta
    /// inutilizable). 15 min: esperar más no cambia el resultado, y cada minuto extra es un minuto de
    /// doble escritura potencial.
    var markerExportDefinitiveBudgetSeconds: Double = 900
    /// C-1: presupuesto del paso 4 cuando aún no sabemos por qué el marcador no exporta. 72 h, generoso a
    /// propósito: en este punto el snapshot ya está subido Y verificado, así que un falso positivo por 24 h
    /// sin cobertura costaría más que la espera. El canario `cloudCutoverMarkerStalled` se emite en CADA
    /// observación (no solo al agotar), así que un atasco sistémico —p.ej. el record type sin desplegar a
    /// CloudKit Production— se ve en el dashboard mucho antes de que ningún device degrade.
    var markerExportUnknownBudgetSeconds: Double = 259_200

    static let `default` = MigrationPolicy()

    init(
        maxMismatchRetries: Int = 3,
        maxNetworkRetries: Int = 8,
        markerExportDefinitiveBudgetSeconds: Double = 900,
        markerExportUnknownBudgetSeconds: Double = 259_200
    ) {
        self.maxMismatchRetries = maxMismatchRetries
        self.maxNetworkRetries = maxNetworkRetries
        self.markerExportDefinitiveBudgetSeconds = markerExportDefinitiveBudgetSeconds
        self.markerExportUnknownBudgetSeconds = markerExportUnknownBudgetSeconds
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

        // C-1 · PRECONDICIÓN DE ENTRADA. Legal SOLO desde `verifying` y `cutover(.pending)`: ahí no existe
        // `migrated_at`, ni `.cloud` persistido, ni marcador ⇒ el rollback deja el device idéntico a como
        // empezó. NO viola "el cutover jamás hace rollback": esa regla protege los sub-estados POSTERIORES,
        // donde el marcador ya existe y la migración es real. Desde `serverConfirmed` en adelante este
        // evento es `.invalid` a propósito (pinneado por test) — ahí manda el tope del paso 4.
        case (.verifying, .icloudCutoverPreconditionFailed),
             (.cutover(.pending), .icloudCutoverPreconditionFailed):
            return .transition(next: .failedRollback, effects: [.rollback])

        // C-1 · TOPE del paso 4. Bajo presupuesto HOLDEA sin efectos (molde de `newDeltaDetected`): el
        // runner corta retomable y el próximo resume vuelve a observar. Al agotarlo, ABORT LOCAL sin red —
        // el orden de los efectos es OBLIGATORIO:
        //   1. `.persistICloudMode` PRIMERO: escribe `.icloud` + desarma el mirror-off JUNTOS y es el único
        //      efecto que NO puede lanzar (`UserDefaults` puro) ⇒ la mitad peligrosa se deshace antes que
        //      nada más pueda fallar. Sin él, `failedRollback` "pelado" sería PEOR que el bug: dejaría
        //      `.cloud` persistido y el "Reintentar" de la UI (`resetAfterRollback` → `notStarted`, fase
        //      ESTABLE) haría pasar `canRunDomain()` ⇒ motor Y mirror escribiendo a la vez, ya sin gate.
        //   2. `.deleteCloudKitMarker`: el marcador significa "la migración COMPLETÓ y la nube es
        //      autoritativa", y eso pasa a ser FALSO tras el abort. Un marcador sin exportar que exportase
        //      días más tarde le mentiría al parque entero (congelaría escrituras y rutearía a adopt contra
        //      un backend estancado). De regalo, sin fila de marcador `markerReconciliation` ve
        //      `markerFound == false` y no auto-etiqueta este device como secundario.
        //   3. `.rollback`: desarme defensivo + breadcrumb.
        // Espeja el cierre LOCAL de la reversa (§h.4) menos la llamada al server — el mundo queda con la
        // MISMA forma que una reversa completada, que el diseño ya razonó y aceptó. `migrated_at` sigue
        // estampado (no existe RPC de abort de la ida): un reintento entrará por adopt, residual documentado.
        case let (.cutover(.markerWritten), .markerExportStalled(elapsed, cause)):
            let budget = cause == .definitive
                ? policy.markerExportDefinitiveBudgetSeconds
                : policy.markerExportUnknownBudgetSeconds
            guard elapsed >= budget else {
                return .transition(next: .cutover(.markerWritten), effects: [])
            }
            return .transition(
                next: .failedRollback,
                effects: [.persistICloudMode, .deleteCloudKitMarker, .rollback])

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

        // MARK: Reverse (§h) — DARK in I11-1.

        // Entry from `done` (the migration leader) AND from `notStarted` (an adopter, returning-user §k.4).
        // If the reverse only left `done`, ONLY the original leader could ever revert. The origin is
        // recorded so a decline/kill returns to the RIGHT place (see `reverseConfirm` doc).
        case (.done, .reverseActivated):
            return .transition(next: .reverseConfirm(.done), effects: [])
        case (.notStarted, .reverseActivated):
            return .transition(next: .reverseConfirm(.notStarted), effects: [])
        // `icloudActive` re-cutover (§h.4): re-enters the forward migration via consent. The claim will
        // return `existing_stable` → adopt (flow I14); this edge only avoids a terminal without exit.
        case let (.icloudActive, .userActivated(dryRun)):
            return .transition(next: dryRun ? .dryRun : .consent, effects: [])

        // reverseConfirm — NON-durable. CONTRACT (I11-2): the runner persists `reverseOriginRaw` in the
        // SAME journal save as this `reverseConfirm(origin)→reverseClaimLeader` transition; the machine
        // does NOT carry the origin past `reverseConfirm`.
        case (.reverseConfirm, .reverseConfirmed):
            return .transition(next: .reverseClaimLeader, effects: [])
        case let (.reverseConfirm(origin), .reverseDeclined):
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // reverseClaimLeader → reverseDrainAll. CONTRACT (I11-2): the runner RESETS the S9 counters (and
        // scoped fields) when it journals `reverseClaimLeader` — they may carry gasto from the forward
        // verify (the current S2-cleanup only resets on notStarted/failedRollback).
        case (.reverseClaimLeader, .reverseLeaderClaimed):
            return .transition(next: .reverseDrainAll, effects: [])

        // reverseClaimLeader → ORIGIN (desatascador, obligación 4 del review I11-1): otro device ya es
        // reverse-líder. El runner inyecta el `origin` desde el journal (`reverseOriginRaw`, fallback `.done`).
        // Sin esta salida `reverseClaimLeader` (TRANSIENT) quedaría journaleado para siempre → reports
        // suprimidos. v1 single-device: no hay reverse-follower que modelar; se cede al origin (una
        // re-activación posterior vuelve a entrar por `reverseActivated`). Sin efectos.
        case let (.reverseClaimLeader, .reverseOtherLeader(origin)):
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // reverseDrainAll → reverseVerify
        case (.reverseDrainAll, .reverseDrainCompleted):
            return .transition(next: .reverseVerify, effects: [])

        // reverseVerify — S9 reused; the mismatch fix is a PULL (re-drain), not a re-upload.
        case let (.reverseVerify, .reverseVerifyOutcome(outcome)):
            return reverseVerifyTransition(outcome: outcome, policy: policy)

        // reverseFreezeBackend → reverseMountMirror (RE-LIGHT the mirror, crosses the process boundary).
        case (.reverseFreezeBackend, .reverseBackendFrozen):
            return .transition(next: .reverseMountMirror, effects: [.mountMirrorAndRelaunch])

        // reverseMountMirror → reverseReconcile(.awaitingQuiescence), resolved by OBSERVATION post-relaunch.
        case (.reverseMountMirror, .reverseMirrorMounted):
            return .transition(next: .reverseReconcile(.awaitingQuiescence), effects: [])

        // reverseReconcile — STRICT order, one journaled sub-state per event (like cutover).
        case (.reverseReconcile(.awaitingQuiescence), .reverseQuiescenceReached):
            return .transition(next: .reverseReconcile(.deletingZombies), effects: [])
        case (.reverseReconcile(.deletingZombies), .reverseZombiesDeleted):
            return .transition(next: .reverseReconcile(.rebindingUUIDs), effects: [])
        case (.reverseReconcile(.rebindingUUIDs), .reverseUUIDsRebound):
            return .transition(next: .reverseReconcile(.dedupHealed), effects: [])
        case (.reverseReconcile(.dedupHealed), .reverseDedupHealed):
            // Leaving the reconcile IS its done (no sub-state for it), same pattern as cutover→done.
            return .transition(next: .reverseUpload, effects: [])

        // reverseUpload → icloudActive, with the closing quartet in ORDER (marker first — it needs the
        // mirror already mounted, which it is; server last — the network is the flakiest, journal-then-
        // execute keeps it retakeable). No export gate for the marker-delete: the mirror stays alive
        // FOREVER after the reverse → the export lands on its own (unlike the cutover, where turning the
        // mirror off killed the channel).
        case (.reverseUpload, .reverseUploadCompleted):
            return .transition(next: .icloudActive, effects: [
                .deleteCloudKitMarker, .clearCloudBeacon, .persistICloudMode, .completeReverseServer,
            ])

        // fatalError PRE-mount (nothing local changed; the mirror was never re-lit) → reverseFailedRollback.
        case (.reverseClaimLeader, .fatalError),
             (.reverseDrainAll, .fatalError),
             (.reverseVerify, .fatalError),
             (.reverseFreezeBackend, .fatalError):
            return .transition(next: .reverseFailedRollback, effects: [.reverseRollback])

        // fatalError POST-mount → HOLD the state (idempotent resume covers recovery), NEVER rollback: the
        // mirror is already alive and the resume retakes.
        case let (.reverseReconcile(sub), .fatalError):
            return .transition(next: .reverseReconcile(sub), effects: [])
        case (.reverseMountMirror, .fatalError):
            return .transition(next: .reverseMountMirror, effects: [])
        case (.reverseUpload, .fatalError):
            return .transition(next: .reverseUpload, effects: [])

        // fatalError in reverseConfirm → back to the origin (nothing durable).
        case let (.reverseConfirm(origin), .fatalError):
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // §h.6 (born-cloud→iCloud) reuses this SAME chain; its differences (trivial reconcile, first
        // upload, SyncIdentity capture in reverseUpload) are the EXECUTOR's — annotated for I11-2, exposed
        // in I14. The machine models no separate born-cloud path.

        default:
            return .invalid(from: phase, event: event)
        }
    }

    /// The phase a `reverseConfirm` decline/kill returns to. A migrated leader → `done`; an adopter →
    /// `notStarted`.
    private static func reverseOriginPhase(_ origin: ReverseOrigin) -> MigrationPhase {
        switch origin {
        case .done:       return .done
        case .notStarted: return .notStarted
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

    /// The reverse verify (§h) — REUSES `VerifyOutcome` and the S9 counters (INDEPENDENT of the forward
    /// verify's; the runner resets them on `reverseClaimLeader`). Authority in the reverse is backend→local,
    /// so a mismatch is fixed by a PULL (`reverseDrainAll`), NEVER a re-upload.
    private static func reverseVerifyTransition(outcome: VerifyOutcome, policy: MigrationPolicy) -> TransitionOutcome {
        switch outcome {
        case .match:
            return .transition(next: .reverseFreezeBackend, effects: [])
        case .newDeltaDetected:
            // Re-run verify; does NOT consume a retry.
            return .transition(next: .reverseVerify, effects: [])
        case let .mismatch(retriesSoFar):
            if retriesSoFar >= policy.maxMismatchRetries {
                return .transition(next: .reverseFailedRollback, effects: [.reverseRollback])
            }
            // Backend→local authority: fix a divergence by re-pulling/draining, never re-uploading.
            return .transition(next: .reverseDrainAll, effects: [])
        case let .networkTimeout(retriesSoFar):
            if retriesSoFar >= policy.maxNetworkRetries {
                return .transition(next: .reverseFailedRollback, effects: [.reverseRollback])
            }
            return .transition(next: .reverseVerify, effects: [])
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
        case let .reverseConfirm(origin):
            // NON-durable (like consent) → re-enter from the origin. All other reverse phases are durable
            // and idempotent → they resume in themselves (covered by `default`), incl. each
            // `reverseReconcile(sub)` exactly (invariant: never regress/skip a sub-state).
            return reverseOriginPhase(origin)
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
        // EXHAUSTIVE SIN default (D3 of the I11-1 review — same principle as `BGTaskMigrationGate`): a
        // future phase MUST break compilation and force classification. A silent `default` was EXACTLY the
        // bug-class the inverted §i.9 gate already paid for. Here it would route a device MID-REVERSE (its
        // own marker still alive — it is deleted at the end) falsely to `secondaryDeviceCloudLogin`.
        switch journaledPhase {
        case .cutover:
            return .resumeOwnCutover
        case .done:
            return .none
        // Reverse phases + terminals → `.none`: a present marker is EXPECTED mid-reverse (deleted as an
        // effect of `icloudActive`, drained by resume; post-reverse a residual marker is its own delete
        // still in export, benign). The marker is only VISIBLE with the mirror mounted (post-mount phases +
        // icloudActive) but ALL reverse phases are classified for robustness.
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
             .icloudActive, .reverseFailedRollback:
            return .none
        // Forward phases before/at the cutover trace, with a marker but no OWN cutover trace → a
        // legitimate secondary device; route to cloud login.
        case .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader,
             .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying, .failedRollback:
            return .secondaryDeviceCloudLogin
        }
    }

    // MARK: Write-window invariant (SERIO 1 v3)

    /// The parallel-history-capture window: `phase >= cutover(.localModeSet) && phase < done`. During it,
    /// every new local write MUST be captured to the outbox or it is lost functionally (the mirror still
    /// owns CloudKit, the engine does not push yet). The runtime consumes this predicate; the golden test
    /// fixes the contract.
    static func requiresParallelHistoryCapture(phase: MigrationPhase) -> Bool {
        // EXHAUSTIVE SIN default (D3 of the I11-1 review) — same principle as `markerReconciliation`.
        switch phase {
        case let .cutover(sub):
            return sub >= .localModeSet
        // Reverse phases (§h) → false: during the reverse the RE-MOUNTED mirror is the write channel; the
        // backend is frozen and receives no more — the user's writes in the window go to CloudKit via the
        // mirror. The I14 UI communicates the freeze; residual documented.
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
             .icloudActive, .reverseFailedRollback:
            return false
        // `done` and everything before `localModeSet` → no active capture window.
        case .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader,
             .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying, .done, .failedRollback:
            return false
        }
    }
}
