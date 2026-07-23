//
//  GroupExpenseServiceCurrentMemberTests.swift
//  YalaTests
//
//  Tests de `GroupExpenseService.selectCurrentUserMemberID` — la resolución del SplitMember.id del
//  usuario actual que el write-side estampa en lastEditedByMemberID/recordedByMemberID.
//
//  Regresión del hallazgo SERIO (review adversarial 2026-07-23): el write-side DEBE resolver el MISMO id
//  que el consumidor `GroupNotificationService.currentMemberID(inZone:)` (isCurrentUser con `joinedAt` más
//  antiguo). Un tie-break distinto (p.ej. `first(where:)` sobre el orden de `fetchMembers`) elegiría OTRO
//  id bajo members `isCurrentUser` DUPLICADOS → el eco no se autoexcluiría. También cubre el fallback por
//  identidad iCloud de la ventana temprana (isCurrentUser aún no marcado en 2º device / restore).
//
//  @Model directo sin contexto (regla R8: preferir @Model directo cuando la lógica lo permite).
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseServiceCurrentMemberTests {

    @MainActor
    private func member(id: UUID = UUID(), current: Bool = false, joined: Date, recordName: String = "") -> SplitMember {
        let m = SplitMember(cloudKitUserRecordID: recordName, isCurrentUser: current)
        m.id = id
        m.joinedAt = joined
        return m
    }

    // MARK: - Resolución canónica (tie-break del hallazgo SERIO)

    @Test @MainActor func duplicateIsCurrentUser_picksOldestJoinedAt_regardlessOfArrayOrder() {
        let older = UUID()
        let newer = UUID()
        // Orden de array: el más nuevo primero (como podría devolver fetchMembers por displayName).
        let members = [
            member(id: newer, current: true, joined: Date(timeIntervalSince1970: 200)),
            member(id: older, current: true, joined: Date(timeIntervalSince1970: 100)),
        ]
        // Canónico = joinedAt más antiguo, NO el primero del array. Espeja a currentMemberID(inZone:).
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: nil) == older.uuidString)
    }

    @Test @MainActor func singleIsCurrentUser_picksIt() {
        let mine = UUID()
        let members = [
            member(id: UUID(), current: false, joined: .now, recordName: "_other"),
            member(id: mine, current: true, joined: .now),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: nil) == mine.uuidString)
    }

    @Test @MainActor func isCurrentUser_preferredOverIdentityFallback() {
        let flagged = UUID()
        let members = [
            member(id: flagged, current: true, joined: .now, recordName: "_zzz"),
            member(id: UUID(), current: false, joined: .now, recordName: "_me"),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: "_me") == flagged.uuidString)
    }

    // MARK: - Fallback por identidad iCloud (ventana temprana)

    @Test @MainActor func noIsCurrentUser_fallsBackToICloudIdentity() {
        let mine = UUID()
        let members = [
            member(id: UUID(), current: false, joined: Date(timeIntervalSince1970: 100), recordName: "_other"),
            member(id: mine, current: false, joined: Date(timeIntervalSince1970: 200), recordName: "_me"),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: "_me") == mine.uuidString)
    }

    @Test @MainActor func identityFallback_duplicateMatches_picksOldest() {
        let older = UUID()
        let members = [
            member(id: UUID(), current: false, joined: Date(timeIntervalSince1970: 300), recordName: "_me"),
            member(id: older, current: false, joined: Date(timeIntervalSince1970: 100), recordName: "_me"),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: "_me") == older.uuidString)
    }

    @Test @MainActor func noIsCurrentUser_noOrEmptyIdentity_returnsNil() {
        let members = [member(id: UUID(), current: false, joined: .now, recordName: "_x")]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: nil) == nil)
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: "") == nil)
    }

    @Test @MainActor func noIsCurrentUser_identityNoMatch_returnsNil() {
        let members = [member(id: UUID(), current: false, joined: .now, recordName: "_other")]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: "_me") == nil)
    }
}
