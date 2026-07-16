//
//  GroupCardDisplayLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para `GroupCardDisplayLogic.displayMode`. Sin SwiftData
//  ni ModelContext — verifica solo la decisión basada en `SplitMemberStatus`.
//

import Foundation
import Testing

@testable import Yala

struct GroupCardDisplayLogicTests {

    @Test func displayMode_returnsPendingApproval_whenStatusIsPendingApproval() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .pendingApproval) == .pendingApproval)
    }

    @Test func displayMode_returnsRejected_whenStatusIsRejected() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .rejected) == .rejected)
    }

    @Test func displayMode_returnsActive_whenStatusIsActive() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .active) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsNil() {
        // Caso: current user no tiene SplitMember en el grupo (ej. owner pre-A0).
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: nil) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsLeft() {
        // Caso edge: defensa-en-profundidad. El filtro upstream debería evitar
        // mostrar cards de members .left, pero si llegan, no bloquear navegación.
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .left) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsRemoved() {
        // Caso edge: similar a .left.
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .removed) == .active)
    }

    // MARK: - G6-3: migratedFrozen

    @Test func displayMode_returnsMigratedFrozen_whenFrozen() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .active, isMigratedFrozen: true) == .migratedFrozen)
    }

    @Test func displayMode_migratedFrozen_hasPriorityOverStatus() {
        // El freeze gana sobre pending/rejected (un grupo migrado ya no acepta la interacción normal).
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .pendingApproval, isMigratedFrozen: true) == .migratedFrozen)
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .rejected, isMigratedFrozen: true) == .migratedFrozen)
    }

    @Test func displayMode_notFrozen_fallsThroughToStatus() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .active, isMigratedFrozen: false) == .active)
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .pendingApproval, isMigratedFrozen: false) == .pendingApproval)
    }
}

// MARK: - G6-3: GroupFreezeLogic

struct GroupFreezeLogicTests {

    @Test func member_isFrozen_whenMarkerSetAndNotBackend() {
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: false, hasCKSystemFields: true) == true)
    }

    @Test func notFrozen_whenMarkerNil() {
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: nil, isBackendGroup: false, isOwner: false, hasCKSystemFields: true) == false)
    }

    @Test func owner_notFrozen_whenAdopted() {
        // Owner ya adoptado (isBackendGroup=true) → nunca congelado (sus writes van al backend).
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: .now, isBackendGroup: true, isOwner: true, hasCKSystemFields: true) == false)
    }

    @Test func owner_reinstallMitigation_notFrozen() {
        // Mitigación #9: owner que perdió isBackendGroup (LOCAL-only) en un reinstall pero conserva
        // movedToBackendAt (viaja) + ckSystemFieldsData → NO congelado (el pull re-adopta).
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true, hasCKSystemFields: true) == false)
    }

    @Test func owner_withoutCKSystemFields_frozen() {
        // Owner sin ckSystemFieldsData → la mitigación NO aplica (borde teórico).
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: .now, isBackendGroup: false, isOwner: true, hasCKSystemFields: false) == true)
    }

    @Test func bornBackend_neverFrozen() {
        // H5 review: un grupo born-backend (isBackendGroup=true, jamás vivió en CloudKit) NUNCA se congela,
        // aunque un estado imposible le pusiera el marcador.
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: nil, isBackendGroup: true, isOwner: false, hasCKSystemFields: false) == false)
        #expect(GroupFreezeLogic.isFrozen(
            movedToBackendAt: .now, isBackendGroup: true, isOwner: false, hasCKSystemFields: false) == false)
    }
}
