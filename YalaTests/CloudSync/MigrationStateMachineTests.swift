//
//  MigrationStateMachineTests.swift
//  YalaTests
//
//  Golden tests for the pure-logic migration state machine (Modo Nube §g / diagram §4.1, I10).
//  No SwiftData, no network, no Date — the machine is a pure function of (phase, event, policy).
//  The 9 golden groups mirror the plan: happy path (strict cutover order + early beacon), kill-resume
//  per state, idempotent same-device reclaim, the S9 verify split, the write-capture window, marker
//  reconciliation, terminal exits (declined/fatalError), the follower path, and Codable round-trip.
//

import Foundation
import Testing

@testable import Yala

@Suite("Migration State Machine")
struct MigrationStateMachineTests {

    typealias Phase = MigrationPhase
    typealias Sub = CutoverSubstate
    typealias RSub = ReverseReconcileSubstate
    typealias Event = MigrationEvent
    typealias Effect = MigrationEffect

    /// Every journaled phase (manual `CaseIterable` — `.cutover`/`.reverseReconcile`/`.reverseConfirm`
    /// carry associated values). 16 forward + 14 reverse (I11-1) = 30.
    static let allPhases: [Phase] = [
        .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader,
        .claimingMigration, .assigningIdentity, .uploadingSnapshot, .verifying,
        .cutover(.pending), .cutover(.serverConfirmed), .cutover(.localModeSet),
        .cutover(.markerWritten), .cutover(.mirrorOff),
        .done, .failedRollback,
        // Reverse (§h, I11-1)
        .reverseConfirm(.done), .reverseConfirm(.notStarted),
        .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend, .reverseMountMirror,
        .reverseReconcile(.awaitingQuiescence), .reverseReconcile(.deletingZombies),
        .reverseReconcile(.rebindingUUIDs), .reverseReconcile(.dedupHealed),
        .reverseUpload, .icloudActive, .reverseFailedRollback,
    ]

    /// The reverse phases that resume in themselves (durable). `reverseConfirm` is NON-durable (→ origin).
    static let durableReversePhases: [Phase] = [
        .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend, .reverseMountMirror,
        .reverseReconcile(.awaitingQuiescence), .reverseReconcile(.deletingZombies),
        .reverseReconcile(.rebindingUUIDs), .reverseReconcile(.dedupHealed),
        .reverseUpload, .icloudActive, .reverseFailedRollback,
    ]

    /// Helper: asserts a transition is valid and returns (next, effects).
    private func step(
        _ phase: Phase, _ event: Event, policy: MigrationPolicy = .default
    ) -> (next: Phase, effects: [Effect]) {
        switch MigrationStateMachine.transition(from: phase, event: event, policy: policy) {
        case let .transition(next, effects):
            return (next, effects)
        case let .invalid(from, ev):
            Issue.record("expected a valid transition, got .invalid(from: \(from), event: \(ev))")
            return (phase, [])
        }
    }

    // MARK: - 1. Happy path (strict cutover order, early beacon)

