//
//  GroupInviteOnboardingLogicTests.swift
//  YalaTests
//
//  Pure-logic del step del onboarding de invitación (espejo de
//  GroupsOnboardingLogicTests). Invariante central: JAMÁS `.active` sin
//  `phase == .active` — LA regresión del bug "¡Todo listo!" falso.
//

import Foundation
import Testing

@testable import Yala

struct GroupInviteOnboardingLogicTests {

    private typealias Logic = GroupInviteOnboardingLogic

    // MARK: - welcome gana antes del tap

    @Test func beforeTap_alwaysWelcome() {
        let phases: [JoinIntentPhase] = [
            .idle, .accepting, .waitingForZone, .creatingMember,
            .pendingApproval, .active, .failed(.memberSaveFailed)
        ]
        for phase in phases {
            #expect(Logic.step(hasTappedJoin: false, phase: phase, hitSoftTimeout: false) == .welcome)
            #expect(Logic.step(hasTappedJoin: false, phase: phase, hitSoftTimeout: true) == .welcome)
        }
    }

    // MARK: - fases en progreso

    @Test func inProgressPhases_showJoining_beforeTimeout() {
        let inProgress: [JoinIntentPhase] = [.idle, .accepting, .waitingForZone, .creatingMember]
        for phase in inProgress {
            #expect(Logic.step(hasTappedJoin: true, phase: phase, hitSoftTimeout: false) == .joining)
        }
    }

    @Test func inProgressPhases_showTakingLong_afterTimeout() {
        let inProgress: [JoinIntentPhase] = [.idle, .accepting, .waitingForZone, .creatingMember]
        for phase in inProgress {
            #expect(Logic.step(hasTappedJoin: true, phase: phase, hitSoftTimeout: true) == .takingLong)
        }
    }

    // MARK: - terminales dominan el timeout (monotonía)

    @Test func terminalPhases_dominateTimeout() {
        #expect(Logic.step(hasTappedJoin: true, phase: .pendingApproval, hitSoftTimeout: true) == .pendingApproval)
        #expect(Logic.step(hasTappedJoin: true, phase: .active, hitSoftTimeout: true) == .active)
        #expect(Logic.step(
            hasTappedJoin: true,
            phase: .failed(.acceptFailed(recoverable: true)),
            hitSoftTimeout: true) == .failed(.acceptFailed(recoverable: true)))
    }

    // MARK: - Invariante del bug: jamás .active sin phase == .active

    @Test func neverActive_withoutActivePhase() {
        let nonActive: [JoinIntentPhase] = [
            .idle, .accepting, .waitingForZone, .creatingMember,
            .pendingApproval,
            .failed(.acceptFailed(recoverable: false)),
            .failed(.memberSaveFailed),
            .failed(.expired)
        ]
        for phase in nonActive {
            for timeout in [false, true] {
                let step = Logic.step(hasTappedJoin: true, phase: phase, hitSoftTimeout: timeout)
                #expect(step != .active, "phase \(phase) timeout \(timeout) produjo .active")
            }
        }
    }

    @Test func activePhase_showsActive() {
        #expect(Logic.step(hasTappedJoin: true, phase: .active, hitSoftTimeout: false) == .active)
    }

    // MARK: - failed muestra la razón

    @Test func failedPhase_propagatesReason() {
        #expect(Logic.step(
            hasTappedJoin: true, phase: .failed(.memberSaveFailed),
            hitSoftTimeout: false) == .failed(.memberSaveFailed))
        #expect(Logic.step(
            hasTappedJoin: true, phase: .failed(.expired),
            hitSoftTimeout: false) == .failed(.expired))
    }

    // MARK: - shouldClearPendingInvite

    @Test func clearPolicy_keepsInviteOnlyForRecoverableAbandon() {
        #expect(Logic.shouldClearPendingInvite(outcome: .joined))
        #expect(Logic.shouldClearPendingInvite(outcome: .pendingApproval))
        #expect(Logic.shouldClearPendingInvite(outcome: .closedWhileSyncing))
        #expect(Logic.shouldClearPendingInvite(outcome: .abandonedAfterFailure(recoverable: false)))
        // Recuperable → conservar para que el re-emit de foreground reintente.
        #expect(!Logic.shouldClearPendingInvite(outcome: .abandonedAfterFailure(recoverable: true)))
    }
}
