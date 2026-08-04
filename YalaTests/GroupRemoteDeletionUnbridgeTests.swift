//
//  GroupRemoteDeletionUnbridgeTests.swift
//  YalaTests
//
//  Bug device 2026-08-02 (build 9, producción, dos teléfonos): el device que BORRA un gasto o una
//  liquidación de grupo limpia bien su puente personal (camino local → `unbridgeExpense` /
//  `unbridgeSettlement`); el device que RECIBE el tombstone borraba la fila del grupo y dejaba la
//  `TransactionItem` viva. Dinero fantasma en Panel, presupuestos y reportes, y ATRAPADO: tocarlo llevaba
//  al grupo, donde ya no existía.
//
//  Tres piezas, tres bloques aquí:
//    1. hacia delante — los dos canales des-puentean al aplicar un tombstone (backend y CloudKit)
//    2. reparación — el barrido del arranque resuelve las huérfanas que ya están en los teléfonos
//    3. red de seguridad — una TX cuyo puntero no resuelve NO queda en solo-lectura
//  + cableado (source-scan): los seams de DEBUG entran por debajo del call-site real.
//
//  Harness ON-DISK con los 3 stores (molde `GroupsSyncClientTests` / `GroupBridgeCaseBPreserveTests`): el
//  puente cruza stores —lee Grupos y escribe el PERSONAL— y `makeTestContext()` no sirve para eso.
//

import CloudKit
import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Infra compartida

@MainActor
private enum UnbridgeHarness {

    static func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GRDU-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    static func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GRDU-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GRDU-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GRDU-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    /// Grupo ASENTADO del canal backend: `initialMemberImportStartedAt == nil` es lo que el barrido exige
    /// para creerse que el corpus del grupo ya bajó a este device.
    @discardableResult
    static func makeGroup(zoneID: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zoneID
        g.isBackendGroup = true
        g.initialMemberImportStartedAt = nil
        context.insert(g)
        return g
    }

    static func makeAccount(_ context: ModelContext, isSystem: Bool) -> Account {
        let a = Account(
            name: isSystem ? "Grupos" : "Efectivo", currencyCode: "USD", colorHex: "#111111",
            iconName: "banknote", type: "cash", isSystemAccount: isSystem)
        context.insert(a)
        return a
    }

    /// Una `TransactionItem` puenteada, tal cual la deja el bridge (los tres punteros a la vez).
    @discardableResult
    static func makeBridgedTx(
        expenseID: UUID? = nil, settlementID: UUID? = nil, zone: String, amount: Double = 10,
        accountIsSystem: Bool = true, context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: .now, amount: amount, currencyCode: "USD",
            account: makeAccount(context, isSystem: accountIsSystem))
        tx.splitExpenseID = expenseID?.uuidString
        tx.splitSettlementID = settlementID?.uuidString
        tx.splitGroupZoneID = zone
        context.insert(tx)
        return tx
    }

    @discardableResult
    static func makeBridgedDraft(
        expenseID: UUID? = nil, settlementID: UUID? = nil, zone: String, context: ModelContext
    ) -> InboxDraft {
        let d = InboxDraft(
            note: "Cena", amount: 10, date: .now,
            sourceType: expenseID != nil ? .groupExpense : .groupSettlement,
            needsUserInput: [DraftInputRequirement.account],
            splitExpenseID: expenseID?.uuidString, splitGroupZoneID: zone,
            splitSettlementID: settlementID?.uuidString)
        context.insert(d)
        return d
    }

    static func txCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<TransactionItem>())
    }

    static func draftCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<InboxDraft>())
    }

    /// Ejecuta `body` con el bridge apuntando a este contexto y lo devuelve a «sin contexto» al salir —
    /// `GroupTransactionBridge` es singleton y su estado se filtraría al test siguiente.
    static func withBridge(_ context: ModelContext, _ body: () throws -> Void) rethrows {
        GroupTransactionBridge.shared.setContext(context)
        defer { GroupTransactionBridge.shared._testClearContext() }
        try body()
    }

    // MARK: - Frescura del canal (gate del barrido)

    /// Señales de SESIÓN de los dos canales. El default es el estado que hace posible barrer en el canal
    /// backend —pull AGOTADO—, que es donde viven los grupos de `makeGroup`; se pasa explícito para que el
    /// estado de los singletons no decida el resultado de un test.
    static func signals(
        backendPullCompleted: Bool = true,
        cloudKitAllEngines: Bool = false,
        failedZones: Set<String> = []
    ) -> GroupChannelFreshness.ChannelSignals {
        GroupChannelFreshness.ChannelSignals(
            backendPullCompleted: backendPullCompleted,
            cloudKitAllEnginesCompletedFetchCycle: cloudKitAllEngines,
            cloudKitZoneFetchFailed: { failedZones.contains($0) })
    }

    /// Deja el cursor del pull listando estas zonas — es lo que el servidor devuelve para todo grupo del
    /// alcance del usuario tras un pull agotado, HAYA o no deltas. Sin esto, una zona backend nunca es
    /// fresca por más que el pull haya completado.
    static func markZonesPulled(_ zones: [String], context: ModelContext) throws {
        var descriptor = FetchDescriptor<GroupSyncCursor>()
        descriptor.fetchLimit = 1
        let cursor = try context.fetch(descriptor).first ?? {
            let fresh = GroupSyncCursor()
            context.insert(fresh)
            return fresh
        }()
        let pairs = zones.map { "\"\($0)\":1" }.joined(separator: ",")
        cursor.groupCursorsJSON = "{\(pairs)}"
        try context.save()
    }

    /// El estado completo de «el canal backend entregó esta zona»: cursor + señal de pull agotado.
    static func makeSettledBackendZone(_ zoneID: String, context: ModelContext) throws {
        makeGroup(zoneID: zoneID, context: context)
        try markZonesPulled([zoneID], context: context)
    }
}

// MARK: - Pieza 1 · canal BACKEND (`GroupsSyncClient.applyPulledPage`)

@Suite("Tombstone remoto · des-puenteo en el canal backend", .serialized)
@MainActor
struct RemoteTombstoneUnbridgeBackendTests {

