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
    //
    // Hay UNA salida post-montaje, y no es un fallo: la ESPERA de `reverseUpload`. Si el mirror no drena durante
    // un presupuesto de tiempo SIN avanzar, o la persona cancela desde la pantalla de espera, la reversa VUELVE a
    // su origen en modo nube (ticket `reverse-upload-has-no-ceiling-and-no-exit`, decisión de Jürgen del
    // 2026-09-16). Sin ella la espera no tenía techo, y el backend ya estaba congelado.
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
    /// The mirror exports the complete store (the History token survives, spike S2). Durable. La espera tiene
    /// techo por tiempo journaleado SIN avanzar (`reverseUploadStalled`) y una salida de la persona
    /// (`reverseUploadCancelled`); las dos vuelven al origen en modo nube.
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
    /// «Migrar a la nube» y el claim contestó `existing_stable` o `claiming_in_progress`: la cuenta ya tiene lo personal
    /// reclamado —completa, o volvió a iCloud y sigue congelada— u otro dispositivo la está migrando. Con esa intención no
    /// se adopta ni se sigue al líder: el adopt subiría a esa cuenta el corpus local y la persona terminaría con dos datasets
    /// mezclados (ticket `settings-migrate-to-cloud-adopts-silently-instead-of-migrating`).
    /// El runner lo emite en vez del `claimResult` solo con `ForwardClaimIntent.migrateOnly`; la máquina no conoce la
    /// intención.
    case claimRefusedExistingAccount
    case identityAssigned
    case snapshotUploaded
    /// Observación de `uploadingSnapshot` en una pasada que no confirmó ninguna página (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`). Bajo presupuesto HOLDEA en la fase, sin efectos: el runner
    /// corta retomable y el próximo resume vuelve a observar. **Trae DOS relojes, y cada uno gobierna un techo**, molde
    /// de `reversePreMountStalled`:
    ///  · `stalledSeconds` es el de AVANCE —`now()` menos `MigrationState.snapshotStallProgressAt`, la última página
    ///    confirmada— y gobierna el presupuesto LARGO, con cualquier causa;
    ///  · `definitiveStalledSeconds` es el de «CUALQUIER motivo definitivo» —lo ACUMULADO desde el último avance bajo
    ///    motivos que esperar no arregla, sean el mismo o distintos; una observación sin motivo lo pausa— y gobierna el
    ///    CORTO, que solo aplica con `cause == .definitive`.
    /// **Hasta `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` el corto se medía contra el
    /// reloj de UNA causa**, que se reinicia al cambiar de motivo: con un fallo local al leer y el 409 del push
    /// turnándose no pasaba nunca de una observación, y la salida se iba a las 72 h. El reloj por causa sigue en el
    /// runner, solo para elegir el COPY de la salida; la máquina no lo necesita, porque todo lo que acumula un motivo lo
    /// acumula también éste (salvo en una fila anterior a la v13, que trae el de causa acumulado y éste vacío: ahí la
    /// salida llega, como mucho, un plazo corto después).
    /// Aquí avanzar SÍ es una cifra: la subida confirma páginas, así que un corpus grande que sube despacio re-sella
    /// los relojes en cada página y no agota nunca ninguno.
    case snapshotUploadStalled(stalledSeconds: Double, definitiveStalledSeconds: Double, cause: MarkerExportStall)
    /// La persona cancela la activación de la nube desde la tarjeta de progreso de la subida.
    case snapshotUploadCancelled
    /// Observación de uno de los TRES pasos de la ida sin cifra que baje —`claimingMigration` (22 %),
    /// `assigningIdentity` (35 %) y `cutover(.pending)` (80 %)— en una pasada que no avanzó (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`). Hasta ese ticket los tres cortaban sin evento y la barra
    /// se quedaba quieta para siempre. Bajo presupuesto HOLDEA en su propia fase, sin efectos. **Dos relojes**, molde de
    /// `reversePreMountStalled`:
    ///  · `stalledSeconds` es el de AVANCE —`now()` menos `MigrationState.forwardStepStallProgressAt`— y gobierna el
    ///    presupuesto LARGO con cualquier causa. Aquí avanzar es CAMBIAR DE PASO: el runner lo sella en la primera
    ///    observación del paso y `handle` lo borra en cada cambio de paso;
    ///  · `causeStalledSeconds` es el de CAUSA —lo ACUMULADO bajo el mismo motivo— y gobierna el CORTO, solo con
    ///    `cause == .definitive`.
    case forwardStepStalled(stalledSeconds: Double, causeStalledSeconds: Double, cause: MarkerExportStall)
    /// La persona cancela la activación desde uno de esos tres pasos. Misma salida que la cancelación de la subida.
    case forwardStepCancelled
    /// Observación del EFECTO del adopt (`.adoptBackendAccount` pendiente en `notStarted`) que venció su techo (ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`, decisión de Jürgen del 2026-09-23: 15 min / 72 h). **Solo sale; no
    /// holdea**: bajo presupuesto el runner no emite nada y deja el efecto pendiente, porque una transición que lo repusiera
    /// lo volvería a ejecutar en el mismo `handle`. Por eso aquí, bajo presupuesto, es `.invalid`. Dos relojes:
    ///  · `stalledSeconds` —`now()` menos `MigrationState.adoptEffectStallProgressAt`, el primer intento fallido— gobierna
    ///    las 72 h con cualquier causa;
    ///  · `definitiveStalledSeconds` —lo ACUMULADO con un motivo que esperar no arregla, hoy la base local— los 15 min.
    case adoptEffectStalled(stalledSeconds: Double, definitiveStalledSeconds: Double)
    /// La persona cancela mientras el efecto del adopt se reintenta. A `notStarted` sin el pendiente.
    case adoptEffectCancelled
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
    /// El servidor RECHAZÓ el claim de la reversa (`ok:false` con un motivo que no es `other_leader`: hoy
    /// `not_complete`, `migration_in_progress` o `no_profile`). Segunda salida de `reverseClaimLeader`, gemela de
    /// `reverseOtherLeader`: sin ella el journal se quedaba en esa fase TRANSITORIA para siempre, con la barra al
    /// 15 %, el motor de la nube sin arrancar en los siguientes lanzamientos y los BGTasks diferidos (ticket
    /// `reverse-claim-rejection-has-no-way-out-in-the-client`). El runner inyecta `returnTo` desde
    /// `reverseOriginRaw` y journalea el porqué para la pantalla; la máquina no lo necesita.
    case reverseClaimRejected(returnTo: ReverseOrigin)
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

    // MARK: Techo y salida de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)

    /// Observación de la espera de `reverseUpload`: el mirror aún no drena. `returnTo` lo inyecta el runner desde
    /// `reverseOriginRaw`, como en `reverseOtherLeader`: la máquina no propaga el origen más allá de `reverseConfirm`.
    ///
    /// **Trae DOS relojes, y cada uno gobierna un techo** (ticket
    /// `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`, molde de `reversePreMountStalled`):
    ///  · `stalledSeconds` es el de AVANCE —`now()` menos el instante del ÚLTIMO AVANCE journaleado
    ///    (`MigrationState.reverseUploadProgressAt`)—, no desde que empezó la espera: un corpus grande que sube despacio
    ///    avanza y nunca lo agota. Gobierna el LARGO, con cualquier motivo;
    ///  · `definitiveStalledSeconds` es el de «cualquier motivo definitivo» —lo ACUMULADO desde el último avance bajo
    ///    `icloudFull` o `icloudUnusable`, sean el mismo o se turnen; `icloudOff` y `unknown` lo pausan— y gobierna el
    ///    CORTO, que solo se aplica cuando `cause == .definitive`.
    ///
    /// Hasta ese ticket venía uno solo y el corto se aplicaba a él: tres horas sin cuenta de iCloud y un
    /// `notAuthenticated` de una pasada al entrar —lo habitual— sacaban de la vuelta en ese mismo instante, sin un
    /// reintento.
    case reverseUploadStalled(
        stalledSeconds: Double, definitiveStalledSeconds: Double,
        cause: MarkerExportStall, returnTo: ReverseOrigin)
    /// La persona cancela la vuelta desde la pantalla de espera («Cancelar y seguir en la nube»). Misma salida
    /// que el tope, sin esperar a que venza.
    case reverseUploadCancelled(returnTo: ReverseOrigin)

    // MARK: Techo y salida de las CUATRO fases previas al montaje
    // (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`)

    /// Observación de una fase PREVIA al montaje que no avanza. Válido desde las cuatro (`reverseClaimLeader`,
    /// `reverseDrainAll`, `reverseVerify`, `reverseFreezeBackend`), y bajo presupuesto HOLDEA en su propia fase como
    /// el techo de la espera de subida. `returnTo` lo inyecta el runner desde `reverseOriginRaw`, como en
    /// `reverseOtherLeader`.
    ///
    /// **Trae DOS relojes, y cada uno gobierna un techo** (ticket
    /// `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`):
    ///  · `stalledSeconds` es el de la FASE —`now()` menos `MigrationState.reversePreMountProgressAt`, el instante
    ///    del último CAMBIO de fase journaleado— y gobierna el presupuesto LARGO;
    ///  · `definitiveStalledSeconds` es el de «CUALQUIER motivo definitivo» —lo ACUMULADO parado bajo motivos que
    ///    esperar no arregla, sean el mismo o distintos; una observación sin motivo lo pausa— y gobierna el CORTO,
    ///    que solo se aplica cuando `cause == .definitive`.
    ///
    /// Hasta ese ticket venía uno solo y el corto se aplicaba a él: una espera larga por otra causa se cobraba
    /// entera contra el presupuesto de la causa de esta observación, y un fallo aislado sacaba de la vuelta en el
    /// acto. **Y hasta `alternating-definitive-causes-never-reach-the-short-ceiling` el corto se medía contra el
    /// reloj de UNA causa**, que se reinicia al cambiar de motivo: con dos motivos definitivos turnándose —una cuenta
    /// suspendida y un store que falla a ratos— no pasaba nunca de una observación, y la salida se iba a las 72 h.
    /// El reloj por causa sigue existiendo, pero en el runner y solo para elegir el COPY de la salida; la máquina no
    /// lo necesita, porque todo lo que acumula un motivo lo acumula también éste (salvo en una fila anterior a la
    /// v12, que trae el de causa acumulado y éste vacío: ahí la salida llega, como mucho, un plazo corto después).
    ///
    /// Aquí «avanzar» no es una cifra que baje sino cambiar de fase: el drenaje no expone un pendiente comparable, la
    /// verificación es un veredicto y el congelado es una sola llamada. El único bucle posible
    /// (`reverseVerify ⇄ reverseDrainAll` por mismatch) lo acota `maxMismatchRetries`, así que no puede re-sellar el
    /// reloj para siempre.
    case reversePreMountStalled(
        stalledSeconds: Double, definitiveStalledSeconds: Double,
        cause: MarkerExportStall, returnTo: ReverseOrigin)
    /// La persona cancela la vuelta desde una de las cuatro fases previas al montaje. Misma salida que su techo, sin
    /// esperar a que venza.
    case reversePreMountCancelled(returnTo: ReverseOrigin)
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
    /// Un-reserve the server (`reverse_abort`). Desde el ticket `reverse-upload-has-no-ceiling-and-no-exit` es
    /// alcanzable también en la salida de `reverseUpload` —ahí además DESCONGELA el backend—, y va DESPUÉS de
    /// `.rearmMirrorOff`. Pre-montaje, el local sigue intacto.
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

    /// Salida de `reverseUpload`: vuelve a ARMAR el apagado del mirror manteniendo `.cloud`, con el escritor único
    /// del par (`StorageModePersistence.writeCloudArmed`). El mirror sigue montado en ESTE proceso; el siguiente
    /// arranque monta el store sin él, y hasta entonces la UI pide relanzar (`needsRelaunch(.toCloud)`) y el
    /// motor no arranca (`personalMountMismatch`). `UserDefaults` puro: no puede lanzar, y por eso va PRIMERO,
    /// antes del `.reverseRollback` de red. Idempotente, sin observación: re-ejecutarlo tras un kill no cambia
    /// nada. NO se reusa `.disableMirrorAndRelaunch`: el resume lo resuelve por observación y dispara
    /// `mirrorRelaunchCompleted`, inválido fuera del cutover, y corta el drenaje de los pendientes que le siguen.
    case rearmMirrorOff
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

    /// Techo de la espera de `reverseUpload` contra el reloj de lo DEFINITIVO, y solo cuando CloudKit YA dijo que no
    /// entra (iCloud lleno, cuenta inutilizable): 15 min ACUMULADOS desde el último avance bajo esos motivos, sean el
    /// mismo o se turnen. Las horas sin cuenta de iCloud (`icloudOff`) o sin saber por qué (`unknown`) no cuentan.
    /// Decisión de Jürgen (2026-09-16) para el número; `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`
    /// para el reloj. Mientras tanto la nube de Yala está congelada y lo que la persona escribe vive solo en el teléfono.
    ///
    /// El mismo número decide también el TEXTO, contra el reloj de UNA causa: si un solo motivo llegó a él, la salida
    /// lleva el suyo; si no, `stalled` (`MigrationRunner.reverseUploadExitReason`).
    var reverseUploadDefinitiveBudgetSeconds: Double = 900
    /// Techo de la espera de `reverseUpload` contra el reloj de AVANCE, con CUALQUIER motivo: 72 h SIN avanzar. El
    /// reloj es el del ÚLTIMO avance, no el del inicio, así que un corpus grande que sube despacio nunca lo agota. Es el
    /// suelo del mecanismo: con un motivo definitivo también aplica.
    ///
    /// **Se llamaba `…UnknownBudgetSeconds` hasta el 2026-09-23**, y desde que aplica con cualquier motivo ese nombre
    /// invitaba a bajarlo creyendo que solo tocaba lo desconocido (el renombrado del gemelo previo al montaje).
    var reverseUploadProgressBudgetSeconds: Double = 259_200

    /// El predicado del techo CORTO de la espera de subida, en UN solo sitio: lo consultan la máquina —al reloj de
    /// «cualquier motivo definitivo», para salir— y el runner —al de la causa de esta observación, para elegir el
    /// texto—. Por eso el parámetro no nombra ningún reloj.
    func reverseUploadDefinitiveCeilingReached(stalledSeconds: Double, cause: MarkerExportStall) -> Bool {
        cause == .definitive && stalledSeconds >= reverseUploadDefinitiveBudgetSeconds
    }

    /// Techo de las CUATRO fases previas al montaje del espejo contra el reloj de lo DEFINITIVO, y solo cuando el
    /// motivo de la observación lo es —esperar no lo arregla—: 15 min de parada ACUMULADA bajo motivos definitivos,
    /// sean el mismo o se turnen, que no es lo mismo que 15 min de fase parada: las horas de red no cuentan. Ticket
    /// `reverse-before-mount-has-no-way-to-abandon-the-return` para el número, que es el mismo que el resto de techos
    /// de esta familia y no hay medición que justifique otro; `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-
    /// stops-it-last` para el reloj acumulado con pausa, y `alternating-definitive-causes-never-reach-the-short-ceiling`
    /// para que ese reloj no se reinicie al cambiar de motivo. Mientras tanto el teléfono NO sincroniza: ninguna de
    /// las cuatro fases es estable.
    ///
    /// El mismo número decide también el COPY, contra el reloj de UNA causa: si un solo motivo llegó a él, la salida
    /// lleva su texto; si no, el genérico (`MigrationRunner.reversePreMountExitReason`).
    ///
    /// **Se llamaba `…DefinitiveBudgetSeconds` hasta el 2026-09-22.** El nombre nuevo dice contra QUÉ RELOJ se
    /// mide, que es lo que cambió; el de al lado se renombró por lo contrario —dejó de ser «el de lo desconocido»
    /// y pasó a aplicar con cualquier causa—, y con los dos nombres viejos uno de los dos mentía.
    var reversePreMountCauseBudgetSeconds: Double = 900
    /// Techo de las mismas cuatro fases contra el reloj de la FASE, con CUALQUIER causa: 72 h. Aquí caen la red que
    /// no vuelve y la sesión que nadie renueva —incluida la cuenta a la que ya no se puede entrar—, y las dos tienen
    /// su aviso y su botón mucho antes de llegar a esto. Es además el suelo del mecanismo entero: con un motivo
    /// definitivo también aplica. Hasta `alternating-definitive-causes-never-reach-the-short-ceiling` era lo único que
    /// sacaba de la espera con dos motivos definitivos turnándose; desde ese ticket los saca el corto.
    ///
    /// **Se llamaba `…UnknownBudgetSeconds`**, y desde que aplica también a las causas definitivas ese nombre
    /// invitaba a bajarlo creyendo que solo tocaba lo desconocido.
    var reversePreMountPhaseBudgetSeconds: Double = 259_200

    /// Techo de `uploadingSnapshot` contra el reloj de lo DEFINITIVO, y solo cuando el motivo de la observación lo es
    /// —esperar no lo arregla: sesión caducada, cuenta suspendida o congelada, fallo local—: 15 min ACUMULADOS desde la
    /// última página confirmada bajo motivos definitivos, sean el mismo o se turnen. Las horas de red no cuentan.
    /// Decisión de Jürgen del 2026-09-22 (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`): el mismo número que el
    /// resto de techos cortos de la familia. Aquí rendirse no rompe nada —el teléfono sigue intacto en iCloud—, así que
    /// no hay nada que proteger esperando más. Que el reloj no se reinicie al cambiar de motivo es de
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`.
    ///
    /// El mismo número decide también el COPY, contra el reloj de UNA causa: si un solo motivo llegó a él, la salida
    /// lleva su texto; si no, `stalled` (`MigrationRunner.snapshotExitReason`).
    var snapshotCauseBudgetSeconds: Double = 900
    /// Techo de la misma fase contra el reloj de AVANCE, con CUALQUIER causa: 72 h sin confirmar una sola página. Aquí
    /// cae la red que no vuelve. Es también el suelo del mecanismo: con un motivo definitivo también aplica. Hasta
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` era lo único que sacaba de la espera
    /// con dos motivos definitivos turnándose; desde ese ticket los saca el corto.
    var snapshotProgressBudgetSeconds: Double = 259_200

    /// El predicado del techo CORTO de la subida, en un solo sitio por la misma razón que el de la vuelta: lo
    /// consultan la máquina (para salir) y el runner (para elegir el motivo que journalea). Desde
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` los dos lo aplican a relojes
    /// DISTINTOS, y por eso el parámetro no nombra ninguno: la máquina, al de «cualquier motivo definitivo» (¿sale?); el
    /// runner, al de la causa de esta observación (¿fue ESTE motivo solo el que agotó el plazo?).
    func snapshotCauseCeilingReached(stalledSeconds: Double, cause: MarkerExportStall) -> Bool {
        cause == .definitive && stalledSeconds >= snapshotCauseBudgetSeconds
    }

    /// Techo de los TRES pasos de la ida sin cifra que baje (22 %, 35 %, 80 %) contra el reloj de la CAUSA, y solo cuando
    /// esperar no la arregla: 15 min ACUMULADOS bajo ese motivo desde que empezó el paso. Decisión de Jürgen del
    /// 2026-09-22 (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`): el mismo número que la subida y la
    /// vuelta. Antes del cutover el teléfono sigue intacto en iCloud, así que rendirse no rompe nada.
    var forwardStepCauseBudgetSeconds: Double = 900
    /// Techo de los mismos tres pasos contra el reloj de AVANCE, con CUALQUIER causa: 72 h en el mismo paso. Aquí cae
    /// la red que no vuelve y el 401 con la sesión todavía guardada. Es también el suelo del mecanismo: con dos causas
    /// definitivas alternándose, el reloj corto se reinicia en cada cambio y lo único que garantiza la salida es éste.
    var forwardStepProgressBudgetSeconds: Double = 259_200

    /// El predicado del techo CORTO de los tres pasos, en un solo sitio: lo consultan la máquina y el runner.
    func forwardStepCauseCeilingReached(causeStalledSeconds: Double, cause: MarkerExportStall) -> Bool {
        cause == .definitive && causeStalledSeconds >= forwardStepCauseBudgetSeconds
    }

    /// Techo del EFECTO del adopt contra el reloj de «cualquier motivo definitivo»: 15 min ACUMULADOS con la base local que
    /// no se deja leer (ticket `adopt-effect-retries-forever-with-no-ceiling`, decisión de Jürgen del 2026-09-23). El mismo
    /// número que la ida y la vuelta. Antes del paso 5 el teléfono sigue en iCloud, así que rendirse no rompe nada.
    var adoptEffectDefinitiveBudgetSeconds: Double = 900
    /// Techo del mismo efecto contra el reloj de AVANCE, con CUALQUIER causa: 72 h desde el primer intento fallido. Aquí
    /// cae la red que no vuelve, la quiescencia del import que no llega y la sesión borrada en la enumeración.
    var adoptEffectProgressBudgetSeconds: Double = 259_200

    /// ¿Venció alguno de los dos techos del efecto del adopt? En un solo sitio: lo consultan la máquina —para salir— y el
    /// runner —para decidir si emite el evento—.
    func adoptEffectCeilingReached(stalledSeconds: Double, definitiveStalledSeconds: Double) -> Bool {
        stalledSeconds >= adoptEffectProgressBudgetSeconds || adoptEffectDefinitiveCeilingReached(definitiveStalledSeconds)
    }

    /// ¿Venció el CORTO? Aparte porque el runner lo usa para elegir el motivo: lo elige el techo que VENCIÓ.
    func adoptEffectDefinitiveCeilingReached(_ definitiveStalledSeconds: Double) -> Bool {
        definitiveStalledSeconds >= adoptEffectDefinitiveBudgetSeconds
    }

    /// **El predicado del techo CORTO, en UN solo sitio.** Lo consultan la máquina —para decidir si la vuelta sale—
    /// y el runner —para decidir QUÉ MOTIVO journalea—, y tenerlo dos veces escrito es precisamente la forma de que
    /// un día discrepen: el runner diría «la cuenta en la nube no lo permitió», con su correo de soporte, en una
    /// salida que en realidad produjo el techo de las 72 h.
    ///
    /// Desde `alternating-definitive-causes-never-reach-the-short-ceiling` los dos lo aplican a relojes DISTINTOS, y
    /// por eso el parámetro no nombra ninguno: la máquina, al de «cualquier motivo definitivo» (¿sale?); el runner, al
    /// de la causa de esta observación (¿fue ESTE motivo solo el que agotó el plazo?).
    func reversePreMountCauseCeilingReached(
        stalledSeconds: Double, cause: MarkerExportStall
    ) -> Bool {
        cause == .definitive && stalledSeconds >= reversePreMountCauseBudgetSeconds
    }

    static let `default` = MigrationPolicy()

    init(
        maxMismatchRetries: Int = 3,
        maxNetworkRetries: Int = 8,
        markerExportDefinitiveBudgetSeconds: Double = 900,
        markerExportUnknownBudgetSeconds: Double = 259_200,
        reverseUploadDefinitiveBudgetSeconds: Double = 900,
        reverseUploadProgressBudgetSeconds: Double = 259_200,
        reversePreMountCauseBudgetSeconds: Double = 900,
        reversePreMountPhaseBudgetSeconds: Double = 259_200,
        snapshotCauseBudgetSeconds: Double = 900,
        snapshotProgressBudgetSeconds: Double = 259_200,
        forwardStepCauseBudgetSeconds: Double = 900,
        forwardStepProgressBudgetSeconds: Double = 259_200
    ) {
        self.maxMismatchRetries = maxMismatchRetries
        self.maxNetworkRetries = maxNetworkRetries
        self.markerExportDefinitiveBudgetSeconds = markerExportDefinitiveBudgetSeconds
        self.markerExportUnknownBudgetSeconds = markerExportUnknownBudgetSeconds
        self.reverseUploadDefinitiveBudgetSeconds = reverseUploadDefinitiveBudgetSeconds
        self.reverseUploadProgressBudgetSeconds = reverseUploadProgressBudgetSeconds
        self.reversePreMountCauseBudgetSeconds = reversePreMountCauseBudgetSeconds
        self.reversePreMountPhaseBudgetSeconds = reversePreMountPhaseBudgetSeconds
        self.snapshotCauseBudgetSeconds = snapshotCauseBudgetSeconds
        self.snapshotProgressBudgetSeconds = snapshotProgressBudgetSeconds
        self.forwardStepCauseBudgetSeconds = forwardStepCauseBudgetSeconds
        self.forwardStepProgressBudgetSeconds = forwardStepProgressBudgetSeconds
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
        // claimingMigration → notStarted SIN efectos: «Migrar» sobre una cuenta que ya tiene lo personal o que otro
        // dispositivo está migrando. Las ramas `existing_stable` y `claiming_in_progress` (sin relevo) de `claim_account`
        // solo clasifican —no hay UPDATE—, así que no queda nada que deshacer ni en el servidor ni aquí.
        case (.claimingMigration, .claimRefusedExistingAccount):
            return .transition(next: .notStarted, effects: [])

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

        // uploadingSnapshot · TECHO (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`). Hasta este ticket la fase
        // tenía dos salidas y ninguna alcanzable ante un fallo persistente: `snapshotUploaded` y un `fatalError` que el
        // runner nunca emite aquí. La barra se quedaba al 55 % para siempre.
        //
        // Bajo presupuesto HOLDEA sin efectos. Al agotarlo sale a `failedRollback` con `[.rollback]`, la misma salida que
        // `verifying` cuando agota sus reintentos: antes del cutover el teléfono está intacto (el espejo nunca se apagó)
        // y `.rollback` no toca la red, así que no puede quedarse pendiente lanzando en cada arranque. Lo ya subido se
        // queda en el backend —no existe RPC de abort de la ida— y el siguiente intento lo re-sube y converge por LWW.
        //
        // Sale con el PRIMERO de los dos techos que venza, igual que la vuelta: el largo contra el reloj de AVANCE con
        // cualquier causa, el corto contra el de lo DEFINITIVO solo con `.definitive`. Ese reloj no se reinicia al
        // cambiar de motivo: medirlo por causa era el bug de
        // `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`, donde un fallo local al leer y el
        // 409 del push turnándose dejaban la salida en manos del LARGO.
        case let (.uploadingSnapshot, .snapshotUploadStalled(stalled, definitiveStalled, cause)):
            let hitProgressCeiling = stalled >= policy.snapshotProgressBudgetSeconds
            let hitCauseCeiling = policy.snapshotCauseCeilingReached(stalledSeconds: definitiveStalled, cause: cause)
            guard hitProgressCeiling || hitCauseCeiling else {
                return .transition(next: .uploadingSnapshot, effects: [])
            }
            return .transition(next: .failedRollback, effects: [.rollback])

        // uploadingSnapshot · SALIDA de la persona («Cancelar la activación»). A `notStarted` SIN efectos, molde de
        // `consentDeclined` y `claimRefusedExistingAccount`: no queda nada local que deshacer, y lo que decidió la
        // persona no es un fallo que explicar. El backend queda como en la salida del techo.
        case (.uploadingSnapshot, .snapshotUploadCancelled):
            return .transition(next: .notStarted, effects: [])

        // Los TRES pasos de la ida sin cifra que baje · TECHO (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`).
        // `claimingMigration` (22 %), `assigningIdentity` (35 %) y `cutover(.pending)` (80 %) cortaban sin evento ante un
        // fallo persistente, y ninguno tenía otra arista alcanzable: el `fatalError` de los dos primeros no lo emite nadie,
        // y `.pending` solo sale por la precondición del canal iCloud.
        //
        // Bajo presupuesto HOLDEA en su propia fase y sin efectos. Al agotarlo sale a `failedRollback` con `[.rollback]`, la
        // misma salida de la subida y de la precondición del canal iCloud: en los tres el teléfono sigue en `.icloud`, sin
        // marcador y con el espejo vivo, y `.rollback` no toca la red. En `.pending` una respuesta perdida puede haber dejado
        // `migrated_at` estampado en el servidor; el cliente no lo lee y el reintento del mismo líder converge (el claim
        // contesta `created` y el `cutover` es idempotente), así que tampoco ahí hay nada que deshacer. Desde
        // `.serverConfirmed` el evento es `.invalid` a propósito: ahí manda «el cutover jamás hace rollback».
        //
        // Sale con el PRIMERO de los dos techos que venza, igual que la subida y la vuelta.
        case let (.claimingMigration, .forwardStepStalled(stalled, causeStalled, cause)),
             let (.assigningIdentity, .forwardStepStalled(stalled, causeStalled, cause)),
             let (.cutover(.pending), .forwardStepStalled(stalled, causeStalled, cause)):
            let hitProgressCeiling = stalled >= policy.forwardStepProgressBudgetSeconds
            let hitCauseCeiling = policy.forwardStepCauseCeilingReached(
                causeStalledSeconds: causeStalled, cause: cause)
            guard hitProgressCeiling || hitCauseCeiling else {
                return .transition(next: phase, effects: [])
            }
            return .transition(next: .failedRollback, effects: [.rollback])

        // Los mismos tres · SALIDA de la persona («Cancelar la activación»). A `notStarted` SIN efectos, como la cancelación
        // de la subida: no queda nada local que deshacer, y lo que decidió la persona no es un fallo que explicar.
        case (.claimingMigration, .forwardStepCancelled),
             (.assigningIdentity, .forwardStepCancelled),
             (.cutover(.pending), .forwardStepCancelled):
            return .transition(next: .notStarted, effects: [])

        // notStarted con `.adoptBackendAccount` pendiente · el EFECTO del adopt (ticket
        // `adopt-effect-retries-forever-with-no-ceiling`). La salida del techo es la del claim del adopt: `failedRollback`
        // con `[.rollback]`, que antes del paso 5 no toca nada (el teléfono sigue en `.icloud`; el runner no emite el evento
        // si el modo ya es `.cloud`). Bajo presupuesto `.invalid`: la espera la hace el runner sin evento, con el efecto
        // pendiente — una transición que lo repusiera lo ejecutaría otra vez en el mismo `handle`.
        case let (.notStarted, .adoptEffectStalled(stalled, definitiveStalled)):
            guard policy.adoptEffectCeilingReached(
                stalledSeconds: stalled, definitiveStalledSeconds: definitiveStalled) else {
                return .invalid(from: phase, event: event)
            }
            return .transition(next: .failedRollback, effects: [.rollback])
        // La persona cancela: a `notStarted` SIN efectos, que retira el pendiente. Lo que decidió no es un fallo que explicar.
        case (.notStarted, .adoptEffectCancelled):
            return .transition(next: .notStarted, effects: [])

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
        // `icloudActive` re-cutover (§h.4): re-enters the forward migration via consent; this edge only avoids a
        // terminal without exit. The claim answers `existing_stable` for an account that returned to iCloud, and
        // «Migrar a la nube» no longer adopts it: `ForwardClaimIntent.migrateOnly` returns to `notStarted` with
        // `claimRefusedExistingAccount` (Jürgen, 2026-09-16: the account stays frozen until the re-cutover exists).
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

        // reverseClaimLeader → ORIGIN: el servidor rechazó la reserva. SIN efectos, igual que `other_leader`: todos los
        // rechazos de `reverse_claim` salen del RPC antes de cualquier UPDATE, así que ESTE claim no reservó nada ni
        // congeló nada. Un `.reverseRollback` aquí sería un efecto de red que, sin red, se quedaría pendiente en una
        // fase estable y dejaría el motor parado: el callejón que esta salida existe para quitar. Lo que sí hace el
        // runner, fuera de la máquina, es reponer los pendientes del origen que `reverseActivated` había reemplazado
        // (`ReverseOriginPendingEffects`).
        //
        // La excepción conocida es del backend: en una cuenta ya revertida, un claim fresco con éxito cuya respuesta se
        // pierde resetea `reverted_at`, y el reintento recibe `not_complete` con la reserva de ESTE dispositivo puesta
        // y sin congelar (el 409 solo mira `reverse_frozen_at`). Ticket `reverse-exit-on-a-reverted-account-rejects-the-retry`.
        case let (.reverseClaimLeader, .reverseClaimRejected(origin)):
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // reverseDrainAll → reverseVerify
        case (.reverseDrainAll, .reverseDrainCompleted):
            return .transition(next: .reverseVerify, effects: [])

        // reverseVerify — S9 reused; the mismatch fix is a PULL (re-drain), not a re-upload.
        case let (.reverseVerify, .reverseVerifyOutcome(outcome)):
            return reverseVerifyTransition(outcome: outcome, policy: policy, from: phase, event: event)

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

        // reverseUpload · TECHO. Bajo presupuesto HOLDEA sin efectos (molde de `markerExportStalled`): el runner
        // corta retomable y el próximo resume vuelve a observar. Al agotarlo, la reversa VUELVE a su origen en
        // modo nube. El orden de los efectos es OBLIGATORIO:
        //   1. `.rearmMirrorOff` PRIMERO: re-arma el apagado del mirror con `.cloud`. Es `UserDefaults` puro y no
        //      puede lanzar, así que la mitad local queda hecha antes de tocar la red: la UI pide relanzar y el
        //      motor no arranca con el mirror montado aunque lo segundo falle.
        //   2. `.reverseRollback`: `reverse_abort` descongela el backend. Sin red lanza y queda journaleado.
        // Al revés, un `reverse_abort` fallido dejaría `.cloud` + mirror vivo en una fase ESTABLE: el estado
        // prohibido de `isCloudWithMirrorOn`, con la pantalla diciendo «en la nube».
        // No se borra el marcador ni el faro: la cuenta sigue en la nube, que es donde vuelve.
        //
        // **Sale con el PRIMERO de los dos techos que venza**, y son de relojes distintos (ticket
        // `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`): el LARGO contra el de AVANCE, con cualquier
        // motivo, y el CORTO contra el de «cualquier motivo definitivo». El largo no está en el `else` del motivo: es el
        // que garantiza que la espera termine pase lo que pase.
        case let (.reverseUpload, .reverseUploadStalled(stalled, definitiveStalled, cause, origin)):
            let hitProgressCeiling = stalled >= policy.reverseUploadProgressBudgetSeconds
            let hitDefinitiveCeiling = policy.reverseUploadDefinitiveCeilingReached(
                stalledSeconds: definitiveStalled, cause: cause)
            guard hitProgressCeiling || hitDefinitiveCeiling else {
                return .transition(next: .reverseUpload, effects: [])
            }
            return .transition(next: reverseOriginPhase(origin), effects: [.rearmMirrorOff, .reverseRollback])

        // reverseUpload · SALIDA de la persona: la misma vuelta que el techo, sin esperar a que venza.
        case let (.reverseUpload, .reverseUploadCancelled(origin)):
            return .transition(next: reverseOriginPhase(origin), effects: [.rearmMirrorOff, .reverseRollback])

        // Las CUATRO fases PREVIAS al montaje · TECHO (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`).
        // Bajo presupuesto HOLDEA en su propia fase, sin efectos: el runner corta retomable y el próximo resume vuelve
        // a observar. Al agotarlo, la vuelta regresa a su origen en modo nube **SIN EFECTOS**, y las dos mitades de esa
        // frase son decisiones:
        //   · Sin `.rearmMirrorOff` porque pre-montaje el local está INTACTO: el espejo no se ha re-encendido todavía
        //     (lo enciende `.mountMirrorAndRelaunch`, en la arista `reverseFreezeBackend → reverseMountMirror`), así que
        //     no hay nada que re-armar. Es el mismo motivo por el que `reverseClaimRejected` sale sin efectos.
        //   · Sin `.reverseRollback` porque ese efecto LANZA con el token ausente, con la sesión caducada y con
        //     cualquier `.transient` —el 403 incluido, que `CloudAccountClient` lee como red—, y un efecto que lanza no
        //     se consume: `MigrationBootDecision.decide` devuelve `.resume` mientras haya pendientes, así que volvería a
        //     lanzar en cada arranque y en cada vuelta a la app. Ese es el bug-class que esta salida existe para cerrar
        //     (criterio 3 del ticket). El `reverse_abort` lo intenta el RUNNER, una vez y best-effort, DESPUÉS de
        //     journalear la salida; que no salga cuesta poco, porque el re-claim del mismo dispositivo es idempotente y
        //     no mira la edad del lease.
        //
        // **Sale con el PRIMERO de los dos techos que venza**, y son de relojes distintos (ticket
        // `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last`):
        //   · el LARGO, contra el reloj de la FASE, aplica con cualquier causa. Es el que impide que la espera sea
        //     eterna, y por eso no está dentro del `else` de la causa: la red que no vuelve y la sesión que nadie
        //     renueva solo tienen éste.
        //   · el CORTO, contra el reloj de lo DEFINITIVO, solo con `.definitive`. Mide lo que la fase lleva parada
        //     bajo motivos que esperar no arregla, no lo que lleva parada en total: esa confusión es el bug de
        //     `…charges-a-stall-to-whoever-stops-it-last`. Y no se reinicia al cambiar de motivo: medirlo por causa
        //     era el de `alternating-definitive-causes-never-reach-the-short-ceiling`, donde dos motivos turnándose
        //     dejaban la salida en manos del LARGO.
        case let (.reverseClaimLeader, .reversePreMountStalled(stalled, definitiveStalled, cause, origin)),
             let (.reverseDrainAll, .reversePreMountStalled(stalled, definitiveStalled, cause, origin)),
             let (.reverseVerify, .reversePreMountStalled(stalled, definitiveStalled, cause, origin)),
             let (.reverseFreezeBackend, .reversePreMountStalled(stalled, definitiveStalled, cause, origin)):
            let hitPhaseCeiling = stalled >= policy.reversePreMountPhaseBudgetSeconds
            let hitCauseCeiling = policy.reversePreMountCauseCeilingReached(
                stalledSeconds: definitiveStalled, cause: cause)
            guard hitPhaseCeiling || hitCauseCeiling else {
                return .transition(next: phase, effects: [])
            }
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // Las mismas cuatro · SALIDA de la persona: la misma vuelta que el techo, sin esperar a que venza.
        case let (.reverseClaimLeader, .reversePreMountCancelled(origin)),
             let (.reverseDrainAll, .reversePreMountCancelled(origin)),
             let (.reverseVerify, .reversePreMountCancelled(origin)),
             let (.reverseFreezeBackend, .reversePreMountCancelled(origin)):
            return .transition(next: reverseOriginPhase(origin), effects: [])

        // fatalError PRE-mount (nothing local changed; the mirror was never re-lit) → reverseFailedRollback.
        case (.reverseClaimLeader, .fatalError),
             (.reverseDrainAll, .fatalError),
             (.reverseVerify, .fatalError),
             (.reverseFreezeBackend, .fatalError):
            return .transition(next: .reverseFailedRollback, effects: [.reverseRollback])

        // fatalError POST-mount → HOLD the state (idempotent resume covers recovery), NEVER rollback: the
        // mirror is already alive and the resume retakes. Un fallo NO es la salida de `reverseUpload`: esa la
        // deciden el techo por tiempo sin avanzar y la persona, arriba.
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

    /// The reverse verify (§h) — REUSES `VerifyOutcome`, but only for the MISMATCH counter (independent of the
    /// forward verify's; the runner resets them on `reverseClaimLeader`). Authority in the reverse is backend→local,
    /// so a mismatch is fixed by a PULL (`reverseDrainAll`), NEVER a re-upload.
    ///
    /// **`networkTimeout` ya no es un par legal aquí** (2026-09-21, ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`, decisión de Jürgen). La red de la
    /// VUELTA pasa por el techo de la etapa previa al montaje —igual que la del drenaje y la del congelado—, así que
    /// `driveReverseVerify` emite `reversePreMountStalled` y no este evento. Dejar la rama viva la habría convertido
    /// en una rama muerta que afirma lo contrario del ticket: que la vuelta degrada a `reverseFailedRollback` con
    /// `.reverseRollback` pendiente por quedarse sin cobertura. `.invalid` lo dice, y un test lo puede fijar.
    ///
    /// La IDA no cambia: `verifyTransition` sigue tratando el suyo igual, y esa sí es la rama que `driveVerify`
    /// alimenta con la red, la sesión caducada y el `blocked`.
    private static func reverseVerifyTransition(
        outcome: VerifyOutcome, policy: MigrationPolicy, from: MigrationPhase, event: MigrationEvent
    ) -> TransitionOutcome {
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
        case .networkTimeout:
            return .invalid(from: from, event: event)
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
