//
//  GroupExpenseEligibilityLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupExpenseEligibilityLogic.canCreateExpense`:
//  decide si el current user puede abrir un form de gasto USABLE para un grupo
//  (usado por el composer "Nuevo gasto" del FAB del tab Grupos).
//
//  Sin SwiftUI, sin SwiftData, sin singletons, sin `makeTestContext()` — evita
//  flake R8 conocido.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct GroupExpenseEligibilityLogicTests {

    @Test func activeMemberCanCreate() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == true)
    }

    @Test func pendingApprovalCannotCreate() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .pendingApproval, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
    }

    @Test func rejectedCannotCreate() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .rejected, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
    }

    @Test func leftOrRemovedCannotCreate() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .left, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .removed, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
    }

    /// Owner cuyo SplitMember aún no sincronizó (cold start/restore): status nil → NO
    /// elegible. Abrir el form sería inutilizable (sin paidBy/miembros). Se excluye
    /// hasta que el member llegue por sync.
    @Test func nilStatusCannotCreate() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: nil, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
    }

    @Test func archivedNeverEligible() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: true, isHiddenForAll: false, isMigratedFrozen: false
        ) == false)
    }

    @Test func hiddenForAllNeverEligible() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: false, isHiddenForAll: true, isMigratedFrozen: false
        ) == false)
    }

    /// H-2026-07-18-2: grupo congelado tras migrar al backend — el save lanzaría
    /// `GroupExpenseServiceError.movedToBackend` SIEMPRE, así que no debe ofrecerse en el
    /// picker de "Nuevo gasto" pese a que el current user sea miembro `.active`.
    @Test func migratedFrozenNeverEligible() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: false, isHiddenForAll: false, isMigratedFrozen: true
        ) == false)
    }

    /// El freeze gana aunque todo lo demás sea elegible; y no-frozen conserva el comportamiento
    /// actual (miembro `.active` sin flags → elegible).
    @Test func migratedFrozenGatesOverActiveMember() {
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: false, isHiddenForAll: false, isMigratedFrozen: false
        ) == true)
        #expect(GroupExpenseEligibilityLogic.canCreateExpense(
            currentMemberStatus: .active, isArchived: false, isHiddenForAll: false, isMigratedFrozen: true
        ) == false)
    }
}