    private func expenseDelta(id: UUID, op: SyncOutboxOp, group: String = "SplitGroup-A", serverSeq: Int64 = 3)
        -> GroupPulledDelta
    {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitExpense.table, groupID: group, rawSyncID: id.uuidString, syncID: id,
            op: op,
            fields: [
                "expense_description": .string("Cena"), "amount": .number(20),
                "currency_code": .string("USD"), "paid_by_member_key": .string("member-1"),
                "split_type": .string("equal"),
            ],
            fieldHlcs: [:], hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000ff",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    private func settlementDelta(id: UUID, op: SyncOutboxOp, group: String = "SplitGroup-A", serverSeq: Int64 = 3)
        -> GroupPulledDelta
    {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitSettlement.table, groupID: group, rawSyncID: id.uuidString, syncID: id,
            op: op,
            fields: [
                "from_member_key": .string("member-1"), "to_member_key": .string("member-2"),
                "amount": .number(25), "currency_code": .string("USD"),
            ],
            fieldHlcs: [:], hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000fe",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// El caso REPORTADO: A borra un gasto de 20 al 50/50, B se quedaba con un fantasma de 10.
    @Test func expenseTombstone_removesBridgedTransactionAndDraft() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let expenseID = UUID()
        let expense = SplitExpense(
            groupZoneID: "SplitGroup-A", amount: 20, currencyCode: "USD",
            expenseDescription: "Cena", paidByMemberID: "member-1")
        expense.id = expenseID
        context.insert(expense)
        UnbridgeHarness.makeBridgedTx(expenseID: expenseID, zone: "SplitGroup-A", amount: 10, context: context)
        UnbridgeHarness.makeBridgedDraft(expenseID: expenseID, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(deltas: [expenseDelta(id: expenseID, op: .tombstone)], cursors: [:],
                                memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try UnbridgeHarness.txCount(context) == 0, "la TransactionItem puenteada sobrevivió al tombstone")
        #expect(try UnbridgeHarness.draftCount(context) == 0)
    }

    /// Confirmado en device el 2026-08-02 y BIDIRECCIONAL: da igual quién borre, el que recibe el
    /// tombstone se quedaba con el movimiento personal de la liquidación.
    @Test func settlementTombstone_removesBridgedTransaction() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let settlementID = UUID()
        let settlement = SplitSettlement(
            groupZoneID: "SplitGroup-A", fromMemberID: "member-1", toMemberID: "member-2",
            amount: 25, currencyCode: "USD")
        settlement.id = settlementID
        context.insert(settlement)
        UnbridgeHarness.makeBridgedTx(
            settlementID: settlementID, zone: "SplitGroup-A", amount: 25, context: context)
        UnbridgeHarness.makeBridgedDraft(settlementID: settlementID, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(deltas: [settlementDelta(id: settlementID, op: .tombstone)], cursors: [:],
                                memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 0)
        #expect(try UnbridgeHarness.txCount(context) == 0,
                "la TransactionItem de la liquidación sobrevivió al tombstone")
        #expect(try UnbridgeHarness.draftCount(context) == 0)
    }

    /// Un upsert NO des-puentea: el gasto sigue vivo y su transacción también.
    @Test func expenseUpsert_keepsBridgedTransaction() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let expenseID = UUID()
        UnbridgeHarness.makeBridgedTx(expenseID: expenseID, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(deltas: [expenseDelta(id: expenseID, op: .upsert)], cursors: [:],
                                memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    /// Crear y borrar el mismo gasto dentro de UNA página: gana el tombstone. Sin la limpieza cruzada se
    /// armaría además la intención de puentear un gasto que ya no existe.
    @Test func upsertThenTombstoneInSamePage_tombstoneWins() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let expenseID = UUID()
        UnbridgeHarness.makeBridgedTx(expenseID: expenseID, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [expenseDelta(id: expenseID, op: .upsert),
                             expenseDelta(id: expenseID, op: .tombstone, serverSeq: 4)],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try UnbridgeHarness.txCount(context) == 0)
    }

    /// El GRUPO entero borrado remotamente CONGELA en vez de destruir: los gastos ocurrieron y el dinero
    /// salió de una cuenta real. Y el congelado tiene que correr aunque el `SplitGroup` ya no exista — el
    /// apply acaba de borrarlo, por eso `drainSoftDeleteFreeze` va por zona y no por objeto.
    @Test func groupTombstone_freezesInsteadOfDestroying() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 40, accountIsSystem: false, context: context)
        let virtual = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 10, accountIsSystem: true, context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [GroupPulledDelta(
                        entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-A",
                        rawSyncID: "SplitGroup-A", syncID: nil, op: .tombstone, fields: [:], fieldHlcs: [:],
                        hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000fd", serverSeq: 5,
                        schemaVersion: 1)],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        // NADA se borra: las dos transacciones siguen ahí con su dinero.
        #expect(try UnbridgeHarness.txCount(context) == 2)
        // La de cuenta real queda LIBERADA (editable por el usuario).
        #expect(real.splitExpenseID == nil)
        #expect(real.splitGroupZoneID == nil)
        #expect(real.amount == 40)
        // La virtual se preserva intacta: es el rastro «presté / debo» de gastos que sí ocurrieron.
        #expect(virtual.splitExpenseID != nil)
    }

