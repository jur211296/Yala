//
//  GroupsDrainHistoryStoreAnchorTests.swift
//  YalaTests / CloudSync
//
//  El ancla del high-water del drain de Grupos y el store al que pertenece.
//
//  `DefaultHistoryToken` es POR-STORE: `fetchHistory(predicate: $0.token > token)` devuelve lo posterior
//  DEL STORE de ese token y OCULTA por completo los demás stores del container. Anclar el high-water en
//  una transacción del store PERSONAL —que en producción domina el tráfico— deja al canal de Grupos ciego
//  a su propio store, y como sin verlo tampoco puede re-anclar en él, el estado es un PUNTO FIJO: ningún
//  gasto vuelve a salir del device. Medido en producción el 2026-07-31 con dos iPhones (build 8,
//  `GROUPS_BACKEND_ROLLOUT_PERCENT = 100`): `POST /groups/push` no se emitió NI UNA VEZ en todo el día.
//
//  Los dos primeros tests fijan la SEMÁNTICA DE LA PLATAFORMA que obliga a la forma del fix (el ancla, no
//  el fetch). El resto son la regresión.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Grupos · ancla del History por-store (drain)", .serialized)
@MainActor
struct GroupsDrainHistoryStoreAnchorTests {

    // MARK: - Infra (molde de `GroupsSyncClientTests`: 3 stores, un `ModelContext` que los abarca)

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSAnchor-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSA-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSA-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSA-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func outbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    private func expenseRows(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try outbox(context).filter { $0.entityType == GroupSyncEntityType.splitExpense }
    }

    /// Espeja `GroupBackendMembershipService.saveUnderOutboxAuthor` (el camino REAL de `createGroup`: el
    /// grupo y su member owner se persisten bajo el autor del canal para que el drain no re-emita la meta).
    private func saveUnderOutboxAuthor(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }

