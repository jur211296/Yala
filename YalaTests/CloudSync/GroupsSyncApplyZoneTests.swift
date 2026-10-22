//
//  GroupsSyncApplyZoneTests.swift
//  YalaTests / CloudSync
//
//  `GroupsSyncClient.applyGroupMeta` — el apply del pull sobre la fila del GRUPO. CUARTO miembro de la
//  familia «decidir sobre una ZONA de Grupos mirando UNA sola fila `SplitGroup`», tras `GroupZoneCacheGate`
//  (transporte), `GroupService.performLocalCleanupAndDelete` (cleanup local) y `executeBatchStep` +
//  `routesMembershipToBackend` (canal). Y el que llega más lejos de los cuatro, porque aquí estaba el
//  PRODUCTOR: `fetchSplitGroup` resolvía con `fetchLimit = 1` y **sin `sortBy`**, así que
//
//   1. **el tombstone dejaba un CASCARÓN.** `cascadeDeleteGroupRows` barre TODA la zona y el `delete` del
//      grupo iba sobre UNA fila ⇒ con un duplicado, la gemela SOBREVIVÍA con todas sus hijas muertas. Lo
//      que hace el cascarón, MEDIDO: es VISIBLE (`fetchAllGroups` no lleva predicado ⇒ tarjeta en el tab
//      con 0 miembros y 0 gastos) pero NO escribible por el camino obvio —sin `SplitMember`,
//      `eligibleGroupsForExpense` lo excluye y `createExpense` lanza—; la escritura alcanzable es
//      `GroupService.softDelete`, gateado solo por `isOwner`, que emite un upsert de `split_groups` contra
//      un grupo ya tombstoneado server-side.
//   2. **la meta se escribía en una fila y las gemelas divergían** (nombre, icono, archivado, oculto…), y la
//      UI mostraba una u otra según qué fetch usara.
//   3. **el flip de canal de la adopción C3 marcaba UNA fila**, así que la zona se quedaba MIXTA —una fila
//      backend y su gemela sin marcar—, que es el estado del que dependían los otros tres defectos de la
//      familia. Ojo con la dirección de la causa: `applyGroupMeta` **no crea** la segunda fila (resuelve
//      por zona y solo inserta si está vacía) — el duplicado nace ya mixto del canal CloudKit
//      (`SplitSyncManager.applyGroupMeta` resuelve por `$0.id == modelID`, no ve la fila born-remote, e
//      inserta una gemela que nunca setea `isBackendGroup`). Lo que este flip era, y no ejercía, es el
//      único punto capaz de CURAR la mixtura.
//
//  Molde de infra: `GroupsSyncClientTests` (container ON-DISK con los 3 stores + drain real contra
//  `GroupSyncOutbox`), del que esta suite es el complemento por-zona.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSyncClient · applyGroupMeta decide por ZONA", .serialized)
@MainActor
struct GroupsSyncApplyZoneTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsApplyZone-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GAZ-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GAZ-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GAZ-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Una fila de la zona. `createdAt` explícito para poder fijar cuál es la CANÓNICA.
    @discardableResult
    private func makeGroup(
        zone: String, name: String = "Viejo", isBackendGroup: Bool, createdAt: Date,
        isHiddenForAll: Bool = false, context: ModelContext
    ) -> SplitGroup {
        let g = SplitGroup(name: name)
        g.cloudKitZoneID = zone
        g.isBackendGroup = isBackendGroup
        g.createdAt = createdAt
        g.isHiddenForAll = isHiddenForAll
        context.insert(g)
        return g
    }

    private func seedChildren(zone: String, context: ModelContext) {
        let expense = SplitExpense(groupZoneID: zone, amount: 40, currencyCode: "USD",
                                   expenseDescription: "Hotel", paidByMemberID: "member-1")
        context.insert(expense)
        context.insert(SplitShare(
            expenseID: expense.id, memberID: "member-1", amount: 20, groupZoneID: zone))
        context.insert(SplitSettlement(
            groupZoneID: zone, fromMemberID: "member-1", toMemberID: "member-2", amount: 20))
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
    }

    private func counts(
        _ context: ModelContext, zone: String
    ) throws -> (groups: Int, members: Int, expenses: Int, shares: Int, settlements: Int) {
        (
            try context.fetchCount(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zone }))
        )
    }

    private func rows(_ context: ModelContext, zone: String) throws -> [SplitGroup] {
        try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zone },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    }

    private func delta(
        zone: String, op: SyncOutboxOp, fields: [String: WireValue] = [:], seq: Int64 = 9
    ) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: zone,
            rawSyncID: zone, syncID: nil, op: op, fields: fields, fieldHlcs: [:],
            hlc: "2026-08-03T00:00:00.000Z-0000-00000000000000f9", serverSeq: seq, schemaVersion: 1)
    }

    private func apply(_ d: GroupPulledDelta, client: GroupsSyncClient, context: ModelContext) throws {
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [d], cursors: [:], memberships: []),
            cursor: cursor, context: context)
    }

    // MARK: - (1) El tombstone barre la ZONA — no deja cascarón

    /// **La aserción que carga el peso.** Zona con `SplitGroup` DUPLICADO: el tombstone del grupo tiene que
    /// llevarse las DOS filas, no solo una. Con el criterio por fila la gemela quedaba viva con sus cuatro
    /// clases de hijas muertas — un grupo fantasma en la lista del tab, con 0 miembros y 0 gastos, cuya
    /// zona el servidor ya había tombstoneado.
    ///
    /// El duplicado es imprescindible en el fixture: con una sola fila por zona el escenario pasa igual SIN
    /// el fix (corolario de test de `.claude/rules/swiftdata-cloudkit.md`).
    ///
    /// MUTACIÓN: volver a `if let first = rows.first { context.delete(first) }` deja `groups == 1`.
    @Test func tombstone_withDuplicateRows_leavesNoShellRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Dup"
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        seedChildren(zone: zone, context: context)
        try context.save()

        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .tombstone), client: client, context: context)

        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    /// El barrido es por ZONA, no global: una zona vecina queda INTACTA, filas e hijas. Sin esta aserción un
    /// `#Predicate` mal escrito (o un fetch sin predicado) pasaría el test de arriba en verde.
    ///
    /// MUTACIÓN: quitar el `predicate` del `FetchDescriptor` de `fetchSplitGroupRows` → `otras == 0`.
    @Test func tombstone_doesNotTouchAnotherZone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Dying"
        let other = "SplitGroup-Neighbour"
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        seedChildren(zone: zone, context: context)
        makeGroup(zone: other, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        seedChildren(zone: other, context: context)
        try context.save()

        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .tombstone), client: client, context: context)

        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
        #expect(try counts(context, zone: other) == (1, 1, 1, 1, 1))
    }

    // MARK: - (2) La meta se aplica a TODA la zona

    /// La meta del wire es autoridad del SERVIDOR y las filas de una zona son el MISMO grupo: escribirla en
    /// una sola las hacía divergir, y la UI mostraba el nombre viejo o el nuevo según qué fetch usara
    /// (`group(for:)` ordena por `createdAt`, `fetchAllGroups` por `name`).
    ///
    /// MUTACIÓN: `let models = isBorn ? [SplitGroup()] : Array(rows.prefix(1))` deja una fila en "Viejo".
    @Test func upsert_appliesMetaToEveryRowInTheZone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Meta"
        makeGroup(zone: zone, name: "Viejo", isBackendGroup: true,
                  createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        makeGroup(zone: zone, name: "Viejo", isBackendGroup: true,
                  createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        try context.save()

        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .upsert,
                        fields: ["name": .string("Nuevo"), "is_archived": .bool(true)]),
                  client: client, context: context)

        let all = try rows(context, zone: zone)
        #expect(all.count == 2)
        #expect(all.allSatisfy { $0.name == "Nuevo" }, "una gemela se quedó con el nombre viejo")
        #expect(all.allSatisfy { $0.isArchived }, "una gemela se quedó sin archivar")
    }

    /// **La adopción C3 es el único punto que puede CURAR la mixtura, y marcaba una sola fila.** Un
    /// `SplitGroup` CloudKit preexistente que aparece en el pull backend se flipea a `isBackendGroup`; con
    /// una sola marcada la zona se quedaba MIXTA para siempre — el estado del que dependen los otros tres
    /// defectos de la familia. (No es su fábrica: la segunda fila la inserta el canal CloudKit y nace ya sin
    /// marcar; ver la cabecera.)
    ///
    /// MUTACIÓN: `if let m = models.first(where: { !$0.isBackendGroup }) { m.isBackendGroup = true }` deja
    /// una fila sin marcar.
    @Test func adoption_flipsChannelOnEveryRow_soTheZoneNeverEndsUpMixed() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Adopt"
        makeGroup(zone: zone, isBackendGroup: false, createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        makeGroup(zone: zone, isBackendGroup: false, createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        try context.save()

        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .upsert, fields: ["name": .string("Migrado")]),
                  client: client, context: context)

        let all = try rows(context, zone: zone)
        #expect(all.count == 2, "la adopción no debe insertar una fila nueva: la zona ya tenía filas")
        #expect(all.allSatisfy { $0.isBackendGroup }, "la zona quedó MIXTA — es justo el estado que produce el bug")
    }

    /// No-regresión del born-remote: una zona VACÍA sigue insertando UNA fila, marcada como backend y con la
    /// ventana de import inicial abierta (supresión del «Jür se unió al grupo»).
    @Test func upsert_onEmptyZone_stillInsertsExactlyOneBornRemoteRow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Born"
        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .upsert, fields: ["name": .string("Nace")]),
                  client: client, context: context)

        let all = try rows(context, zone: zone)
        #expect(all.count == 1)
        #expect(all.first?.name == "Nace")
        #expect(all.first?.isBackendGroup == true)
        #expect(all.first?.initialMemberImportStartedAt != nil)
    }

    /// `wasHidden` va por ZONA y con sesgo a DISPARAR el freeze: basta con que UNA fila estuviera visible
    /// para que el soft-delete remoto cuente como flip. Con la fila arbitraria, caer en la gemela ya oculta
    /// se comía el flip y dejaba las TX y los borradores personales colgando de una zona invisible.
    ///
    /// El freeze se observa por su efecto REAL en el store personal: una `TransactionItem` de cuenta REAL
    /// puenteada a la zona queda con los tres punteros en `nil` (liberada, preservando el rastro
    /// financiero). La cuenta tiene que ser no-sistema o `computeFreezePlan` no la mete en `txsToRelease`
    /// (`tx.account?.isSystemAccount == false`), y el bridge necesita contexto o `drainSoftDeleteFreeze`
    /// se lo traga en su `catch`.
    ///
    /// MUTACIÓN: `let wasHidden = rows.first?.isHiddenForAll ?? false` — con la fila oculta como canónica,
    /// el freeze no corre y el puntero sobrevive.
    @Test func softDeleteFlip_isDecidedOverTheZone_soTheFreezeStillRuns() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        GroupTransactionBridge.shared.setContext(context)
        defer { GroupTransactionBridge.shared._testClearContext() }

        let zone = "SplitGroup-Hidden"
        // La CANÓNICA (más antigua) ya estaba oculta; la gemela seguía visible ⇒ sigue habiendo flip.
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 1_000),
                  isHiddenForAll: true, context: context)
        makeGroup(zone: zone, isBackendGroup: true, createdAt: Date(timeIntervalSince1970: 2_000),
                  isHiddenForAll: false, context: context)

        let account = Account(name: "Cuenta", currencyCode: "USD", colorHex: "#000000",
                              iconName: "creditcard", type: "Banco")
        context.insert(account)
        let tx = TransactionItem(date: .now, amount: 40, currencyCode: "USD", note: "Hotel",
                                 account: account)
        tx.splitGroupZoneID = zone
        tx.splitExpenseID = UUID().uuidString
        context.insert(tx)
        try context.save()

        let client = GroupsSyncClient()
        try apply(delta(zone: zone, op: .upsert, fields: ["is_hidden_for_all": .bool(true)]),
                  client: client, context: context)

        #expect(tx.splitGroupZoneID == nil && tx.splitExpenseID == nil,
                "el freeze no corrió: el flip se decidió con una sola fila")
    }

    // MARK: - (3) Los otros dos consumidores de la zona

    /// El `groupID` del `RemoteChangeSet` es el **`SplitGroup.id` LOCAL**, y de él sale el deep-link de la
    /// notificación. Tiene que ser el de la fila CANÓNICA (`createdAt` ASC) porque eso es lo que
    /// `GroupService.group(for:)` —lo que la UI resuelve al abrirla— devuelve: con una fila arbitraria el
    /// toque podía aterrizar en una fila distinta de la que se muestra.
    ///
    /// MUTACIÓN: `fetchSplitGroupRows(...).last?.id` en `resolveNotificationChanges` → el id de la gemela.
    @Test func notificationDeepLink_usesTheCanonicalRowOfTheZone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Deep"
        let canonical = makeGroup(zone: zone, isBackendGroup: true,
                                  createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        let twin = makeGroup(zone: zone, isBackendGroup: true,
                             createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        try context.save()

        let collector = GroupsSyncClientTests.ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let expenseID = UUID()
        try apply(
            GroupPulledDelta(
                entityType: GroupEntityEmissionMap.splitExpense.table, groupID: zone,
                rawSyncID: expenseID.uuidString.lowercased(), syncID: expenseID, op: .upsert,
                fields: ["expense_description": .string("Cena"), "amount": .string("25.0000"),
                         "currency_code": .string("PEN"), "paid_by_member_key": .string("m1")],
                fieldHlcs: [:], hlc: "2026-08-03T00:00:00.000Z-0000-00000000000000fa",
                serverSeq: 3, schemaVersion: 1),
            client: client, context: context)

        let set = try #require(collector.sets.first)
        #expect(set.newExpenses.first?.groupID == canonical.id)
        #expect(set.newExpenses.first?.groupID != twin.id)
    }

    /// El baseline de primer import va por ZONA y con sesgo a CALLAR: basta con que UNA fila lleve el
    /// `initialMemberImportStartedAt` dentro de la ventana para que el import en curso silencie las
    /// notificaciones de membership. Con la fila arbitraria, caer en la que NO lleva la marca devolvía
    /// `.established` y el pull notificaba «Ana se unió al grupo» miembro a miembro — el bug que la marca
    /// existe para evitar.
    ///
    /// MUTACIÓN: `importStartedAt: rows.first?.initialMemberImportStartedAt` — la canónica no la lleva, así
    /// que el baseline pasa a `.established` y aparece un `newMembers`.
    @Test func memberImportBaseline_isDecidedOverTheZone_soTheImportStaysSilent() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let zone = "SplitGroup-Baseline"
        // La CANÓNICA no lleva la marca; la gemela (born-remote) sí, y está DENTRO de la ventana.
        makeGroup(zone: zone, isBackendGroup: true,
                  createdAt: Date(timeIntervalSince1970: 1_000), context: context)
        let born = makeGroup(zone: zone, isBackendGroup: true,
                             createdAt: Date(timeIntervalSince1970: 2_000), context: context)
        born.initialMemberImportStartedAt = .now
        try context.save()

        let collector = GroupsSyncClientTests.ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        try apply(
            GroupPulledDelta(
                entityType: "group_members", groupID: zone,   // tabla Postgres, no clase (applyDelta:2155)
                rawSyncID: "mk-ana", syncID: nil, op: .upsert,
                fields: ["member_key": .string("mk-ana"), "display_name": .string("Ana"),
                         "status": .string("active")],
                fieldHlcs: [:], hlc: "2026-08-03T00:00:00.000Z-0000-00000000000000fb",
                serverSeq: 4, schemaVersion: 1),
            client: client, context: context)

        #expect(collector.sets.allSatisfy { $0.newMembers.isEmpty },
                "el import inicial no silenció la notificación: el baseline se leyó de una sola fila")
    }

    // MARK: - Source-scan (lo que ningún test de comportamiento puede fijar)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func clientSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"),
            encoding: .utf8)
    }

    private static func body(_ source: String, from signature: String) -> String? {
        guard let start = source.range(of: signature) else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    private func ") ?? rest.range(of: "\n    // MARK:") else {
            return nil
        }
        return String(rest[..<end.lowerBound])
    }

    private static let metaSignature = "private func applyGroupMeta("

    /// **El invariante que este fix dejó SIN observar, y por qué se mide aquí.** La cascada del tombstone
    /// corre bajo `outboxSaveAuthor` (va dentro del `saveWithAuthor` de `applyPulledPage` y no hace `save()`
    /// propio); sacarla de ahí la dejaría bajo el autor por DEFECTO y el drain traduciría esos borrados a
    /// tombstones de `split_expenses`/`split_shares`/`split_settlements`, que el servidor aplica con
    /// `is_group_writer` — los gastos desaparecerían para TODOS los miembros.
    ///
    /// Ese invariante lo cubría `GroupsSyncClientTests.apply_groupTombstone_sweepsWholeZone_soDrainEmitsNothing`
    /// con un duplicado a propósito, para que la fila superviviente mantuviera la zona dentro de
    /// `backendGroupZoneIDs` y la fuga fuera observable. **Al barrer TODAS las filas, la zona sale del set
    /// SIEMPRE y esa fuga deja de ser alcanzable ⇒ el test dejó de probar el autor: MEDIDO, con la cascada
    /// movida al autor por defecto y un `save()` propio, pasa VERDE.** No se borra cobertura: se traslada
    /// aquí, donde sí se puede afirmar.
    ///
    /// MUTACIÓN: dar a `applyGroupMeta` un `context.save()`, o tocar `context.author` dentro, deja esto rojo.
    @Test func sourceScan_cascadeStaysUnderTheOutboxAuthor() throws {
        let source = try Self.clientSource()
        let meta = try #require(Self.body(source, from: Self.metaSignature),
                                "cambió la firma o el cierre de applyGroupMeta: el escáner no tiene sujeto")
        #expect(meta.contains("try cascadeDeleteGroupRows(zoneID: delta.groupID, context: context)"),
                "la cascada ya no se invoca desde applyGroupMeta")
        #expect(!meta.contains("context.save()"),
                "applyGroupMeta hace su propio save: sus borrados saldrían del saveWithAuthor de la página")
        #expect(!meta.contains("context.author"),
                "applyGroupMeta toca el autor del contexto: el drain dejaría de filtrar sus borrados")
        let cascade = try #require(Self.body(source, from: "private func cascadeDeleteGroupRows(zoneID: String, context: ModelContext) throws {"))
        #expect(!cascade.contains("context.save()"), "la cascada hace su propio save")
        // Un solo call-site: si aparece otro fuera del `saveWithAuthor`, este conteo lo delata.
        #expect(source.components(separatedBy: "try cascadeDeleteGroupRows(").count - 1 == 1,
                "la cascada tiene más de un call-site: comprueba que el nuevo va dentro del saveWithAuthor")
    }

    /// El barrido del grupo va ANTES del cascade de las hijas, molde de `GroupZoneCacheGate.deleteCache` y
    /// `GroupService.performLocalCleanupAndDelete`. Hoy es indiferente —todo va dentro del mismo
    /// `saveWithAuthor`, cuyo `catch` hace `rollback()`, así que no hay commit intermedio observable— y por
    /// eso ningún test de comportamiento puede fijarlo. Se fija igual para que el invariante no dependa de
    /// que ese `rollback()` siga ahí.
    ///
    /// MUTACIÓN: intercambiar las dos líneas → rojo, y los tests de comportamiento siguen VERDES.
    @Test func sourceScan_groupRowsAreDeletedBeforeTheChildren() throws {
        let meta = try #require(Self.body(try Self.clientSource(), from: Self.metaSignature))
        let deleteRows = try #require(meta.range(of: "for row in rows { context.delete(row) }"),
                                      "el tombstone ya no barre TODAS las filas de la zona")
        let cascade = try #require(meta.range(of: "try cascadeDeleteGroupRows(zoneID:"))
        #expect(deleteRows.lowerBound < cascade.lowerBound)
    }

    /// El fetch de la zona no puede volver a resolver con una fila arbitraria. `fetchLimit = 1` sobre
    /// `SplitGroup` es exactamente lo que se retiró; el `sortBy` por `createdAt` es lo que alinea la fila
    /// CANÓNICA con la que resuelve `GroupService.group(for:)` — sin él, el deep-link de una notificación
    /// puede abrir una fila distinta de la que la UI muestra.
    ///
    /// MUTACIÓN: reintroducir `fetchLimit = 1`, o quitar el `sortBy`, deja esto rojo.
    @Test func sourceScan_zoneFetchIsOrderedAndUnbounded() throws {
        let source = try Self.clientSource()
        let fetch = try #require(
            Self.body(source, from: "private func fetchSplitGroupRows(zoneID: String, context: ModelContext) throws -> [SplitGroup] {"),
            "cambió la firma de fetchSplitGroupRows")
        #expect(fetch.contains("sortBy: [SortDescriptor(\\.createdAt, order: .forward)]"),
                "la fila canónica de la zona volvería a elegirla el store")
        #expect(!fetch.contains("fetchLimit"), "el fetch de la zona volvió a truncarse a una fila")
        #expect(!source.contains("func fetchSplitGroup(zoneID:"),
                "volvió el helper que devolvía UNA fila arbitraria de la zona")
    }
}