    /// El grupo desaparece y sus HIJAS se van con él. Cuelgan del string plano `groupZoneID` —sin
    /// `@Relationship`— así que SwiftData no cascadea nada solo, y el camino remoto solo borraba la fila del
    /// grupo: `SplitMember`/`SplitShare`/`SplitExpense`/`SplitSettlement` quedaban vivos apuntando a una
    /// zona que ya no existe. El camino LOCAL sí lo hace desde siempre (`cascadeDeleteGroupData`).
    ///
    /// MUTACIÓN: quitar la llamada a `cascadeDeleteGroupRows` deja las cuatro primeras aserciones en rojo.
    @Test func groupTombstone_cascadeDeletesChildRows() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)
        // Zona VECINA: el barrido va por zona y no debe pasarse de largo.
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-B", context: context)

        for zone in ["SplitGroup-A", "SplitGroup-B"] {
            context.insert(SplitMember(groupZoneID: zone, displayName: "Jür"))
            let expense = SplitExpense(
                groupZoneID: zone, amount: 20, currencyCode: "USD",
                expenseDescription: "Cena", paidByMemberID: "member-1")
            context.insert(expense)
            context.insert(SplitShare(
                expenseID: expense.id, memberID: "member-1", amount: 10, groupZoneID: zone))
            context.insert(SplitSettlement(
                groupZoneID: zone, fromMemberID: "member-1", toMemberID: "member-2", amount: 5))
        }
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [GroupPulledDelta(
                        entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-A",
                        rawSyncID: "SplitGroup-A", syncID: nil, op: .tombstone, fields: [:], fieldHlcs: [:],
                        hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000fb", serverSeq: 6,
                        schemaVersion: 1)],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)
        }

        func countInZone<T: PersistentModel>(_ type: T.Type, _ predicate: Predicate<T>) throws -> Int {
            try context.fetchCount(FetchDescriptor<T>(predicate: predicate))
        }
        #expect(try countInZone(SplitMember.self, #Predicate { $0.groupZoneID == "SplitGroup-A" }) == 0)
        #expect(try countInZone(SplitShare.self, #Predicate { $0.groupZoneID == "SplitGroup-A" }) == 0)
        #expect(try countInZone(SplitExpense.self, #Predicate { $0.groupZoneID == "SplitGroup-A" }) == 0)
        #expect(try countInZone(SplitSettlement.self, #Predicate { $0.groupZoneID == "SplitGroup-A" }) == 0)

        // La zona vecina, intacta — grupo incluido.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try countInZone(SplitMember.self, #Predicate { $0.groupZoneID == "SplitGroup-B" }) == 1)
        #expect(try countInZone(SplitShare.self, #Predicate { $0.groupZoneID == "SplitGroup-B" }) == 1)
        #expect(try countInZone(SplitExpense.self, #Predicate { $0.groupZoneID == "SplitGroup-B" }) == 1)
        #expect(try countInZone(SplitSettlement.self, #Predicate { $0.groupZoneID == "SplitGroup-B" }) == 1)
    }

    /// La cascada NO cambia el criterio del grupo, que es CONGELAR y no destruir: las transacciones
    /// personales siguen su camino (`freezeZones` → `drainSoftDeleteFreeze`), que trabaja por zona sobre el
    /// store PERSONAL y no lee ninguna fila `Split*`. Si alguien mete los gastos cascadeados en el
    /// des-puenteo, la de cuenta real —dinero que salió de verdad— desaparece.
    @Test func groupTombstone_cascade_stillFreezesInsteadOfUnbridging() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let expenseID = UUID()
        let expense = SplitExpense(
            groupZoneID: "SplitGroup-A", amount: 40, currencyCode: "USD",
            expenseDescription: "Hotel", paidByMemberID: "member-1")
        expense.id = expenseID
        context.insert(expense)
        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: expenseID, zone: "SplitGroup-A", amount: 40, accountIsSystem: false, context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [GroupPulledDelta(
                        entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-A",
                        rawSyncID: "SplitGroup-A", syncID: nil, op: .tombstone, fields: [:], fieldHlcs: [:],
                        hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000fa", serverSeq: 7,
                        schemaVersion: 1)],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0, "la hija se fue con el grupo")
        #expect(try UnbridgeHarness.txCount(context) == 1, "pero el dinero de la cuenta real se preserva")
        #expect(real.splitExpenseID == nil, "liberado, no borrado")
        #expect(real.amount == 40)
    }

    /// EL CHOQUE DE CRITERIOS: el servidor cascadea, así que una misma página puede traer el tombstone del
    /// GRUPO y los de sus gastos. El grupo dice «congela» y el gasto dice «destruye», sobre las mismas
    /// filas. Gana el congelado para la de cuenta real —dinero que salió de verdad— y el des-puenteo se
    /// lleva la virtual, que sin gasto ni grupo detrás es justo el fantasma. Lo sostiene el ORDEN
    /// (`drainSoftDeleteFreeze` antes que `drainUnbridge`); invertirlo destruye la real.
    @Test func groupAndExpenseTombstonesTogether_freezeWinsOverDestroy() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let realExpenseID = UUID()
        let virtualExpenseID = UUID()
        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: realExpenseID, zone: "SplitGroup-A", amount: 40, accountIsSystem: false,
            context: context)
        UnbridgeHarness.makeBridgedTx(
            expenseID: virtualExpenseID, zone: "SplitGroup-A", amount: 10, accountIsSystem: true,
            context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [
                        expenseDelta(id: realExpenseID, op: .tombstone),
                        expenseDelta(id: virtualExpenseID, op: .tombstone, serverSeq: 4),
                        GroupPulledDelta(
                            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-A",
                            rawSyncID: "SplitGroup-A", syncID: nil, op: .tombstone, fields: [:],
                            fieldHlcs: [:], hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000fc",
                            serverSeq: 5, schemaVersion: 1),
                    ],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)
        }

        let survivors = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(survivors.count == 1, "el congelado tenía que preservar la transacción de cuenta real")
        #expect(survivors.first?.amount == 40)
        #expect(real.splitExpenseID == nil, "y dejarla liberada, editable por el usuario")
        #expect(real.splitGroupZoneID == nil)
    }

    /// El tombstone de OTRO gasto no se lleva la transacción de éste.
    @Test func tombstoneOfAnotherExpense_leavesThisOneAlone() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)

        let mine = UUID()
        UnbridgeHarness.makeBridgedTx(expenseID: mine, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let client = GroupsSyncClient()
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(deltas: [expenseDelta(id: UUID(), op: .tombstone)], cursors: [:],
                                memberships: []),
                cursor: cursor, context: context)
        }

        #expect(try UnbridgeHarness.txCount(context) == 1)
    }
}

// MARK: - Pieza 1 · canal CLOUDKIT (`SplitSyncManager.applyRemoteDeletion`)

@Suite("Tombstone remoto · des-puenteo en el canal CloudKit", .serialized)
@MainActor
struct RemoteTombstoneUnbridgeCloudKitTests {

    private func recordID(_ modelID: UUID, zone: String) -> CKRecord.ID {
        CKConstants.recordID(
            for: modelID,
            in: CKRecordZone.ID(zoneName: zone, ownerName: CKCurrentUserDefaultName))
    }

