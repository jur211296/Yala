//
//  CompartidoMarcaPersonaTests.swift
//  YalaTests
//
//  Lote 1 de Compartido (26-nov-2026, esquema aprobado por Jürgen): una persona es un grupo de dos con la marca
//  `SplitGroup.isPerson`, que viaja como `split_groups.is_person` desde la v4 del manifiesto de Grupos. Aquí: que la
//  columna sale del emisor solo desde v4 (un Worker v3 no la recibe), que el pull la aplica por presencia de la clave
//  y que la lista de Personas nombra «Sin grupo» lo que se comparte en una persona marcada.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite("Compartido · la marca de persona viaja en v4", .serialized)
@MainActor
struct CompartidoMarcaPersonaTests {

    @Test("La v4 estrena is_person en split_groups, y su since vive en la capacidad, no en el emisor")
    func versionAndSince() {
        #expect(GroupsSyncCapability.clientManifestVersion == 4)
        #expect(GroupsSyncCapability.personSince == 4)
        #expect(GroupsSyncCapability.since(table: "split_groups", column: "is_person") == 4)
        #expect(GroupEntityEmissionMap.splitGroup.emitters.contains { $0.column == "is_person" })
        #expect(GroupEntityEmissionMap.splitGroup.columnKeyPaths[\SplitGroup.isPerson] == ["is_person"])
    }

    @Test("Contra un Worker v3 la marca no se emite ni se hashea; desde v4, sí")
    func prunedBelowV4() {
        let v3 = GroupsSyncCapability.emission(GroupEntityEmissionMap.splitGroup, upTo: 3)
        let v4 = GroupsSyncCapability.emission(GroupEntityEmissionMap.splitGroup, upTo: 4)
        #expect(!v3.emitters.contains { $0.column == "is_person" })
        #expect(v3.emitters.contains { $0.column == "budget_limit_amount" })
        #expect(v4.emitters.contains { $0.column == "is_person" })
    }

    @Test("El pull aplica la marca cuando viene, y sin la clave no la toca")
    func pullAppliesTheMark() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CompartidoMarca-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { discardTestStoreDirectory(dir) }
        let context = try Self.makeContext(dir)
        context.autosaveEnabled = false
        let group = SplitGroup(name: "Ana")
        group.cloudKitZoneID = "SplitGroup-Persona"
        group.isBackendGroup = true
        context.insert(group)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [Self.meta(["is_person": .bool(true)])], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        #expect(group.isPerson)

        client.applyPulledPage(
            GroupPulledPage(deltas: [Self.meta(["name": .string("Ana P.")], serverSeq: 6)], cursors: [:],
                            memberships: []),
            cursor: cursor, context: context)
        #expect(group.isPerson, "un delta sin la clave quitó la marca")
        #expect(group.name == "Ana P.")
    }

    @Test("Lo que compartes en una persona marcada se nombra «Sin grupo», junto a sus grupos")
    func personGroupIsNamedNoGroup() throws {
        typealias Logic = CompartidoPersonasLogic
        let ana = Logic.Member(id: "a1", name: "Ana", accountKey: "u:ana")
        let anaPair = Logic.Member(id: "a2", name: "Ana", accountKey: "u:ana")
        let me = Logic.Member(id: "yo", name: "Tú", accountKey: "u:yo")
        let result = Logic.people(from: [
            Logic.GroupInput(groupKey: "g1", groupName: "Viaje a Cusco", members: [me, ana], myMemberIDs: ["yo"],
                             debts: [Debt(fromMemberID: "a1", toMemberID: "yo", amount: 30, currencyCode: "PEN")],
                             interactedMemberIDs: ["a1"]),
            Logic.GroupInput(groupKey: "p1", groupName: "Ana", isPerson: true, members: [me, anaPair],
                             myMemberIDs: ["yo"],
                             debts: [Debt(fromMemberID: "a2", toMemberID: "yo", amount: 20, currencyCode: "PEN")],
                             interactedMemberIDs: ["a2"]),
        ], noGroupLabel: "Sin grupo")
        let person = try #require(result.active.first)
        #expect(result.active.count == 1)
        #expect(person.groupNames == ["Viaje a Cusco", "Sin grupo"])
        #expect(person.netByCurrency == ["PEN": 50])
    }

    @Test("La lista de Grupos no enseña a las personas; la cifra de arriba sí las cuenta")
    func groupsListHidesPeople() throws {
        let code = try String(
            contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().appendingPathComponent("Yala/App/ViewModels/GroupsViewModel.swift"),
            encoding: .utf8)
        #expect(code.contains("var listedActiveGroups: [SplitGroup] { activeGroups.filter { !$0.isPerson } }"))
        #expect(code.contains("var listedArchivedGroups: [SplitGroup] { archivedGroups.filter { !$0.isPerson } }"))
        // `activeGroups` (de donde sale el resumen de arriba) no filtra la marca.
        #expect(code.contains("groups.filter { !$0.isArchived && !$0.isHiddenForAll }"))
    }

    // MARK: - Andamio

    private static func meta(_ fields: [String: WireValue], serverSeq: Int64 = 5) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-Persona",
            rawSyncID: nil, syncID: nil, op: .upsert, fields: fields,
            fieldHlcs: [:], hlc: "2026-11-26T00:00:00.000Z-0000-000000000000000c",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    private static func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "CM-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "CM-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "CM-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }
}
