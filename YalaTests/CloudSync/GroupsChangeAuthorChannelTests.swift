//
//  GroupsChangeAuthorChannelTests.swift
//  YalaTests / CloudSync
//
//  Card xi74 (2026-11-02, g29_01): quién creó o editó un gasto, y quién registró una liquidación, viajan por el canal de
//  Grupos desde la v3 del manifest. Hasta ese día el autor vivía solo en el teléfono que hizo el cambio: en el iPad de la
//  misma cuenta llegaba vacío, el aviso local caía al pagador como autor, y Jürgen recibía en su iPad «Ana agregó 'Cena'
//  — te toca S/ 25» por un gasto que había apuntado él en su iPhone.
//
//  Lo que se fija:
//   · la EMISIÓN: el autor sale con el alta y con CADA edición del formulario, también cuando no cambia (reescribir el
//     mismo valor no emite, así que colgado solo de su keypath no saldría); en v2 se filtra y se apunta;
//   · la APLICACIÓN: el pull lo escribe en el modelo; un NULL del servidor manda, y sin la key no se toca;
//   · el AVISO: con lo que baja del pull, el dispositivo del autor no se avisa a sí mismo. El caso sin la key es el bug.
//
//  `GroupsSyncCapability.defaults` es ESTÁTICO: cada caso lo aísla y lo restaura.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · Grupos · el autor del cambio viaja por el canal (xi74)", .serialized)
@MainActor
struct GroupsChangeAuthorChannelTests {

    // MARK: - Infra

    private let zone = "SplitGroup-Autor"
    private let hlc = "2026-11-02T12:00:00.000Z-0000-00000000000000aa"
    private let me = "MEMBER-JURGEN"
    private let ana = "MEMBER-ANA"