    /// El canal viejo arrastraba el mismo defecto desde antes del Modo Nube: le pasa HOY a los usuarios
    /// que no están en el rollout.
    @Test func expenseDeletion_accumulatesAndUnbridges() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)

        let expenseID = UUID()
        let expense = SplitExpense(
            groupZoneID: "SplitGroup-B", amount: 20, currencyCode: "USD",
            expenseDescription: "Cena", paidByMemberID: "member-1")
        expense.id = expenseID
        context.insert(expense)
        UnbridgeHarness.makeBridgedTx(expenseID: expenseID, zone: "SplitGroup-B", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let accumulated = SplitSyncManager.shared._testApplyRemoteDeletion(
                recordID: recordID(expenseID, zone: "SplitGroup-B"),
                recordType: CKConstants.RecordType.splitExpense, context: context)
            #expect(accumulated.expenseIDs == [expenseID])
            #expect(accumulated.settlementIDs.isEmpty)
            try GroupTransactionBridge.shared.unbridgeDeletedRemotely(
                expenseIDs: accumulated.expenseIDs, settlementIDs: accumulated.settlementIDs)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try UnbridgeHarness.txCount(context) == 0)
    }

    @Test func settlementDeletion_accumulatesAndUnbridges() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)

        let settlementID = UUID()
        let settlement = SplitSettlement(
            groupZoneID: "SplitGroup-B", fromMemberID: "m1", toMemberID: "m2",
            amount: 25, currencyCode: "USD")
        settlement.id = settlementID
        context.insert(settlement)
        UnbridgeHarness.makeBridgedTx(
            settlementID: settlementID, zone: "SplitGroup-B", amount: 25, context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let accumulated = SplitSyncManager.shared._testApplyRemoteDeletion(
                recordID: recordID(settlementID, zone: "SplitGroup-B"),
                recordType: CKConstants.RecordType.splitSettlement, context: context)
            #expect(accumulated.settlementIDs == [settlementID])
            #expect(accumulated.expenseIDs.isEmpty)
            try GroupTransactionBridge.shared.unbridgeDeletedRemotely(
                expenseIDs: accumulated.expenseIDs, settlementIDs: accumulated.settlementIDs)
        }

        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 0)
        #expect(try UnbridgeHarness.txCount(context) == 0)
    }

    /// El borrado de una `SplitShare` no acumula nada: no tiene puente propio.
    @Test func shareDeletion_accumulatesNothing() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)

        let accumulated = SplitSyncManager.shared._testApplyRemoteDeletion(
            recordID: recordID(UUID(), zone: "SplitGroup-B"),
            recordType: CKConstants.RecordType.splitShare, context: context)
        #expect(accumulated.expenseIDs.isEmpty)
        #expect(accumulated.settlementIDs.isEmpty)
    }
}

// MARK: - Pieza 1 bis · el lote no guarda si no hay nada que borrar

@Suite("Des-puenteo en lote · forma de la operación", .serialized)
@MainActor
struct UnbridgeDeletedRemotelyTests {

    /// Idempotente: pasarle IDs sin nada colgando no borra ni escribe. Es lo que permite acumular TODOS
    /// los tombstones de la página sin mirar si la fila local existía.
    @Test func unknownIDs_areNoOp() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeBridgedTx(expenseID: UUID(), zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let result = try GroupTransactionBridge.shared.unbridgeDeletedRemotely(
                expenseIDs: [UUID()], settlementIDs: [UUID()])
            #expect(result.transactions == 0)
            #expect(result.drafts == 0)
        }
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    /// Un solo `save()` para toda la página, y se lleva las DOS familias a la vez.
    @Test func mixedBatch_removesBothFamilies() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        let e1 = UUID(), e2 = UUID(), s1 = UUID()
        UnbridgeHarness.makeBridgedTx(expenseID: e1, zone: "SplitGroup-A", context: context)
        UnbridgeHarness.makeBridgedTx(expenseID: e2, zone: "SplitGroup-A", context: context)
        UnbridgeHarness.makeBridgedTx(settlementID: s1, zone: "SplitGroup-A", context: context)
        try context.save()

        try UnbridgeHarness.withBridge(context) {
            let result = try GroupTransactionBridge.shared.unbridgeDeletedRemotely(
                expenseIDs: [e1, e2], settlementIDs: [s1])
            #expect(result.transactions == 3)
        }
        #expect(try UnbridgeHarness.txCount(context) == 0)
    }
}

// MARK: - Pieza 2 · barrido de huérfanas

@Suite("Barrido de transacciones puenteadas huérfanas", .serialized)
@MainActor
struct OrphanedBridgedTxSweeperTests {

    // --- decisión pura ---

    @Test func realAccountOrphan_isReleasedNotDeleted() {
        let action = OrphanedBridgedTxSweeper.decide(.init(
            expensePointerIsOrphan: true, settlementPointerIsOrphan: false,
            accountIsSystem: false, zoneEvidenceIsFresh: true))
        #expect(action == .releasePointers)
    }

    @Test func virtualOrphan_isDeleted() {
        let action = OrphanedBridgedTxSweeper.decide(.init(
            expensePointerIsOrphan: true, settlementPointerIsOrphan: false,
            accountIsSystem: true, zoneEvidenceIsFresh: true))
        #expect(action == .deleteVirtual)
    }

    @Test func resolvedPointer_isUntouched() {
        let action = OrphanedBridgedTxSweeper.decide(.init(
            expensePointerIsOrphan: false, settlementPointerIsOrphan: false,
            accountIsSystem: true, zoneEvidenceIsFresh: true))
        #expect(action == nil)
    }

    /// EL guard que evita destruir datos buenos: sin evidencia de que el grupo bajó a este device, una
    /// transacción cuyo gasto todavía no llegó parece huérfana y no lo es.
    @Test func unsettledZone_isNeverTouched() {
        let action = OrphanedBridgedTxSweeper.decide(.init(
            expensePointerIsOrphan: true, settlementPointerIsOrphan: false,
            accountIsSystem: true, zoneEvidenceIsFresh: false))
        #expect(action == nil)
    }

    // --- barrido sobre el store ---