    @discardableResult
    private func makeBackendGroup(_ context: ModelContext) throws -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.isBackendGroup = true
        try saveUnderOutboxAuthor(context) { context.insert(group) }
        return group
    }

    private func addPersonalTx(_ context: ModelContext, at offset: Double = 0) throws {
        context.insert(TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000 + offset), amount: 3, currencyCode: "USD"))
        try context.save()
    }

    @discardableResult
    private func addExpense(
        _ context: ModelContext, zone: String, amount: Double = 20
    ) throws -> SplitExpense {
        let expense = SplitExpense(groupZoneID: zone, amount: amount, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: "m1")
        context.insert(expense)
        try context.save()
        return expense
    }

    // MARK: - Semántica de la plataforma (lo que obliga a la forma del fix)

    /// CONTRATO MEDIDO de SwiftData: el token es POR-STORE. Anclado en el store personal, el predicado no
    /// devuelve NADA del store de grupos —ni siquiera una transacción POSTERIOR en el tiempo—; anclado en
    /// el de grupos, sí. Si Apple cambia esto, este test avisa y el fix del ancla puede simplificarse.
    @Test func historyToken_isPerStore_andHidesOtherStores() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let group = SplitGroup(name: "G")
        context.insert(group)
        try context.save()
        try addPersonalTx(context)
        _ = try addExpense(context, zone: group.cloudKitZoneID)

        let all = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        func transaction(touching entity: String) throws -> DefaultHistoryTransaction {
            try #require(all.first { tx in
                tx.changes.contains { $0.changedPersistentIdentifier.entityName == entity }
            })
        }
        let personalTx = try transaction(touching: "TransactionItem")
        let groupTx = try transaction(touching: "SplitGroup")
        let expenseTx = try transaction(touching: "SplitExpense")

        // El gasto es POSTERIOR en el tiempo a la transacción personal...
        #expect(expenseTx.timestamp > personalTx.timestamp)

        // ...y aun así el token anclado en el store personal NO lo surfacea.
        let personalAnchor = personalTx.token
        let afterPersonal = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(
                predicate: #Predicate { $0.token > personalAnchor }))
        #expect(afterPersonal.isEmpty, "el token del store personal debería ocultar el store de grupos")

        // Anclado en el store de GRUPOS sí surfacea lo posterior de ese store.
        let groupAnchor = groupTx.token
        let afterGroup = try context.fetchHistory(
            HistoryDescriptor<DefaultHistoryTransaction>(
                predicate: #Predicate { $0.token > groupAnchor }))
        #expect(afterGroup.contains { tx in
            tx.changes.contains { $0.changedPersistentIdentifier.entityName == "SplitExpense" }
        })

        // Y los stores son efectivamente distintos (la premisa de todo lo anterior).
        #expect(groupTx.storeIdentifier != personalTx.storeIdentifier)
        #expect(groupTx.storeIdentifier == expenseTx.storeIdentifier)
    }

    /// CONTRATO MEDIDO: `storeIdentifier` NO es un keypath soportado en el `#Predicate` de un
    /// `HistoryDescriptor` ⇒ el fetch no se puede acotar por store y el fix TIENE que ir por el ancla.
    /// Si algún día se soporta, `fetchHistory` puede acotarse y el suelo de barrido sobra.
    @Test func storeIdentifier_isNotASupportedPredicateKeyPath() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        context.insert(SplitGroup(name: "G"))
        try context.save()

        let storeID = try #require(
            try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
                .first?.storeIdentifier)
        #expect(throws: (any Error).self) {
            _ = try context.fetchHistory(
                HistoryDescriptor<DefaultHistoryTransaction>(
                    predicate: #Predicate { $0.storeIdentifier == storeID }))
        }
    }

    // MARK: - Regresión del bug medido en producción

    /// LA SECUENCIA REAL: `createGroup` bajo el autor del canal → tráfico del store PERSONAL (que es lo
    /// que anclaba el high-water en el store equivocado) → el gasto. El escenario limpio de
    /// `GroupsSyncClientTests` pasa con el bug puesto porque nunca drena después de una transacción
    /// personal; este es el que lo caza.
    @Test func drain_personalTrafficBeforeExpense_capturesExpense() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)                 // arranque del canal (crea el cursor)
        let group = try makeBackendGroup(context)
        client.drainOnce(context: context)                 // ciclo de cadencia
        try addPersonalTx(context, at: 100)
        client.drainOnce(context: context)                 // ← aquí se anclaba en el store personal

        try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)                 // `syncNowFromUI`

        #expect(try expenseRows(context).count == 1)
    }

    /// La pieza que hacía la pérdida PERMANENTE: `GroupExpenseService.createExpense` puentea a
    /// `TransactionItem` justo después de guardar el gasto ⇒ hay una transacción del store PERSONAL con
    /// timestamp POSTERIOR al gasto. Adelantaba `lastDrainedTxAt` por encima de él, así que el guard del
    /// token tampoco lo veía al relanzar (`tx.timestamp > lastDrainedTxAt` falso) y lo daba por validado.
    @Test func drain_bridgeTransactionAfterExpense_doesNotStrandIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)
        let group = try makeBackendGroup(context)
        client.drainOnce(context: context)
        try addPersonalTx(context, at: 100)
        client.drainOnce(context: context)

        try addExpense(context, zone: group.cloudKitZoneID)
        try addPersonalTx(context, at: 200)                // el bridge, POSTERIOR al gasto
        client.drainOnce(context: context)

        #expect(try expenseRows(context).count == 1)

        // Y sigue capturado tras relanzar la app (cliente nuevo, mismo cursor persistido).
        GroupsSyncClient().drainOnce(context: context)
        #expect(try expenseRows(context).count == 1)
    }

    /// PUNTO FIJO: una vez anclado en el store equivocado, el canal no volvía a ver el suyo NUNCA. Cinco
    /// gastos seguidos, cada uno con su drain y su transacción personal de bridge → los cinco salen.
    @Test func drain_repeatedExpensesInterleavedWithPersonalTraffic_capturesAll() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let group = try makeBackendGroup(context)
        try addPersonalTx(context)
        client.drainOnce(context: context)

        for i in 1...5 {
            try addExpense(context, zone: group.cloudKitZoneID, amount: Double(i))
            try addPersonalTx(context, at: Double(i))
            client.drainOnce(context: context)
        }
        #expect(try expenseRows(context).count == 5)
    }

    /// MIGRACIÓN de los cursores YA envenenados en producción (todo device con build 8): el ancla vieja
    /// apunta al store personal y su procedencia no consta (`historyTokenStoreID == nil`). El drain la
    /// descarta, re-escanea y recupera el gasto que había quedado atrás.
    @Test func drain_legacyAnchorFromPersonalStore_isDiscardedAndRecovers() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let group = try makeBackendGroup(context)
        try addPersonalTx(context, at: 100)
        let expense = try addExpense(context, zone: group.cloudKitZoneID)
        try addPersonalTx(context, at: 200)

        // Fabrica el estado de producción: cursor anclado en el token del store PERSONAL, con
        // `lastDrainedTxAt` ya adelantado por encima del gasto y SIN procedencia (build anterior).
        let all = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        let lastPersonal = try #require(all.last { tx in
            tx.changes.contains { $0.changedPersistentIdentifier.entityName == "TransactionItem" }
        })
        let cursor = try client.loadOrCreateCursor(context)
        try saveUnderOutboxAuthor(context) {
            cursor.historyTokenData = try JSONEncoder().encode(lastPersonal.token)
            cursor.historyTokenStoreID = nil
            cursor.lastDrainedTxAt = lastPersonal.timestamp
        }
        #expect(try expenseRows(context).isEmpty)

        // Un drain del build nuevo tiene que recuperarlo y re-anclar en el store de Grupos.
        GroupsSyncClient().drainOnce(context: context)

        let rows = try expenseRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.syncID == expense.id)
        let migrated = try client.loadOrCreateCursor(context)
        #expect(migrated.historyTokenStoreID != nil, "el ancla nueva debe declarar su procedencia")
    }

    /// El RE-ANCLA del guard del token tiene que caer en el store de GRUPOS, igual que el avance normal.
    /// `orderedUnion.last` pelado es la última por TIMESTAMP, que en producción es casi siempre la
    /// transacción PERSONAL del bridge — y anclar ahí reintroduce el punto fijo que el guard deshace: la
    /// vuelta que recupera parece correcta (el gasto sale, porque viene en el union) y el DAÑO solo se ve
    /// en el gasto SIGUIENTE. Por eso la aserción de fondo es el segundo gasto, no el primero.
    @Test func drain_tokenGuardReanchor_landsOnGroupsStore() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let group = try makeBackendGroup(context)
        try addPersonalTx(context, at: 100)
        try addExpense(context, zone: group.cloudKitZoneID, amount: 11)
        try addPersonalTx(context, at: 200)                // el bridge: última por TIMESTAMP

        let all = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        func transaction(touching entity: String) throws -> DefaultHistoryTransaction {
            try #require(all.first { tx in
                tx.changes.contains { $0.changedPersistentIdentifier.entityName == entity }
            })
        }
        let groupsStoreID = try transaction(touching: "SplitGroup").storeIdentifier
        let firstPersonal = try transaction(touching: "TransactionItem")

        // Ancla que DECLARA procedencia de Grupos pero cuyo token ya no surfacea ese store (lo que produce
        // un remount: el caso que este guard existe para cubrir). `lastDrainedTxAt` queda por DEBAJO del
        // gasto, así que el guard lo ve como `missing` y re-ancla.
        let cursor = try client.loadOrCreateCursor(context)
        try saveUnderOutboxAuthor(context) {
            cursor.historyTokenData = try JSONEncoder().encode(firstPersonal.token)
            cursor.historyTokenStoreID = groupsStoreID
            cursor.lastDrainedTxAt = firstPersonal.timestamp
        }

        client.drainOnce(context: context)
        #expect(try expenseRows(context).count == 1, "el guard debería recuperar el gasto rezagado")
        #expect(client.historyTokenRecoveredCount == 1, "y hacerlo por el camino del re-ancla")

        // LA ASERCIÓN DE FONDO: con el ancla ya en el store de Grupos, el gasto SIGUIENTE también sale.
        // `historyTokenValidated` ya es true ⇒ el guard no volverá a correr: si el re-ancla cayó en el
        // store personal, este gasto se pierde en silencio.
        try addExpense(context, zone: group.cloudKitZoneID, amount: 22)
        try addPersonalTx(context, at: 300)
        client.drainOnce(context: context)
        #expect(try expenseRows(context).count == 2)
    }

    /// SUELO DEL BARRIDO: sin actividad de Grupos no hay token que anclar, así que el drain avanza
    /// `lastDrainedTxAt` para que el fetch por timestamp no re-lea todo el History en cada vuelta. Solo es
    /// seguro porque en la ventana barrida no había ninguna transacción del store de Grupos — y un gasto
    /// posterior tiene que seguir capturándose.
    @Test func drain_withoutGroupsActivity_advancesScanFloor_andStillCapturesLater() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        try addPersonalTx(context, at: 10)
        try addPersonalTx(context, at: 20)
        client.drainOnce(context: context)

        let cursor = try client.loadOrCreateCursor(context)
        #expect(cursor.lastDrainedTxAt != nil, "el suelo del barrido debe avanzar sin actividad de Grupos")
        #expect(cursor.historyTokenStoreID == nil, "sin transacciones de Grupos no hay ancla de token")

        // Y a partir de ahí un grupo + gasto SÍ se captura.
        let group = try makeBackendGroup(context)
        try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)
        #expect(try expenseRows(context).count == 1)
    }

    // MARK: - Device que solo RECIBE (el invitado de un grupo)

    //  La otra mitad del ancla, y la que no se ve mirando al device que ESCRIBE: en un miembro que solo
    //  recibe —la población más común de un grupo— las ÚNICAS transacciones del store de Grupos son las
    //  que escribe su propio pull (`applyPulledPage` persiste los `Split*` bajo `outboxSaveAuthor`).
    //  Descartarlas por ECO tanto para traducir como para ANCLAR dejaba el cursor sin escribirse nunca:
    //  `sawGroupsStoreTx` bloqueaba el suelo del barrido y `advancedToken` se quedaba nil, así que el
    //  fetch por timestamp re-barría una ventana que crecía en cada drain, indefinidamente y en silencio.

    private func historyCount(_ context: ModelContext) throws -> Int {
        try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()).count
    }

    /// Delta mínimo de `split_shares` (molde de `GroupsSyncClientTests.apply_advancesGroupCursors_perGroup`):
    /// materializa una fila del store de GRUPOS, que es lo único que hace falta aquí. Se usa `split_shares`
    /// y no `split_expenses` a propósito: no arma intent de bridge, así que el test no toca `UserDefaults`.
    private func shareDelta(seq: Int64, group: String = "SplitGroup-A") -> GroupPulledDelta {
        let shareID = UUID()
        return GroupPulledDelta(
            entityType: "split_shares", groupID: group,
            rawSyncID: shareID.uuidString, syncID: shareID, op: .upsert,
            fields: [
                "expense_id": .string(UUID().uuidString),
                "member_key": .string("member-1"),
                "amount": .string("10.0000"),
                "is_paid": .bool(false),
            ],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-\(String(format: "%016x", seq))",
            serverSeq: seq, schemaVersion: 1)
    }

    private func pulledPage(seq: Int64, group: String = "SplitGroup-A") -> GroupPulledPage {
        GroupPulledPage(deltas: [shareDelta(seq: seq, group: group)],
                        cursors: [group: seq], memberships: [group])
    }

    /// CONTRATO MEDIDO, y es lo que hace SEGURO mover el high-water con el eco: lo que escribe un PULL es
    /// una transacción del store de GRUPOS bajo `outboxSaveAuthor` (⇒ hay dónde anclar), mientras que lo
    /// que escribe el propio DRAIN —`GroupSyncCursor`, `GroupSyncOutbox`— vive en `syncMetaSchema` y NO es
    /// del store de Grupos (⇒ anclar no genera una transacción nueva de ese store ⇒ no hay bucle).
    /// Si SwiftData dejara de partir por store un `save()` que toca ambos, este test avisa.
    @Test func pullWritesAreGroupsStoreEchoes_whileDrainWritesAreNot() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(pulledPage(seq: 7), cursor: cursor, context: context)

        let all = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        func transaction(touching entity: String) throws -> DefaultHistoryTransaction {
            try #require(all.last { tx in
                tx.changes.contains { $0.changedPersistentIdentifier.entityName == entity }
            })
        }
        let shareTx = try transaction(touching: "SplitShare")
        let cursorTx = try transaction(touching: "GroupSyncCursor")

        #expect(shareTx.author == GroupsSyncClient.outboxSaveAuthor,
                "el apply de un pull escribe bajo el autor del canal: es ECO por definición")
        #expect(shareTx.storeIdentifier != cursorTx.storeIdentifier,
                "el cursor vive en syncMeta, no en el store de Grupos: es lo que impide el bucle")
        #expect(!shareTx.changes.contains { $0.changedPersistentIdentifier.entityName == "GroupSyncCursor" },
                "un save que toca dos stores tiene que producir DOS transacciones, una por store")
    }

    /// EL DEFECTO: tras un pull, el drain de un device que solo recibe tiene que anclar en el store de
    /// GRUPOS usando su propio eco. Sin eso no escribe el cursor NUNCA y la ventana del fetch crece.
    @Test func drain_receiveOnlyDevice_anchorsOnItsOwnPullWrites() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)                 // arranque del canal (crea el cursor)
        let cursor = try client.loadOrCreateCursor(context)
        let floorAtStart = try #require(cursor.lastDrainedTxAt)

        client.applyPulledPage(pulledPage(seq: 7), cursor: cursor, context: context)
        client.drainOnce(context: context)

        #expect(cursor.historyTokenStoreID != nil,
                "el eco del propio pull es del store de Grupos: el ancla tiene que caer ahí")
        #expect(try #require(cursor.lastDrainedTxAt) > floorAtStart,
                "sin avanzar el suelo, el fetch por timestamp re-barre la misma ventana cada vuelta")
    }

    /// LA CONSECUENCIA MEDIDA: vuelta tras vuelta de «llega una página, drena», el suelo del barrido tiene
    /// que avanzar SIEMPRE. Con el defecto puesto se queda clavado en el valor del arranque y cada drain
    /// re-escanea todo lo acumulado desde entonces — coste de CPU y memoria creciendo sin tope.
    @Test func drain_receiveOnlyDevice_scanWindowDoesNotGrow() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)
        let cursor = try client.loadOrCreateCursor(context)
        var previous = try #require(cursor.lastDrainedTxAt)

        for seq in Int64(1)...4 {
            client.applyPulledPage(pulledPage(seq: seq), cursor: cursor, context: context)
            client.drainOnce(context: context)
            let floor = try #require(cursor.lastDrainedTxAt)
            #expect(floor > previous, "vuelta \(seq): el suelo no avanzó → la ventana del barrido crece")
            previous = floor
        }
    }

    /// LA RAZÓN QUE DABA EL CÓDIGO VIEJO para no avanzar con el eco («cada avance escribiría el cursor →
    /// loop») era real cuando el ancla no estaba acotada al store. Esta es la prueba de que hoy no lo es:
    /// una vez anclado, un drain SIN novedades no escribe nada — ni una transacción de History por vuelta.
    @Test func drain_afterAnchoringOnEcho_idleTurnsWriteNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(pulledPage(seq: 7), cursor: cursor, context: context)
        client.drainOnce(context: context)                 // ← aquí ancla en el eco

        let afterAnchor = try historyCount(context)
        client.drainOnce(context: context)
        client.drainOnce(context: context)
        #expect(try historyCount(context) == afterAnchor,
                "un drain ocioso escribió el cursor: eso es exactamente el bucle que se temía")
    }

    /// NO-REGRESIÓN del eco, que es lo que este fix podía romper: mover el high-water con las filas del
    /// pull NO puede hacer que se re-emitan al servidor como ediciones locales.
    @Test func drain_receiveOnlyDevice_neverReEmitsPulledRows() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(pulledPage(seq: 7), cursor: cursor, context: context)
        client.drainOnce(context: context)
        client.drainOnce(context: context)

        #expect(try outbox(context).isEmpty, "el apply de un pull no se re-empuja al servidor")
    }

    /// Y el invitado que DESPUÉS escribe: con el ancla ya puesta en el eco de su propio pull, su primer
    /// gasto local tiene que salir igual (mismo store ⇒ el token lo surfacea).
    @Test func drain_receiveOnlyThenLocalExpense_stillCapturesIt() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let client = GroupsSyncClient()

        client.drainOnce(context: context)
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(pulledPage(seq: 7), cursor: cursor, context: context)
        client.drainOnce(context: context)
        try addPersonalTx(context, at: 100)                // tráfico personal entre medias (producción)

        let group = try makeBackendGroup(context)
        try addExpense(context, zone: group.cloudKitZoneID)
        client.drainOnce(context: context)

        #expect(try expenseRows(context).count == 1)
    }

    // MARK: - No-regresión del canal PERSONAL

    /// El canal personal no sufría el bug (su punto fijo natural es el store correcto), pero comparte el
    /// patrón `advancedToken = tx.token`. Esta es la red de que el fix del canal de Grupos no lo mueve.
    @Test func personalChannel_stillDrainsAcrossGroupsStoreTraffic() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()

        try addPersonalTx(context, at: 0)
        engine.drainOnce(context: context)

        context.insert(SplitGroup(name: "G"))
        try context.save()
        engine.drainOnce(context: context)

        try addPersonalTx(context, at: 200)
        engine.drainOnce(context: context)

        #expect(try context.fetch(FetchDescriptor<SyncOutbox>()).count == 2)
    }
}
