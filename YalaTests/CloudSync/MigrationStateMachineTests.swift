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

    @Test func reverseVerify_networkTimeout_belowCap_retriesVerify_atCap_failsRollback() {
        let policy = MigrationPolicy(maxMismatchRetries: 3, maxNetworkRetries: 8)
        for retries in 0..<policy.maxNetworkRetries {
            let r = step(.reverseVerify, .reverseVerifyOutcome(.networkTimeout(retriesSoFar: retries)), policy: policy)
            #expect(r.next == .reverseVerify, "reverse network timeout \(retries) must retry verify")
            #expect(r.effects.isEmpty)
        }
        let capped = step(.reverseVerify, .reverseVerifyOutcome(.networkTimeout(retriesSoFar: 8)), policy: policy)
        #expect(capped.next == .reverseFailedRollback)
        #expect(capped.effects == [.reverseRollback])
    }

    @Test func reverseVerify_newDelta_reRuns_doesNotConsumeRetry() {
        let r = step(.reverseVerify, .reverseVerifyOutcome(.newDeltaDetected))
        #expect(r.next == .reverseVerify)
        #expect(r.effects.isEmpty)
    }

    @Test func reverseVerify_countersIndependent_networkDoesNotConsumeMismatchBudget() {
        let policy = MigrationPolicy(maxMismatchRetries: 1, maxNetworkRetries: 8)
        #expect(step(.reverseVerify, .reverseVerifyOutcome(.networkTimeout(retriesSoFar: 7)), policy: policy).next
            == .reverseVerify)
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
}
