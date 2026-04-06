//
//  GroupServiceTests.swift
//  YalaTests
//
//  Unit tests for GroupService validation logic and error types.
//

import Foundation
import Testing

@testable import Yala

struct GroupServiceTests {

    // MARK: - Error Descriptions

    @Test func error_noContext_hasDescription() {
        let error = GroupServiceError.noContext
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("No ModelContext"))
    }

    @Test func error_emptyName_hasDescription() {
        let error = GroupServiceError.emptyName
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("name"))
    }

    @Test func error_emptyMemberName_hasDescription() {
        let error = GroupServiceError.emptyMemberName
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Member name"))
    }

    @Test func error_invalidRole_hasDescription() {
        let error = GroupServiceError.invalidRole
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("admin"))
    }

    @Test func error_notOwner_hasDescription() {
        let error = GroupServiceError.notOwner
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("owner"))
    }

    @Test func error_ownerCannotLeave_hasDescription() {
        let error = GroupServiceError.ownerCannotLeave
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("delete"))
    }

    @Test func error_lastAdmin_hasDescription() {
        let error = GroupServiceError.lastAdmin
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("last admin"))
    }

    @Test func error_saveFailed_includesUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42)
        let error = GroupServiceError.saveFailed(underlying)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Save failed"))
    }

    // MARK: - Singleton

    @Test func singleton_isSameInstance() {
        let a = GroupService.shared
        let b = GroupService.shared
        #expect(a === b)
    }

    // MARK: - SplitGroup Model

    @Test func splitGroup_initSetsCloudKitZoneID() {
        let group = SplitGroup(name: "Test")
        #expect(group.cloudKitZoneID.hasPrefix("SplitGroup-"))
        #expect(group.cloudKitZoneID.contains(group.id.uuidString))
    }

    @Test func splitGroup_defaultValues() {
        let group = SplitGroup()
        #expect(group.isOwner == false)
        #expect(group.isArchived == false)
        #expect(group.autoCreateTransaction == true)
        #expect(group.simplifyDebts == false)
        #expect(group.currencyCode == "PEN")
    }
}
