//
//  GroupBackendIdentityLogicTests.swift
//  YalaTests / CloudSync
//
//  Lógica PURA de identidad del canal Grupos → backend (incremento G3, DARK). Sin contexto, sin
//  singletons, sin CloudKit → no requiere `.serialized`.
//

import Foundation
import Testing

@testable import Yala

@Suite("GroupBackendIdentityLogic · identidad backend (DARK)")
struct GroupBackendIdentityLogicTests {

    // MARK: - deterministicMemberID

    @Test func memberID_isStable_forSameInputs() {
        let a = GroupBackendIdentityLogic.deterministicMemberID(groupID: "SplitGroup-A", memberKey: "member-1")
        let b = GroupBackendIdentityLogic.deterministicMemberID(groupID: "SplitGroup-A", memberKey: "member-1")
        #expect(a == b)
    }

    @Test func memberID_differs_perGroupAndPerMember() {
        let base = GroupBackendIdentityLogic.deterministicMemberID(groupID: "SplitGroup-A", memberKey: "member-1")
        let otherGroup = GroupBackendIdentityLogic.deterministicMemberID(groupID: "SplitGroup-B", memberKey: "member-1")
        let otherMember = GroupBackendIdentityLogic.deterministicMemberID(groupID: "SplitGroup-A", memberKey: "member-2")
        #expect(base != otherGroup)
        #expect(base != otherMember)
        #expect(otherGroup != otherMember)
    }

    /// NAMESPACE NUEVO: para los MISMOS inputs, el id backend NO colisiona con el id del path CloudKit
    /// (namespace `"SplitMember"`, `GroupUserIdentityService.deterministicUUID`). Prueba que el canal
    /// re-deriva su identidad de su propia autoridad y no reusa la CloudKit.
    @Test func memberID_distinctFromCloudKitNamespace_forSameInputs() {
        let group = "SplitGroup-A"
        let key = "member-1"
        let backend = GroupBackendIdentityLogic.deterministicMemberID(groupID: group, memberKey: key)
        // Espejo EXACTO de lo que produce el path CloudKit vigente (namespace "SplitMember").
        let cloudKit = GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember", name: "\(group):\(key)")
        #expect(backend != cloudKit)
    }

    // MARK: - isCurrentUser (nil-safe, case-insensitive)

    @Test func isCurrentUser_matchesCaseInsensitively() {
        #expect(GroupBackendIdentityLogic.isCurrentUser(
            memberUserID: "ABC-123", currentUserID: "abc-123"))
        #expect(GroupBackendIdentityLogic.isCurrentUser(
            memberUserID: "abc-123", currentUserID: "abc-123"))
    }

    @Test func isCurrentUser_falseForDifferentIDs() {
        #expect(!GroupBackendIdentityLogic.isCurrentUser(
            memberUserID: "abc-123", currentUserID: "def-456"))
    }

    @Test func isCurrentUser_nilSafe_neverMatchesOnMissingIdentity() {
        #expect(!GroupBackendIdentityLogic.isCurrentUser(memberUserID: nil, currentUserID: "abc"))
        #expect(!GroupBackendIdentityLogic.isCurrentUser(memberUserID: "abc", currentUserID: nil))
        #expect(!GroupBackendIdentityLogic.isCurrentUser(memberUserID: nil, currentUserID: nil))
        #expect(!GroupBackendIdentityLogic.isCurrentUser(memberUserID: "", currentUserID: "abc"))
        #expect(!GroupBackendIdentityLogic.isCurrentUser(memberUserID: "abc", currentUserID: ""))
    }

    // MARK: - isLegacyMemberKey (R10, C1) — discriminador namespace-aware

    /// Un `sub` del backend SIEMPRE parsea UUID → NO es legacy (deriva en el namespace propio del canal).
    @Test func isLegacyMemberKey_falseForSubUUID() {
        #expect(!GroupBackendIdentityLogic.isLegacyMemberKey("11111111-1111-1111-1111-111111111111"))
        // UUID(uuidString:) es case-insensitive → un UUID en MAYÚSCULAS tampoco es legacy.
        #expect(!GroupBackendIdentityLogic.isLegacyMemberKey("ABCDEF01-2345-6789-ABCD-EF0123456789"))
    }

    /// Un recordName de CloudKit (`"_…"`) JAMÁS parsea UUID → ES legacy (namespace CloudKit-era).
    @Test func isLegacyMemberKey_trueForCloudKitRecordName() {
        #expect(GroupBackendIdentityLogic.isLegacyMemberKey("_recordName123"))
        #expect(GroupBackendIdentityLogic.isLegacyMemberKey("not-a-uuid"))
    }

    /// Guards defensivos: vacío y el sentinel de cuenta-eliminada NUNCA son legacy (el sentinel jamás llega
    /// por `member_key` — verificado en DDL; guard defensivo por si el campo cambiara).
    @Test func isLegacyMemberKey_falseForEmptyAndSentinel() {
        #expect(!GroupBackendIdentityLogic.isLegacyMemberKey(""))
        #expect(!GroupBackendIdentityLogic.isLegacyMemberKey(SplitMember.deletedUserSentinel))
    }
}