    @Test func sweep_deletesVirtualOrphan_andReleasesRealOne() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        // Huérfanas: sus gastos nunca se insertan.
        let virtual = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 10, accountIsSystem: true, context: context)
        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 40, accountIsSystem: false, context: context)
        // Sana: su gasto SÍ existe.
        let liveID = UUID()
        let live = SplitExpense(
            groupZoneID: "SplitGroup-A", amount: 30, currencyCode: "USD",
            expenseDescription: "Taxi", paidByMemberID: "member-1")
        live.id = liveID
        context.insert(live)
        UnbridgeHarness.makeBridgedTx(expenseID: liveID, zone: "SplitGroup-A", context: context)
        try context.save()

        let virtualIsGone = virtual.isDeleted
        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())

        #expect(outcome.deleted == 1)
        #expect(outcome.released == 1)
        #expect(virtualIsGone == false)  // no lo estaba antes de barrer
        #expect(try UnbridgeHarness.txCount(context) == 2, "la virtual huérfana debía desaparecer")
        // La real conserva el dinero y recupera el control: sin punteros es una transacción normal.
        #expect(real.splitExpenseID == nil)
        #expect(real.splitSettlementID == nil)
        #expect(real.splitGroupZoneID == nil)
        #expect(real.amount == 40)
        // La sana no se toca.
        let survivors = try context.fetch(FetchDescriptor<TransactionItem>())
        #expect(survivors.contains { $0.splitExpenseID == liveID.uuidString })
    }

    /// El lado LIQUIDACIÓN del barrido: mismo trato, y su puntero se resuelve contra otra tabla.
    @Test func sweep_handlesOrphanSettlements() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        UnbridgeHarness.makeBridgedTx(
            settlementID: UUID(), zone: "SplitGroup-A", amount: 25, accountIsSystem: true, context: context)
        let real = UnbridgeHarness.makeBridgedTx(
            settlementID: UUID(), zone: "SplitGroup-A", amount: 60, accountIsSystem: false, context: context)
        // Sana: su liquidación existe.
        let liveID = UUID()
        let live = SplitSettlement(
            groupZoneID: "SplitGroup-A", fromMemberID: "m1", toMemberID: "m2", amount: 15,
            currencyCode: "USD")
        live.id = liveID
        context.insert(live)
        UnbridgeHarness.makeBridgedTx(
            settlementID: liveID, zone: "SplitGroup-A", amount: 15, context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(outcome.deleted == 1)
        #expect(outcome.released == 1)
        #expect(real.splitSettlementID == nil)
        #expect(real.amount == 60)
        #expect(try UnbridgeHarness.txCount(context) == 2)
    }

    /// Los BORRADORES huérfanos también se reparan: uno con puntero muerto vuelve a ser manual, con su
    /// contenido intacto, en vez de quedarse mandando al usuario a un grupo donde el gasto no existe.
    @Test func sweep_convertsOrphanDraftToManual() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        let draft = UnbridgeHarness.makeBridgedDraft(
            expenseID: UUID(), zone: "SplitGroup-A", context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(outcome.draftsConverted == 1)
        #expect(draft.sourceTypeRaw == DraftSourceType.manual.rawValue)
        #expect(draft.splitExpenseID == nil)
        #expect(draft.splitGroupZoneID == nil)
        #expect(draft.amount == 10, "el borrador conserva lo que el usuario ya tenía")
        #expect(try UnbridgeHarness.draftCount(context) == 1)
    }

    /// El puntero de clasificación redundante se BORRA, no se convierte — y eso solo funciona si el plan
    /// se calcula ANTES de mutar las transacciones. Convertido a manual, aprobarlo insertaría una
    /// transacción NUEVA junto a la que el barrido acaba de liberar: el gasto DOS veces en Panel,
    /// presupuestos y reportes. Sería una regresión respecto a no tener barrido.
    @Test func sweep_deletesRedundantPointerDraft_notConvertsIt() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        // Caso A: transacción de cuenta REAL + su draft-puntero (solo pide subcategoría), ambos huérfanos.
        let expenseID = UUID()
        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: expenseID, zone: "SplitGroup-A", amount: 40, accountIsSystem: false, context: context)
        let pointerDraft = InboxDraft(
            note: "Cena", amount: 40, date: .now, sourceType: .groupExpense,
            needsUserInput: [DraftInputRequirement.subcategory],
            splitExpenseID: expenseID.uuidString, splitGroupZoneID: "SplitGroup-A")
        context.insert(pointerDraft)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())

        #expect(outcome.draftsDeleted == 1,
                "el puntero redundante debía BORRARSE; convertido a manual duplicaría la transacción")
        #expect(outcome.draftsConverted == 0)
        #expect(try UnbridgeHarness.draftCount(context) == 0)
        // La transacción sobrevive liberada: el usuario la clasifica editándola directamente.
        #expect(outcome.released == 1)
        #expect(real.amount == 40)
        #expect(real.splitExpenseID == nil)
    }

    /// Un borrador cuyo gasto SÍ existe no se toca.
    @Test func sweep_leavesLiveDraftAlone() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        let liveID = UUID()
        let live = SplitExpense(
            groupZoneID: "SplitGroup-A", amount: 20, currencyCode: "USD",
            expenseDescription: "Cena", paidByMemberID: "m1")
        live.id = liveID
        context.insert(live)
        let draft = UnbridgeHarness.makeBridgedDraft(
            expenseID: liveID, zone: "SplitGroup-A", context: context)
        try context.save()

        #expect(OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals()).isEmpty)
        #expect(draft.sourceTypeRaw == DraftSourceType.groupExpense.rawValue)
        #expect(draft.splitExpenseID == liveID.uuidString)
    }

    /// Correrlo dos veces no hace nada la segunda.
    @Test func sweep_isIdempotent() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", accountIsSystem: true, context: context)
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", accountIsSystem: false, context: context)
        try context.save()

        let first = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(first.isEmpty == false)

        let second = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(second.isEmpty, "el segundo barrido volvió a tocar filas: no es idempotente")
    }

    /// El guard de zona, medido sobre el store: mismo estado, pero el grupo aún poblándose.
    ///
    /// El canal se le da FRESCO a propósito (pull agotado + cursor listando la zona): así lo único que
    /// puede bloquear es `initialMemberImportStartedAt`, que es lo que este test existe para fijar. Sin esa
    /// precisión pasaría en verde por el motivo equivocado.
    @Test func sweep_skipsZoneStillImporting() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)
        let group = try #require(
            try context.fetch(FetchDescriptor<SplitGroup>()).first, "el grupo del harness no se insertó")
        group.initialMemberImportStartedAt = .now  // el pull todavía trae su contenido
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", accountIsSystem: true, context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(outcome.isEmpty)
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    /// Una zona sin `SplitGroup` local tampoco es evidencia: el grupo puede no haber bajado todavía.
    /// Igual que el anterior, con el canal fresco (el cursor SÍ lista la zona) para que lo que falte sea
    /// exactamente el grupo local.
    @Test func sweep_skipsUnknownZone() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        try UnbridgeHarness.markZonesPulled(["SplitGroup-Desconocida"], context: context)
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-Desconocida", accountIsSystem: true, context: context)
        try context.save()

        #expect(OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals()).isEmpty)
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    // MARK: - El gate de FRESCURA del canal (lo que el guard viejo no veía)

    /// **EL escenario del bug, y el que no existía.** Zona asentada desde hace semanas —el marcador de
    /// primer import está limpio y nada lo re-arma— con el canal de Grupos PARADO (kill-switch remoto,
    /// sesión Yala caducada o snapshot de remote-config ausente) y un gasto EN VUELO: su
    /// `TransactionItem` ya llegó por el espejo personal, su `SplitExpense` no ha llegado por ningún lado.
    ///
    /// El guard viejo (`zoneIsSettled`) decía «huérfana» y destruía: borraba la virtual, soltaba la de
    /// cuenta real, y las dos mutaciones se exportan por el espejo personal ⇒ el device que SÍ tiene el
    /// gasto pierde su transacción. Al bajar el gasto, `bridgeExpense` ya no encuentra `existingRealTx` y
    /// crea un draft Caso A: aprobarlo DUPLICA el gasto.
    @Test func sweep_settledZoneButChannelStopped_touchesNothing() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        // Zona conocida desde hace semanas: grupo asentado y su `group_id` en el cursor del pull.
        try UnbridgeHarness.makeSettledBackendZone("SplitGroup-A", context: context)

        let virtual = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 10, accountIsSystem: true, context: context)
        let real = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", amount: 40, accountIsSystem: false, context: context)
        UnbridgeHarness.makeBridgedDraft(expenseID: UUID(), zone: "SplitGroup-A", context: context)
        try context.save()

        // Canal PARADO: ningún pull agotó su entrega en esta sesión.
        let outcome = OrphanedBridgedTxSweeper.sweep(
            context: context, signals: UnbridgeHarness.signals(backendPullCompleted: false))

        #expect(outcome.isEmpty, "el barrido tocó filas sin evidencia de que el canal hubiera entregado")
        #expect(try UnbridgeHarness.txCount(context) == 2)
        #expect(try UnbridgeHarness.draftCount(context) == 1)
        #expect(virtual.isDeleted == false)
        #expect(real.splitExpenseID != nil, "la de cuenta real perdió su puntero: el device A pierde su TX")
        #expect(real.splitGroupZoneID == "SplitGroup-A")
    }

    /// El pull agotó su entrega, pero el cursor NO lista esta zona ⇒ el servidor no la enumera para este
    /// usuario y este canal no habla de ella. No es evidencia de que sus gastos no existan.
    @Test func sweep_backendPullCompletedButZoneNotInCursor_touchesNothing() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-A", context: context)
        try UnbridgeHarness.markZonesPulled(["SplitGroup-OTRA"], context: context)
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-A", accountIsSystem: true, context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(outcome.isEmpty)
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    /// Un grupo de CloudKit (`isBackendGroup == false`) no tiene entrada en el cursor del pull JAMÁS, así
    /// que su evidencia es la del otro canal: **ambos** engines con ≥1 ciclo de fetch entero. Con el canal
    /// CloudKit quieto no se toca nada aunque el backend haya completado su pull.
    @Test func sweep_cloudKitZone_needsBothEnginesFetchCycle() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        let group = UnbridgeHarness.makeGroup(zoneID: "SplitGroup-CK", context: context)
        group.isBackendGroup = false
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-CK", accountIsSystem: true, context: context)
        try context.save()

        // El pull backend completó, pero esta zona no es suya: irrelevante.
        #expect(OrphanedBridgedTxSweeper.sweep(
            context: context,
            signals: UnbridgeHarness.signals(cloudKitAllEngines: false)).isEmpty)
        #expect(try UnbridgeHarness.txCount(context) == 1)

        // Con los dos engines cerrados, la misma huérfana SÍ se repara.
        let outcome = OrphanedBridgedTxSweeper.sweep(
            context: context,
            signals: UnbridgeHarness.signals(backendPullCompleted: false, cloudKitAllEngines: true))
        #expect(outcome.deleted == 1)
        #expect(try UnbridgeHarness.txCount(context) == 0)
    }

    /// El testigo NEGATIVO por zona: el último `didFetchRecordZoneChanges` de esta zona llegó con error, así
    /// que su contenido no bajó — aunque los dos engines hayan cerrado su ciclo.
    @Test func sweep_cloudKitZone_withFailedZoneFetch_touchesNothing() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        let group = UnbridgeHarness.makeGroup(zoneID: "SplitGroup-CK", context: context)
        group.isBackendGroup = false
        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-CK", accountIsSystem: true, context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(
            context: context,
            signals: UnbridgeHarness.signals(
                cloudKitAllEngines: true, failedZones: ["SplitGroup-CK"]))
        #expect(outcome.isEmpty)
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }

    /// Una zona rezagada NO retiene la limpieza de las demás: el barrido decide por zona.
    @Test func sweep_repairsFreshZone_whileSparingStaleOne() throws {
        let dir = UnbridgeHarness.freshDir(); defer { UnbridgeHarness.cleanup(dir) }
        let context = try UnbridgeHarness.makeContext(dir)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-FRESCA", context: context)
        UnbridgeHarness.makeGroup(zoneID: "SplitGroup-REZAGADA", context: context)
        // El servidor solo enumera la primera.
        try UnbridgeHarness.markZonesPulled(["SplitGroup-FRESCA"], context: context)

        UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-FRESCA", accountIsSystem: true, context: context)
        let rezagada = UnbridgeHarness.makeBridgedTx(
            expenseID: UUID(), zone: "SplitGroup-REZAGADA", accountIsSystem: true, context: context)
        try context.save()

        let outcome = OrphanedBridgedTxSweeper.sweep(context: context, signals: UnbridgeHarness.signals())
        #expect(outcome.deleted == 1)
        #expect(rezagada.isDeleted == false)
        #expect(try UnbridgeHarness.txCount(context) == 1)
    }
}

