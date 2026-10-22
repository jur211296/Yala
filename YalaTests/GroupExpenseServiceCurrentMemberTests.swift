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
    private func member(
        id: UUID = UUID(), current: Bool = false, joined: Date, recordName: String = "",
        userID: String? = nil, memberKey: String? = nil
    ) -> SplitMember {
        let m = SplitMember(cloudKitUserRecordID: recordName, isCurrentUser: current)
        m.id = id
        m.joinedAt = joined
        m.userID = userID
        m.memberKey = memberKey
        return m
    }

    private static let sub = "11111111-1111-1111-1111-111111111111"

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

    // MARK: - Fallback por identidad del canal BACKEND (2.6)

    /// El hueco que cierra 2.6: `GroupsSyncClient.applyMember` NUNCA setea `isCurrentUser` y los members
    /// born-backend llevan `cloudKitUserRecordID` vacío por diseño ⇒ los DOS criterios anteriores fallaban
    /// y el write-side guardaba nil (el eco de la propia edición no se autoexcluía).
    @Test @MainActor func backendIdentity_resolvesWhenIsCurrentUserIsOffAndICloudIsAbsent() {
        let mine = UUID()
        let members = [
            member(id: UUID(), current: false, joined: Date(timeIntervalSince1970: 100), userID: "other-sub"),
            member(id: mine, current: false, joined: Date(timeIntervalSince1970: 200), userID: Self.sub),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: Self.sub) == mine.uuidString)
    }

    /// `memberKey == sub` es el otro lado del match (para un member propio ambos son el sub), y la
    /// comparación es case-insensitive — paridad con `backendMemberMatchesCurrentUser`.
    @Test @MainActor func backendIdentity_matchesByMemberKey_caseInsensitive() {
        let mine = UUID()
        let members = [member(id: mine, current: false, joined: .now, memberKey: Self.sub.uppercased())]
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: Self.sub) == mine.uuidString)
    }

    /// Canal apagado (kill remoto) o sin sesión de nube ⇒ el callsite pasa `currentUserID: nil` ⇒ el
    /// criterio backend no matchea NADA y la función es byte-idéntica a la de antes de 2.6.
    @Test @MainActor func backendIdentity_nilCurrentUserID_matchesNothing() {
        let members = [member(id: UUID(), current: false, joined: .now, userID: Self.sub, memberKey: Self.sub)]
        #expect(GroupExpenseService.selectCurrentUserMemberID(from: members, cachedRecordName: nil) == nil)
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: "") == nil)
    }

    /// `isCurrentUser` conserva la PRIMERA posición: es lo que mantiene la simetría con
    /// `GroupNotificationService.currentMemberID(inZone:)`, que resuelve SOLO por ese flag.
    @Test @MainActor func isCurrentUser_stillWinsOverBackendIdentity() {
        let flagged = UUID()
        let members = [
            member(id: flagged, current: true, joined: .now),
            member(id: UUID(), current: false, joined: .now, userID: Self.sub),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: Self.sub) == flagged.uuidString)
    }

    /// Entre los dos fallbacks manda el backend: en un grupo del canal nuevo la identidad autoritativa es
    /// el `sub`, no el record-name del Apple ID (que puede haber cambiado sin que eso signifique nada).
    @Test @MainActor func backendIdentity_preferredOverICloudFallback() {
        let backendMine = UUID()
        let members = [
            member(id: UUID(), current: false, joined: .now, recordName: "_me"),
            member(id: backendMine, current: false, joined: .now, userID: Self.sub),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: "_me", currentUserID: Self.sub) == backendMine.uuidString)
    }

    /// Mismo tie-break determinista que los otros dos criterios: `joinedAt` más antiguo, no el orden del
    /// array. Un tie-break distinto por criterio reabriría el hallazgo SERIO de la cabecera.
    @Test @MainActor func backendIdentity_duplicateMatches_picksOldest() {
        let older = UUID()
        let members = [
            member(id: UUID(), current: false, joined: Date(timeIntervalSince1970: 300), userID: Self.sub),
            member(id: older, current: false, joined: Date(timeIntervalSince1970: 100), memberKey: Self.sub),
        ]
        #expect(GroupExpenseService.selectCurrentUserMemberID(
            from: members, cachedRecordName: nil, currentUserID: Self.sub) == older.uuidString)
    }
}
