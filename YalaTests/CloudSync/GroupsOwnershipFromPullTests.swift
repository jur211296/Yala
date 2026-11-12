//
//  GroupsOwnershipFromPullTests.swift
//  YalaTests / CloudSync
//
//  Card y1cd («siempre un admin tras crear o wipe»): el pull de Grupos trae `owned_groups` y el cliente corrige con él
//  `isOwner` (grupo) e `isGroupOwner` (el miembro propio), que son LOCALES y el pull no escribía. El caso de origen
//  (2026-10-27): el dueño de «Matri» borró su cuenta, el servidor pasó la propiedad a Pia y la hizo admin, y el teléfono de
//  Pia seguía sin «Invitar» (invitar exige `group.isOwner`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · Grupos · quién es dueño según el pull (y1cd)", .serialized)
@MainActor
struct GroupsOwnershipFromPullTests {

    private let pia = "sub-pia"

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsOwnership-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupsOwnershipFromPullTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GOP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GOP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GOP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    private struct Fixture {
        let group: SplitGroup
        let me: SplitMember
        let other: SplitMember
    }

    /// Lo que deja el pull en el teléfono de Pia: el grupo (sin `isOwner`), su miembro admin (con su `sub`, sin las
    /// marcas locales) y el de quien se borró.
    private func seed(_ context: ModelContext, zone: String = "SplitGroup-MATRI", isOwner: Bool = false) throws -> Fixture {
        let group = SplitGroup(name: "Matri", isOwner: isOwner)
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        let me = SplitMember(groupZoneID: zone, displayName: "Pia", cloudKitUserRecordID: "", role: "admin",
                             status: .active, isGroupOwner: isOwner, isCurrentUser: false)
        me.memberKey = pia
        me.userID = pia
        context.insert(me)
        let other = SplitMember(groupZoneID: zone, displayName: "__deleted_user__", cloudKitUserRecordID: "",
                                role: "admin", status: .removed, isGroupOwner: true, isCurrentUser: false)
        other.memberKey = "sub-jurgen"
        context.insert(other)
        try context.save()
        return Fixture(group: group, me: me, other: other)
    }

    private func client() -> GroupsSyncClient {
        GroupsSyncClient(currentUserIDProvider: { [pia] in pia }, outboxMirror: nil)
    }

    private func page(memberships: [String]?, owned: [String]?) -> GroupPulledPage {
        GroupPulledPage(deltas: [], cursors: [:], memberships: memberships, ownedGroups: owned)
    }

    @Test("la propiedad heredada por el servidor llega: el grupo y el miembro propio pasan a dueño")
    func inheritedOwnership_isApplied() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context)
        client().reconcileOwnership(page(memberships: ["SplitGroup-MATRI"], owned: ["SplitGroup-MATRI"]), context: context)
        #expect(f.group.isOwner, "Pia sigue sin poder invitar a un grupo que ya es suyo")
        #expect(f.me.isGroupOwner)
        #expect(f.other.isGroupOwner, "la marca de otro miembro no es de este pull: no se toca")
        #expect(!context.hasChanges, "la corrección no quedó guardada")
    }

    @Test("la propiedad cedida también llega: deja de ser dueño")
    func cededOwnership_isApplied() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context, isOwner: true)
        client().reconcileOwnership(page(memberships: ["SplitGroup-MATRI"], owned: []), context: context)
        #expect(!f.group.isOwner)
        #expect(!f.me.isGroupOwner)
    }

    /// Review adversarial: la fila de otra cuenta que estuvo antes en el teléfono puede conservar `isCurrentUser` hasta que
    /// la refresque `GroupService`; con sesión, el miembro propio se casa SOLO por su `sub`.
    @Test("con sesión, la fila de otra cuenta marcada como propia no hereda la propiedad")
    func anotherAccountsRow_isNotTouched() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context)
        f.other.isCurrentUser = true
        f.other.isGroupOwner = false
        try context.save()
        client().reconcileOwnership(page(memberships: ["SplitGroup-MATRI"], owned: ["SplitGroup-MATRI"]), context: context)
        #expect(f.me.isGroupOwner)
        #expect(!f.other.isGroupOwner, "otra cuenta quedó como dueña de un grupo que no es suyo")
    }

    @Test("un Worker que no manda owned_groups no toca nada")
    func olderWorker_touchesNothing() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context, isOwner: true)
        client().reconcileOwnership(page(memberships: ["SplitGroup-MATRI"], owned: nil), context: context)
        #expect(f.group.isOwner)
        #expect(f.me.isGroupOwner)
    }

    @Test("un grupo que no está en memberships no se toca: el pull no dice nada de él")
    func groupOutsideMemberships_isUntouched() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context, isOwner: true)
        client().reconcileOwnership(page(memberships: ["SplitGroup-OTRO"], owned: []), context: context)
        #expect(f.group.isOwner)
    }

    @Test("la página ociosa también corrige: owned_groups viaja en todas las páginas")
    func idlePage_reconcilesToo() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let f = try seed(context)
        let client = client()
        let cursor = try client.loadOrCreateCursor(context)
        #expect(client.applyPulledPage(page(memberships: ["SplitGroup-MATRI"], owned: ["SplitGroup-MATRI"]),
                                       cursor: cursor, context: context))
        #expect(f.group.isOwner)
    }

    @Test("decodePage lee owned_groups, y su ausencia es nil (no «ninguno»)")
    func decodePage_readsOwnedGroups() throws {
        let with = try GroupsSyncClient.decodePage(Data(
            #"{"deltas":[],"cursors":{},"memberships":["g"],"owned_groups":["g"],"manifest_version":2}"#.utf8))
        #expect(with.ownedGroups == ["g"])
        let without = try GroupsSyncClient.decodePage(Data(#"{"deltas":[],"cursors":{},"memberships":["g"]}"#.utf8))
        #expect(without.ownedGroups == nil)
    }
}