    @Test func happyPath_fullSequenceOfPhasesAndEffects() {
        var phase = Phase.notStarted
        var log: [(Phase, [Effect])] = []

        func fire(_ event: Event) {
            let r = step(phase, event)
            phase = r.next
            log.append((r.next, r.effects))
        }

        fire(.userActivated(dryRun: false))          // → consent
        fire(.consentAccepted)                        // → authenticating
        fire(.signInSucceeded)                        // → claimingMigration
        fire(.claimResult(.created, sameDeviceReclaim: false)) // → assigningIdentity [.writeBeacon]
        fire(.identityAssigned)                       // → uploadingSnapshot
        fire(.snapshotUploaded)                       // → verifying
        fire(.verifyOutcome(.match))                  // → cutover(.pending)
        fire(.serverConfirmedAck)                     // → cutover(.serverConfirmed)
        fire(.localModePersisted)                     // → cutover(.localModeSet) [.startParallelHistoryCapture]
        fire(.markerWritten)                          // → cutover(.markerWritten) [.writeCloudKitMarker]
        fire(.mirrorDisabled)                         // → cutover(.mirrorOff) [.disableMirrorAndRelaunch]
        fire(.mirrorRelaunchCompleted)                // → done [.runLeaderReconcileFromFrozenCloudKit]

        let phases = log.map(\.0)
        #expect(phases == [
            .consent, .authenticating, .claimingMigration, .assigningIdentity,
            .uploadingSnapshot, .verifying, .cutover(.pending), .cutover(.serverConfirmed),
            .cutover(.localModeSet), .cutover(.markerWritten), .cutover(.mirrorOff), .done,
        ])

        // Effects, flattened in emission order — the strict cutover order + EARLY beacon.
        let effects = log.flatMap(\.1)
        #expect(effects == [
            .writeBeacon,                        // EARLY, at the claim — NOT at markerWritten.
            .startParallelHistoryCapture,        // entering localModeSet
            .writeCloudKitMarker,                // entering markerWritten (LAST observable, after localModeSet)
            .disableMirrorAndRelaunch,           // entering mirrorOff
            .runLeaderReconcileFromFrozenCloudKit, // entering done
        ])
    }

    @Test func happyPath_beaconIsEmittedAtClaim_notAtMarker() {
        // The beacon rides the claim edge (§g.4-faro v8); the marker edge carries ONLY writeCloudKitMarker.
        let atClaim = step(.claimingMigration, .claimResult(.created, sameDeviceReclaim: false))
        #expect(atClaim.effects == [.writeBeacon])

        let atMarker = step(.cutover(.localModeSet), .markerWritten)
        #expect(atMarker.effects == [.writeCloudKitMarker])
        #expect(!atMarker.effects.contains(.writeBeacon))
    }

    @Test func cutoverOrder_serverConfirmedBeforeLocalModeBeforeMarkerBeforeMirrorOff() {
        // Each edge advances by EXACTLY one sub-state; none skips.
        #expect(step(.cutover(.pending), .serverConfirmedAck).next == .cutover(.serverConfirmed))
        #expect(step(.cutover(.serverConfirmed), .localModePersisted).next == .cutover(.localModeSet))
        #expect(step(.cutover(.localModeSet), .markerWritten).next == .cutover(.markerWritten))
        #expect(step(.cutover(.markerWritten), .mirrorDisabled).next == .cutover(.mirrorOff))
        #expect(step(.cutover(.mirrorOff), .mirrorRelaunchCompleted).next == .done)
    }

    @Test func cutover_cannotSkipASubstate() {
        // e.g. a marker event while still in pending is illegal (would skip serverConfirmed/localModeSet).
        #expect(
            MigrationStateMachine.transition(from: .cutover(.pending), event: .markerWritten)
                == .invalid(from: .cutover(.pending), event: .markerWritten)
        )
        #expect(
            MigrationStateMachine.transition(from: .cutover(.serverConfirmed), event: .mirrorDisabled)
                == .invalid(from: .cutover(.serverConfirmed), event: .mirrorDisabled)
        )
    }

    // MARK: - 2. Kill in every state → resume retakes cleanly

    @Test func resume_durableStatesRetakeInThemselves_uiStatesReenterFromTop() {
        for phase in Self.allPhases {
            let resumed = MigrationStateMachine.resume(fromJournaled: phase)
            switch phase {
            case .dryRun, .consent, .authenticating:
                #expect(resumed == .notStarted, "\(phase) is not durable progress → notStarted")
            case .reverseConfirm(.done):
                #expect(resumed == .done, "reverseConfirm(.done) is NON-durable → origin done")
            case .reverseConfirm(.notStarted):
                #expect(resumed == .notStarted, "reverseConfirm(.notStarted) is NON-durable → origin notStarted")
            default:
                #expect(resumed == phase, "\(phase) must resume in itself")
            }
        }
    }

    @Test func resume_cutoverRetakesExactSubstate_neverRegressesOrSkips() {
        for sub in Sub.allCases {
            #expect(MigrationStateMachine.resume(fromJournaled: .cutover(sub)) == .cutover(sub))
        }
    }

    // MARK: - 3. Idempotent same-device reclaim (SERIO 1 pt4)

    @Test func reclaim_sameDevice_isTreatedAsCreated_advancesWithBeacon() {
        let r = step(.claimingMigration, .claimResult(.claimingInProgress, sameDeviceReclaim: true))
        #expect(r.next == .assigningIdentity)
        #expect(r.effects == [.writeBeacon])
    }

    @Test func reclaim_otherDevice_waitsForLeader_noEffects() {
        let r = step(.claimingMigration, .claimResult(.claimingInProgress, sameDeviceReclaim: false))
        #expect(r.next == .waitingForLeader)
        #expect(r.effects.isEmpty)
    }

    @Test func claim_existingStable_bowsOutToAdoption_neverReMigrates() {
        let r = step(.claimingMigration, .claimResult(.existingStable, sameDeviceReclaim: false))
        #expect(r.next == .notStarted)
        #expect(r.effects == [.adoptBackendAccount])
    }

    // MARK: - 4. S9 verify split (network timeout ≠ mismatch, independent counters)

    @Test func verify_networkTimeout_belowCap_alwaysRetriesVerifying() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        for retries in 0..<policy.maxNetworkRetries { // 0...7 → still retry
            let r = step(.verifying, .verifyOutcome(.networkTimeout(retriesSoFar: retries)), policy: policy)
            #expect(r.next == .verifying, "network timeout \(retries) must retry verifying")
            #expect(r.effects.isEmpty)
            // NEVER degrades to uploadingSnapshot or failedRollback before the cap.
            #expect(r.next != .uploadingSnapshot)
            #expect(r.next != .failedRollback)
        }
    }

    @Test func verify_networkTimeout_atCap_failsRollback() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        let r = step(.verifying, .verifyOutcome(.networkTimeout(retriesSoFar: 8)), policy: policy)
        #expect(r.next == .failedRollback)
        #expect(r.effects == [.rollback])
    }

    @Test func verify_mismatch_belowCap_reUploads() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        for retries in 0..<policy.maxMismatchRetries { // 0...2 → re-upload
            let r = step(.verifying, .verifyOutcome(.mismatch(retriesSoFar: retries)), policy: policy)
            #expect(r.next == .uploadingSnapshot, "mismatch \(retries) must re-upload")
            #expect(r.effects.isEmpty)
        }
    }

    @Test func verify_mismatch_atCap_failsRollback() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        let r = step(.verifying, .verifyOutcome(.mismatch(retriesSoFar: 3)), policy: policy)
        #expect(r.next == .failedRollback)
        #expect(r.effects == [.rollback])
    }

    @Test func verify_countersAreIndependent_networkDoesNotConsumeMismatchBudget() {
        // maxMismatch=1, maxNetwork=8: 7 network timeouts (well past the mismatch cap) STILL retry,
        // because network retries never touch the mismatch counter.
        let policy = MigrationPolicy(maxMismatchRetries: 1, maxNetworkRetries: 8)
        let net = step(.verifying, .verifyOutcome(.networkTimeout(retriesSoFar: 7)), policy: policy)
        #expect(net.next == .verifying)
        // Conversely a single mismatch at the (low) mismatch cap degrades regardless of network budget.
        let mism = step(.verifying, .verifyOutcome(.mismatch(retriesSoFar: 1)), policy: policy)
        #expect(mism.next == .failedRollback)
    }

    @Test func verify_newDelta_reRunsVerify_doesNotConsumeRetries() {
        let r = step(.verifying, .verifyOutcome(.newDeltaDetected))
        #expect(r.next == .verifying)
        #expect(r.effects.isEmpty)
    }

    @Test func verify_match_entersCutoverPending_noEffects() {
        let r = step(.verifying, .verifyOutcome(.match))
        #expect(r.next == .cutover(.pending))
        #expect(r.effects.isEmpty)
    }

    // MARK: - 5. Write-capture window (localModeSet → mirrorOff)

    @Test func requiresParallelHistoryCapture_trueOnlyInsideTheWindow() {
        for phase in Self.allPhases {
            let inWindow: Bool
            switch phase {
            case .cutover(.localModeSet), .cutover(.markerWritten), .cutover(.mirrorOff):
                inWindow = true
            default:
                inWindow = false
            }
            #expect(
                MigrationStateMachine.requiresParallelHistoryCapture(phase: phase) == inWindow,
                "\(phase) capture window expectation"
            )
        }
    }

    @Test func requiresParallelHistoryCapture_falseBeforeLocalModeSetAndAtDone() {
        #expect(!MigrationStateMachine.requiresParallelHistoryCapture(phase: .cutover(.pending)))
        #expect(!MigrationStateMachine.requiresParallelHistoryCapture(phase: .cutover(.serverConfirmed)))
        #expect(!MigrationStateMachine.requiresParallelHistoryCapture(phase: .done))
    }

    @Test func startParallelHistoryCapture_emittedExactlyOnEnteringLocalModeSet() {
        #expect(step(.cutover(.serverConfirmed), .localModePersisted).effects == [.startParallelHistoryCapture])
        // Not emitted on any other cutover edge.
        #expect(!step(.cutover(.pending), .serverConfirmedAck).effects.contains(.startParallelHistoryCapture))
        #expect(!step(.cutover(.localModeSet), .markerWritten).effects.contains(.startParallelHistoryCapture))
    }

    @Test func leaderReconcile_emittedOnEnteringDone() {
        #expect(step(.cutover(.mirrorOff), .mirrorRelaunchCompleted).effects == [.runLeaderReconcileFromFrozenCloudKit])
    }

    // MARK: - 6. Marker reconciliation (self-authored) — 3 branches

    @Test func marker_notFound_isNone() {
        for phase in Self.allPhases {
            #expect(MigrationStateMachine.markerReconciliation(markerFound: false, journaledPhase: phase) == .none)
        }
    }

    @Test func marker_found_withOwnCutoverTrace_resumesOwnCutover() {
        // Any cutover sub-state (incl. < markerWritten = aborted, and >= markerWritten = resuming).
        for sub in Sub.allCases {
            #expect(
                MigrationStateMachine.markerReconciliation(markerFound: true, journaledPhase: .cutover(sub))
                    == .resumeOwnCutover
            )
        }
    }

    @Test func marker_found_ownDone_isNone() {
        #expect(MigrationStateMachine.markerReconciliation(markerFound: true, journaledPhase: .done) == .none)
    }

    @Test func marker_found_noOwnCutoverTrace_isSecondaryDeviceCloudLogin() {
        // Forward pre-cutover phases (+ failedRollback) with a marker but no own cutover trace → secondary.
        // The reverse phases + terminals are EXCLUDED here — they are `.none` (see the reverse test below).
        let noTracePhases = Self.allPhases.filter { phase in
            if case .cutover = phase { return false }
            if case .done = phase { return false }
            if isReversePhase(phase) { return false }
            return true
        }
        for phase in noTracePhases {
            #expect(
                MigrationStateMachine.markerReconciliation(markerFound: true, journaledPhase: phase)
                    == .secondaryDeviceCloudLogin,
                "\(phase) with a marker but no own cutover → secondary"
            )
        }
    }

    /// Whether a phase is one of the reverse (§h) phases + reverse terminals (`icloudActive`,
    /// `reverseFailedRollback`).
    private func isReversePhase(_ phase: Phase) -> Bool {
        switch phase {
        case .reverseConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify,
             .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload,
             .icloudActive, .reverseFailedRollback:
            return true
        default:
            return false
        }
    }

    // MARK: - 7. Terminal exits (declined / signInFailed / fatalError)

    @Test func signInFailed_returnsToNotStarted_noEffects() {
        let r = step(.authenticating, .signInFailed)
        #expect(r.next == .notStarted)
        #expect(r.effects.isEmpty)
    }

    @Test func consentDeclined_returnsToNotStarted_noEffects() {
        let r = step(.consent, .consentDeclined)
        #expect(r.next == .notStarted)
        #expect(r.effects.isEmpty)
    }

    @Test func fatalError_preCutover_failsRollbackWithEffect() {
        let preCutover: [Phase] = [
            .consent, .authenticating, .waitingForLeader, .claimingMigration,
            .assigningIdentity, .uploadingSnapshot, .verifying,
        ]
        for phase in preCutover {
            let r = step(phase, .fatalError)
            #expect(r.next == .failedRollback, "\(phase) + fatalError → failedRollback")
            #expect(r.effects == [.rollback])
        }
    }

    @Test func fatalError_insideCutover_holdsState_neverRollback() {
        // §g.4: a failure inside cutover retakes idempotently by sub-state; the marker means it's real.
        for sub in Sub.allCases {
            let r = step(.cutover(sub), .fatalError)
            #expect(r.next == .cutover(sub), "cutover(\(sub)) + fatalError holds the sub-state")
            #expect(r.effects.isEmpty)
            #expect(r.next != .failedRollback)
        }
    }

    @Test func fatalError_notStartedOrDryRun_isInvalid_nothingToRollBack() {
        #expect(
            MigrationStateMachine.transition(from: .notStarted, event: .fatalError)
                == .invalid(from: .notStarted, event: .fatalError)
        )
        #expect(
            MigrationStateMachine.transition(from: .dryRun, event: .fatalError)
                == .invalid(from: .dryRun, event: .fatalError)
        )
    }

    // MARK: - 8. Follower path

    @Test func follower_reachedViaOtherDeviceClaim() {
        #expect(step(.claimingMigration, .claimResult(.claimingInProgress, sameDeviceReclaim: false)).next
            == .waitingForLeader)
    }

    @Test func follower_leaderCompleted_adoptsBackendAccount() {
        let r = step(.waitingForLeader, .leaderCompleted)
        #expect(r.next == .notStarted)
        #expect(r.effects == [.adoptBackendAccount])
    }

    @Test func follower_leaderVanished_reClaims() {
        let r = step(.waitingForLeader, .leaderVanished)
        #expect(r.next == .claimingMigration)
        #expect(r.effects.isEmpty)
    }

    @Test func follower_resumesTheWaitAfterKill() {
        #expect(MigrationStateMachine.resume(fromJournaled: .waitingForLeader) == .waitingForLeader)
    }

    // MARK: - 9. Codable round-trip (journal)

    @Test func codable_roundTrips_everyPhaseIncludingCutoverSubstates() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for phase in Self.allPhases {
            let data = try encoder.encode(phase)
            let back = try decoder.decode(Phase.self, from: data)
            #expect(back == phase, "round-trip failed for \(phase)")
        }
    }

    @Test func codable_cutoverSubstate_preservesExactSubstate() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for sub in Sub.allCases {
            let phase = Phase.cutover(sub)
            let back = try decoder.decode(Phase.self, from: encoder.encode(phase))
            guard case let .cutover(decodedSub) = back else {
                Issue.record("decoded phase was not a cutover: \(back)")
                continue
            }
            #expect(decodedSub == sub)
        }
    }

    // MARK: - Invalid transitions carry the (from, event) pair

    @Test func invalidTransition_carriesTheOffendingPair() {
        // An out-of-order event: snapshotUploaded while still authenticating.
        let outcome = MigrationStateMachine.transition(from: .authenticating, event: .snapshotUploaded)
        #expect(outcome == .invalid(from: .authenticating, event: .snapshotUploaded))
    }

    @Test func terminalStates_rejectFurtherEvents() {
        #expect(
            MigrationStateMachine.transition(from: .done, event: .signInSucceeded)
                == .invalid(from: .done, event: .signInSucceeded)
        )
        #expect(
            MigrationStateMachine.transition(from: .failedRollback, event: .userActivated(dryRun: false))
                == .invalid(from: .failedRollback, event: .userActivated(dryRun: false))
        )
    }

    // MARK: - Guard tests del review adversarial (M3/M4)

    /// M3: un `claimResult` crudo re-polleado en `waitingForLeader` NO transiciona — el wiring DEBE
    /// traducir el re-poll a `leaderCompleted`/`leaderVanished`. Este test fija ese contrato.
    @Test func waitingForLeader_rawClaimResult_isInvalid_wiringMustTranslate() {
        let event = MigrationEvent.claimResult(.existingStable, sameDeviceReclaim: false)
        #expect(
            MigrationStateMachine.transition(from: .waitingForLeader, event: event)
                == .invalid(from: .waitingForLeader, event: event)
        )
    }

    /// M4: dry-run es UI pura (§g.5) — simula, re-simula, o procede a consent; nunca progreso durable.
    @Test func dryRun_transitions_simulateAndProceed() {
        #expect(
            MigrationStateMachine.transition(from: .notStarted, event: .userActivated(dryRun: true))
                == .transition(next: .dryRun, effects: [])
        )
        #expect(
            MigrationStateMachine.transition(from: .dryRun, event: .userActivated(dryRun: true))
                == .transition(next: .dryRun, effects: [])
        )
        #expect(
            MigrationStateMachine.transition(from: .dryRun, event: .userActivated(dryRun: false))
                == .transition(next: .consent, effects: [])
        )
    }

    /// M4: `created` con `sameDeviceReclaim: true` (reclaim idempotente colapsado a created por el
    /// backend) avanza igual que `false` — el flag no altera el camino del líder fresco.
    @Test func claimCreated_sameDeviceReclaimFlag_isIrrelevant() {
        for reclaim in [true, false] {
            #expect(
                MigrationStateMachine.transition(
                    from: .claimingMigration,
                    event: .claimResult(.created, sameDeviceReclaim: reclaim)
                ) == .transition(next: .assigningIdentity, effects: [.writeBeacon])
            )
        }
    }

    // MARK: - R1. Reverse happy path (§h) — from `done` and from `notStarted`

    /// Full reverse from `done`: the exact phase + effect sequence. Mount effect on entering
    /// `reverseMountMirror`; the closing quartet [marker, beacon, mode, server] IN ORDER on `icloudActive`.
    @Test func reverse_happyPath_fromDone_fullSequenceAndEffects() {
        assertReverseHappyPath(origin: .done, expectedConfirm: .reverseConfirm(.done))
    }

    /// Full reverse from `notStarted` (an ADOPTER device — returning-user §k.4). Same chain, different origin.
    @Test func reverse_happyPath_fromNotStarted_fullSequenceAndEffects() {
        assertReverseHappyPath(origin: .notStarted, expectedConfirm: .reverseConfirm(.notStarted))
    }

    private func assertReverseHappyPath(origin: MigrationPhase, expectedConfirm: Phase) {
        var phase = origin
        var log: [(Phase, [Effect])] = []
        func fire(_ event: Event) {
            let r = step(phase, event)
            phase = r.next
            log.append((r.next, r.effects))
        }

        fire(.reverseActivated)              // → reverseConfirm(origin)
        #expect(log.first?.0 == expectedConfirm)
        fire(.reverseConfirmed)              // → reverseClaimLeader
        fire(.reverseLeaderClaimed)          // → reverseDrainAll
        fire(.reverseDrainCompleted)         // → reverseVerify
        fire(.reverseVerifyOutcome(.match))  // → reverseFreezeBackend
        fire(.reverseBackendFrozen)          // → reverseMountMirror [.mountMirrorAndRelaunch]
        fire(.reverseMirrorMounted)          // → reverseReconcile(.awaitingQuiescence)
        fire(.reverseQuiescenceReached)      // → reverseReconcile(.deletingZombies)
        fire(.reverseZombiesDeleted)         // → reverseReconcile(.rebindingUUIDs)
        fire(.reverseUUIDsRebound)           // → reverseReconcile(.dedupHealed)
        fire(.reverseDedupHealed)            // → reverseUpload
        fire(.reverseUploadCompleted)        // → icloudActive [quartet]

        #expect(log.map(\.0) == [
            expectedConfirm, .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
            .reverseMountMirror, .reverseReconcile(.awaitingQuiescence), .reverseReconcile(.deletingZombies),
            .reverseReconcile(.rebindingUUIDs), .reverseReconcile(.dedupHealed), .reverseUpload, .icloudActive,
        ])

        #expect(log.flatMap(\.1) == [
            .mountMirrorAndRelaunch,                 // entering reverseMountMirror
            .deleteCloudKitMarker, .clearCloudBeacon, .persistICloudMode, .completeReverseServer, // icloudActive
        ])
    }

    @Test func reverse_closingQuartet_exactOrder_onlyOnEnteringICloudActive() {
        let r = step(.reverseUpload, .reverseUploadCompleted)
        #expect(r.next == .icloudActive)
        #expect(r.effects == [.deleteCloudKitMarker, .clearCloudBeacon, .persistICloudMode, .completeReverseServer])
        // The marker-delete is FIRST (needs the mirror mounted); the server is LAST (flakiest).
        #expect(r.effects.first == .deleteCloudKitMarker)
        #expect(r.effects.last == .completeReverseServer)
    }

    @Test func reverse_mountEffect_onlyOnEnteringReverseMountMirror() {
        #expect(step(.reverseFreezeBackend, .reverseBackendFrozen).effects == [.mountMirrorAndRelaunch])
        // Not emitted on any other reverse edge.
        #expect(step(.reverseConfirm(.done), .reverseConfirmed).effects.isEmpty)
        #expect(step(.reverseMountMirror, .reverseMirrorMounted).effects.isEmpty)
    }

    // MARK: - R2. Reverse entry from both origins + re-cutover from icloudActive

    @Test func reverse_entry_fromDoneAndNotStarted_recordsOrigin() {
        #expect(
            MigrationStateMachine.transition(from: .done, event: .reverseActivated)
                == .transition(next: .reverseConfirm(.done), effects: [])
        )
        #expect(
            MigrationStateMachine.transition(from: .notStarted, event: .reverseActivated)
                == .transition(next: .reverseConfirm(.notStarted), effects: [])
        )
    }

    @Test func icloudActive_userActivated_reEntersMigrationViaConsent() {
        #expect(
            MigrationStateMachine.transition(from: .icloudActive, event: .userActivated(dryRun: false))
                == .transition(next: .consent, effects: [])
        )
        #expect(
            MigrationStateMachine.transition(from: .icloudActive, event: .userActivated(dryRun: true))
                == .transition(next: .dryRun, effects: [])
        )
    }

    // MARK: - R3. Decline from both origins + kill in reverseConfirm

    @Test func reverse_decline_returnsToExactOrigin() {
        #expect(step(.reverseConfirm(.done), .reverseDeclined).next == .done)
        #expect(step(.reverseConfirm(.done), .reverseDeclined).effects.isEmpty)
        #expect(step(.reverseConfirm(.notStarted), .reverseDeclined).next == .notStarted)
        #expect(step(.reverseConfirm(.notStarted), .reverseDeclined).effects.isEmpty)
    }

    @Test func reverse_killInConfirm_resumesToOrigin_nothingDurable() {
        #expect(MigrationStateMachine.resume(fromJournaled: .reverseConfirm(.done)) == .done)
        #expect(MigrationStateMachine.resume(fromJournaled: .reverseConfirm(.notStarted)) == .notStarted)
    }

    // MARK: - R4. Kill-resume in every reverse phase (durables retake in themselves)

    @Test func reverse_durablePhases_resumeInThemselves() {
        for phase in Self.durableReversePhases {
            #expect(MigrationStateMachine.resume(fromJournaled: phase) == phase, "\(phase) must resume in itself")
        }
    }

    @Test func reverse_reconcile_resumesExactSubstate_neverRegressesOrSkips() {
        for sub in RSub.allCases {
            #expect(MigrationStateMachine.resume(fromJournaled: .reverseReconcile(sub)) == .reverseReconcile(sub))
        }
        // The sub-state raw values encode the strict order (Comparable invariant).
        #expect(RSub.awaitingQuiescence < RSub.deletingZombies)
        #expect(RSub.deletingZombies < RSub.rebindingUUIDs)
        #expect(RSub.rebindingUUIDs < RSub.dedupHealed)
    }

    // MARK: - R5. Reverse verify (S9) — mismatch RE-DRAINS (never re-uploads), independent counters

    @Test func reverseVerify_match_entersFreezeBackend_noEffects() {
        let r = step(.reverseVerify, .reverseVerifyOutcome(.match))
        #expect(r.next == .reverseFreezeBackend)
        #expect(r.effects.isEmpty)
    }

    @Test func reverseVerify_mismatch_belowCap_reDrains_neverReUploads() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        for retries in 0..<policy.maxMismatchRetries {
            let r = step(.reverseVerify, .reverseVerifyOutcome(.mismatch(retriesSoFar: retries)), policy: policy)
            #expect(r.next == .reverseDrainAll, "reverse mismatch \(retries) must re-drain (pull), not re-upload")
            #expect(r.next != .reverseUpload)
            #expect(r.next != .uploadingSnapshot)
            #expect(r.effects.isEmpty)
        }
    }

    @Test func reverseVerify_mismatch_atCap_failsRollbackWithReverseRollback() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        let r = step(.reverseVerify, .reverseVerifyOutcome(.mismatch(retriesSoFar: 3)), policy: policy)
        #expect(r.next == .reverseFailedRollback)
        #expect(r.effects == [.reverseRollback])
    }

    /// La red de la VUELTA dejó de ser un desenlace del verify el 2026-09-21 (ticket
    /// `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out`): pasa por el techo de la etapa previa
    /// al montaje, como la del drenaje y la del congelado, así que `driveReverseVerify` ya no emite este evento.
    ///
    /// **El par se declara inválido y no se deja como estaba.** La rama vieja degradaba a `reverseFailedRollback`
    /// con `.reverseRollback` pendiente, y dejarla viva sin emisor es una rama muerta que afirma lo contrario del
    /// ticket. Se barre el presupuesto ENTERO más el tope: ninguno de los nueve valores puede volver a transicionar.
    ///
    /// **La IDA no se tocó, y quien lo fija ya estaba escrito**: `verify_networkTimeout_belowCap_alwaysRetriesVerifying`
    /// y `verify_networkTimeout_atCap_failsRollback`, en la sección 4. Este ticket llegó a añadir aquí un tercero que
    /// repetía esos dos literalmente; la review lo midió y se quitó. A nivel de RUNNER sí hacía falta uno
    /// (`MigrationRunnerTests.forwardVerify_networkTimeout_stillSpendsTheBudget_andDegradesAtTheCap`): allí el único
    /// forward del verify que había era el de la sesión caducada.
    @Test func reverseVerify_networkTimeout_isNoLongerALegalPair() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        for retries in 0...policy.maxNetworkRetries {
            let event = Event.reverseVerifyOutcome(.networkTimeout(retriesSoFar: retries))
            #expect(MigrationStateMachine.transition(from: .reverseVerify, event: event, policy: policy)
                    == .invalid(from: .reverseVerify, event: event),
                    "la red de la vuelta va al techo de la etapa, no a los contadores S9 (retries \(retries))")
        }
    }

    @Test func reverseVerify_newDelta_reRuns_doesNotConsumeRetry() {
        let r = step(.reverseVerify, .reverseVerifyOutcome(.newDeltaDetected))
        #expect(r.next == .reverseVerify)
        #expect(r.effects.isEmpty)
    }

    /// El contador que la VUELTA sigue usando es el del mismatch, y su tope es el suyo: un `maxNetworkRetries`
    /// generoso no lo estira. Antes esta pareja probaba que los dos contadores no se sumaban; desde que la red salió
    /// del verify de la vuelta, lo que queda es que el mismatch no heredó el presupuesto del otro al quedarse solo.
    ///
    /// **Lo que mata el mutante es la segunda línea, y es la misma que tenía el test viejo** — la review lo midió: la
    /// primera está subsumida por `reverseVerify_mismatch_belowCap_reDrains_neverReUploads`. Se conserva entera
    /// porque el caso sigue contestando «¿de qué presupuesto vive el mismatch?», no porque añada cobertura nueva.
    @Test func reverseVerify_mismatchCap_isItsOwn_notTheNetworkBudget() {
        let policy = MigrationPolicy(maxMismatchRetries: 1, maxNetworkRetries: 8)
        #expect(step(.reverseVerify, .reverseVerifyOutcome(.mismatch(retriesSoFar: 0)), policy: policy).next
            == .reverseDrainAll)
        #expect(step(.reverseVerify, .reverseVerifyOutcome(.mismatch(retriesSoFar: 1)), policy: policy).next
            == .reverseFailedRollback)
    }

    // MARK: - R6. fatalError in reverse (pre-mount rolls back; post-mount HOLDs; terminals invalid)

    @Test func reverse_fatalError_preMount_failsRollbackWithReverseRollback() {
        let preMount: [Phase] = [.reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend]
        for phase in preMount {
            let r = step(phase, .fatalError)
            #expect(r.next == .reverseFailedRollback, "\(phase) + fatalError → reverseFailedRollback")
            #expect(r.effects == [.reverseRollback])
        }
    }

    @Test func reverse_fatalError_postMount_holdsState_noEffects() {
        var postMount: [Phase] = [.reverseMountMirror, .reverseUpload]
        postMount += RSub.allCases.map { .reverseReconcile($0) }
        for phase in postMount {
            let r = step(phase, .fatalError)
            #expect(r.next == phase, "\(phase) + fatalError HOLDS the state")
            #expect(r.effects.isEmpty)
            #expect(r.next != .reverseFailedRollback)
        }
    }

    @Test func reverse_fatalError_inConfirm_returnsToOrigin() {
        #expect(step(.reverseConfirm(.done), .fatalError).next == .done)
        #expect(step(.reverseConfirm(.notStarted), .fatalError).next == .notStarted)
    }

    @Test func reverse_fatalError_terminals_areInvalid() {
        #expect(
            MigrationStateMachine.transition(from: .icloudActive, event: .fatalError)
                == .invalid(from: .icloudActive, event: .fatalError)
        )
        #expect(
            MigrationStateMachine.transition(from: .reverseFailedRollback, event: .fatalError)
                == .invalid(from: .reverseFailedRollback, event: .fatalError)
        )
    }

    // MARK: - R7. markerReconciliation — all reverse phases + terminals with a marker → `.none`

    @Test func reverse_markerReconciliation_allReversePhases_areNone() {
        let reversePhases = Self.allPhases.filter { isReversePhase($0) }
        // sanity: 14 reverse phases in the inventory.
        #expect(reversePhases.count == 14)
        for phase in reversePhases {
            #expect(
                MigrationStateMachine.markerReconciliation(markerFound: true, journaledPhase: phase) == .none,
                "\(phase) with a live marker mid-reverse must NOT be secondaryDeviceCloudLogin"
            )
        }
    }

    // MARK: - R8. requiresParallelHistoryCapture == false in every reverse phase

    @Test func reverse_requiresParallelHistoryCapture_alwaysFalse() {
        for phase in Self.allPhases where isReversePhase(phase) {
            #expect(!MigrationStateMachine.requiresParallelHistoryCapture(phase: phase), "\(phase) → false")
        }
    }

    // MARK: - R9. Codable round-trip of the reverse phases

    @Test func reverse_codable_roundTrips_confirmBothOrigins_andReconcileSubs() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let reversePhases = Self.allPhases.filter { isReversePhase($0) }
        for phase in reversePhases {
            let back = try decoder.decode(Phase.self, from: encoder.encode(phase))
            #expect(back == phase, "round-trip failed for \(phase)")
        }
        // ReverseOrigin + ReverseReconcileSubstate also round-trip standalone.
        for origin in [ReverseOrigin.done, .notStarted] {
            #expect(try decoder.decode(ReverseOrigin.self, from: encoder.encode(origin)) == origin)
        }
        for sub in RSub.allCases {
            #expect(try decoder.decode(RSub.self, from: encoder.encode(sub)) == sub)
        }
    }

    // MARK: - R10. Illegal reverse edges

    @Test func reverse_illegalEdges_areInvalid() {
        // An out-of-order reconcile event while still in reverseVerify.
        #expect(
            MigrationStateMachine.transition(from: .reverseVerify, event: .reverseZombiesDeleted)
                == .invalid(from: .reverseVerify, event: .reverseZombiesDeleted)
        )
        // A reverse ack fired on `done` (before confirming) is illegal.
        #expect(
            MigrationStateMachine.transition(from: .done, event: .reverseConfirmed)
                == .invalid(from: .done, event: .reverseConfirmed)
        )
        // Reverse events on forward phases are illegal.
        #expect(
            MigrationStateMachine.transition(from: .verifying, event: .reverseLeaderClaimed)
                == .invalid(from: .verifying, event: .reverseLeaderClaimed)
        )
        // A reconcile cannot skip a sub-state.
        #expect(
            MigrationStateMachine.transition(
                from: .reverseReconcile(.awaitingQuiescence), event: .reverseUUIDsRebound
            ) == .invalid(from: .reverseReconcile(.awaitingQuiescence), event: .reverseUUIDsRebound)
        )
        // A forward event on a reverse phase is illegal.
        #expect(
            MigrationStateMachine.transition(from: .reverseVerify, event: .snapshotUploaded)
                == .invalid(from: .reverseVerify, event: .snapshotUploaded)
        )
    }

    // MARK: - R11. reverseOtherLeader desatascador (I11-2, obligación 4 del review I11-1)

    @Test func reverseOtherLeader_returnsToOrigin_bothOrigins_noEffects() {
        let toDone = step(.reverseClaimLeader, .reverseOtherLeader(returnTo: .done))
        #expect(toDone.next == .done)
        #expect(toDone.effects.isEmpty)
        let toNotStarted = step(.reverseClaimLeader, .reverseOtherLeader(returnTo: .notStarted))
        #expect(toNotStarted.next == .notStarted)
        #expect(toNotStarted.effects.isEmpty)
    }

    @Test func reverseOtherLeader_illegalOutsideReverseClaimLeader() {
        // Solo legal desde reverseClaimLeader; en cualquier otra fase es inválido.
        #expect(
            MigrationStateMachine.transition(from: .reverseDrainAll, event: .reverseOtherLeader(returnTo: .done))
                == .invalid(from: .reverseDrainAll, event: .reverseOtherLeader(returnTo: .done))
        )
        #expect(
            MigrationStateMachine.transition(from: .done, event: .reverseOtherLeader(returnTo: .done))
                == .invalid(from: .done, event: .reverseOtherLeader(returnTo: .done))
        )
        #expect(
            MigrationStateMachine.transition(from: .reverseReconcile(.deletingZombies), event: .reverseOtherLeader(returnTo: .notStarted))
                == .invalid(from: .reverseReconcile(.deletingZombies), event: .reverseOtherLeader(returnTo: .notStarted))
        )
    }

    // MARK: - R11b. reverseClaimRejected: el rechazo del claim sale al origen (ticket reverse-claim-rejection-has-no-way-out-in-the-client)

    /// Sin esta arista un `.rejected` dejaba `reverseClaimLeader` —fase TRANSITORIA— journaleada para siempre: barra al
    /// 15 %, motor de la nube sin arrancar tras relanzar y BGTasks diferidos. Sale al origen SIN efectos: el claim rechazado no reservó
    /// nada, y un `.reverseRollback` sin red se quedaría pendiente en la fase estable.
    @Test func reverseClaimRejected_returnsToOrigin_bothOrigins_noEffects() {
        let toDone = step(.reverseClaimLeader, .reverseClaimRejected(returnTo: .done))
        #expect(toDone.next == .done)
        #expect(toDone.effects.isEmpty)
        let toNotStarted = step(.reverseClaimLeader, .reverseClaimRejected(returnTo: .notStarted))
        #expect(toNotStarted.next == .notStarted)
        #expect(toNotStarted.effects.isEmpty)
    }

    // MARK: - R11c. claimRefusedExistingAccount: «Migrar» sobre una cuenta con lo personal (ticket settings-migrate-to-cloud-adopts-silently-instead-of-migrating)

    /// Sin esta arista, `existing_stable` solo podía ir al adopt, que sube el corpus local a la cuenta. Vuelve al inicio
    /// SIN efectos: la rama `existing_stable` de `claim_account` no escribe, así que no hay nada que deshacer.
    @Test func claimRefusedExistingAccount_returnsToNotStarted_noEffects() {
        let r = step(.claimingMigration, .claimRefusedExistingAccount)
        #expect(r.next == .notStarted)
        #expect(r.effects.isEmpty, "ni adopt ni rollback: el claim no reservó nada")
        // Control: el mismo desenlace entregado como `claimResult` sigue siendo el adopt de siempre.
        #expect(step(.claimingMigration, .claimResult(.existingStable, sameDeviceReclaim: false)).effects
                == [.adoptBackendAccount])
    }

    /// Solo desde el claim de la ida. En `waitingForLeader` el seguidor adopta lo que migró su líder, y desde cualquier
    /// otra fase ya hay algo reservado o escrito.
    @Test func claimRefusedExistingAccount_illegalOutsideClaimingMigration() {
        for phase in Self.allPhases where phase != .claimingMigration {
            let event = MigrationEvent.claimRefusedExistingAccount
            #expect(MigrationStateMachine.transition(from: phase, event: event) == .invalid(from: phase, event: event),
                    "\(phase)")
        }
    }

    @Test func reverseClaimRejected_illegalOutsideReverseClaimLeader() {
        // Solo legal desde reverseClaimLeader: después de la reserva ya hay algo que deshacer y quien sale es otro.
        for phase: MigrationPhase in [.reverseDrainAll, .reverseFreezeBackend, .reverseUpload, .done, .notStarted,
                                      .reverseConfirm(.done), .icloudActive, .reverseFailedRollback] {
            let event = MigrationEvent.reverseClaimRejected(returnTo: .done)
            #expect(MigrationStateMachine.transition(from: phase, event: event) == .invalid(from: phase, event: event),
                    "\(phase)")
        }
    }

    // MARK: - C1. Precondición de entrada del cutover (bug C-1)

    /// Presupuestos INYECTADOS y pequeños para los tests del tope: pinnean la MECÁNICA (comparar elapsed
    /// contra el presupuesto que elige la causa) sin depender de los números de producto, que se pinnean
    /// aparte en `markerExportBudgets_defaultsArePinnedProductDecision`.
    private static let stallPolicy = MigrationPolicy(
        markerExportDefinitiveBudgetSeconds: 60,
        markerExportUnknownBudgetSeconds: 600
    )

    /// Canal iCloud sabido-roto detectado en `verifying` (rama `.match`): abortar AQUÍ es gratis — no hay
    /// `migrated_at`, ni `.cloud` persistido, ni marcador ⇒ el device queda idéntico a como empezó.
    @Test func icloudPreconditionFailed_fromVerifying_rollsBackClean() {
        let r = step(.verifying, .icloudCutoverPreconditionFailed)
        #expect(r.next == .failedRollback)
        #expect(r.effects == [.rollback])
    }

    /// Segunda oportunidad de abortar: el journal ya dice `cutover(.pending)` (p.ej. tras un kill entre el
    /// verify y el paso 1), pero `pending` significa literalmente "a punto de escribir `migrated_at`" —
    /// nada externo ha cambiado todavía, así que el rollback sigue siendo limpio.
    @Test func icloudPreconditionFailed_fromCutoverPending_rollsBackClean() {
        let r = step(.cutover(.pending), .icloudCutoverPreconditionFailed)
        #expect(r.next == .failedRollback)
        #expect(r.effects == [.rollback])
    }

    /// PIN ANTI-REGRESIÓN CRÍTICO. Solo la ENTRADA del cutover puede abortar. Desde `serverConfirmed` en
    /// adelante existe ya algo durable (`migrated_at` estampado, `.cloud` persistido, el marcador escrito),
    /// y la regla §g.4 "el cutover jamás hace rollback" protege exactamente esos sub-estados: la migración
    /// es REAL y la recuperación es retomar por sub-estado, no deshacer. Si alguien "generalizase" este
    /// evento a todo el cutover, un fallo de canal en el paso 4 dispararía un rollback con el marcador ya
    /// vivo en CloudKit ⇒ el resto del parque congelando escrituras contra un backend que este device
    /// abandonó. El tope del paso 4 (abajo) es el ÚNICO camino de degradación pasado `pending`.
    @Test func icloudPreconditionFailed_pastCutoverEntry_isInvalid_cutoverNeverRollsBack() {
        // Sanity: 5 sub-estados (cero sub-estados nuevos en C-1) — 1 de entrada + 4 protegidos.
        #expect(Sub.allCases.count == 5)
        for sub in Sub.allCases where sub > .pending { // serverConfirmed, localModeSet, markerWritten, mirrorOff
            #expect(
                MigrationStateMachine.transition(from: .cutover(sub), event: .icloudCutoverPreconditionFailed)
                    == .invalid(from: .cutover(sub), event: .icloudCutoverPreconditionFailed),
                "cutover(\(sub)) + icloudCutoverPreconditionFailed debe ser inválido (el marcador ya existe)"
            )
        }
    }

    // MARK: - C2. Tope por tiempo del paso 4 (bug C-1)

    /// Bajo presupuesto el paso 4 HOLDEA (molde de `newDeltaDetected`): el runner corta retomable y el
    /// próximo resume vuelve a observar. Dos cosas que el `effects.isEmpty` protege: NO se re-emite
    /// `.writeCloudKitMarker` (doble escritura del marcador en cada observación) y NO se cuela
    /// `.disableMirrorAndRelaunch` (apagar el mirror antes de que el marcador exporte lo pierde para
    /// siempre — el gate de export es precisamente lo que estamos esperando).
    @Test func markerExportStalled_belowBudget_holdsMarkerWritten_noEffects() {
        let policy = Self.stallPolicy
        // 59 = presupuesto definitivo - 1: por debajo de AMBOS presupuestos, así que vale para las 2 causas.
        let belowBoth: [Double] = [0, 1, policy.markerExportDefinitiveBudgetSeconds - 1]
        for cause in [MarkerExportStall.definitive, .unknown] {
            for elapsed in belowBoth {
                let r = step(
                    .cutover(.markerWritten),
                    .markerExportStalled(elapsedSeconds: elapsed, cause: cause),
                    policy: policy
                )
                #expect(r.next == .cutover(.markerWritten), "elapsed \(elapsed) (\(cause)) debe holdear")
                #expect(r.effects.isEmpty)
                // Negativos: ni degrada antes de tiempo ni avanza el cutover por su cuenta.
                #expect(r.next != .failedRollback)
                #expect(r.next != .cutover(.mirrorOff))
            }
        }
    }

    /// Al agotar el presupuesto (`>=`, no `>`), abort LOCAL sin red. El ORDEN de los 3 efectos es el
    /// contrato, no un detalle: `.persistICloudMode` va PRIMERO porque escribe `.icloud` + desarma el
    /// mirror-off JUNTOS y es el único de los tres que NO puede lanzar (`UserDefaults` puro) ⇒ la mitad
    /// peligrosa (el `.cloud` persistido que monta el mirror en modo nube = doble escritura) se deshace
    /// antes de que nada más pueda fallar. Un `failedRollback` "pelado", sin ese efecto, sería PEOR que el
    /// bug original: el "Reintentar" de la UI lleva a `notStarted` (fase ESTABLE) y ahí ya no hay gate.
    /// Se asserta el array COMPLETO a propósito — un `contains` dejaría pasar cualquier reordenación.
    @Test func markerExportStalled_definitiveAtOrPastBudget_abortsLocallyInExactEffectOrder() {
        let policy = Self.stallPolicy
        let budget = policy.markerExportDefinitiveBudgetSeconds
        for elapsed in [budget, budget + 1, budget * 100] {
            let r = step(
                .cutover(.markerWritten),
                .markerExportStalled(elapsedSeconds: elapsed, cause: .definitive),
                policy: policy
            )
            #expect(r.next == .failedRollback, "elapsed \(elapsed) >= \(budget) debe degradar")
            #expect(r.effects == [.persistICloudMode, .deleteCloudKitMarker, .rollback])
            #expect(r.effects.first == .persistICloudMode)
        }
    }

    /// La causa elige el presupuesto: el MISMO elapsed que aborta con `.definitive` (CloudKit ya dictó que
    /// el write no entra ⇒ esperar no cambia nada) sigue holdeando con `.unknown` (offline, export lento:
    /// un snapshot ya subido Y verificado no se tira por una mala racha de red). Si alguien colapsase los
    /// dos presupuestos en uno, este test lo caza por el lado que importa — el falso positivo.
    @Test func markerExportStalled_unknownUsesTheLongBudget_sameElapsedStillHolds() {
        let policy = Self.stallPolicy
        let definitiveBudget = policy.markerExportDefinitiveBudgetSeconds
        #expect(
            step(.cutover(.markerWritten),
                 .markerExportStalled(elapsedSeconds: definitiveBudget, cause: .definitive),
                 policy: policy).next == .failedRollback
        )
        let held = step(
            .cutover(.markerWritten),
            .markerExportStalled(elapsedSeconds: definitiveBudget, cause: .unknown),
            policy: policy
        )
        #expect(held.next == .cutover(.markerWritten))
        #expect(held.effects.isEmpty)
        // Pero `.unknown` NO es infinito: al alcanzar SU presupuesto degrada con los mismos 3 efectos.
        let capped = step(
            .cutover(.markerWritten),
            .markerExportStalled(elapsedSeconds: policy.markerExportUnknownBudgetSeconds, cause: .unknown),
            policy: policy
        )
        #expect(capped.next == .failedRollback)
        #expect(capped.effects == [.persistICloudMode, .deleteCloudKitMarker, .rollback])
    }

    /// El tope pertenece SOLO al paso 4. En cualquier otro sub-estado del cutover el marcador no está
    /// escrito (o el mirror ya está apagado y la espera terminó), y fuera del cutover el evento no tiene
    /// sentido: `.invalid` con el par (from, event) para el breadcrumb, nunca una degradación silenciosa.
    @Test func markerExportStalled_outsideMarkerWritten_isInvalid() {
        // Elapsed absurdamente alto: si alguna de estas aristas existiera, degradaría — el test la caza.
        let event = MigrationEvent.markerExportStalled(elapsedSeconds: 10_000_000, cause: .definitive)
        for sub in Sub.allCases where sub != .markerWritten {
            #expect(
                MigrationStateMachine.transition(from: .cutover(sub), event: event, policy: Self.stallPolicy)
                    == .invalid(from: .cutover(sub), event: event),
                "cutover(\(sub)) + markerExportStalled debe ser inválido"
            )
        }
        let nonCutover = Self.allPhases.filter { phase in
            if case .cutover = phase { return false }
            return true
        }
        for phase in nonCutover {
            #expect(
                MigrationStateMachine.transition(from: phase, event: event, policy: Self.stallPolicy)
                    == .invalid(from: phase, event: event),
                "\(phase) + markerExportStalled debe ser inválido"
            )
        }
    }

    /// Los presupuestos por defecto son decisión de PRODUCTO ratificada por el owner: 15 min cuando el
    /// fallo es definitivo (cada minuto extra es un minuto de doble escritura potencial) y 72 h cuando aún
    /// no se sabe por qué no exporta (el canario `cloudCutoverMarkerStalled` se emite en cada observación,
    /// así que un atasco sistémico se ve en el dashboard mucho antes de que ningún device degrade). Este
    /// test es el que obliga a que cambiarlos sea deliberado, no un descuido.
    @Test func markerExportBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.markerExportDefinitiveBudgetSeconds == 900)      // 15 min
        #expect(MigrationPolicy.default.markerExportUnknownBudgetSeconds == 259_200)     // 72 h
        // Y la relación entre ambos (lo que hace útil la clasificación) también queda fijada.
        #expect(
            MigrationPolicy.default.markerExportUnknownBudgetSeconds
                > MigrationPolicy.default.markerExportDefinitiveBudgetSeconds
        )
        // Con los defaults: a los 900 s, `.definitive` aborta y `.unknown` sigue esperando.
        #expect(step(.cutover(.markerWritten), .markerExportStalled(elapsedSeconds: 900, cause: .definitive)).next
            == .failedRollback)
        #expect(step(.cutover(.markerWritten), .markerExportStalled(elapsedSeconds: 900, cause: .unknown)).next
            == .cutover(.markerWritten))
    }

    // MARK: - RU. Techo y salida de `reverseUpload` (ticket `reverse-upload-has-no-ceiling-and-no-exit`)

    /// Presupuestos pequeños e INYECTADOS: pinnean la mecánica sin depender de los números de producto, que se
    /// pinnean aparte en `reverseUploadBudgets_defaultsArePinnedProductDecision`.
    private static let reverseUploadPolicy = MigrationPolicy(
        reverseUploadDefinitiveBudgetSeconds: 60,
        reverseUploadUnknownBudgetSeconds: 600
    )

    private static let origins: [(ReverseOrigin, Phase)] = [(.done, .done), (.notStarted, .notStarted)]

    /// Bajo presupuesto la espera HOLDEA sin efectos: el runner corta retomable y vuelve a observar. Sin efectos
    /// significa que ni se re-arma el apagado del mirror ni se descongela el backend en cada observación.
    @Test func reverseUploadStalled_belowBudget_holdsReverseUpload_noEffects() {
        let policy = Self.reverseUploadPolicy
        let belowBoth: [Double] = [0, 1, policy.reverseUploadDefinitiveBudgetSeconds - 1]
        for (origin, _) in Self.origins {
            for cause in [MarkerExportStall.definitive, .unknown] {
                for stalled in belowBoth {
                    let r = step(
                        .reverseUpload,
                        .reverseUploadStalled(stalledSeconds: stalled, cause: cause, returnTo: origin),
                        policy: policy)
                    #expect(r.next == .reverseUpload, "\(stalled)s sin avanzar (\(cause), \(origin)) holdea")
                    #expect(r.effects.isEmpty)
                }
            }
        }
    }

    /// EL test del ticket: al agotar el techo (`>=`) la reversa VUELVE al origen en modo nube. El array de
    /// efectos se afirma entero porque el ORDEN es el contrato: `.rearmMirrorOff` primero (no puede lanzar y deja
    /// hecha la mitad local), `.reverseRollback` después (red). Y que el destino sea el ORIGEN, no
    /// `reverseFailedRollback`: ahí el motor de la nube no arranca hasta que alguien toca «Reintentar», y el techo
    /// salta con la persona ausente.
    @Test func reverseUploadStalled_definitiveAtOrPastBudget_returnsToOrigin_rearmThenAbort() {
        let policy = Self.reverseUploadPolicy
        let budget = policy.reverseUploadDefinitiveBudgetSeconds
        for (origin, originPhase) in Self.origins {
            for stalled in [budget, budget + 1, budget * 100] {
                let r = step(
                    .reverseUpload,
                    .reverseUploadStalled(stalledSeconds: stalled, cause: .definitive, returnTo: origin),
                    policy: policy)
                #expect(r.next == originPhase, "\(stalled)s >= \(budget)s vuelve a \(originPhase)")
                #expect(r.effects == [.rearmMirrorOff, .reverseRollback])
                #expect(r.next != .reverseFailedRollback)
                #expect(r.next != .icloudActive, "la salida NO completa la vuelta a iCloud")
            }
        }
    }

    /// La causa elige el techo: el mismo tiempo sin avanzar que hace salir con `.definitive` (iCloud ya dijo que
    /// no) sigue esperando con `.unknown`. Y `.unknown` tampoco es infinito.
    @Test func reverseUploadStalled_unknownUsesTheLongBudget_sameStallStillHolds() {
        let policy = Self.reverseUploadPolicy
        let shortBudget = policy.reverseUploadDefinitiveBudgetSeconds
        #expect(step(.reverseUpload,
                     .reverseUploadStalled(stalledSeconds: shortBudget, cause: .definitive, returnTo: .done),
                     policy: policy).next == .done)
        let held = step(.reverseUpload,
                        .reverseUploadStalled(stalledSeconds: shortBudget, cause: .unknown, returnTo: .done),
                        policy: policy)
        #expect(held.next == .reverseUpload)
        #expect(held.effects.isEmpty)
        let capped = step(
            .reverseUpload,
            .reverseUploadStalled(
                stalledSeconds: policy.reverseUploadUnknownBudgetSeconds, cause: .unknown, returnTo: .done),
            policy: policy)
        #expect(capped.next == .done)
        #expect(capped.effects == [.rearmMirrorOff, .reverseRollback])
    }

    /// «Cancelar y seguir en la nube»: la misma vuelta que el techo, sin esperar a que venza, desde los dos orígenes.
    @Test func reverseUploadCancelled_returnsToOrigin_sameOrderedEffects() {
        for (origin, originPhase) in Self.origins {
            let r = step(.reverseUpload, .reverseUploadCancelled(returnTo: origin))
            #expect(r.next == originPhase)
            #expect(r.effects == [.rearmMirrorOff, .reverseRollback])
        }
    }

    /// La salida es SOLO de `reverseUpload`. Antes del montaje la reversa tiene su propio rollback, y en las demás
    /// fases post-montaje un `.rearmMirrorOff` apagaría un mirror que el reconcile todavía necesita. Tiempo sin
    /// avanzar absurdo: si alguna arista existiera, saldría.
    @Test func reverseUploadExitEvents_outsideReverseUpload_areInvalid() {
        let events: [Event] = [
            .reverseUploadStalled(stalledSeconds: 10_000_000, cause: .definitive, returnTo: .done),
            .reverseUploadCancelled(returnTo: .done),
        ]
        for phase in Self.allPhases where phase != .reverseUpload {
            for event in events {
                #expect(
                    MigrationStateMachine.transition(from: phase, event: event, policy: Self.reverseUploadPolicy)
                        == .invalid(from: phase, event: event),
                    "\(phase) + \(event) debe ser inválido")
            }
        }
    }

    /// Los techos por defecto son la decisión de Jürgen del 2026-09-16: 15 min SIN avanzar si iCloud ya dijo que
    /// no, 72 h si no se sabe. Cambiarlos tiene que ser deliberado.
    @Test func reverseUploadBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.reverseUploadDefinitiveBudgetSeconds == 900)       // 15 min
        #expect(MigrationPolicy.default.reverseUploadUnknownBudgetSeconds == 259_200)      // 72 h
        #expect(step(.reverseUpload,
                     .reverseUploadStalled(stalledSeconds: 900, cause: .definitive, returnTo: .done)).next == .done)
        #expect(step(.reverseUpload,
                     .reverseUploadStalled(stalledSeconds: 900, cause: .unknown, returnTo: .done)).next
            == .reverseUpload)
    }
    // MARK: - Techo y salida de las CUATRO fases previas al montaje
    // (ticket `reverse-before-mount-has-no-way-to-abandon-the-return`)

    private static let preMountPolicy = MigrationPolicy(
        reversePreMountCauseBudgetSeconds: 60,
        reversePreMountPhaseBudgetSeconds: 600
    )

    /// Las cuatro fases que la salida cubre. `reverseUpload` NO está: esa tiene la suya, con otros efectos.
    private static let preMountPhases: [Phase] = [
        .reverseClaimLeader, .reverseDrainAll, .reverseVerify, .reverseFreezeBackend,
    ]

    /// Bajo presupuesto, cada fase HOLDEA EN SÍ MISMA y sin efectos. Lo segundo importa tanto como lo primero: una
    /// observación que emitiera `.reverseRollback` descongelaría el backend en cada re-kick de 30 s.
    @Test func reversePreMountStalled_belowBudget_holdsItsOwnPhase_noEffects() {
        let policy = Self.preMountPolicy
        let below: [Double] = [0, 1, policy.reversePreMountCauseBudgetSeconds - 1]
        for phase in Self.preMountPhases {
            for (origin, _) in Self.origins {
                for cause in [MarkerExportStall.definitive, .unknown] {
                    for stalled in below {
                        let r = step(
                            phase,
                            .reversePreMountStalled(stalledSeconds: stalled, definitiveStalledSeconds: stalled,
                                                    cause: cause, returnTo: origin),
                            policy: policy)
                        #expect(r.next == phase, "\(phase): \(stalled)s (\(cause), \(origin)) se queda donde está")
                        #expect(r.effects.isEmpty)
                    }
                }
            }
        }
    }

    /// EL test del ticket: agotado el techo, cada una de las cuatro vuelve a su ORIGEN y **sin un solo efecto**.
    /// (Las dos aserciones «no es `reverseFailedRollback`, no es `icloudActive`» que este caso tenía se quitaron:
    /// con `origins` acotado a `.done`/`.notStarted`, la igualdad de arriba ya las implica en las 24 iteraciones.)
    /// Las dos mitades son decisiones y las dos tienen su mutante aquí:
    ///  · sin `.rearmMirrorOff`, porque pre-montaje el espejo nunca se re-encendió;
    ///  · sin `.reverseRollback`, porque ese efecto lanza sin sesión y un efecto que lanza se relanza en cada
    ///    arranque — el bug-class que esta salida cierra. El `reverse_abort` lo intenta el runner, best-effort.
    @Test func reversePreMountStalled_atOrPastBudget_returnsToOrigin_withNoEffectsAtAll() {
        let policy = Self.preMountPolicy
        let budget = policy.reversePreMountCauseBudgetSeconds
        for phase in Self.preMountPhases {
            for (origin, originPhase) in Self.origins {
                for stalled in [budget, budget + 1, budget * 100] {
                    let r = step(
                        phase,
                        .reversePreMountStalled(stalledSeconds: stalled, definitiveStalledSeconds: stalled,
                                                cause: .definitive, returnTo: origin),
                        policy: policy)
                    #expect(r.next == originPhase, "\(phase): \(stalled)s >= \(budget)s vuelve a \(originPhase)")
                    #expect(r.effects.isEmpty, "\(phase): ni re-armado ni abort journaleados")
                }
            }
        }
    }

    /// La causa elige el techo: el mismo tiempo parado que hace salir con `.definitive` —el servidor ya dijo que
    /// no— sigue esperando con `.unknown`, que es donde caen la red y la sesión. Un mutante que intercambie los dos
    /// presupuestos muere en las dos mitades.
    @Test func reversePreMountStalled_unknownUsesTheLongBudget() {
        let policy = Self.preMountPolicy
        let shortBudget = policy.reversePreMountCauseBudgetSeconds
        let longBudget = policy.reversePreMountPhaseBudgetSeconds
        for phase in Self.preMountPhases {
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: shortBudget, definitiveStalledSeconds: shortBudget,
                                                 cause: .definitive, returnTo: .done),
                         policy: policy).next == .done)
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: shortBudget, definitiveStalledSeconds: shortBudget,
                                                 cause: .unknown, returnTo: .done),
                         policy: policy).next == phase,
                    "\(phase): sin un motivo que no se arregle esperando, el techo corto no aplica")
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: longBudget, definitiveStalledSeconds: 0,
                                                 cause: .unknown, returnTo: .done),
                         policy: policy).next == .done,
                    "\(phase): pero el largo tampoco es infinito")
        }
    }

    /// **EL test del ticket `…charges-a-stall-to-whoever-stops-it-last`, en la máquina.** El techo corto se mide
    /// contra el reloj de lo DEFINITIVO (hasta `alternating-definitive-causes-never-reach-the-short-ceiling`, el de
    /// UNA causa), no contra el de la fase: una fase que lleva parada casi el presupuesto largo
    /// por otra cosa, y que en ESTA pasada tropieza con un motivo definitivo, tiene que HOLDEAR. Hasta este ticket
    /// la máquina recibía un solo reloj y `10 800 >= 900` salía a la primera: un `fetch` local que falló una vez
    /// sacaba de la vuelta sin un solo reintento.
    ///
    /// Los tres casos son los tres términos de la condición, uno por cada uno, y los dos primeros se clavan con
    /// sus vecinos (`corto - 1` vs `corto`, con el largo sin alcanzar en ambos) para que ningún `>=` se pueda
    /// cambiar por `>` sin que muera algo:
    ///  1. ninguno de los dos vencido → holdea;
    ///  2. vencido el de lo DEFINITIVO con el de fase todavía por debajo del largo → sale;
    ///  3. vencido el de FASE con el de lo definitivo recién empezado → sale igual, **y con causa definitiva**: el
    ///     largo aplica con cualquier causa.
    @Test func reversePreMountStalled_theShortCeilingMeasuresTheDefinitiveClock() {
        let policy = Self.preMountPolicy
        let short = policy.reversePreMountCauseBudgetSeconds       // 60
        let long = policy.reversePreMountPhaseBudgetSeconds           // 600
        for phase in Self.preMountPhases {
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: long - 1, definitiveStalledSeconds: short - 1,
                                                 cause: .definitive, returnTo: .done),
                         policy: policy).next == phase,
                    "\(phase): la espera larga era de OTRA causa — este motivo aún no ha gastado lo suyo")
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: long - 1, definitiveStalledSeconds: short,
                                                 cause: .definitive, returnTo: .done),
                         policy: policy).next == .done,
                    "\(phase): con su propio reloj cumplido sale, y no hizo falta el largo")
            #expect(step(phase,
                         .reversePreMountStalled(stalledSeconds: long, definitiveStalledSeconds: 0,
                                                 cause: .definitive, returnTo: .done),
                         policy: policy).next == .done,
                    "\(phase): el techo de la FASE aplica con cualquier causa — es el suelo del mecanismo")
        }
    }

    /// La salida de la persona: la misma vuelta, sin esperar y sin efectos.
    @Test func reversePreMountCancelled_returnsToOrigin_withNoEffects() {
        for phase in Self.preMountPhases {
            for (origin, originPhase) in Self.origins {
                let r = step(phase, .reversePreMountCancelled(returnTo: origin))
                #expect(r.next == originPhase, "\(phase) → \(originPhase)")
                #expect(r.effects.isEmpty)
            }
        }
    }

    /// Y solo esas cuatro. En `reverseUpload` y en el resto de fases POST-montaje el espejo ya está vivo: salir de
    /// ahí sin `.rearmMirrorOff` dejaría `.cloud` + mirror montado, el estado prohibido de `isCloudWithMirrorOn`.
    /// Tiempo parado absurdo: si alguna arista existiera de más, saldría por ella.
    @Test func reversePreMountExitEvents_outsideTheFourPhases_areInvalid() {
        let events: [Event] = [
            .reversePreMountStalled(stalledSeconds: 10_000_000, definitiveStalledSeconds: 10_000_000,
                                    cause: .definitive, returnTo: .done),
            .reversePreMountCancelled(returnTo: .done),
        ]
        for phase in Self.allPhases where !Self.preMountPhases.contains(phase) {
            for event in events {
                #expect(
                    MigrationStateMachine.transition(from: phase, event: event, policy: Self.preMountPolicy)
                        == .invalid(from: phase, event: event),
                    "\(phase) + \(event) debe ser inválido")
            }
        }
    }

    /// Los techos por defecto: los mismos números que el resto de esta familia. Cambiarlos tiene que ser
    /// deliberado, y aquí se ve que el corto de verdad se aplica y el largo de verdad no.
    @Test func reversePreMountBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.reversePreMountCauseBudgetSeconds == 900)      // 15 min
        #expect(MigrationPolicy.default.reversePreMountPhaseBudgetSeconds == 259_200)     // 72 h
        #expect(step(.reverseDrainAll,
                     .reversePreMountStalled(stalledSeconds: 900, definitiveStalledSeconds: 900,
                                             cause: .definitive, returnTo: .done)).next
            == .done)
        #expect(step(.reverseDrainAll,
                     .reversePreMountStalled(stalledSeconds: 900, definitiveStalledSeconds: 900,
                                             cause: .unknown, returnTo: .done)).next
            == .reverseDrainAll)
    }

    // MARK: - Techo y salida de `uploadingSnapshot` (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`)

    /// Hasta este ticket la fase tenía dos salidas y ninguna alcanzable ante un fallo persistente. Bajo presupuesto la
    /// observación HOLDEA en la propia fase y sin efectos, en las dos combinaciones de causa.
    @Test func snapshotUploadStalled_belowBothBudgets_holdsWithNoEffects() {
        for cause in [MarkerExportStall.unknown, .definitive] {
            let r = step(.uploadingSnapshot,
                         .snapshotUploadStalled(stalledSeconds: 259_199, definitiveStalledSeconds: 899, cause: cause))
            #expect(r.next == .uploadingSnapshot, "\(cause)")
            #expect(r.effects.isEmpty, "\(cause)")
        }
    }

    /// El techo LARGO vale con CUALQUIER causa, clavado con sus dos vecinos. Con `.definitive` también: es el suelo del
    /// mecanismo (hasta `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`, además, lo único
    /// que sacaba de la subida con dos causas definitivas turnándose).
    @Test func snapshotUploadStalled_progressCeiling_appliesWithAnyCause() {
        for cause in [MarkerExportStall.unknown, .definitive] {
            #expect(step(.uploadingSnapshot,
                         .snapshotUploadStalled(stalledSeconds: 259_199, definitiveStalledSeconds: 0, cause: cause)).next
                == .uploadingSnapshot, "\(cause) a 259 199 s todavía no")
            let out = step(.uploadingSnapshot,
                           .snapshotUploadStalled(stalledSeconds: 259_200, definitiveStalledSeconds: 0, cause: cause))
            #expect(out.next == .failedRollback, "\(cause) a 259 200 s sale")
            #expect(out.effects == [.rollback], "la misma salida que `verifying` al agotar sus reintentos")
        }
    }

    /// El techo CORTO: solo con `.definitive` y contra el reloj de lo DEFINITIVO (hasta
    /// `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`, el de UNA causa), no el de avance.
    @Test func snapshotUploadStalled_causeCeiling_onlyWithADefinitiveCause() {
        #expect(step(.uploadingSnapshot,
                     .snapshotUploadStalled(stalledSeconds: 0, definitiveStalledSeconds: 899, cause: .definitive)).next
            == .uploadingSnapshot)
        #expect(step(.uploadingSnapshot,
                     .snapshotUploadStalled(stalledSeconds: 0, definitiveStalledSeconds: 900, cause: .definitive)).next
            == .failedRollback)
        // Con `.unknown`, el reloj de lo definitivo no manda aunque venga enorme: la red solo tiene el largo.
        #expect(step(.uploadingSnapshot,
                     .snapshotUploadStalled(stalledSeconds: 0, definitiveStalledSeconds: 100_000, cause: .unknown)).next
            == .uploadingSnapshot)
        // Y el corto no se mide contra el reloj de AVANCE: tres horas sin avanzar con una causa recién vista holdean.
        #expect(step(.uploadingSnapshot,
                     .snapshotUploadStalled(stalledSeconds: 10_800, definitiveStalledSeconds: 0, cause: .definitive)).next
            == .uploadingSnapshot)
    }

    /// «Cancelar la activación»: a `notStarted` SIN efectos. Lo decidió la persona, no hay fallo que explicar.
    @Test func snapshotUploadCancelled_returnsToNotStarted_withNoEffects() {
        let out = step(.uploadingSnapshot, .snapshotUploadCancelled)
        #expect(out.next == .notStarted)
        #expect(out.effects.isEmpty)
    }

    /// Los dos eventos solo son legales desde `uploadingSnapshot`: un techo o un «Cancelar» que llegan en otra fase no
    /// pueden sacar a nadie de ella.
    @Test func snapshotUploadEvents_areInvalidOutsideTheirPhase() {
        let events: [Event] = [
            .snapshotUploadStalled(stalledSeconds: 10_000_000, definitiveStalledSeconds: 10_000_000, cause: .definitive),
            .snapshotUploadCancelled,
        ]
        for phase in Self.allPhases where phase != .uploadingSnapshot {
            for event in events {
                #expect(MigrationStateMachine.transition(from: phase, event: event) == .invalid(from: phase, event: event),
                        "\(phase) + \(event) debe ser inválido")
            }
        }
    }

    /// Los números son la decisión de Jürgen del 2026-09-22: los mismos que el resto de techos de la familia.
    @Test func snapshotBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.snapshotCauseBudgetSeconds == 900)          // 15 min
        #expect(MigrationPolicy.default.snapshotProgressBudgetSeconds == 259_200)   // 72 h
    }

    // MARK: - Techo y salida de los tres pasos sin cifra que baje (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`)

    /// Los tres pasos: claim (22 %), identidad (35 %) y `cutover(.pending)` (80 %).
    static let forwardStepPhases: [Phase] = [.claimingMigration, .assigningIdentity, .cutover(.pending)]

    /// Bajo los dos presupuestos holdea en su PROPIA fase y sin efectos, con cualquier causa.
    @Test func forwardStepStalled_belowBothBudgets_holdsInItsOwnPhase() {
        for phase in Self.forwardStepPhases {
            for cause in [MarkerExportStall.unknown, .definitive] {
                let out = step(phase, .forwardStepStalled(stalledSeconds: 259_199, causeStalledSeconds: 899, cause: cause))
                #expect(out.next == phase, "\(phase) · \(cause)")
                #expect(out.effects.isEmpty)
            }
        }
    }

    /// El techo LARGO aplica con cualquier causa, clavado con sus dos vecinos, y sale a `failedRollback` con `.rollback`.
    @Test func forwardStepStalled_progressCeiling_appliesWithAnyCause() {
        for phase in Self.forwardStepPhases {
            for cause in [MarkerExportStall.unknown, .definitive] {
                #expect(step(phase, .forwardStepStalled(stalledSeconds: 259_199, causeStalledSeconds: 0, cause: cause)).next
                    == phase)
                let out = step(phase, .forwardStepStalled(stalledSeconds: 259_200, causeStalledSeconds: 0, cause: cause))
                #expect(out.next == .failedRollback, "\(phase) · \(cause)")
                #expect(out.effects == [.rollback], "antes del cutover el teléfono está intacto: solo `.rollback`")
            }
        }
    }

    /// El techo CORTO solo con una causa definitiva, y contra el reloj de la CAUSA, no el de avance.
    @Test func forwardStepStalled_causeCeiling_onlyWithADefinitiveCause() {
        for phase in Self.forwardStepPhases {
            #expect(step(phase, .forwardStepStalled(stalledSeconds: 0, causeStalledSeconds: 899, cause: .definitive)).next
                == phase)
            #expect(step(phase, .forwardStepStalled(stalledSeconds: 0, causeStalledSeconds: 900, cause: .definitive)).next
                == .failedRollback)
            #expect(step(phase, .forwardStepStalled(stalledSeconds: 0, causeStalledSeconds: 100_000, cause: .unknown)).next
                == phase, "sin causa definitiva no hay techo corto")
            #expect(step(phase, .forwardStepStalled(stalledSeconds: 10_800, causeStalledSeconds: 0, cause: .definitive)).next
                == phase, "tres horas de paso parado no se cobran contra el reloj de la causa")
        }
    }

    /// «Cancelar la activación» desde los tres: a `notStarted`, sin efectos.
    @Test func forwardStepCancelled_returnsToNotStarted_withNoEffects() {
        for phase in Self.forwardStepPhases {
            let out = step(phase, .forwardStepCancelled)
            #expect(out.next == .notStarted, "\(phase)")
            #expect(out.effects.isEmpty)
        }
    }

    /// Los dos eventos solo son legales desde los tres pasos. Desde `cutover(.serverConfirmed)` en adelante es a
    /// propósito: el backend ya estampó `migrated_at` y «el cutover jamás hace rollback».
    @Test func forwardStepEvents_areInvalidOutsideTheThreeSteps() {
        let events: [Event] = [
            .forwardStepStalled(stalledSeconds: 10_000_000, causeStalledSeconds: 10_000_000, cause: .definitive),
            .forwardStepCancelled,
        ]
        for phase in Self.allPhases where !Self.forwardStepPhases.contains(phase) {
            for event in events {
                #expect(MigrationStateMachine.transition(from: phase, event: event) == .invalid(from: phase, event: event),
                        "\(phase) + \(event) debe ser inválido")
            }
        }
    }

    /// Los números son la decisión de Jürgen del 2026-09-22: 15 min / 72 h, como la subida y la vuelta.
    @Test func forwardStepBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.forwardStepCauseBudgetSeconds == 900)
        #expect(MigrationPolicy.default.forwardStepProgressBudgetSeconds == 259_200)
    }

    // MARK: - El EFECTO del adopt (ticket `adopt-effect-retries-forever-with-no-ceiling`)

    /// Sale a `failedRollback` con `[.rollback]` con el primero de los dos techos, clavado con sus vecinos.
    @Test func adoptEffectStalled_leavesAtEitherCeiling() {
        let bajo: Event = .adoptEffectStalled(stalledSeconds: 259_199, definitiveStalledSeconds: 899)
        #expect(MigrationStateMachine.transition(from: .notStarted, event: bajo) == .invalid(from: .notStarted, event: bajo),
                "bajo presupuesto no es una transición: la espera la hace el runner sin evento, con el efecto pendiente")
        for event: Event in [
            .adoptEffectStalled(stalledSeconds: 0, definitiveStalledSeconds: 900),
            .adoptEffectStalled(stalledSeconds: 259_200, definitiveStalledSeconds: 0),
        ] {
            #expect(MigrationStateMachine.transition(from: .notStarted, event: event)
                    == .transition(next: .failedRollback, effects: [.rollback]), "\(event)")
        }
    }

    /// «Cancelar» desde el efecto pendiente: a `notStarted` sin efectos, que retira el pendiente.
    @Test func adoptEffectCancelled_returnsToNotStarted_withNoEffects() {
        #expect(MigrationStateMachine.transition(from: .notStarted, event: .adoptEffectCancelled)
                == .transition(next: .notStarted, effects: []))
    }

    /// Los dos solo son legales desde `notStarted`, la fase que el adopt journalea antes de su efecto.
    @Test func adoptEffectEvents_areInvalidOutsideNotStarted() {
        let events: [Event] = [
            .adoptEffectStalled(stalledSeconds: 10_000_000, definitiveStalledSeconds: 10_000_000),
            .adoptEffectCancelled,
        ]
        for phase in Self.allPhases where phase != .notStarted {
            for event in events {
                #expect(MigrationStateMachine.transition(from: phase, event: event) == .invalid(from: phase, event: event),
                        "\(phase) + \(event) debe ser inválido")
            }
        }
    }

    /// Los números son la decisión de Jürgen del 2026-09-23: 15 min / 72 h, como la ida y la vuelta.
    @Test func adoptEffectBudgets_defaultsArePinnedProductDecision() {
        #expect(MigrationPolicy.default.adoptEffectDefinitiveBudgetSeconds == 900)
        #expect(MigrationPolicy.default.adoptEffectProgressBudgetSeconds == 259_200)
    }
}