// MARK: - Pieza 3 · una huérfana no queda en solo-lectura

@Suite("Policy de edición · puntero que no resuelve")
struct BridgedEditPolicyOrphanTests {

    private func shape(
        expense: Bool = true, settlement: Bool = false, accountIsSystem: Bool = true,
        resolves: Bool
    ) -> BridgedEditPolicy.TxShape {
        BridgedEditPolicy.TxShape(
            hasSplitExpenseID: expense, hasSplitSettlementID: settlement,
            accountIsNil: false, accountIsSystem: accountIsSystem,
            subcategoryIsSystem: true, hasPendingPointerDraft: false,
            pointerResolves: resolves)
    }

    /// El corazón de la pieza 3: sin gasto detrás no hay grupo que mande, así que el usuario recupera el
    /// control en vez de quedarse sin salida.
    @Test func orphanExpense_isFullyEditable() {
        let s = shape(resolves: false)
        #expect(BridgedEditPolicy.classify(s) == .notBridged)
        #expect(BridgedEditPolicy.canSave(BridgedEditPolicy.classify(s)))
        #expect(BridgedEditPolicy.canEditAccount(BridgedEditPolicy.classify(s)))
        #expect(BridgedEditPolicy.canEditSubcategoryAndTags(BridgedEditPolicy.classify(s)))
        #expect(BridgedEditPolicy.banner(s) == .none)
    }

