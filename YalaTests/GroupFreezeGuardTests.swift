//
//  GroupFreezeGuardTests.swift
//  YalaTests
//
//  G6-3 (C6): el guard service-level `validateGroupIsWritable` (RED de correctness) lanza para un grupo
//  congelado, NO bloquea al owner migrado, y es byte-idéntico (no lanza) para un grupo sin marcador (flag OFF).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupFreezeGuardTests {

    private func frozenMemberGroup() -> SplitGroup {
        let g = SplitGroup(name: "Frozen")
        g.isOwner = false
        g.movedToBackendAt = .now
        g.isBackendGroup = false
        g.ckSystemFieldsData = Data([0x01])
        return g
    }

    private func adoptedOwnerGroup() -> SplitGroup {
        let g = SplitGroup(name: "Adopted")
        g.isOwner = true
        g.movedToBackendAt = .now
        g.isBackendGroup = true          // owner ya adoptó → sus writes van al backend, NO congelado
        g.ckSystemFieldsData = Data([0x01])
        return g
    }

    private func normalGroup() -> SplitGroup {
        let g = SplitGroup(name: "Normal")
        g.isOwner = true
        // movedToBackendAt == nil → jamás congelado (flag OFF byte-idéntico)
        return g
    }

    // MARK: - GroupService

    @Test func groupService_throwsForFrozen() {
        #expect(throws: GroupServiceError.self) {
            try GroupService.shared.validateGroupIsWritable(frozenMemberGroup())
        }
    }

    @Test func groupService_doesNotThrowForAdoptedOwner() throws {
        try GroupService.shared.validateGroupIsWritable(adoptedOwnerGroup())
    }

    @Test func groupService_doesNotThrowForNormalGroup() throws {
        try GroupService.shared.validateGroupIsWritable(normalGroup())
    }

    // MARK: - GroupExpenseService

    @Test func expenseService_throwsForFrozen() {
        #expect(throws: GroupExpenseServiceError.self) {
            try GroupExpenseService.shared.validateGroupIsWritable(frozenMemberGroup())
        }
    }

    @Test func expenseService_doesNotThrowForAdoptedOwner() throws {
        try GroupExpenseService.shared.validateGroupIsWritable(adoptedOwnerGroup())
    }

    @Test func expenseService_doesNotThrowForNormalGroup() throws {
        try GroupExpenseService.shared.validateGroupIsWritable(normalGroup())
    }
}
