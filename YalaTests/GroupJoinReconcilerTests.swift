//
//  GroupJoinReconcilerTests.swift
//  YalaTests
//
//  Integración SwiftData del reconciliador de join intents: asserta el
//  SplitMember REAL creado (id determinista, status, recordID, displayName) —
//  no solo que "no lanza" (lección d49d2e47). Serializado: makeTestContext
//  per-file + singletons (PendingJoinStore.defaults, GroupUserIdentityService,
//  GroupJoinIntentTracker).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("GroupJoinReconciler", .serialized)
struct GroupJoinReconcilerTests {

    private let ref = Date(timeIntervalSince1970: 1_700_000_000)
    private let recordName = "_testUserABC"

    /// Prepara defaults aislados + identidad cacheada + tracker limpio.
    /// Devuelve el cleanup.
    private func makeEnvironment() -> () -> Void {
        let suiteName = "test.joinreconciler.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suiteName)!
        PendingJoinStore.defaults = d
        GroupUserIdentityService.shared._testSetCachedRecordName(recordName)
        GroupJoinIntentTracker.shared.clear()
        return {
            PendingJoinStore.defaults = .standard
            d.removePersistentDomain(forName: suiteName)
            GroupUserIdentityService.shared._testSetCachedRecordName(nil)
            GroupJoinIntentTracker.shared.clear()
        }
    }

    private func makeInvitedGroup(in context: ModelContext, zoneName: String) -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zoneName
        group.cloudKitZoneOwnerName = "_ownerXYZ"
        group.isOwner = false
        context.insert(group)
        return group
    }

    private func fetchMembers(_ context: ModelContext, zoneName: String) throws -> [SplitMember] {
        try context.fetch(FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName }
        ))
    }

    // MARK: - Reconcile crea el member REAL

    @Test func reconcile_createsPendingMember_withFullContent() async throws {
        let cleanup = makeEnvironment(); defer { cleanup() }
        let context = try makeTestContext()
        let zoneName = "SplitGroup-\(UUID().uuidString)"
        let group = makeInvitedGroup(in: context, zoneName: zoneName)
        try context.save()

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: zoneName, zoneOwnerName: "_ownerXYZ",
            displayName: "Pia", createdAt: ref
        ))

        await GroupJoinReconciler.reconcile(
            trigger: .acceptShare,
            context: context,
            groupLookup: { $0 == zoneName ? group : nil },
            engineReady: { _ in true },
            now: ref
        )

        let members = try fetchMembers(context, zoneName: zoneName)
        #expect(members.count == 1)
        let member = try #require(members.first)
        // Contenido REAL del member (no solo "existe"):
        #expect(member.id == GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember", name: "\(zoneName):\(recordName)"))
        #expect(member.memberStatus == .pendingApproval)  // invitado, no owner
        #expect(member.cloudKitUserRecordID == recordName)
        #expect(member.isCurrentUser)
        #expect(member.displayName == "Pia")  // el displayName del intent aplicado
        // El intent quedó consumido.
        #expect(PendingJoinStore.entry(zoneName: zoneName, now: ref) == nil)
        // Y el tracker refleja la fase real.
        #expect(GroupJoinIntentTracker.shared.phase == .pendingApproval)
    }

    // MARK: - Idempotencia

    @Test func reconcile_secondPass_isIdempotent() async throws {
        let cleanup = makeEnvironment(); defer { cleanup() }
        let context = try makeTestContext()
        let zoneName = "SplitGroup-\(UUID().uuidString)"
        let group = makeInvitedGroup(in: context, zoneName: zoneName)
        try context.save()

        for _ in 0..<2 {
            PendingJoinStore.save(PendingJoinEntry(
                zoneName: zoneName, zoneOwnerName: "_ownerXYZ", createdAt: ref
            ))
            await GroupJoinReconciler.reconcile(
                trigger: .acceptShare,
                context: context,
                groupLookup: { $0 == zoneName ? group : nil },
                engineReady: { _ in true },
                now: ref
            )
        }

        let members = try fetchMembers(context, zoneName: zoneName)
        #expect(members.count == 1)
    }

    // MARK: - Zona ausente: intent intacto, cero members

    @Test func reconcile_groupNotLocal_keepsIntentAndCreatesNothing() async throws {
        let cleanup = makeEnvironment(); defer { cleanup() }
        let context = try makeTestContext()
        let zoneName = "SplitGroup-\(UUID().uuidString)"

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: zoneName, zoneOwnerName: "_ownerXYZ", createdAt: ref
        ))

        await GroupJoinReconciler.reconcile(
            trigger: .acceptShare,
            context: context,
            groupLookup: { _ in nil },
            engineReady: { _ in true },
            now: ref
        )

        #expect(try fetchMembers(context, zoneName: zoneName).isEmpty)
        // El intent sobrevive para el próximo trigger.
        #expect(PendingJoinStore.entry(zoneName: zoneName, now: ref) != nil)
        // El tracker quedó rehidratado en espera de zona.
        #expect(GroupJoinIntentTracker.shared.phase == .waitingForZone)
    }

    // MARK: - Engine nil: intent intacto (el enqueue sería un drop)

    @Test func reconcile_engineNotReady_keepsIntent() async throws {
        let cleanup = makeEnvironment(); defer { cleanup() }
        let context = try makeTestContext()
        let zoneName = "SplitGroup-\(UUID().uuidString)"
        let group = makeInvitedGroup(in: context, zoneName: zoneName)
        try context.save()

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: zoneName, zoneOwnerName: "_ownerXYZ", createdAt: ref
        ))

        await GroupJoinReconciler.reconcile(
            trigger: .acceptShare,
            context: context,
            groupLookup: { $0 == zoneName ? group : nil },
            engineReady: { _ in false },
            now: ref
        )

        #expect(try fetchMembers(context, zoneName: zoneName).isEmpty)
        #expect(PendingJoinStore.entry(zoneName: zoneName, now: ref) != nil)
    }

    // MARK: - Anti-pisado del displayName

    @Test func reconcile_existingRenamedMember_keepsManualName() async throws {
        let cleanup = makeEnvironment(); defer { cleanup() }
        let context = try makeTestContext()
        let zoneName = "SplitGroup-\(UUID().uuidString)"
        let group = makeInvitedGroup(in: context, zoneName: zoneName)
        // Member preexistente con rename manual.
        let member = SplitMember(
            groupZoneID: zoneName,
            displayName: "Pia Renombrada",
            cloudKitUserRecordID: recordName,
            role: "member",
            status: .active,
            isCurrentUser: true
        )
        context.insert(member)
        try context.save()

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: zoneName, zoneOwnerName: "_ownerXYZ",
            displayName: "Pia", createdAt: ref
        ))

        await GroupJoinReconciler.reconcile(
            trigger: .acceptShare,
            context: context,
            groupLookup: { $0 == zoneName ? group : nil },
            engineReady: { _ in true },
            now: ref
        )

        let members = try fetchMembers(context, zoneName: zoneName)
        #expect(members.count == 1)
        // El rename manual NO fue pisado por el displayName del intent.
        #expect(members.first?.displayName == "Pia Renombrada")
        // Member activo → tracker en fase active y el intent consumido.
        #expect(PendingJoinStore.entry(zoneName: zoneName, now: ref) == nil)
    }
}