    /// La liquidación huérfana es el caso más severo del bug: `.settlement` bloquea TODO campo personal.
    @Test func orphanSettlement_isFullyEditable() {
        let s = shape(expense: false, settlement: true, resolves: false)
        #expect(BridgedEditPolicy.classify(s) == .notBridged)
        #expect(BridgedEditPolicy.canSave(BridgedEditPolicy.classify(s)))
    }

    /// Con el puntero vivo, nada cambia respecto a antes.
    @Test func resolvedPointer_keepsItsRestrictions() {
        let s = shape(resolves: true)
        #expect(BridgedEditPolicy.classify(s) == .derivedVirtual)
        #expect(BridgedEditPolicy.canSave(BridgedEditPolicy.classify(s)) == false)
        #expect(BridgedEditPolicy.banner(s) == .editFromGroup)
    }

    /// El default preserva el comportamiento de quien no puede resolver el puntero.
    @Test func defaultShape_behavesAsBefore() {
        let s = BridgedEditPolicy.TxShape(
            hasSplitExpenseID: true, hasSplitSettlementID: false, accountIsNil: false,
            accountIsSystem: false, subcategoryIsSystem: false, hasPendingPointerDraft: false)
        #expect(BridgedEditPolicy.classify(s) == .caseAReal)
    }
}

// MARK: - Cableado de producción (source-scan)