    private func freshDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsChangeAuthor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        discardTestStoreDirectory(dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personal = ModelConfiguration(
            "GCA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groups = ModelConfiguration(
            "GCA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMeta = ModelConfiguration(
            "GCA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personal, groups, syncMeta)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func withIsolatedCapability(_ body: () throws -> Void) throws {
        let previous = GroupsSyncCapability.defaults
        GroupsSyncCapability.defaults = try #require(testDefaults(suiteName: "test.gca.groups.\(UUID().uuidString)"))
        defer { GroupsSyncCapability.defaults = previous }
        try body()
    }

    private func makeBackendGroup(context: ModelContext) throws {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
    }

    private func expenseRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        let type = GroupSyncEntityType.splitExpense
        return try context.fetch(FetchDescriptor<GroupSyncOutbox>(
            predicate: #Predicate { $0.entityType == type }, sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func delta(_ table: String, id: UUID, seq: Int64, fields: [String: WireValue]) -> GroupPulledDelta {
        GroupPulledDelta(entityType: table, groupID: zone, rawSyncID: id.uuidString, syncID: id, op: .upsert,
                         fields: fields, fieldHlcs: [:], hlc: hlc, serverSeq: seq, schemaVersion: 1)
    }

    private func apply(_ d: GroupPulledDelta, client: GroupsSyncClient, context: ModelContext) throws {
        let cursor = try client.loadOrCreateCursor(context)
        let page = GroupPulledPage(deltas: [d], cursors: [zone: d.serverSeq], memberships: [zone])
        #expect(client.applyPulledPage(page, cursor: cursor, context: context))
    }

    private func expenseFields(author: WireValue?) -> [String: WireValue] {
        var f: [String: WireValue] = [
            "expense_description": .string("Cena"), "amount": .string("50.0000"), "currency_code": .string("PEN"),
            "date": .string("2026-11-01T20:00:00.000Z"), "paid_by_member_key": .string(ana),
            "split_type": .string("equal"), "is_settled": .bool(false),
        ]
        if let author { f["last_edited_by_member_key"] = author }
        return f
    }

    // MARK: - Manifest y emisión

    @Test("las dos columnas son de la v3, y este build habla la v3")
    func columnsAreVersionThree() {
        #expect(GroupsSyncCapability.clientManifestVersion == 3)
        #expect(GroupsSyncCapability.since(table: "split_expenses", column: "last_edited_by_member_key") == 3)
        #expect(GroupsSyncCapability.since(table: "split_settlements", column: "recorded_by_member_key") == 3)
        #expect(GroupEntityEmissionMap.splitExpense.columns.contains("last_edited_by_member_key"))
        #expect(GroupEntityEmissionMap.splitSettlement.columns.contains("recorded_by_member_key"))
        // En v2 no viajan ni se hashean (el Merkle reusa esta emisión): las dos tablas pierden SOLO su autor.
        #expect(GroupsSyncCapability.keptColumns(of: GroupEntityEmissionMap.splitExpense, level: 2)
                == GroupEntityEmissionMap.splitExpense.columns.subtracting(["last_edited_by_member_key"]))
        #expect(GroupsSyncCapability.keptColumns(of: GroupEntityEmissionMap.splitSettlement, level: 2)
                == GroupEntityEmissionMap.splitSettlement.columns.subtracting(["recorded_by_member_key"]))
        #expect(GroupsSyncCapability.keptColumns(of: GroupEntityEmissionMap.splitExpense, level: 3)
                == GroupEntityEmissionMap.splitExpense.columns)
    }

    /// Los ocho campos que escribe `GroupExpenseService.updateExpense` arrastran el autor; los que no son del formulario, no.
    @Test("el autor cuelga de cada keypath que escribe el formulario, y solo de esos")
    func authorRidesAlongEveryFormKeyPath() {
        let map = GroupEntityEmissionMap.splitExpense.columnKeyPaths
        let author = GroupEntityEmissionMap.expenseAuthorColumn
        let form: [PartialKeyPath<SplitExpense>] = [
            \SplitExpense.amount, \SplitExpense.currencyCode, \SplitExpense.expenseDescription, \SplitExpense.note,
            \SplitExpense.date, \SplitExpense.paidByMemberID, \SplitExpense.splitType, \SplitExpense.subcategoryName,
            \SplitExpense.lastEditedByMemberID,
        ]
        for keyPath in form {
            #expect(map[keyPath]?.contains(author) == true, "\(keyPath) no arrastra el autor")
        }
        for keyPath: PartialKeyPath<SplitExpense> in [\SplitExpense.isSettled, \SplitExpense.isOpeningBalance, \SplitExpense.createdAt] {
            #expect(map[keyPath]?.contains(author) == false, "\(keyPath) no es una edición del formulario")
        }
    }

    @Test("v3: una edición que solo cambia el importe sube también el autor, aunque el autor no cambió")
    func drain_editCarriesTheAuthor_evenWhenUnchanged() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(3)
            #expect(GroupsSyncCapability.declaredLevel == 3)
            try makeBackendGroup(context: context)
            let client = GroupsSyncClient()
            client.drainOnce(context: context)

            let expense = SplitExpense(groupZoneID: zone, amount: 50, currencyCode: "PEN", expenseDescription: "Cena",
                                       note: nil, date: .now, paidByMemberID: ana, splitType: "equal",
                                       subcategoryName: nil, isOpeningBalance: false)
            expense.lastEditedByMemberID = me
            context.insert(expense)
            try context.save()
            client.drainOnce(context: context)
            let created = try #require(try expenseRows(context).last?.fieldsJSON)
            #expect(created.contains("\"last_edited_by_member_key\":\"\(me)\""), "el alta no subió el autor: \(created)")

            // La edición del formulario reescribe el autor con el MISMO valor: el History no lo trae como cambiado.
            expense.amount = 60
            expense.lastEditedByMemberID = me
            try context.save()
            client.drainOnce(context: context)
            let edited = try #require(try expenseRows(context).last?.fieldsJSON)
            #expect(edited.contains("60"), "la edición no subió: \(edited)")
            #expect(edited.contains("\"last_edited_by_member_key\":\"\(me)\""),
                    "una edición sin cambio de autor dejaría el servidor sin él: \(edited)")
            #expect(GroupsSyncCapability.suppressedRows.isEmpty)
        }
    }

    @Test("control: marcar el gasto como saldado no arrastra el autor (no es una edición del formulario)")
    func drain_settledToggleDoesNotCarryTheAuthor() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(3)
            try makeBackendGroup(context: context)
            let client = GroupsSyncClient()
            let expense = SplitExpense(groupZoneID: zone, amount: 50, currencyCode: "PEN", expenseDescription: "Cena",
                                       note: nil, date: .now, paidByMemberID: ana, splitType: "equal",
                                       subcategoryName: nil, isOpeningBalance: false)
            expense.lastEditedByMemberID = ana
            context.insert(expense)
            try context.save()
            client.drainOnce(context: context)
            expense.isSettled = true
            try context.save()
            client.drainOnce(context: context)
            let toggled = try #require(try expenseRows(context).last?.fieldsJSON)
            #expect(toggled.contains("is_settled"))
            #expect(!toggled.contains("last_edited_by_member_key"), "\(toggled)")
        }
    }

    @Test("v2: el autor no sube y se apunta, para re-emitirlo al cruzar a la v3")
    func drain_atLevelTwo_suppressesAndNotesTheAuthor() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try withIsolatedCapability {
            GroupsSyncCapability.recordBackendManifestVersion(2)
            #expect(GroupsSyncCapability.declaredLevel == 2)
            try makeBackendGroup(context: context)
            let client = GroupsSyncClient()
            let expense = SplitExpense(groupZoneID: zone, amount: 50, currencyCode: "PEN", expenseDescription: "Cena",
                                       note: nil, date: .now, paidByMemberID: ana, splitType: "equal",
                                       subcategoryName: nil, isOpeningBalance: false)
            expense.lastEditedByMemberID = me
            context.insert(expense)
            try context.save()
            client.drainOnce(context: context)
            let fields = try #require(try expenseRows(context).last?.fieldsJSON)
            #expect(!fields.contains("last_edited_by_member_key"), "un Worker v2 lo rechazaría con unknown_column")
            #expect(fields.contains("Cena"))
            let noted = try #require(GroupsSyncCapability.suppressedRows.values.first)
            #expect(noted.columns == ["last_edited_by_member_key"])
            #expect(noted.syncID == expense.id)
        }
    }

    // MARK: - Aplicación del pull

    @Test("el pull escribe el autor del gasto; un NULL del servidor manda; sin la key no se toca")
    func apply_expenseAuthor() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        let id = UUID()

        try apply(delta("split_expenses", id: id, seq: 1, fields: expenseFields(author: .string(me))),
                  client: client, context: context)
        let row = try #require(try context.fetch(FetchDescriptor<SplitExpense>()).first)
        #expect(row.lastEditedByMemberID == me)

        // Sin la key (un Worker o un nivel que no la conocen): el autor local se queda.
        try apply(delta("split_expenses", id: id, seq: 2, fields: expenseFields(author: nil)),
                  client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitExpense>()).first?.lastEditedByMemberID == me)

        // Con la key a NULL (fila anterior a la columna): manda el servidor, o el Merkle divergiría.
        try apply(delta("split_expenses", id: id, seq: 3, fields: expenseFields(author: .null)),
                  client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitExpense>()).first?.lastEditedByMemberID == nil)
    }

    @Test("el pull escribe quién registró la liquidación")
    func apply_settlementRecorder() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        let fields: [String: WireValue] = [
            "from_member_key": .string(ana), "to_member_key": .string(me), "amount": .string("10.0000"),
            "currency_code": .string("PEN"), "date": .string("2026-11-01T20:00:00.000Z"), "is_confirmed": .bool(true),
            "recorded_by_member_key": .string(me),
        ]
        try apply(delta("split_settlements", id: UUID(), seq: 1, fields: fields), client: client, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitSettlement>()).first?.recordedByMemberID == me)
    }

    // MARK: - El aviso, con lo que bajó

    /// El «hecha cuando» de la card: el aviso local nunca sale en un dispositivo del autor. Jürgen apunta en su iPhone un
    /// gasto que pagó Ana y en el que él tiene parte; su iPad lo baja.
    @Test("el iPad del autor no se avisa a sí mismo; sin el autor en el canal (el bug), sí se avisaba")
    func notifyDecision_onTheAuthorsOtherDevice() throws {
        for (author, expected) in [(WireValue.string(me), ExpenseNotifyDecision.skip),
                                   (nil, ExpenseNotifyDecision.notify(share: 25))] {
            let dir = try freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            let client = GroupsSyncClient()
            try apply(delta("split_expenses", id: UUID(), seq: 1, fields: expenseFields(author: author)),
                      client: client, context: context)
            let row = try #require(try context.fetch(FetchDescriptor<SplitExpense>()).first)
            let decision = GroupNotificationRecipientLogic.expenseDecision(
                currentMemberID: me, paidByMemberID: row.paidByMemberID,
                lastEditedByMemberID: row.lastEditedByMemberID, myShareAmount: 25)
            #expect(decision == expected, "autor en el canal: \(author.map { "\($0)" } ?? "ninguno")")
        }
    }

    /// Grupo migrado: el iPhone firma con mi fila heredada (la que tiene `isCurrentUser`) y el iPad se reconoce en la del
    /// backend. Con mis otras filas, el iPad sabe que el cambio es suyo.
    @Test("mi otra fila de la zona también me identifica como autor (grupo migrado, dos dispositivos)")
    func myOtherRowIsAlsoMe() {
        let legacyMe = "MEMBER-JURGEN-LEGACY"
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: ana, lastEditedByMemberID: legacyMe,
            myOtherMemberIDs: [legacyMe], myShareAmount: 25) == .skip)
        // Control: sin conocer mis otras filas, el iPad se avisaba de su propia edición.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: ana, lastEditedByMemberID: legacyMe,
            myShareAmount: 25) == .notify(share: 25))
        // Y si pagué con mi otra fila, tampoco (nunca se avisa al pagador).
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: legacyMe, lastEditedByMemberID: ana,
            myOtherMemberIDs: [legacyMe], myShareAmount: 25) == .skip)
        #expect(!GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: me, recordedByMemberID: legacyMe, myOtherMemberIDs: [legacyMe]))
    }

    @Test("una liquidación que registré yo no me avisa «te pagó» en mi otro dispositivo")
    func settlementDecision_onTheRecordersOtherDevice() throws {
        let dir = try freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()
        let fields: [String: WireValue] = [
            "from_member_key": .string(ana), "to_member_key": .string(me), "amount": .string("10.0000"),
            "currency_code": .string("PEN"), "date": .string("2026-11-01T20:00:00.000Z"), "is_confirmed": .bool(true),
            "recorded_by_member_key": .string(me),
        ]
        try apply(delta("split_settlements", id: UUID(), seq: 1, fields: fields), client: client, context: context)
        let row = try #require(try context.fetch(FetchDescriptor<SplitSettlement>()).first)
        #expect(!GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: row.toMemberID, recordedByMemberID: row.recordedByMemberID))
        // Control: si la registró Ana, a mí sí me avisa.
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: row.toMemberID, recordedByMemberID: ana))
    }
}
