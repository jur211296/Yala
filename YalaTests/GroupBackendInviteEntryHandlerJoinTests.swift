//
//  GroupBackendInviteEntryHandlerJoinTests.swift
//  YalaTests
//
//  C4/C5 (G6-2, DARK): `attemptJoin` LEE el `legacyMemberKey` del intent persistido y lo pasa al
//  `join_group` RPC (joinProvider mock). Serializado: toca los providers estáticos del handler +
//  `PendingJoinStore.defaults` + `GroupJoinIntentTracker.shared` (restaurados en el cleanup).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("GroupBackendInviteEntryHandler · join legacyMemberKey (DARK)", .serialized)
struct GroupBackendInviteEntryHandlerJoinTests {

    /// Caja de captura del `legacyMemberKey` recibido por el joinProvider (todo corre en el main actor).
    final class Capture {
        var called = false
        var legacyMemberKey: String?
    }

    private func makeEnv() -> () -> Void {
        let suite = "test.backendjoin.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        PendingJoinStore.defaults = d
        let savedJoin = GroupBackendInviteEntryHandler.joinProvider
        let savedProfile = GroupBackendInviteEntryHandler.profileNameProvider
        GroupJoinIntentTracker.shared.clear()
        return {
            GroupBackendInviteEntryHandler.joinProvider = savedJoin
            GroupBackendInviteEntryHandler.profileNameProvider = savedProfile
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suite)
            GroupJoinIntentTracker.shared.clear()
        }
    }

    /// El intent lleva `legacyMemberKey` (RE-JOIN de grupo migrado) → attemptJoin lo pasa al joinProvider.
    @Test func attemptJoin_passesLegacyMemberKeyFromIntent() async {
        let cleanup = makeEnv(); defer { cleanup() }
        let capture = Capture()
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.joinProvider = { _, _, legacy in
            capture.called = true
            capture.legacyMemberKey = legacy
            return JoinGroupResult(groupID: "G1", memberKey: "_legacyRec", status: "active", rebound: true)
        }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G1", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G1", inviteToken: "tok", legacyMemberKey: "_legacyRec"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G1", token: "tok", source: .userAction)

        #expect(capture.called)
        #expect(capture.legacyMemberKey == "_legacyRec")
    }

    /// Un join normal (intent sin `legacyMemberKey`) pasa `nil` al joinProvider — sin RE-JOIN.
    @Test func attemptJoin_nilLegacyMemberKey_whenIntentHasNone() async {
        let cleanup = makeEnv(); defer { cleanup() }
        let capture = Capture()
        GroupBackendInviteEntryHandler.profileNameProvider = { "Pia" }
        GroupBackendInviteEntryHandler.joinProvider = { _, _, legacy in
            capture.called = true
            capture.legacyMemberKey = legacy
            return JoinGroupResult(groupID: "G1", memberKey: "sub-uuid", status: "active", rebound: false)
        }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "G1", zoneOwnerName: "", displayName: "Pia",
            backendGroupID: "G1", inviteToken: "tok"))

        await GroupBackendInviteEntryHandler.attemptJoin(groupID: "G1", token: "tok", source: .userAction)

        #expect(capture.called)
        #expect(capture.legacyMemberKey == nil)
    }
}
