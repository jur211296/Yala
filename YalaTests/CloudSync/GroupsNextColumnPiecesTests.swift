//
//  GroupsNextColumnPiecesTests.swift
//  YalaTests / CloudSync
//
//  Card u8cl (ticket `groups-next-column-needs-the-capability-level-in-the-drain`): las cuatro piezas que la primera
//  columna de Grupos con `since: 3` necesita. Hoy el canal declara siempre 2; los casos bajan el nivel anunciado por el
//  Worker a 1 para que `split_groups.budget_limit_amount` (since 2) haga de «columna nueva».
//   (1) el drain emite con el nivel de GRUPOS, no con el del canal personal;
//   (2) la subida de versión re-encola lo que no subió y vuelve a bajar desde 0 los grupos de aquí;
//   (3) el guard de despliegue lo fija `gateway/test/manifestGuard.test.ts`;
//   (4) la poda es por grupo de coherencia entero, la misma para lo que viaja y lo que se hashea.
//
//  `GroupsSyncCapability.defaults` y `SyncCapability.defaults` son ESTÁTICOS: cada caso los aísla y los restaura.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · Grupos · las cuatro piezas de la próxima columna (u8cl)", .serialized)
@MainActor
struct GroupsNextColumnPiecesTests {

    // MARK: - Infra

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsNextColumn-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        do {
            try FileManager.default.removeItem(at: dir)
        } catch {
            #if DEBUG
            print("GroupsNextColumnPiecesTests: cleanup: \(error)")
            #endif
        }
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GNC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GNC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GNC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        return ModelContext(container)
    }

    /// Los dos `defaults` de capability aislados; todo se restaura al salir.
    private func withIsolatedCapability(_ body: () throws -> Void) throws {
        let previousGroups = GroupsSyncCapability.defaults
        let previousPersonal = SyncCapability.defaults
        GroupsSyncCapability.defaults = try #require(UserDefaults(suiteName: "test.gnc.groups.\(UUID().uuidString)"))
        SyncCapability.defaults = try #require(UserDefaults(suiteName: "test.gnc.personal.\(UUID().uuidString)"))
        defer {
            GroupsSyncCapability.defaults = previousGroups
            SyncCapability.defaults = previousPersonal
        }
        try body()
    }

    @discardableResult
    private func makeBackendGroup(zoneID: String, context: ModelContext) throws -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zoneID
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
        return group
    }

    private func groupRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        let type = GroupSyncEntityType.splitGroup
        return try context.fetch(FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.entityType == type }))
    }

    // MARK: - (4) La poda, pura

    @Test("(4) una columna posterior dentro de un grupo de coherencia se lleva el grupo ENTERO, como el Worker")
    func keptColumns_dropsTheWholeCoherenceGroup() {
        let columns: [(column: String, group: String?)] = [
            ("name", nil), ("amount", "money"), ("currency_code", "money"), ("rate", "money"), ("note", nil),
        ]
        // `rate` nace en la v3 dentro del grupo `money`: en v2 no viaja nada del grupo, como `droppedGroupsFor`.
        let since: (String, String) -> Int = { _, column in column == "rate" ? 3 : 1 }
        let v2 = GroupsSyncCapability.keptColumns(table: "t", columns: columns, level: 2, since: since)
        #expect(v2 == ["name", "note"])
        let v3 = GroupsSyncCapability.keptColumns(table: "t", columns: columns, level: 3, since: since)
        #expect(v3 == ["name", "amount", "currency_code", "rate", "note"])
        // Una suelta posterior se va sola: no arrastra a nadie.
        let loose: (String, String) -> Int = { _, column in column == "note" ? 3 : 1 }
        #expect(GroupsSyncCapability.keptColumns(table: "t", columns: columns, level: 2, since: loose)
                == ["name", "amount", "currency_code", "rate"])
    }

    @Test("(4) con el manifest de hoy, v2 conserva todas las columnas y v1 solo quita el presupuesto")
    func keptColumns_todaysManifest() {
        let emission = GroupEntityEmissionMap.splitGroup
        #expect(GroupsSyncCapability.keptColumns(of: emission, level: 2) == emission.columns)
        #expect(GroupsSyncCapability.keptColumns(of: emission, level: 1)
                == emission.columns.subtracting(["budget_limit_amount"]))
        for table in [GroupEntityEmissionMap.splitExpense.columns, GroupEntityEmissionMap.splitShare.columns,
                      GroupEntityEmissionMap.splitSettlement.columns] {
            #expect(!table.isEmpty)
        }
        #expect(GroupsSyncCapability.keptColumns(of: GroupEntityEmissionMap.splitExpense, level: 2)
                == GroupEntityEmissionMap.splitExpense.columns)
    }

    @Test("(1)(4) lo que viaja y lo que se hashea salen de la misma poda, y el emit del drain lleva el nivel de Grupos")
    func wiring_driftAndMerkleUseTheSameCut() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let client = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"), encoding: .utf8)
        let merkle = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/Groups/GroupMerkleProjection.swift"), encoding: .utf8)
        #expect(merkle.contains("GroupsSyncCapability.keptColumns(of: emission, level: capabilityLevel)"))
        #expect(client.contains("let restricted = GroupsSyncCapability.emission(emission, upTo: level)"))
        // Todo `DeltaEmitter.emit` del cliente de Grupos lleva su nivel: sin él, el default es el del canal PERSONAL.
        var rest = client[...]
        var emits = 0
        while let range = rest.range(of: "DeltaEmitter.emit(") {
            let call = rest[range.lowerBound...].prefix(260)
            #expect(call.contains("capabilityLevel: level"), "un emit de Grupos sin el nivel de Grupos: \(call)")
            emits += 1
            rest = rest[range.upperBound...]
        }
        #expect(emits == 2, "el drain y la re-emisión de la subida; un emit nuevo se revisa aquí")
        // La subida solo con el drain completo: el re-pull desde 0 pisaría una edición que sigue en el History.
        #expect(client.contains("if drained { try applyCapabilityUpgradeIfPending(context: context) }"))
        // Y durante su re-pull, un gasto que ya estaba no avisa de «modificado».
        #expect(client.contains("notify.modifiedExpenses.removeAll { capabilityRepullZones.contains($0.zone) }"))
    }

    // MARK: - (1) El drain emite con el nivel de GRUPOS

    @Test("(1) con Grupos en v1 el drain NO sube el presupuesto aunque el canal personal hable v4, y lo apunta")
    func drain_usesTheGroupsLevel_notThePersonalOne() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            SyncCapability.recordBackendManifestVersion(4)
            GroupsSyncCapability.recordBackendManifestVersion(1)
            #expect(GroupsSyncCapability.declaredLevel == 1)

            let group = try makeBackendGroup(zoneID: "SplitGroup-A", context: context)
            let client = GroupsSyncClient()
            client.drainOnce(context: context)
            group.budgetLimitAmount = 3000
            group.name = "Viaje a Cusco"
            try context.save()
            client.drainOnce(context: context)

            let rows = try groupRows(context)
            #expect(rows.count == 1)
            let fields = try #require(rows.first?.fieldsJSON)
            #expect(!fields.contains("budget_limit_amount"), "subió una columna que el Worker de v1 no conoce")
            #expect(fields.contains("Viaje a Cusco"), "el resto del cambio no subió")
            let noted = Array(GroupsSyncCapability.suppressedRows.values)
            #expect(noted.count == 1)
            #expect(noted.first?.columns == ["budget_limit_amount"])
            #expect(noted.first?.syncID == group.id)
        }
    }

    @Test("(1) control: con Grupos en v2 el presupuesto sube y no se apunta nada")
    func drain_atLevelTwo_uploadsTheBudget() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            // El canal personal en v1 (el teléfono sin la nube personal): no puede quitarle nada a Grupos.
            SyncCapability.recordBackendManifestVersion(nil)
            GroupsSyncCapability.recordBackendManifestVersion(2)
            let group = try makeBackendGroup(zoneID: "SplitGroup-A", context: context)
            let client = GroupsSyncClient()
            client.drainOnce(context: context)
            group.budgetLimitAmount = 3000
            try context.save()
            client.drainOnce(context: context)
            let fields = try #require(try groupRows(context).first?.fieldsJSON)
            #expect(fields.contains("budget_limit_amount"))
            #expect(GroupsSyncCapability.suppressedRows.isEmpty)
        }
    }

    // MARK: - (2) La subida de versión

    @Test("(2) sin apunte previo, anunciar v2 no pide subida: el parque de hoy no vuelve a bajar nada")
    func firstAnnouncement_doesNotRequestAnUpgrade() throws {
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(2)
            #expect(GroupsSyncCapability.upgradePendingLevel == nil)
            GroupsSyncCapability.recordBackendManifestVersion(nil)
            #expect(GroupsSyncCapability.upgradePendingLevel == nil)
        }
    }

    @Test("(2) al subir de v1 a v2: re-encola lo apuntado y vuelve a bajar desde 0 solo los grupos que hay aquí")
    func upgrade_reenqueuesTheSuppressed_andResetsLocalGroups() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(1)
            let group = try makeBackendGroup(zoneID: "SplitGroup-A", context: context)
            let client = GroupsSyncClient()
            client.drainOnce(context: context)
            group.budgetLimitAmount = 3000
            try context.save()
            client.drainOnce(context: context)
            #expect(GroupsSyncCapability.suppressedRows.count == 1)

            // Cursores: el grupo de aquí y uno que ya no está (tras «Empezar de cero», la barrera).
            let cursor = try client.loadOrCreateCursor(context)
            cursor.groupCursorsJSON = #"{"SplitGroup-A":50,"SplitGroup-GONE":70}"#
            try context.save()

            // Sin subida pedida no hace nada.
            #expect(try client.applyCapabilityUpgradeIfPending(context: context) == false)

            GroupsSyncCapability.recordBackendManifestVersion(2)
            #expect(GroupsSyncCapability.upgradeDue)
            #expect(try client.applyCapabilityUpgradeIfPending(context: context))

            let rows = try groupRows(context)
            #expect(rows.count == 1, "la primera fila (v1) no llevaba el presupuesto; falta la re-encolada")
            let reemitted = try #require(rows.first)
            #expect(reemitted.fieldsJSON.contains("budget_limit_amount"))
            #expect(reemitted.fieldsJSON.contains("3000"))
            #expect(reemitted.groupID == "SplitGroup-A")

            let cursorsData = try #require(try client.loadOrCreateCursor(context).groupCursorsJSON.data(using: .utf8))
            let cursors = try JSONDecoder().decode([String: Int64].self, from: cursorsData)
            #expect(cursors["SplitGroup-A"] == 0, "el grupo que bajó sin la columna no vuelve a bajar")
            #expect(cursors["SplitGroup-GONE"] == 70, "un grupo que no está aquí no puede volver a bajar por esto")
            #expect(client.capabilityRepullZones == ["SplitGroup-A"],
                    "el re-pull de la subida avisaría de «gasto modificado» por cada gasto que ya estaba")

            #expect(GroupsSyncCapability.suppressedRows.isEmpty)
            #expect(GroupsSyncCapability.upgradePendingLevel == nil)
            #expect(try client.applyCapabilityUpgradeIfPending(context: context) == false, "se cumple una sola vez")
        }
    }

    @Test("(2) con la subida pedida y el Worker vuelto atrás, espera sin tocar nada")
    func upgrade_waitsWhileTheWorkerIsBehind() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(1)
            GroupsSyncCapability.recordBackendManifestVersion(2)
            #expect(GroupsSyncCapability.upgradePendingLevel == 2)
            GroupsSyncCapability.recordBackendManifestVersion(1)
            #expect(!GroupsSyncCapability.upgradeDue)
            let applied = try GroupsSyncClient().applyCapabilityUpgradeIfPending(context: context)
            #expect(!applied)
            #expect(GroupsSyncCapability.upgradePendingLevel == 2, "la petición se perdió con el rollback del Worker")
        }
    }

    @Test("(2) una fila apuntada que ya no existe no se re-encola, y lo apuntado se retira igual")
    func upgrade_skipsRowsThatAreGone() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(1)
            try makeBackendGroup(zoneID: "SplitGroup-A", context: context)
            GroupsSyncCapability.noteSuppressed(entityType: GroupSyncEntityType.splitGroup, syncID: UUID(),
                                                groupID: "SplitGroup-A", ownerUserID: nil,
                                                columns: ["budget_limit_amount"])
            GroupsSyncCapability.recordBackendManifestVersion(2)
            #expect(try GroupsSyncClient().applyCapabilityUpgradeIfPending(context: context))
            #expect(try groupRows(context).isEmpty)
            #expect(GroupsSyncCapability.suppressedRows.isEmpty)
        }
    }
}