/// Los seams `_testApplyRemoteDeletion` / `applyPulledPage` entran por DEBAJO de donde producción decide,
/// así que revertir el hunk que cablea el des-puenteo dejaría toda la suite de arriba en verde con el bug
/// de vuelta. Mismo patrón y misma razón que `GroupsPendingBridgeWiringTests` / `AttestWiringTests`.
@Suite("Des-puenteo remoto · cableado de producción (source-scan)")
struct RemoteUnbridgeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// El handler REAL del fetch de CloudKit drena lo acumulado. Ancla DENTRO del cuerpo del handler: que
    /// la función exista y llame a `unbridgeDeletedRemotely` en algún sitio se satisface sin ningún
    /// llamador.
    @Test func cloudKitFetchHandler_drainsTheUnbridge() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        let handler = try #require(
            src.components(separatedBy: "private func handleFetchedRecordZoneChanges").dropFirst().first,
            "El handler del fetch cambió de nombre; este scan dejó de medir nada.")
        let body = handler.components(separatedBy: "\n    private func ").first ?? ""
        #expect(body.contains("unbridgeDeletedRemotely("),
                """
                El handler del fetch de CloudKit dejó de des-puentear lo que borra. Las TransactionItem del \
                otro miembro vuelven a quedarse huérfanas, y NINGUNA celda de comportamiento se entera \
                porque todas entran por el seam de DEBUG.
                """)
        // Y solo con el batch persistido: su `save()` arrastraría filas Split* dirty bajo el autor por
        // defecto, que es justo lo que el drain de Grupos re-empuja al servidor. Se ancla en el GUARD
        // literal, no en el nombre: `body.contains("didPersistBatch")` lo satisface la declaración de la
        // variable aunque nadie la lea.
        #expect(body.contains("if didPersistBatch, !unbridgeExpenseIDs.isEmpty || !unbridgeSettlementIDs.isEmpty"),
                """
                El drenaje del canal CloudKit dejó de exigir que el save del batch hubiera tenido éxito. \
                Con el batch sin persistir, el `save()` del des-puenteo comitea las filas Split* dirty bajo \
                el autor por defecto y el drain las re-empuja al servidor con HLC fresco.
                """)
        // Y el ORDEN: el drenaje va DESPUÉS del save, no antes del bucle de deletions.
        let saveIndex = try #require(body.range(of: "try modelContext.save()")?.lowerBound)
        let drainIndex = try #require(body.range(of: "unbridgeDeletedRemotely(")?.lowerBound)
        #expect(drainIndex > saveIndex,
                "El des-puenteo se movió por encima del save del batch.")
    }

    /// El apply del canal backend drena post-save, después del `return false` del `catch` — un unbridge
    /// anterior al `rollback()` se llevaría la transacción de un gasto que sigue vivo.
    @Test func backendApply_drainsAfterTheSave() throws {
        let src = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        let apply = try #require(
            src.components(separatedBy: "func applyPulledPage(").dropFirst().first,
            "`applyPulledPage` cambió de nombre; este scan dejó de medir nada.")
        let body = apply.components(separatedBy: "\n    /// ").first ?? ""
        let drainIndex = try #require(body.range(of: "drainUnbridge(")?.lowerBound,
                                      "El apply del canal backend dejó de drenar el des-puenteo.")
        let catchIndex = try #require(body.range(of: "context.rollback()")?.lowerBound)
        #expect(drainIndex > catchIndex,
                "El drenaje se movió por encima del `catch`: un save fallido revierte el borrado del gasto.")
    }

    /// Las dos ramas de tombstone acumulan. Un `return` seco es exactamente la forma que tenía el bug.
    @Test func backendTombstoneBranches_accumulate() throws {
        let src = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        #expect(src.contains("unbridgeExpenseIDs.insert(id)"),
                "La rama de tombstone de gasto dejó de acumular el des-puenteo.")
        #expect(src.contains("unbridgeSettlementIDs.insert(id)"),
                "La rama de tombstone de liquidación dejó de acumular el des-puenteo.")
    }

    /// El barrido está cableado al arranque. Sin call-site sería una reparación que nunca corre — la
    /// familia de `AppAttestClient.ensureRegistered()`.
    @Test func sweeper_isWiredIntoBootstrap() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        #expect(src.contains("OrphanedBridgedTxSweeper.sweep(context: context)"),
                "El barrido de huérfanas perdió su call-site en el arranque.")
        #expect(src.contains("SaveBreadcrumb.deferred(\"AppBootstrapper.orphanedBridgedTxSweep\""),
                "El barrido dejó de estar gateado por la quiescencia del import personal.")
    }

    /// **El barrido espera a que el canal de Grupos entregue, y en ESTE orden.** Es lo que la lógica pura
    /// no puede probar: `GroupChannelFreshnessGate` puede ser perfecta y sus tests verdes mientras el
    /// barrido corre en cada arranque ANTES del primer pull —`startIfEligible` es síncrono en el paso G2,
    /// su ciclo tarda un viaje de red— y entonces el gate solo consigue que no se repare NUNCA nada, sin
    /// un solo rojo. Mutación: quitar el `guard await awaitGroupsChannelEvidence(...)` deja este test en
    /// rojo y TODOS los de comportamiento en verde, que es exactamente por qué hace falta.
    @Test func sweeper_waitsForChannelEvidence_afterPersonalStore() throws {
        let src = try Self.source("Yala/App/AppBootstrapper.swift")
        let task = try #require(
            src.components(separatedBy: "SaveBreadcrumb.deferred(\"AppBootstrapper.orphanedBridgedTxSweep\", \"import not quiescent\")")
                .dropFirst().first,
            "El Task del barrido cambió de forma; este scan dejó de medir nada.")
        let body = task.components(separatedBy: "\n        // 16.6").first ?? ""
        let evidence = try #require(
            body.range(of: "await awaitGroupsChannelEvidence(context: context)"),
            """
            El barrido dejó de esperar evidencia del canal de Grupos. Vuelve a decidir «este gasto no \
            existe» con el store de Grupos a medio poblar, que es el bug entero.
            """)
        let sweep = try #require(body.range(of: "OrphanedBridgedTxSweeper.sweep(context: context)"))
        #expect(evidence.lowerBound < sweep.lowerBound,
                "La espera del canal se movió por DEBAJO del barrido: no gatea nada.")
        #expect(body.contains("\"groups channel not fresh\""),
                "El diferido por canal no fresco dejó de dejar rastro en el breadcrumb.")
    }

    /// El gate vive en UNA primitiva y la consumen los DOS sitios que hacen la misma pregunta. El conteo
    /// esperado es el anti-falso-verde (molde `AttestWiringTests`): sin él, borrar un call-site o
    /// renombrar el tipo pasaría en verde con el escáner comprobando nada.
    @Test func freshnessGate_hasExactlyItsThreeProductionCallSites() throws {
        // Se cuentan LLAMADAS, no menciones del tipo: `ChannelSignals` aparece además como tipo del
        // parámetro inyectable del barrido, y contar el prefijo suelto convertiría una firma en cobertura.
        let sites: [(path: String, call: String, expected: Int)] = [
            // El barrido: veredicto por zona de todas a la vez.
            ("Yala/Services/Groups/OrphanedBridgedTxSweeper.swift",
             "GroupChannelFreshness.verdictsByZone(", 1),
            // El editor: veredicto de la zona de la transacción abierta.
            ("Yala/App/Views/Transactions/NewTransactionView.swift",
             "GroupChannelFreshness.isFresh(", 1),
            // El arranque: la espera acotada antes de barrer.
            ("Yala/App/AppBootstrapper.swift",
             "GroupChannelFreshness.verdictsByZone(", 1),
        ]
        for site in sites {
            let src = try Self.source(site.path)
            // Sin líneas que sean comentario entero: los docblocks nombran el tipo constantemente.
            let code = src.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            let calls = code.components(separatedBy: site.call).count - 1
            #expect(calls == site.expected,
                    "\(site.path) tiene \(calls) llamadas a `\(site.call)` y se esperaban \(site.expected).")
        }
    }

    /// La vista resuelve el puntero de verdad y se lo pasa a la policy.
    ///
    /// El ancla del CALL-SITE va dentro del `onAppear`, no sobre el nombre suelto: `resolveBridgedPointer()`
    /// casa con su PROPIA declaración (`private func resolveBridgedPointer() {`), así que un scan por el
    /// nombre pelado pasa en verde con la función huérfana y sin un solo llamador — la familia de
    /// `AppAttestClient.ensureRegistered()`, cuatro tests verdes demostrando algo que el producto no hacía.
    @Test func editorResolvesThePointer() throws {
        let src = try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let onAppear = try #require(
            src.components(separatedBy: "\n        .onAppear {").dropFirst().first,
            "El `onAppear` del editor cambió de forma; este scan dejó de medir nada.")
        let body = onAppear.components(separatedBy: "\n        }").first ?? ""
        #expect(body.contains("resolveBridgedPointer()"),
                """
                El editor dejó de comprobar si el puntero de grupo resuelve al abrirse. La transacción \
                huérfana vuelve a quedar en solo-lectura y sin salida.
                """)
        #expect(src.contains("pointerResolves: bridgedPointerResolves"),
                "La policy volvió a decidir sin saber si el puntero resuelve.")
        #expect(src.contains("guard let tx = transactionToEdit, bridgedPointerResolves else { return false }"),
                "`isBridgedReadOnly` volvió al criterio «puntero no nulo».")
        // El guard de Duplicar/Borrar. `isBridgedCasoA` es el que desactiva Borrar, así que sin él la
        // huérfana de cuenta real sigue sin poder eliminarse aunque el resto del form se desbloquee.
        #expect(src.contains("              bridgedPointerResolves,"),
                "`isBridgedCasoA` volvió al criterio «puntero no nulo» y Borrar se queda desactivado.")
    }

    /// **Un fetch VACÍO no es «no existe» en el editor tampoco.** El mismo criterio y la misma primitiva
    /// que el barrido: en un device recién reinstalado el store de Grupos arranca vacío (`.none`,
    /// local-only) mientras el espejo personal ya entregó las transacciones, y tomar el vacío por «no
    /// existe» habilita Borrar y Duplicar sobre un gasto de grupo VIVO — borrado que además se exporta.
    ///
    /// Mutación: devolver el resultado del fetch pelado (quitar el `|| !GroupChannelFreshness.isFresh`)
    /// deja este test en rojo.
    @Test func editorTreatsEmptyFetchAsUnresolvedOnlyWithChannelEvidence() throws {
        let src = try Self.source("Yala/App/Views/Transactions/NewTransactionView.swift")
        let fn = try #require(
            src.components(separatedBy: "private func resolveBridgedPointer() {").dropFirst().first,
            "`resolveBridgedPointer` cambió de nombre; este scan dejó de medir nada.")
        let body = fn.components(separatedBy: "\n    /// ").first ?? ""
        #expect(body.contains("bridgedPointerResolves = found\n                || !GroupChannelFreshness.isFresh(zone: tx.splitGroupZoneID, context: modelContext)"),
                """
                El editor volvió a tomar un fetch VACÍO por «el gasto no existe». Con el store de Grupos \
                todavía sin poblar, Borrar y Duplicar se habilitan sobre un gasto de grupo VIVO.
                """)
        // El `catch` NO cambia: un error del store sigue cayendo a `true`. Ése nunca fue el bug.
        #expect(body.contains("bridgedPointerResolves = true"),
                "El `catch` del editor dejó de caer a `true`: un fallo de lectura abriría la edición.")
    }
}
