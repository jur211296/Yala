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

    // MARK: - shouldRepublishPhase (bug 2026-07-31: el banner pendiente no se retiraba)

    /// La mitad simétrica del invariante: con el member YA confirmado, la fase pendiente TIENE que moverse.
    @Test func republish_inFlightPhases_acceptTrackedZone() {
        let inFlight: [JoinIntentPhase] = [.accepting, .waitingForZone, .creatingMember, .pendingApproval]
        for phase in inFlight {
            #expect(Logic.shouldRepublishPhase(
                trackedPhase: phase, trackedZone: "zone-A", appliedZone: "zone-A"),
                "phase \(phase) debería re-publicar: es un join en vuelo sobre la zona trackeada")
        }
    }

    /// Terminales: `.active` la consume la vista y las `.failed` tienen salida propia (Retry / X). Republicar
    /// desde ellas movería una fase que ya nadie está esperando.
    @Test func republish_terminalPhases_never() {
        let terminal: [JoinIntentPhase] = [
            .active,
            .failed(.acceptFailed(recoverable: true)),
            .failed(.acceptFailed(recoverable: false)),
            .failed(.memberSaveFailed),
            .failed(.expired)
        ]
        for phase in terminal {
            #expect(!Logic.shouldRepublishPhase(
                trackedPhase: phase, trackedZone: "zone-A", appliedZone: "zone-A"),
                "phase terminal \(phase) NO debe re-publicarse")
        }
    }

    /// `.idle` es "no hay banner que retirar": tras un relanzamiento el tracker arranca ahí con el intent ya
    /// limpio, y publicar crearía un banner que nadie estaba mostrando.
    @Test func republish_idlePhase_neverResurrectsBanner() {
        #expect(!Logic.shouldRepublishPhase(
            trackedPhase: .idle, trackedZone: "zone-A", appliedZone: "zone-A"))
        // Sin zona trackeada tampoco, en NINGUNA fase (no hay join al que referirse).
        let all: [JoinIntentPhase] = [
            .idle, .accepting, .waitingForZone, .creatingMember, .pendingApproval, .active,
            .failed(.memberSaveFailed)
        ]
        for phase in all {
            #expect(!Logic.shouldRepublishPhase(
                trackedPhase: phase, trackedZone: nil, appliedZone: "zone-A"))
        }
    }

    /// Otra zona NO toca la fase: el pull entrega members de todos los grupos del usuario, y la aprobación
    /// de OTRO grupo no dice nada del join en curso.
    @Test func republish_otherZone_never() {
        let inFlight: [JoinIntentPhase] = [.accepting, .waitingForZone, .creatingMember, .pendingApproval]
        for phase in inFlight {
            #expect(!Logic.shouldRepublishPhase(
                trackedPhase: phase, trackedZone: "zone-A", appliedZone: "zone-B"),
                "phase \(phase) se movió por un member de otra zona")
        }
    }
}
