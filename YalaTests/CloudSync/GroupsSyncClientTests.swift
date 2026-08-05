//
//  GroupsSyncClientTests.swift
//  YalaTests / CloudSync
//
//  Canal de sync de GRUPOS → backend (incremento G2, DARK). Espeja la infra de `CloudSyncEngineTests`:
//  container ON-DISK temp con los 3 stores (personal `.none` + grupos `.none` + sync-meta `.none`), un
//  solo `ModelContext` que los abarca (el History es por-CONTAINER). `.serialized` + containers propios
//  por test.
//
//  Cubre la sección D del brief G2: (1) partición del muro, (2) drain de Grupos aislado del personal,
//  (3) echo-suppression, (4) cursores + URL del pull, (5) flag no-op, (6) emisión canon c1.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupsSyncClient · drain / push / pull (DARK)", .serialized)
@MainActor
struct GroupsSyncClientTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsSync-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "GS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none
        )
        let syncMetaCfg = ModelConfiguration(
            "GS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg
        )
        return ModelContext(container)
    }

    private func groupOutbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
    }

    private func makeExpense(
        group: String = "SplitGroup-A", amount: Double = 12.5, currency: String = "USD",
        desc: String = "Dinner", context: ModelContext
    ) -> SplitExpense {
        let e = SplitExpense(groupZoneID: group, amount: amount, currencyCode: currency,
                             expenseDescription: desc, paidByMemberID: "member-1")
        context.insert(e)
        return e
    }

    /// C2-bis: el drain solo emite filas de grupos del canal BACKEND (`isBackendGroup`). Los tests de drain
    /// deben materializar un `SplitGroup` backend cuyo `cloudKitZoneID` = el `groupZoneID` de sus entidades,
    /// o el muro POR-GRUPO las salta. `group.name` no importa (no se emite).
    @discardableResult
    private func makeBackendGroup(zoneID: String, context: ModelContext) -> SplitGroup {
        let g = SplitGroup(name: "G")
        g.cloudKitZoneID = zoneID
        g.isBackendGroup = true
        context.insert(g)
        return g
    }

    // MARK: - Stub HTTP session (sin red)

    final class StubHTTPSession: SyncHTTPSession, @unchecked Sendable {
        var lastRequest: URLRequest?
        var callCount = 0
        let responseData: Data
        let statusCode: Int

        init(responseData: Data = Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[]}".utf8),
             statusCode: Int = 200) {
            self.responseData = responseData
            self.statusCode = statusCode
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            lastRequest = request
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }
    }

    /// Stub que devuelve una SECUENCIA de respuestas (una por request). Al agotar la secuencia repite la
    /// última. Para el pull iterado (2 páginas con deltas + 1 vacía).
    final class SequenceStubHTTPSession: SyncHTTPSession, @unchecked Sendable {
        struct Reply { let data: Data; let status: Int }
        private var replies: [Reply]
        private let fallback: Reply
        var callCount = 0
        var requests: [URLRequest] = []

        init(_ replies: [Reply], fallback: Reply) {
            self.replies = replies
            self.fallback = fallback
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            requests.append(request)
            let reply = replies.isEmpty ? fallback : replies.removeFirst()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
            return (reply.data, response)
        }
    }

    /// Contador por referencia para el sleeper inyectado del loop (evita capturar un `var` local en una
    /// closure escapante bajo Swift 6).
    final class SleeperCounter: @unchecked Sendable { var count = 0 }

    /// Contador por referencia para el closure `onRemoteChangesApplied` inyectado (H-2026-07-18-5) —
    /// mismo motivo que `SleeperCounter` (var local capturada en closure escapante bajo Swift 6).
    final class CallCounter: @unchecked Sendable { var count = 0 }

    // MARK: - Helpers de página del pull

    private func pageJSON(shareID: UUID, group: String, serverSeq: Int64, cursor: Int64) -> Data {
        Data("""
        {"deltas":[{"entity_type":"split_shares","group_id":"\(group)","sync_id":"\(shareID.uuidString.lowercased())","op":"upsert","fields":{"expense_id":"\(UUID().uuidString.lowercased())","member_key":"m1","amount":"10.0000","is_paid":false},"field_hlcs":{},"hlc":"2026-07-15T00:00:00.000Z-0000-00000000000000aa","server_seq":\(serverSeq),"schema_version":1}],"cursors":{"\(group)":\(cursor)},"memberships":["\(group)"]}
        """.utf8)
    }

    /// Página TERMINAL del pull: cero deltas, cero cursores. **Lleva `memberships` con la zona en juego a
    /// propósito**: desde que `reconcileLostMemberships` lee ese campo (S4, 2026-08-04), un `[]` significa
    /// «me sacaron de TODOS los grupos», y este fixture cierra los cuatro pulls multi-página cuyo sujeto es
    /// un grupo que sigue VIVO. Con `[]` la página terminal encolaría la limpieza de `SplitGroup-A` — no
    /// rompe sus aserciones (el `Task` es posterior y el actor las serializa) pero es un fixture que MIENTE
    /// sobre el wire: el gateway manda `memberships` en todas las páginas, también en la que agota la cola.
    private var emptyPageJSON: Data {
        Data("{\"deltas\":[],\"cursors\":{},\"memberships\":[\"SplitGroup-A\"]}".utf8)
    }

    // MARK: - Test 1 · Partición del muro

    @Test func partition_groupEntityNames_matchGroupsSchema_disjointFromPersonal() {
        let groupsSchemaNames = Set(SwiftDataConfiguration.groupsSchema.entities.map(\.name))

        // groupEntityNames == los nombres del groupsSchema (las 5 entidades Split*).
        #expect(GroupsSyncClient.groupEntityNames == groupsSchemaNames)
        #expect(GroupsSyncClient.groupEntityNames.count == 5)

        // Disjunto del muro personal (cada entidad de dominio en EXACTAMENTE un canal).
        #expect(GroupsSyncClient.groupEntityNames.isDisjoint(with: CloudSyncEngine.personalEntityNames))

        // El subconjunto EMISIBLE excluye SplitMember (pull-only) y está contenido en el muro.
        #expect(GroupEntityEmissionMap.emittableGroupEntityNames.isSubset(of: GroupsSyncClient.groupEntityNames))
        #expect(!GroupEntityEmissionMap.emittableGroupEntityNames.contains(GroupSyncEntityType.splitMember))
        #expect(GroupEntityEmissionMap.emittableGroupEntityNames.count == 4)
    }

    // MARK: - Test 2 · Drain de Grupos aislado del personal (los dos muros a la vez)

    @Test func drain_capturesOnlyGroupEntities_personalCapturesOnlyPersonal() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-A", context: context)  // C2-bis: la zona debe ser backend
        _ = makeExpense(context: context)
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: 3, currencyCode: "USD")
        context.insert(tx)
        try context.save()

        // Muro de Grupos: solo el SplitExpense.
        GroupsSyncClient().drainOnce(context: context)
        let gRows = try groupOutbox(context)
        #expect(gRows.count == 1)
        #expect(gRows.first?.entityType == GroupSyncEntityType.splitExpense)
        #expect(!gRows.contains { $0.entityType == "TransactionItem" })

        // Muro personal: solo el TransactionItem (nunca un Split*).
        CloudSyncEngine().drainOnce(context: context)
        let pRows = try context.fetch(FetchDescriptor<SyncOutbox>())
        #expect(pRows.count == 1)
        #expect(pRows.first?.entityType == SyncEntityType.transactionItem)
        #expect(!pRows.contains { GroupsSyncClient.groupEntityNames.contains($0.entityType) })
    }

    // MARK: - Test 3 · Echo-suppression (saves con el autor del canal no re-drenan)

    @Test func drain_ignoresOwnAuthorSaves() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-A", context: context)  // C2-bis: la zona debe ser backend
        let expense = makeExpense(context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)
        #expect(try groupOutbox(context).count == 1)

        // Simular un apply remoto: mutar bajo el autor del canal → NO debe re-capturarse.
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        expense.amount = 99
        try context.save()
        context.author = previous

        client.drainOnce(context: context)
        #expect(try groupOutbox(context).count == 1)  // el cambio bajo el autor propio se suprimió
    }

    // MARK: - Test 3-bis · Partición POR-GRUPO del drain (C2-bis, CRÍTICO #1)

    /// Grupo BACKEND y grupo CloudKit coexistiendo, con un expense en cada uno: SOLO la fila del backend
    /// llega al outbox. Sin C2-bis, editar un grupo CloudKit bajo flag ON drenaría a un `group_id`
    /// inexistente server-side → dead-letter permanente.
    @Test func drain_partitionsBackendVsCloudKit_onlyBackendRowsEmitted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-Backend", context: context)
        let ckGroup = SplitGroup(name: "CK")
        ckGroup.cloudKitZoneID = "SplitGroup-CloudKit"  // isBackendGroup == false (default)
        context.insert(ckGroup)
        _ = makeExpense(group: "SplitGroup-Backend", desc: "BackendDinner", context: context)
        _ = makeExpense(group: "SplitGroup-CloudKit", desc: "CloudKitDinner", context: context)
        try context.save()

        GroupsSyncClient().drainOnce(context: context)

        let rows = try groupOutbox(context)
        #expect(rows.count == 1)
        #expect(rows.first?.groupID == "SplitGroup-Backend")
        #expect(!rows.contains { $0.groupID == "SplitGroup-CloudKit" })
    }

    /// Los tombstones del cascade de un `leave` (el SplitGroup backend se borra localmente → su zona sale del
    /// set) NO se emiten: el server aplica el leave vía RPC y RLS rechazaría esos tombstones igual.
    @Test func drain_leaveCascadeTombstones_ofDeletedBackendGroup_notEmitted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let group = makeBackendGroup(zoneID: "SplitGroup-Leave", context: context)
        let expense = makeExpense(group: "SplitGroup-Leave", desc: "Dinner", context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)
        #expect(try groupOutbox(context).count == 1)  // el upsert del expense sí viajó (grupo en el set)

        // Leave: cascade-borra el expense + el SplitGroup. La zona SALE del set backend.
        context.delete(expense)
        context.delete(group)
        try context.save()
        client.drainOnce(context: context)

        let rows = try groupOutbox(context)
        #expect(rows.count == 1)  // sin filas nuevas
        #expect(!rows.contains { $0.opRaw == SyncOutboxOp.tombstone.rawValue })
    }

    /// El caso que el test de arriba NO cubre y que era el único camino VIVO hacia un tombstone de grupo:
    /// una zona con `SplitGroup` DUPLICADO. Ahí «la zona sale del set backend al borrar el SplitGroup» es
    /// falso —la ganadora la mantiene dentro—, así que el guard por zona no frena nada y el dedup del
    /// arranque (`SplitGroupDeduplicationService`, `context.save()` con autor por DEFECTO) emitía el
    /// tombstone de la perdedora. Server-side la identidad de `split_groups` es la ZONA ⇒ eso borra el
    /// grupo para TODOS los miembros. Lo para el `guard !updateOnly` del `case .delete`.
    ///
    /// MUTACIÓN: quitar ese guard deja la primera aserción en rojo.
    @Test func drain_deletingDuplicateSplitGroup_neverEmitsGroupTombstone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Dos filas, MISMA zona: el estado que documenta `SplitGroupDeduplicationService`.
        let keeper = makeBackendGroup(zoneID: "SplitGroup-Dup", context: context)
        let loser = makeBackendGroup(zoneID: "SplitGroup-Dup", context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)          // consume el History previo (los inserts no se emiten)
        let before = try groupOutbox(context).count

        // El dedup borra la perdedora; la ganadora sigue viva con la MISMA zona.
        context.delete(loser)
        try context.save()
        client.drainOnce(context: context)

        let rows = try groupOutbox(context)
        // `GroupSyncOutbox.entityType` guarda el nombre de CLASE — la tabla Postgres solo aparece en el
        // wire, vía `buildDelta`. Comparar contra `.table` aquí haría pasar la aserción en vacío.
        #expect(!rows.contains {
            $0.entityType == GroupSyncEntityType.splitGroup
                && $0.opRaw == SyncOutboxOp.tombstone.rawValue
        }, "un borrado LOCAL de una fila duplicada jamás debe tombstonear el grupo en el servidor")
        #expect(rows.count == before)
        #expect(keeper.cloudKitZoneID == "SplitGroup-Dup")
    }

    /// La otra mitad del guard nuevo: sigue sin emitirse el INSERT de `split_groups` (nace vía
    /// `create_group`) y los tombstones de las entidades de CONTENIDO sí viajan — el guard es por entidad,
    /// no un apagón del `case .delete`.
    @Test func drain_expenseTombstone_stillEmitted_afterGroupTombstoneGuard() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-Live", context: context)
        let expense = makeExpense(group: "SplitGroup-Live", desc: "Taxi", context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)

        context.delete(expense)
        try context.save()
        client.drainOnce(context: context)

        let rows = try groupOutbox(context)
        #expect(rows.contains {
            $0.entityType == GroupSyncEntityType.splitExpense
                && $0.opRaw == SyncOutboxOp.tombstone.rawValue
        }, "el grupo sigue vivo: el borrado del gasto SÍ es una edición local que debe viajar")
    }

    /// El tombstone del grupo barre TODA la zona —las DOS filas del duplicado y sus cuatro clases de
    /// hijas— y el drain no emite nada por ello.
    ///
    /// **Este test CAMBIÓ DE SUJETO el 2026-08-03 y el porqué es la lección.** Probaba la
    /// TRANSACCIONALIDAD: la cascada corre dentro del `saveWithAuthor` del apply, así que sus borrados
    /// llevan `outboxSaveAuthor` y el drain no los traduce; sacarla de ahí los dejaría bajo el autor por
    /// DEFECTO y el servidor aplicaría esos tombstones con `is_group_writer`, borrando los gastos para
    /// TODOS los miembros. Para que esa fuga fuera OBSERVABLE, el fixture montaba un duplicado a propósito:
    /// `fetchSplitGroup` borraba UNA fila y la superviviente mantenía la zona dentro de `backendZoneIDs`.
    ///
    /// Al pasar el tombstone a barrer TODAS las filas, la zona sale del set SIEMPRE ⇒ **esa fuga dejó de
    /// ser alcanzable y este test dejó de probar el autor: MEDIDO** — con la cascada movida al autor por
    /// defecto y un `save()` propio, pasaba VERDE. El invariante del autor se trasladó a
    /// `GroupsSyncApplyZoneTests.sourceScan_cascadeStaysUnderTheOutboxAuthor`, que sí puede afirmarlo.
    /// Lo que este test prueba ahora es el barrido por zona y su consecuencia: outbox intacto.
    ///
    /// MUTACIÓN: volver a borrar una sola fila (`if let first = rows.first`) deja la última aserción en rojo.
    @Test func apply_groupTombstone_sweepsWholeZone_soDrainEmitsNothing() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-Dup", context: context)
        makeBackendGroup(zoneID: "SplitGroup-Dup", context: context)
        let expense = makeExpense(group: "SplitGroup-Dup", desc: "Hotel", context: context)
        context.insert(SplitShare(
            expenseID: expense.id, memberID: "member-1", amount: 6, groupZoneID: "SplitGroup-Dup"))
        context.insert(SplitSettlement(
            groupZoneID: "SplitGroup-Dup", fromMemberID: "member-1", toMemberID: "member-2", amount: 3))
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)                 // consume el History de la siembra
        let before = try groupOutbox(context).count

        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(
                deltas: [GroupPulledDelta(
                    entityType: GroupEntityEmissionMap.splitGroup.table, groupID: "SplitGroup-Dup",
                    rawSyncID: "SplitGroup-Dup", syncID: nil, op: .tombstone, fields: [:], fieldHlcs: [:],
                    hlc: "2026-08-02T00:00:00.000Z-0000-00000000000000f9", serverSeq: 9, schemaVersion: 1)],
                cursors: [:], memberships: []),
            cursor: cursor, context: context)

        client.drainOnce(context: context)
        let rows = try groupOutbox(context)
        #expect(!rows.contains { $0.opRaw == SyncOutboxOp.tombstone.rawValue },
                "el tombstone del grupo se filtró al outbox")
        #expect(rows.count == before)
        // Y la cascada sí ocurrió en local.
        #expect(try context.fetchCount(FetchDescriptor<SplitExpense>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitShare>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitSettlement>()) == 0)
        // Lo que ahora carga el peso: las DOS filas del duplicado se fueron. Con una sola borrada, la
        // superviviente quedaba como CASCARÓN —visible y escribible— y mantenía la zona en `backendZoneIDs`.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
    }

    // MARK: - Test 4 · Cursores por grupo + URL del pull (assert del request generado, lección d49d2e47)

    @Test func apply_advancesGroupCursors_perGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)

        let shareID = UUID()
        let delta = GroupPulledDelta(
            entityType: "split_shares", groupID: "SplitGroup-A",
            rawSyncID: shareID.uuidString, syncID: shareID, op: .upsert,
            fields: [
                "expense_id": .string(UUID().uuidString),
                "member_key": .string("member-1"),
                "amount": .string("10.0000"),
                "is_paid": .bool(false),
            ],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
            serverSeq: 7, schemaVersion: 1
        )
        let page = GroupPulledPage(deltas: [delta], cursors: ["SplitGroup-A": 7], memberships: ["SplitGroup-A"])
        client.applyPulledPage(page, cursor: cursor, context: context)

        // El cursor del grupo avanzó a 7.
        let json = cursor.groupCursorsJSON
        let map = try JSONDecoder().decode([String: Int64].self, from: Data(json.utf8))
        #expect(map["SplitGroup-A"] == 7)

        // Y el SplitShare se materializó localmente.
        #expect(try context.fetch(FetchDescriptor<SplitShare>()).count == 1)
    }

    /// El `catch` del save de página deja el contexto LIMPIO — mismo contrato F-3 que el mirror declarado
    /// `SyncApplyEngine.applyPage`, que corre sobre ESTE MISMO `mainContext` compartido (los dos canales
    /// reciben el mismo `context` en `AppBootstrapper`). Sin el `rollback()`, las filas insertadas por la
    /// página y la mutación de `groupCursorsJSON` se quedan dirty: el próximo `save()` de cualquier otro las
    /// persiste bajo el autor por defecto, el drain las captura (filtra por `author != outboxSaveAuthor`) y
    /// las RE-EMPUJA al servidor como ediciones locales con HLC fresco.
    @Test("Un save de página que falla no deja el grafo remoto a medias en el contexto compartido")
    func apply_saveFails_rollsBack_andCursorDoesNotAdvance() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)

        let shareID = UUID()
        let delta = GroupPulledDelta(
            entityType: "split_shares", groupID: "SplitGroup-A",
            rawSyncID: shareID.uuidString, syncID: shareID, op: .upsert,
            fields: [
                "expense_id": .string(UUID().uuidString),
                "member_key": .string("member-1"),
                "amount": .string("10.0000"),
                "is_paid": .bool(false),
            ],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
            serverSeq: 7, schemaVersion: 1
        )
        let page = GroupPulledPage(deltas: [delta], cursors: ["SplitGroup-A": 7], memberships: ["SplitGroup-A"])

        client._testThrowOnApplySave = true
        let ok = client.applyPulledPage(page, cursor: cursor, context: context)

        #expect(ok == false)
        #expect(context.hasChanges == false, """
            El apply fallido dejó el contexto DIRTY. Esas filas las persiste el próximo save ajeno bajo el \
            autor por defecto, y desde ahí el drain las re-empuja al servidor como ediciones locales: \
            laundering del grafo remoto a medias.
            """)

        // El cursor no avanzó **en el STORE**, que es el invariante que de verdad importa: el próximo pull
        // re-pide la página entera y el apply es idempotente.
        //
        // ⚠️ Se lee del store y del re-fetch, JAMÁS de `cursor.groupCursorsJSON` directo. El valor en
        // memoria de un `@Model` YA PERSISTIDO, leído en la ventana entre el `rollback()` y el siguiente
        // fetch, es **dependiente del runtime**: iOS 27.0 re-hidrata el snapshot del objeto, iOS 26.5 no
        // (medido el 2026-07-30 en los dos, con sondas). La versión anterior de este test aserjaba ese
        // valor y convirtió esa diferencia en un rojo que se leyó como pérdida de datos en producción — y
        // no lo era: el store estaba limpio en ambos.
        let fresh = ModelContext(context.container)
        let storedCursor = try #require(try fresh.fetch(FetchDescriptor<GroupSyncCursor>()).first)
        let storedMap = try JSONDecoder().decode(
            [String: Int64].self, from: Data(storedCursor.groupCursorsJSON.utf8))
        #expect(storedMap["SplitGroup-A"] == nil, """
            El cursor avanzó EN DISCO pese al save fallido. El servidor no re-emite esos deltas, así que la \
            página se pierde para siempre.
            """)

        // Y lo que verá el CICLO SIGUIENTE: `pullAndApplyOnce` re-hace `loadOrCreateCursor` sobre este mismo
        // contexto, y ese fetch tiene que devolver el valor del store.
        //
        // **Esta es la aserción que caza la ausencia del `rollback()`**, y es portable entre runtimes: sin
        // rollback el objeto sigue SUCIO, y un fetch NO descarta cambios pendientes ⇒ el ciclo siguiente
        // arrancaría desde un cursor que no está en disco y no re-pediría la página.
        let reloaded = try client.loadOrCreateCursor(context)
        let reloadedMap = try JSONDecoder().decode(
            [String: Int64].self, from: Data(reloaded.groupCursorsJSON.utf8))
        #expect(reloadedMap["SplitGroup-A"] == nil, """
            El ciclo siguiente arrancaría desde un cursor avanzado que no está en el store: no re-pediría \
            la página y sus filas faltarían hasta el próximo arranque en frío.
            """)

        // Y la fila remota no llegó al store por ninguna vía.
        #expect(try fresh.fetch(FetchDescriptor<SplitShare>()).isEmpty)
    }

    @Test func pull_buildsExpectedQuery_withCursorsAndLimit() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // URL directa (buildPullURL).
        let client = GroupsSyncClient(
            tokenProvider: { "jwt-token" }, urlSession: StubHTTPSession())
        let url = client.buildPullURL(cursorsJSON: "{\"SplitGroup-A\":5}", limit: 500)
        #expect(url != nil)
        let comps = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        #expect(url!.absoluteString.contains("groups/pull"))
        #expect(comps?.queryItems?.first { $0.name == "cursors" }?.value == "{\"SplitGroup-A\":5}")
        #expect(comps?.queryItems?.first { $0.name == "limit" }?.value == "500")

        // Request REAL enviado por pullAndApplyOnce (assert del BODY/URL, lección d49d2e47).
        let stub = StubHTTPSession()
        let netClient = GroupsSyncClient(tokenProvider: { "jwt-token" }, urlSession: stub)
        // Sembrar un cursor con contenido para que la query lo lleve.
        let cursor = try netClient.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"SplitGroup-B\":9}"
        try context.save()

        _ = await netClient.pullAndApplyOnce(context: context, limit: 250)
        #expect(stub.callCount == 1)
        let sent = stub.lastRequest
        #expect(sent?.httpMethod == "GET")
        #expect(sent?.url?.absoluteString.contains("groups/pull") == true)
        let sentComps = URLComponents(url: sent!.url!, resolvingAgainstBaseURL: false)
        #expect(sentComps?.queryItems?.first { $0.name == "cursors" }?.value == "{\"SplitGroup-B\":9}")
        #expect(sentComps?.queryItems?.first { $0.name == "limit" }?.value == "250")
        #expect(sent?.value(forHTTPHeaderField: "Authorization") == "Bearer jwt-token")
    }

    // MARK: - Test 5 · Flag DARK: startIfEligible es no-op

    @Test func startIfEligible_isNoOp_whenFlagDisabled() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = false

        // Sesión "viva" y una red que FALLARÍA el test si se tocara.
        let stub = StubHTTPSession()
        let client = GroupsSyncClient(
            tokenProvider: { Issue.record("tokenProvider tocado con flag OFF"); return nil },
            urlSession: stub,
            sessionCheck: { true })

        client.startIfEligible(context: context)

        // Sin red y sin modelos del canal (ni cursor ni outbox).
        #expect(stub.callCount == 0)
        #expect(try context.fetch(FetchDescriptor<GroupSyncCursor>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).isEmpty)
    }

    // MARK: - Test 5b · Apply de group_members (pull-only): userID + born-remote id determinista

    private func memberDelta(
        group: String = "SplitGroup-A", memberKey: String = "member-rec-1",
        userID: WireValue? = .string("auth-uid-1"), op: SyncOutboxOp = .upsert,
        serverSeq: Int64 = 3
    ) -> GroupPulledDelta {
        var fields: [String: WireValue] = [
            "display_name": .string("Alice"),
            "role": .string("admin"),
            "status": .string("active"),
            "joined_at": .string("2026-07-15T00:00:00.000Z"),
        ]
        if let userID { fields["user_id"] = userID }
        return GroupPulledDelta(
            entityType: "group_members", groupID: group, rawSyncID: memberKey, syncID: nil,
            op: op, fields: fields, fieldHlcs: [:],
            hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000b",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// R10 (C2/C4 ajuste #2): un `member_key` = sub UUID (born-remote del backend) → id LOCAL en el namespace
    /// PROPIO del canal. El fixture usa un sub UUID (NO el default `"member-rec-1"` del helper, que con R10
    /// derivaría CloudKit-era y del que depende el test de adopción :406).
    @Test func apply_member_writesUserID_andDeterministicBornRemoteID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let subUUID = "11111111-1111-1111-1111-111111111111"
        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        let page = GroupPulledPage(
            deltas: [memberDelta(memberKey: subUUID)], cursors: ["SplitGroup-A": 3], memberships: ["SplitGroup-A"])
        client.applyPulledPage(page, cursor: cursor, context: context)

        let members = try context.fetch(FetchDescriptor<SplitMember>())
        let member = try #require(members.first)
        // El `user_id` del wire aterrizó en la columna LOCAL `userID` (cierra el residual de G2).
        #expect(member.userID == "auth-uid-1")
        // Separación de canales (G3): el `member_key` aterriza en `memberKey`; `cloudKitUserRecordID` se
        // queda VACÍO (el sub del backend nunca contamina el campo CloudKit).
        #expect(member.memberKey == subUUID)
        #expect(member.cloudKitUserRecordID == "")
        #expect(member.displayName == "Alice")
        // Born-remote de un sub UUID (NO legacy): id LOCAL = namespace BACKEND determinista.
        #expect(member.id == GroupBackendIdentityLogic.deterministicMemberID(
            groupID: "SplitGroup-A", memberKey: subUUID))
    }

    /// R10 (C2): un `member_key` LEGACY (recordName de CloudKit, no parsea UUID) born-remote → id LOCAL en el
    /// namespace CloudKit-era `"SplitMember"` — BYTE-IDÉNTICO al id del owner (`GroupService`), preservando la
    /// identidad del mundo CloudKit del grupo migrado. NO usa el namespace propio del canal.
    @Test func apply_member_bornRemoteLegacyKey_usesCloudKitEraNamespace() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let legacyKey = "_legacyRecordName"
        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(memberKey: legacyKey)], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let member = try #require(try context.fetch(FetchDescriptor<SplitMember>()).first)
        #expect(member.memberKey == legacyKey)
        // Id EXACTO calculado con la primitiva CloudKit-era (namespace "SplitMember", group_id == zoneID).
        let cloudKitEraID = GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember", name: "SplitGroup-A:\(legacyKey)")
        #expect(member.id == cloudKitEraID)
        // Y los DOS namespaces difieren para el MISMO par → el legacy JAMÁS cae en el id del canal backend.
        #expect(member.id != GroupBackendIdentityLogic.deterministicMemberID(
            groupID: "SplitGroup-A", memberKey: legacyKey))
    }

    /// Apply sobre una fila SplitMember PREEXISTENTE del mundo CloudKit (grupo migrado G6-era): su
    /// `cloudKitUserRecordID` ES el `member_key` server-side y su `memberKey` es `nil`. El dual-match cae al
    /// fallback por `cloudKitUserRecordID`, ADOPTA `memberKey`, NO duplica y CONSERVA el `id` original.
    @Test func apply_member_adoptsLegacyCloudKitRow_noDuplicate_keepsID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Fila preexistente del mundo CloudKit: matchea por record-name, sin memberKey backend.
        let legacy = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Bob",
                                 cloudKitUserRecordID: "member-rec-1")
        let legacyID = legacy.id
        context.insert(legacy)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let members = try context.fetch(FetchDescriptor<SplitMember>())
        #expect(members.count == 1)                                    // adoptó, no duplicó
        let member = try #require(members.first)
        #expect(member.id == legacyID)                                 // conservó el id original
        #expect(member.memberKey == "member-rec-1")                    // adopción: escribió memberKey
        #expect(member.cloudKitUserRecordID == "member-rec-1")         // no se toca (fila legacy)
        #expect(member.userID == "auth-uid-1")                         // proyección del user_id del wire
        #expect(member.displayName == "Alice")                         // PATCH aplicado

        // Un segundo apply matchea ya por el path directo (memberKey) → sigue sin duplicar.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(serverSeq: 4)], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).count == 1)
    }

    // MARK: - Test 5b-bis · applyGroupMeta: adopción ATÓMICA de un grupo CloudKit migrado (C3, G6-2)

    private func groupMetaDelta(
        group: String = "SplitGroup-A", op: SyncOutboxOp = .upsert, serverSeq: Int64 = 5
    ) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: group,
            rawSyncID: nil, syncID: nil, op: op,
            fields: ["name": .string("Viaje")],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000c",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// Un SplitGroup CloudKit PREEXISTENTE (isBackendGroup=false, con ckSystemFieldsData) que aparece en el
    /// pull backend (mismo group_id) = grupo MIGRADO cuyo member re-entró → se flipea a backend DENTRO del
    /// mismo apply (sin save extra). Congela CloudKit y activa el drain backend en UN commit.
    @Test func applyGroupMeta_adoptsPreexistingCloudKitGroup_flipsToBackend() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let ckGroup = SplitGroup(name: "CK")
        ckGroup.cloudKitZoneID = "SplitGroup-A"
        ckGroup.isBackendGroup = false
        ckGroup.ckSystemFieldsData = Data([0x01, 0x02])
        context.insert(ckGroup)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [groupMetaDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let groups = try context.fetch(FetchDescriptor<SplitGroup>())
        #expect(groups.count == 1)                       // adoptó, no duplicó
        let group = try #require(groups.first)
        #expect(group.isBackendGroup)                    // flip atómico a backend
        #expect(group.name == "Viaje")                   // PATCH aplicado
    }

    /// Un grupo born-backend PREEXISTENTE (isBackendGroup=true) permanece true tras el apply (el guard
    /// `!isBackendGroup` evita un write espurio; sin regresión de estado).
    @Test func applyGroupMeta_bornBackendGroup_staysBackend() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [groupMetaDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let group = try #require(try context.fetch(FetchDescriptor<SplitGroup>()).first)
        #expect(group.isBackendGroup)
        #expect(group.name == "Viaje")
    }

    @Test func apply_member_nullUserID_isAnonymization_nullsColumn() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)

        // Primer apply: llega con user_id.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        #expect(try context.fetch(FetchDescriptor<SplitMember>()).first?.userID == "auth-uid-1")

        // Segundo apply del MISMO member con user_id = null (anonimización del server) → NULLea la columna.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(userID: .null, serverSeq: 4)], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        let members = try context.fetch(FetchDescriptor<SplitMember>())
        #expect(members.count == 1)  // mismo member (dedup por id determinista), no duplicado
        #expect(members.first?.userID == nil)
    }

    // MARK: - Test 5c · refreshCurrentUserFlags con flag OFF = byte-idéntico (path CloudKit, ignora userID)

    /// Con `groupsBackendEnabled == false` (kill remoto / binario sin canal), `refreshCurrentUserFlags` deriva
    /// `isCurrentUser` EXCLUSIVAMENTE por el path CloudKit (`cloudKitUserRecordID == recordName`) e IGNORA
    /// `SplitMember.userID`. Toca los singletons `GroupService.shared`/`GroupUserIdentityService.shared`
    /// → suite `.serialized` + restore. No dispara `enqueueSave` (members con record-id no vacío, grupo
    /// no-owner) → sin acoplar `SplitSyncManager`.
    @Test func refreshCurrentUserFlags_flagOff_usesCloudKitPath_ignoresUserID() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevCache = GroupUserIdentityService.shared.cachedRecordName
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupUserIdentityService.shared._testSetCachedRecordName(prevCache)
        }
        CloudSyncFlags.groupsBackendEnabled = false
        GroupUserIdentityService.shared._testSetCachedRecordName("rec-current")

        let group = SplitGroup(name: "Trip")
        group.cloudKitZoneID = "zone-1"
        group.isOwner = false
        context.insert(group)

        // memberA: match por record-name → debe volverse current. Su `userID` apunta a OTRO uid: con flag
        // OFF NO se consulta → no altera la decisión.
        let memberA = SplitMember(groupZoneID: "zone-1", displayName: "Me",
                                  cloudKitUserRecordID: "rec-current")
        memberA.userID = "someone-else-uid"
        // memberB: sin match por record-name, pero su `userID` == "rec-current". Con flag OFF NO debe
        // volverse current (el path backend está apagado).
        let memberB = SplitMember(groupZoneID: "zone-1", displayName: "Other",
                                  cloudKitUserRecordID: "rec-other")
        memberB.userID = "rec-current"
        context.insert(memberA)
        context.insert(memberB)
        try context.save()

        await GroupService.shared.refreshCurrentUserFlags(context: context)

        #expect(memberA.isCurrentUser == true)   // match por record-name (path CloudKit)
        #expect(memberB.isCurrentUser == false)  // userID ignorado con flag OFF
    }

    // MARK: - Test 5d · A1: el backfill de cloudKitUserRecordID EXCLUYE members del canal backend

    /// Un member del canal backend tiene `cloudKitUserRecordID == ""` POR DISEÑO (su identidad es
    /// `memberKey`/`userID`, no el record-name). El backfill de `refreshCurrentUserFlags` NO debe adoptarlo
    /// (con el flag ON le pondría un record-name de CloudKit Y lo encolaría a CKSyncEngine → fuga
    /// cross-canal). Prueba observable: su `cloudKitUserRecordID` sigue VACÍO tras el refresh (no
    /// backfilleado → no encolado). Grupo NO-owner para evitar el enqueue de la promoción a owner.
    @Test func refreshCurrentUserFlags_doesNotBackfillBackendMember() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevCache = GroupUserIdentityService.shared.cachedRecordName
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupUserIdentityService.shared._testSetCachedRecordName(prevCache)
        }
        CloudSyncFlags.groupsBackendEnabled = false
        GroupUserIdentityService.shared._testSetCachedRecordName("rec-current")

        let group = SplitGroup(name: "Trip")
        group.cloudKitZoneID = "zone-1"
        group.isOwner = false
        context.insert(group)

        // Member del canal backend: cloudKitUserRecordID vacío, pero memberKey/userID seteados.
        let backendMember = SplitMember(groupZoneID: "zone-1", displayName: "Me",
                                        cloudKitUserRecordID: "")
        backendMember.memberKey = "mk-1"
        backendMember.userID = "uid-1"
        backendMember.isCurrentUser = true
        context.insert(backendMember)
        try context.save()

        await GroupService.shared.refreshCurrentUserFlags(context: context)

        // A1: NO backfilleado (sigue vacío) → no se encoló a CKSyncEngine.
        #expect(backendMember.cloudKitUserRecordID == "")
        #expect(backendMember.memberKey == "mk-1")
    }

    /// A1 sobre el BLOQUE 1 de `refreshCurrentUserFlags` (candidates + rama `group.isOwner == true`,
    /// GroupService.swift:800-822): el test A1 anterior usa un grupo NO-owner → nunca alcanza la rama del
    /// owner (admins / earliest-join). Aquí el grupo ES owner y el ÚNICO member es del canal backend
    /// (`memberKey`/`userID` seteados, `cloudKitUserRecordID == ""`, `role == "admin"`). SIN el guard A1
    /// (el filtro `memberKey == nil && userID == nil` de los candidates), ese member entraría a candidates,
    /// sería el único admin, y la rama del owner le backfillearía el record-name + lo encolaría a
    /// CKSyncEngine (fuga cross-canal). CON el guard, candidates queda VACÍO → nada se toca. `displayName`
    /// que NO matchee `currentUserDisplayName()` para forzar la rama del owner (no la de nameMatches).
    @Test func refreshCurrentUserFlags_ownerBranch_doesNotBackfillBackendAdmin() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevCache = GroupUserIdentityService.shared.cachedRecordName
        defer {
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupUserIdentityService.shared._testSetCachedRecordName(prevCache)
        }
        CloudSyncFlags.groupsBackendEnabled = false
        GroupUserIdentityService.shared._testSetCachedRecordName("rec-current")

        let group = SplitGroup(name: "Trip")
        group.cloudKitZoneID = "zone-1"
        group.isOwner = true
        context.insert(group)

        // Member backend admin: cloudKitUserRecordID vacío, memberKey/userID seteados, role admin.
        // displayName improbable de matchear `currentUserDisplayName()` → fuerza la rama del owner (814-822).
        let backendAdmin = SplitMember(groupZoneID: "zone-1", displayName: "ZZ-Backend-Admin",
                                       cloudKitUserRecordID: "")
        backendAdmin.memberKey = "mk-owner"
        backendAdmin.userID = "uid-owner"
        backendAdmin.role = "admin"
        context.insert(backendAdmin)
        try context.save()

        await GroupService.shared.refreshCurrentUserFlags(context: context)

        // A1 en la rama del owner: candidates vacío → NO backfilleado (sigue "") → no se encoló.
        #expect(backendAdmin.cloudKitUserRecordID == "")
        #expect(backendAdmin.memberKey == "mk-owner")
    }

    // MARK: - Test 6 · Emisión canon c1 (gmoney junto; gshare trío)

    @Test func emission_expense_gmoneyTogether_partialUpdateExpandsGroup() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-A", context: context)  // C2-bis: la zona debe ser backend
        let expense = makeExpense(amount: 12.5, currency: "USD", desc: "Dinner", context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)

        // INSERT: proyección completa — gmoney (amount + currency_code) presente en el mismo delta.
        let insertRow = try #require(try groupOutbox(context).first)
        #expect(insertRow.entityType == GroupSyncEntityType.splitExpense)
        #expect(insertRow.opRaw == SyncOutboxOp.upsert.rawValue)
        #expect(insertRow.groupID == "SplitGroup-A")
        #expect(insertRow.fieldsJSON.contains("\"amount\":\"12.5000\""))   // money escala 4
        #expect(insertRow.fieldsJSON.contains("\"currency_code\":\"USD\""))
        #expect(insertRow.fieldsJSON.contains("\"expense_description\":\"Dinner\""))
        #expect(insertRow.fieldHlcsJSON?.contains("gmoney") == true)

        // UPDATE PARCIAL de solo `amount`: el invariante de coherencia arrastra `currency_code` (gmoney
        // viaja entero) pero NO `expense_description` (no tocado).
        expense.amount = 20.0
        try context.save()
        client.drainOnce(context: context)

        let updateRow = try #require(
            try groupOutbox(context).first { !$0.fieldsJSON.contains("expense_description") })
        #expect(updateRow.fieldsJSON.contains("\"amount\":\"20.0000\""))
        #expect(updateRow.fieldsJSON.contains("\"currency_code\":\"USD\""))   // gmoney expandido
        #expect(updateRow.fieldsJSON.contains("expense_description") == false)
        #expect(updateRow.fieldHlcsJSON?.contains("gmoney") == true)
    }

    @Test func emission_share_gshareTrioTravelsWhole() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        makeBackendGroup(zoneID: "SplitGroup-A", context: context)  // C2-bis: la zona debe ser backend
        let share = SplitShare(expenseID: UUID(), memberID: "member-1", amount: 6.25,
                               groupZoneID: "SplitGroup-A")
        context.insert(share)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)

        let row = try #require(try groupOutbox(context).first { $0.entityType == GroupSyncEntityType.splitShare })
        // gshare trío = expense_id + member_key + amount, todos presentes en el mismo delta.
        #expect(row.fieldsJSON.contains("\"expense_id\":"))
        #expect(row.fieldsJSON.contains("\"member_key\":\"member-1\""))
        #expect(row.fieldsJSON.contains("\"amount\":\"6.2500\""))
        #expect(row.fieldsJSON.contains("\"is_paid\":false"))
        #expect(row.fieldHlcsJSON?.contains("gshare") == true)
    }

    // MARK: - Paridad emisión ↔ group_capability_manifest.json (guard del review adversarial G2)

    /// El manifest (raíz del repo, vía #filePath) es el contrato del wire; la emisión debe ser un
    /// SUBCONJUNTO exacto por tabla. La única resta permitida es split_groups.created_at: el manifest la
    /// conserva para la PROYECCIÓN del pull, pero el column-grant del server (supabase-groups-staging.ddl,
    /// hallazgo #1 de G1) la excluye del UPDATE — emitirla rechazaría el delta ENTERO de meta (42501).
    /// Este test es el que faltaba cuando el review cazó esa emisión a mano.
    @Test func emissionParity_catalogMatchesGroupManifest_minusNonGrantable() throws {
        let manifestURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("group_capability_manifest.json")
        let data = try Data(contentsOf: manifestURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let entities = try #require(root["entities"] as? [String: Any])

        // group_members es pull-only: JAMÁS en el catálogo de emisión.
        #expect(GroupEntityEmissionMap.catalog["group_members"] == nil)

        let nonGrantable: [String: Set<String>] = ["split_groups": ["created_at"]]

        for (table, spec) in GroupEntityEmissionMap.catalog {
            let entity = try #require(entities[table] as? [String: Any], "tabla \(table) ausente del manifest")
            let columnSpecs = try #require(entity["columns"] as? [String: Any])
            let manifestColumns = Set(columnSpecs.keys)
            let expectedEmitted = manifestColumns.subtracting(nonGrantable[table] ?? [])
            #expect(spec.columns == expectedEmitted,
                    "emisión de \(table) difiere del manifest: extra=\(spec.columns.subtracting(expectedEmitted)) faltan=\(expectedEmitted.subtracting(spec.columns))")

            // group_key por columna idéntico en las dos puntas (gmoney/gshare/smoney).
            for (column, colSpec) in columnSpecs {
                guard spec.columns.contains(column) else { continue }
                let manifestGroup = (colSpec as? [String: Any])?["group_key"] as? String
                #expect(spec.groups[column] == manifestGroup,
                        "\(table).\(column): group_key manifest=\(manifestGroup ?? "nil") emisión=\(spec.groups[column] ?? "nil")")
            }
        }
    }

    // MARK: - Test 7 · Pull hasta agotar (pieza 1 / A1)

    /// 2 páginas con deltas + 1 vacía → 3 requests, outcome `.completed(pages:2, deltas:2)`, cursores
    /// finales correctos. La señal de terminación es PÁGINA VACÍA (no `deltas.count < limit`).
    @Test func pullUntilExhausted_stopsOnEmptyPage_aggregatesPagesAndDeltas() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let s1 = UUID(); let s2 = UUID()
        let stub = SequenceStubHTTPSession([
            .init(data: pageJSON(shareID: s1, group: "SplitGroup-A", serverSeq: 5, cursor: 5), status: 200),
            .init(data: pageJSON(shareID: s2, group: "SplitGroup-A", serverSeq: 9, cursor: 9), status: 200),
            .init(data: emptyPageJSON, status: 200),
        ], fallback: .init(data: emptyPageJSON, status: 200))

        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)
        let outcome = await client.pullUntilExhausted(context: context, limit: 1)

        #expect(outcome == .completed(pages: 2, deltasApplied: 2))
        #expect(stub.callCount == 3)  // 2 con deltas + 1 vacía (terminación)

        // Los 2 shares se materializaron; el cursor del grupo quedó en 9 (el máximo aplicado).
        #expect(try context.fetch(FetchDescriptor<SplitShare>()).count == 2)
        let cursor = try client.loadOrCreateCursor(context)
        let map = try JSONDecoder().decode([String: Int64].self, from: Data(cursor.groupCursorsJSON.utf8))
        #expect(map["SplitGroup-A"] == 9)
    }

    /// A1: un pull que nunca devuelve página vacía (server que no converge) se corta en el CAP de 20
    /// iteraciones con outcome `.transient` (no gira para siempre).
    @Test func pullUntilExhausted_cap_returnsTransient() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Fallback = SIEMPRE una página con deltas (jamás vacía).
        let stub = SequenceStubHTTPSession(
            [], fallback: .init(data: pageJSON(shareID: UUID(), group: "SplitGroup-A", serverSeq: 1, cursor: 1), status: 200))
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        let outcome = await client.pullUntilExhausted(context: context, limit: 1)
        #expect(outcome == .transient)
        #expect(stub.callCount == 20)  // tope duro
    }

    // MARK: - Test 7-bis · Refresh vivo de UI tras aplicar deltas (H-2026-07-18-5)

    /// 2 páginas de deltas en el MISMO ciclo → el bump de refresh (`onRemoteChangesApplied`) se dispara
    /// EXACTAMENTE 1 vez (POR-CICLO, no por-página): con la vista de detalle montada, un solo bump de
    /// `dataVersion` la refresca; los VMs ya debouncan las ráfagas.
    @Test func pullCycle_withDeltas_firesOnRemoteChangesApplied_once() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let refreshBumps = CallCounter()
        let s1 = UUID(); let s2 = UUID()
        let stub = SequenceStubHTTPSession([
            .init(data: pageJSON(shareID: s1, group: "SplitGroup-A", serverSeq: 5, cursor: 5), status: 200),
            .init(data: pageJSON(shareID: s2, group: "SplitGroup-A", serverSeq: 9, cursor: 9), status: 200),
            .init(data: emptyPageJSON, status: 200),
        ], fallback: .init(data: emptyPageJSON, status: 200))

        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub,
            onRemoteChangesApplied: { refreshBumps.count += 1 })
        let outcome = await client.pullUntilExhausted(context: context, limit: 1)

        #expect(outcome == .completed(pages: 2, deltasApplied: 2))
        #expect(refreshBumps.count == 1)  // por-ciclo: 2 páginas de deltas → 1 solo bump
    }

    /// Pull que solo trae páginas vacías (nada que aplicar) → el bump de refresh NO se dispara (evita
    /// reloads espurios en cada vuelta ociosa del loop de 60s).
    @Test func pullCycle_emptyPages_doesNotFire() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let refreshBumps = CallCounter()
        let stub = StubHTTPSession()  // default = página vacía (200, deltas:[])
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub,
            onRemoteChangesApplied: { refreshBumps.count += 1 })
        let outcome = await client.pullUntilExhausted(context: context, limit: 1)

        #expect(outcome == .completed(pages: 0, deltasApplied: 0))
        #expect(refreshBumps.count == 0)  // sin deltas aplicados → sin bump
    }

    // MARK: - Test 8 · Dead-letter para upstream_400 (pieza 2 / A2)

    private func seedOutbox(
        _ context: ModelContext, group: String = "SplitGroup-A",
        mid: UUID, rejectedReason: String? = nil
    ) throws -> GroupSyncOutbox {
        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
            clientMutationID: mid, fieldsJSON: "{\"amount\":\"1.0000\"}", author: "",
            rejectedReason: rejectedReason)
        context.insert(row)
        try context.save()
        return row
    }

    private func pushResultJSON(mid: UUID, status: String, reason: String, outcome: String) -> Data {
        Data("""
        {"results":[{"sync_id":"s","client_mutation_id":"\(mid.uuidString.lowercased())","status":"\(status)","reason":"\(reason)","outcome":\(outcome)}]}
        """.utf8)
    }

    @Test func push_upstream400_deadLettersWithSanitizedCode_excludedFromNextPush() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(
            responseData: pushResultJSON(mid: mid, status: "rejected", reason: "upstream_400",
                                         outcome: "{\"code\":\"P0001\",\"message\":\"yala_not_authorized\"}"),
            statusCode: 200)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        _ = await client.pushPending(context: context)

        let rows = try groupOutbox(context)
        #expect(rows.count == 1)
        #expect(rows.first?.rejectedReason == "upstream_400:yala_not_authorized")
        #expect(rows.first?.rejectedAt != nil)

        // Siguiente push: la fila dead-lettered queda EXCLUIDA (predicate rejectedReason == nil) → sin request.
        _ = await client.pushPending(context: context)
        #expect(stub.callCount == 1)
    }

    @Test func push_upstream503_isTransient_rowStaysAlive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(
            responseData: pushResultJSON(mid: mid, status: "rejected", reason: "upstream_503",
                                         outcome: "null"),
            statusCode: 200)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        _ = await client.pushPending(context: context)

        let rows = try groupOutbox(context)
        #expect(rows.count == 1)
        #expect(rows.first?.rejectedReason == nil)  // viva → retriable

        // Siguiente push SÍ la reintenta (sigue pendiente) → segundo request.
        _ = await client.pushPending(context: context)
        #expect(stub.callCount == 2)
    }

    @Test func push_noopGroupNotFound_purgesRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(
            responseData: pushResultJSON(mid: mid, status: "noop", reason: "group_not_found",
                                         outcome: "{\"op\":\"upsert\",\"noop\":true,\"reason\":\"group_not_found\"}"),
            statusCode: 200)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        _ = await client.pushPending(context: context)
        // La purga del noop group_not_found SE MANTIENE (decisión G3).
        #expect(try groupOutbox(context).isEmpty)
    }

    // MARK: - Test 8b · Header X-Yala-Device-Token del push (G8-3)

    /// Con un provider registrar-backed (non-nil), el push lleva el header `X-Yala-Device-Token` → el server
    /// excluye SOLO este device del autor del fan-out (el 2º device del autor SÍ recibe el silent push).
    @Test func push_includesDeviceTokenHeader_whenProviderGivesToken() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let deviceToken = String(repeating: "a", count: 64)
        let stub = StubHTTPSession(
            responseData: pushResultJSON(mid: mid, status: "applied", reason: "", outcome: "null"),
            statusCode: 200)
        let client = GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: stub,
            deviceTokenProvider: { deviceToken })

        _ = await client.pushPending(context: context)
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "X-Yala-Device-Token") == deviceToken)
    }

    /// Con el DEFAULT del init (`{ nil }`), el header queda AUSENTE (byte-idéntico al pre-G8-3 / flag OFF).
    @Test func push_omitsDeviceTokenHeader_withDefaultNilProvider() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(
            responseData: pushResultJSON(mid: mid, status: "applied", reason: "", outcome: "null"),
            statusCode: 200)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)

        _ = await client.pushPending(context: context)
        #expect(stub.lastRequest?.value(forHTTPHeaderField: "X-Yala-Device-Token") == nil)
    }

    // MARK: - Test 9 · RE-DRIVE del dead-letter al aprobar al member (A2)

    /// Un member `pendingApproval` que escribió contenido fue rechazado (upstream_400:yala_not_authorized).
    /// Al bajar por pull su fila con status "active" siendo el PROPIO usuario, sus filas dead-lettered de ese
    /// grupo se REVIVEN (rejectedReason = nil) → reintento natural. Otros códigos permanentes NO se re-driven.
    @Test func apply_member_becomingActiveCurrentUser_revivesNotAuthorizedDeadLetters() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let notAuthMid = UUID(); let badRequestMid = UUID(); let otherGroupMid = UUID()
        let notAuth = try seedOutbox(context, group: "zone-1", mid: notAuthMid,
                                     rejectedReason: "upstream_400:yala_not_authorized")
        let badRequest = try seedOutbox(context, group: "zone-1", mid: badRequestMid,
                                        rejectedReason: "upstream_400:yala_bad_request")
        let otherGroup = try seedOutbox(context, group: "zone-2", mid: otherGroupMid,
                                        rejectedReason: "upstream_400:yala_not_authorized")

        // currentUserID == el userID del member que se aprueba.
        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(group: "zone-1")], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        // Solo el not_authorized de ESE grupo se revive.
        #expect(notAuth.rejectedReason == nil)
        #expect(notAuth.rejectedAt == nil)
        // Otros códigos permanentes y otros grupos NO se tocan.
        #expect(badRequest.rejectedReason == "upstream_400:yala_bad_request")
        #expect(otherGroup.rejectedReason == "upstream_400:yala_not_authorized")
    }

    /// El member que se aprueba es OTRO usuario (userID != currentUserID) → NO se revive nada (evita revivir
    /// por la aprobación de un compañero).
    @Test func apply_member_becomingActive_otherUser_doesNotRevive() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        let row = try seedOutbox(context, group: "zone-1", mid: mid,
                                 rejectedReason: "upstream_400:yala_not_authorized")

        let client = GroupsSyncClient(currentUserIDProvider: { "someone-else" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(group: "zone-1")], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(row.rejectedReason == "upstream_400:yala_not_authorized")  // intacto
    }

    // MARK: - Test 9b · Reset del cursor por-grupo al re-join (pendingApproval→active, H-2026-07-18-3)

    /// Decodifica el cursor por-grupo REALMENTE persistido en `groupCursorsJSON` (assert del estado real,
    /// no del mock — lección del repo).
    private func decodedCursor(_ cursor: GroupSyncCursor, group: String) -> Int64? {
        let map = try? JSONDecoder().decode([String: Int64].self, from: Data(cursor.groupCursorsJSON.utf8))
        return map?[group]
    }

    /// El PROPIO user pasa de `pendingApproval` a `active`: mientras estuvo pendiente RLS ocultó el contenido
    /// del grupo pero el cursor por-grupo AVANZÓ igual → al aprobarse, el cursor de ESE grupo se RESETEA a 0
    /// para re-pull del hueco. El reset gana sobre el avance de `page.cursors` de la MISMA página.
    @Test func apply_member_pendingApprovalToActive_currentUser_resetsGroupCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Member local PENDIENTE (matchea el delta por el path directo `memberKey`).
        let member = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        member.memberKey = "member-rec-1"
        context.insert(member)
        try context.save()

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"SplitGroup-A\":50}"   // el cursor YA había avanzado durante pending
        try context.save()

        // memberDelta() trae status "active" + user_id "auth-uid-1" (== currentUserID).
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 60], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)

        // Reseteado a 0 PESE al avance a 60 de esta página (el reset corre tras el merge de cursores).
        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 0)
    }

    /// Born-remote `nil`→active (member que aparece por primera vez ya activo): NO resetea — la primera bajada
    /// del grupo trae su contenido de una vez, no hay hueco. `priorStatus` nil no matchea `pendingApproval`.
    @Test func apply_member_bornRemoteActive_doesNotResetCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)

        // Sin member previo → born-remote. El outer-if del re-drive SÍ dispara (uid == current) pero la rama
        // estrecha del reset exige priorStatus == pendingApproval (aquí nil).
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 7], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)

        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 7)   // avanzó normal, sin reset
    }

    /// La transición pendingApproval→active es de OTRO usuario (userID != currentUserID) → NO resetea (el
    /// hueco de cursor es del PROPIO user; la aprobación de un compañero no lo abre).
    @Test func apply_member_pendingApprovalToActive_otherUser_doesNotReset() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let member = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        member.memberKey = "member-rec-1"
        context.insert(member)
        try context.save()

        let client = GroupsSyncClient(currentUserIDProvider: { "someone-else" })
        let cursor = try client.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"SplitGroup-A\":50}"
        try context.save()

        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 60], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)

        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 60)   // avanzó normal, sin reset
    }

    /// No-loop: tras el reset, un segundo apply del MISMO member (ya `active` local) NO vuelve a resetear —
    /// el cursor avanzado se conserva (el gate `priorStatus != "active"` ya no matchea).
    @Test func apply_member_secondApply_doesNotResetAgain() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let member = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        member.memberKey = "member-rec-1"
        context.insert(member)
        try context.save()

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        cursor.groupCursorsJSON = "{\"SplitGroup-A\":50}"
        try context.save()

        // 1er apply: transición pending→active → reset a 0.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 60], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)
        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 0)

        // 2º apply equivalente (member ya active local): NO resetea; el cursor avanza a 60 y se conserva.
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(serverSeq: 4)], cursors: ["SplitGroup-A": 60], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)
        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 60)   // avanzado, NO vuelve a 0
    }

    // MARK: - Test 9c · La fase del join intent se retira al aprobar (bug device 2026-07-31)

    /// Deja el tracker en «esperando aprobación» por el camino de producción (`handleJoinSuccess` hace
    /// exactamente esto: `rehydrate` + `noteMemberResolved`). El caller es responsable del `clear()`.
    private func trackPendingJoin(zone: String) {
        GroupJoinIntentTracker.shared.clear()
        GroupJoinIntentTracker.shared.rehydrate(zoneName: zone)
        GroupJoinIntentTracker.shared.noteMemberResolved(zoneName: zone, status: .pendingApproval)
        #expect(GroupJoinIntentTracker.shared.phase == .pendingApproval)
    }

    /// EL BUG: el owner aprueba (`approve_member - Ok`), el pull baja el member propio `active` —el banner de
    /// dentro del grupo desaparece porque lo pinta el status local— y el banner de tab
    /// `groups.invite.waitingApproval.banner` se quedaba puesto PARA SIEMPRE: este canal no tenía quién
    /// observase el member tras el pull (no llama al reconciliador) y el intent ya estaba limpio, así que sus
    /// cuatro triggers salían por `guard !entries.isEmpty`.
    @Test func apply_member_ownApproval_retiresPendingApprovalPhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        // Member propio PENDIENTE. `isCurrentUser` queda APAGADO a propósito: es lo que recibe quien se une
        // por el canal backend (`applyMember` nunca lo setea) y por eso la identidad va por `sub`.
        let mine = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        mine.memberKey = "member-rec-1"
        mine.userID = "auth-uid-1"
        context.insert(mine)
        try context.save()
        #expect(mine.isCurrentUser == false)

        trackPendingJoin(zone: "SplitGroup-A")

        // memberDelta() trae status "active" + user_id "auth-uid-1" (== currentUserID) para member-rec-1.
        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 4], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)

        #expect(GroupJoinIntentTracker.shared.phase == .active, """
            El member propio quedó `active` en el store y la fase siguió en `.pendingApproval`: el banner \
            «esperando aprobación» se queda puesto para siempre, con la aprobación ya aplicada.
            """)
    }

    /// El rechazo era el gemelo silencioso del mismo bug: sin observador, un member `rejected` dejaba el
    /// banner «esperando aprobación» igual de pegado. `noteMemberResolved` lo lleva a terminal (`clear()`) y
    /// la pantalla del grupo pinta su propio banner de rechazo.
    @Test func apply_member_ownRejection_retiresPendingApprovalPhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        let mine = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        mine.memberKey = "member-rec-1"
        mine.userID = "auth-uid-1"
        context.insert(mine)
        try context.save()

        trackPendingJoin(zone: "SplitGroup-A")

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        let rejected = GroupPulledDelta(
            entityType: "group_members", groupID: "SplitGroup-A", rawSyncID: "member-rec-1", syncID: nil,
            op: .upsert,
            fields: [
                "display_name": .string("Alice"), "role": .string("member"),
                "status": .string(SplitMemberStatus.rejected.rawValue),
                "user_id": .string("auth-uid-1"),
            ],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000c",
            serverSeq: 4, schemaVersion: 1)
        client.applyPulledPage(
            GroupPulledPage(deltas: [rejected], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(GroupJoinIntentTracker.shared.phase == .idle)
        #expect(GroupJoinIntentTracker.shared.zoneName == nil)
    }

    /// Lo que se publica es el status del member PROPIO leído del store, NUNCA el del delta: en el mismo pull
    /// baja la aprobación de un compañero, y retirar el banner con ella mentiría al invitado (sigue pendiente).
    @Test func apply_member_otherUserApproved_keepsPendingApprovalPhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        // Yo sigo PENDIENTE, con otro member_key que el del delta que baja aprobado.
        let mine = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        mine.memberKey = "11111111-1111-1111-1111-111111111111"
        mine.userID = "auth-uid-1"
        context.insert(mine)
        try context.save()

        trackPendingJoin(zone: "SplitGroup-A")

        // El delta aprobado es de OTRO usuario (user_id distinto del currentUserID).
        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(userID: .string("someone-else"))],
                            cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(GroupJoinIntentTracker.shared.phase == .pendingApproval, """
            La fase se movió por el member de OTRO: el invitado vería «¡Todo listo!» sin estar aprobado.
            """)
    }

    /// Members de OTRA zona no tocan la fase del join en curso (el pull entrega los de todos los grupos).
    @Test func apply_member_otherZone_doesNotTouchTrackedPhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        // En la zona B mi member está ACTIVO; en la trackeada (A) sigo pendiente.
        let inB = SplitMember(groupZoneID: "zone-B", displayName: "Alice", status: .active)
        inB.memberKey = "member-rec-1"
        inB.userID = "auth-uid-1"
        context.insert(inB)
        let inA = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        inA.memberKey = "22222222-2222-2222-2222-222222222222"
        inA.userID = "auth-uid-1"
        context.insert(inA)
        try context.save()

        trackPendingJoin(zone: "SplitGroup-A")

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta(group: "zone-B")], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(GroupJoinIntentTracker.shared.phase == .pendingApproval)
    }

    /// La publicación es POST-SAVE: con el save de la página fallido el `rollback()` revierte el member, así
    /// que retirar el banner ahí sería anunciar una aprobación que no está en disco.
    @Test func apply_saveFails_doesNotPublishJoinPhase() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        // El member propio pendiente TIENE que existir: dentro de la transacción el fetch ve los cambios sin
        // commitear, así que una publicación mal colocada leería `.active` y retiraría el banner. Sin esta
        // fila el test pasaría igual con el bug.
        let mine = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Alice", status: .pendingApproval)
        mine.memberKey = "member-rec-1"
        mine.userID = "auth-uid-1"
        context.insert(mine)
        try context.save()

        trackPendingJoin(zone: "SplitGroup-A")

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client._testThrowOnApplySave = true
        let ok = client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(ok == false)
        #expect(GroupJoinIntentTracker.shared.phase == .pendingApproval, """
            Se publicó la fase con el save revertido: el banner se retira por un member que no llegó al store.
            """)
    }

    /// Sin join trackeado (`.idle`, el caso de casi todos los pulls) el apply NO resucita ningún banner.
    @Test func apply_member_noTrackedJoin_staysIdle() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { GroupJoinIntentTracker.shared.clear() }

        GroupJoinIntentTracker.shared.clear()

        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-1" })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(GroupJoinIntentTracker.shared.phase == .idle)
        #expect(GroupJoinIntentTracker.shared.zoneName == nil)
    }

    // MARK: - Test 10 · Loop de cadencia (pieza 4b / A5 / A6) — sin sleeps reales

    @Test func loop_terminatesOnSessionExpired_noRealSleeps() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        // 401 en cualquier request → el pull (outbox vacío ⇒ el push no manda) devuelve sessionExpired.
        // `forceRefreshTokenProvider: { nil }` (hermético, sin tocar el singleton): el retry-once del 401
        // NO consigue token nuevo → sessionExpired como antes del H-2026-07-18-4. El 401 SIN refresh
        // exitoso DEBE seguir terminando el loop.
        let stub = StubHTTPSession(statusCode: 401)
        let sleeper = SleeperCounter()
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true },
                                      forceRefreshTokenProvider: { nil })
        client.sleeper = { _ in sleeper.count += 1 }

        client.startIfEligible(context: context)
        await client._testLoopTask?.value

        #expect(stub.callCount == 1)   // 1 pull → 401 (sin refresh) → loop termina
        #expect(sleeper.count == 0)    // sessionExpired rompe ANTES del sleeper
    }

    /// Un 403 (cuenta no disponible) arma `stoppedUntilRelaunch` y TERMINA el loop; un `startIfEligible`
    /// posterior en el MISMO proceso es NO-OP (no re-arranca — `_testLoopTask` nil, callCount estable).
    @Test func loop_403_armsStopUntilRelaunch_subsequentStartIsNoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        // 403 en el pull (outbox vacío ⇒ el push no manda) → accountUnavailable → stopUntilRelaunch.
        let stub = StubHTTPSession(statusCode: 403)
        let sleeper = SleeperCounter()
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true })
        client.sleeper = { _ in sleeper.count += 1 }

        client.startIfEligible(context: context)
        await client._testLoopTask?.value

        #expect(stub.callCount == 1)   // 1 pull → 403 → loop termina
        #expect(sleeper.count == 0)    // accountUnavailable rompe ANTES del sleeper

        // startIfEligible posterior = NO-OP (stoppedUntilRelaunch armado): no re-arranca el loop.
        client.startIfEligible(context: context)
        #expect(client._testLoopTask == nil)
        #expect(stub.callCount == 1)   // callCount estable (loop no re-arrancó)
    }

    @Test func loop_singleInstance_secondStartIsNoOpWhileAlive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let stub = StubHTTPSession(statusCode: 401)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true },
                                      forceRefreshTokenProvider: { nil })

        client.startIfEligible(context: context)
        let task = client._testLoopTask
        client.startIfEligible(context: context)  // segundo arranque = no-op (loop vivo)
        await task?.value
        #expect(stub.callCount == 1)  // una sola vuelta corrió (no se duplicó el loop)
    }

    // MARK: - Test 10b · Retry-once del 401 con refresh forzado (H-2026-07-18-4)

    /// 401 → refresh forzado devuelve un token DISTINTO → RE-EMITE la request UNA vez con el bearer nuevo
    /// y COMPLETA. Asserta el header real de la 2ª request (el bearer nuevo) y que el outcome NO es
    /// sessionExpired.
    @Test func retry401_refreshesToken_reissuesOnce_thenCompletes() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        // 1ª respuesta 401; 2ª (tras el refresh) 200 applied → purga la fila.
        let stub = SequenceStubHTTPSession([
            .init(data: Data(), status: 401),
            .init(data: pushResultJSON(mid: mid, status: "applied", reason: "", outcome: "null"), status: 200),
        ], fallback: .init(data: Data(), status: 401))
        let client = GroupsSyncClient(
            tokenProvider: { "old-jwt" }, urlSession: stub,
            forceRefreshTokenProvider: { "new-jwt" })

        let outcome = await client.pushPending(context: context)

        // Re-emitió UNA vez: 2 requests, la 1ª con el token viejo, la 2ª con el NUEVO (header real).
        #expect(stub.callCount == 2)
        #expect(stub.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer old-jwt")
        #expect(stub.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new-jwt")
        // No es sessionExpired: completó.
        if case .sessionExpired = outcome { Issue.record("no debe ser sessionExpired tras el retry exitoso") }
        // La fila se purgó (applied en la re-emisión).
        #expect(try groupOutbox(context).isEmpty)
    }

    /// El pull también rescata el 401: 401 → refresh distinto → re-emite y aplica la página (vacía).
    @Test func retry401_pull_refreshesToken_reissuesOnce() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let stub = SequenceStubHTTPSession([
            .init(data: Data(), status: 401),
            .init(data: emptyPageJSON, status: 200),
        ], fallback: .init(data: emptyPageJSON, status: 200))
        let client = GroupsSyncClient(
            tokenProvider: { "old-jwt" }, urlSession: stub,
            forceRefreshTokenProvider: { "new-jwt" })

        let outcome = await client.pullAndApplyOnce(context: context)

        #expect(stub.callCount == 2)
        #expect(stub.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new-jwt")
        #expect(outcome == .applied(deltas: 0, saved: true))
    }

    /// 401 + refresh devuelve NIL → sin re-emisión → sessionExpired (comportamiento pre-fix).
    @Test func retry401_refreshReturnsNil_yieldsSessionExpired() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(statusCode: 401)
        let client = GroupsSyncClient(
            tokenProvider: { "old-jwt" }, urlSession: stub,
            forceRefreshTokenProvider: { nil })

        let outcome = await client.pushPending(context: context)

        #expect(stub.callCount == 1)   // sin re-emisión
        #expect(outcome == .sessionExpired(pending: 1))
        #expect(try groupOutbox(context).first?.rejectedReason == nil)  // no dead-letter (401 no purga)
    }

    /// 401 + refresh devuelve el MISMO token → sin re-emisión (evita un round-trip inútil) → sessionExpired.
    @Test func retry401_sameToken_yieldsSessionExpired_noReissue() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let mid = UUID()
        _ = try seedOutbox(context, mid: mid)

        let stub = StubHTTPSession(statusCode: 401)
        let client = GroupsSyncClient(
            tokenProvider: { "same-jwt" }, urlSession: stub,
            forceRefreshTokenProvider: { "same-jwt" })

        let outcome = await client.pushPending(context: context)

        #expect(stub.callCount == 1)   // fresh == token → no re-emite
        #expect(outcome == .sessionExpired(pending: 1))
    }

    /// Push MULTI-CHUNK con expiry a mitad: el chunk 1 rescata el 401 (refresh forzado UNA vez) y el
    /// token FRESCO se propaga a los chunks siguientes (inout) — el chunk 2 NO fuerza su propio refresh
    /// y ya sale con el bearer nuevo.
    @Test func retry401_multiChunk_reusesFreshToken_singleRefresh() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // 51 filas → 2 chunks (pushChunkSize = 50).
        var mids: [UUID] = []
        for _ in 0..<(GroupsSyncClient.pushChunkSize + 1) {
            let mid = UUID()
            mids.append(mid)
            context.insert(GroupSyncOutbox(
                syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
                op: .upsert, hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
                clientMutationID: mid, fieldsJSON: "{\"amount\":\"1.0000\"}", author: ""))
        }
        try context.save()

        // Respuesta 200 con TODOS los mids applied (applyResults solo matchea los del chunk; extras skip).
        let items = mids.map {
            "{\"sync_id\":\"s\",\"client_mutation_id\":\"\($0.uuidString.lowercased())\",\"status\":\"applied\"}"
        }.joined(separator: ",")
        let allApplied = Data("{\"results\":[\(items)]}".utf8)

        // chunk1: 401 → retry 200; chunk2: 200 directo (SIN 401 previo — ya va con el token fresco).
        let stub = SequenceStubHTTPSession([
            .init(data: Data(), status: 401),
            .init(data: allApplied, status: 200),
            .init(data: allApplied, status: 200),
        ], fallback: .init(data: allApplied, status: 200))
        let refreshes = SleeperCounter()
        let client = GroupsSyncClient(
            tokenProvider: { "old-jwt" }, urlSession: stub,
            forceRefreshTokenProvider: { refreshes.count += 1; return "new-jwt" })

        let outcome = await client.pushPending(context: context)

        #expect(refreshes.count == 1)  // UN solo refresh forzado para todo el push
        #expect(stub.callCount == 3)   // chunk1 (401) + chunk1 retry + chunk2 directo
        #expect(stub.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old-jwt")
        #expect(stub.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new-jwt")
        #expect(stub.requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer new-jwt")
        if case .sessionExpired = outcome { Issue.record("no debe ser sessionExpired tras el retry exitoso") }
        #expect(try groupOutbox(context).isEmpty)  // los 51 se purgaron (applied)
    }

    // MARK: - Test 10c · Re-arranque del loop muerto (H-2026-07-18-4)

    /// Tras un loop muerto por sessionExpired (401, `stoppedUntilRelaunch` NO armado), un `startIfEligible`
    /// posterior RE-CREA el loopTask (la red del residual: el retry-once no rescató el 401).
    @Test func restart_afterSessionExpiredStop_rearmsLoop_whenSessionAlive() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let stub = StubHTTPSession(statusCode: 401)
        let sleeper = SleeperCounter()
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true },
                                      forceRefreshTokenProvider: { nil })
        client.sleeper = { _ in sleeper.count += 1 }

        client.startIfEligible(context: context)
        await client._testLoopTask?.value
        #expect(stub.callCount == 1)          // 1ª vuelta: pull 401 → sessionExpired → loop muere
        #expect(client._testLoopTask == nil)  // loop liberado

        // sessionExpired NO arma stoppedUntilRelaunch → re-arranca (foreground / post-sign-in).
        client.startIfEligible(context: context, trigger: "foreground")
        await client._testLoopTask?.value
        #expect(stub.callCount == 2)          // el loop RE-ARRANCÓ y corrió otra vuelta
    }

    /// Regresión de `stoppedUntilRelaunch`: tras un 403, `startIfEligible` sigue siendo NO-OP aun con un
    /// refresh disponible (el retry-401 NO interfiere con la semántica de 403 — nunca se dispara ahí).
    @Test func restart_403_stillNoOp() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let stub = StubHTTPSession(statusCode: 403)
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub, sessionCheck: { true },
                                      forceRefreshTokenProvider: { "new-jwt" })

        client.startIfEligible(context: context)
        await client._testLoopTask?.value
        #expect(stub.callCount == 1)          // pull 403 → accountUnavailable → stopUntilRelaunch

        // Aun con refresh disponible, 403 armó stoppedUntilRelaunch → no re-arranca.
        client.startIfEligible(context: context, trigger: "foreground")
        #expect(client._testLoopTask == nil)
        #expect(stub.callCount == 1)          // callCount estable
    }

    // MARK: - Test 11 · Mapeo de outcomes del canal → CadenceOutcome (A4, uso de SyncCadencePolicy)

    @Test func cadenceMapping_pushOutcomes() {
        #expect(GroupsSyncCadence.stopOutcome(push: .completed([])) == nil)
        #expect(GroupsSyncCadence.stopOutcome(push: .sessionExpired(pending: 3)) == .sessionExpired)
        #expect(GroupsSyncCadence.stopOutcome(push: .accountUnavailable) == .accountUnavailable)
        #expect(GroupsSyncCadence.stopOutcome(push: .transient) == .transient)
    }

    @Test func cadenceMapping_pullOutcomes() {
        #expect(GroupsSyncCadence.outcome(pull: .completed(pages: 2, deltasApplied: 4)) == .completed)
        #expect(GroupsSyncCadence.outcome(pull: .sessionExpired) == .sessionExpired)
        #expect(GroupsSyncCadence.outcome(pull: .accountUnavailable) == .accountUnavailable)
        #expect(GroupsSyncCadence.outcome(pull: .transient) == .transient)
    }

    /// El USO de la política reutilizada (A4): los outcomes del canal producen las acciones esperadas —
    /// completed → 60s, transient → backoff exponencial con cap, stops.
    @Test func cadenceMapping_usesSyncCadencePolicyActions() {
        #expect(SyncCadencePolicy.nextAction(outcome: .completed, consecutiveTransients: 0)
                == .scheduleNext(60))
        #expect(SyncCadencePolicy.nextAction(outcome: .transient, consecutiveTransients: 1)
                == .backoff(5))
        #expect(SyncCadencePolicy.nextAction(outcome: .transient, consecutiveTransients: 3)
                == .backoff(20))
        #expect(SyncCadencePolicy.nextAction(outcome: .sessionExpired, consecutiveTransients: 0)
                == .stopUntilSignIn)
        #expect(SyncCadencePolicy.nextAction(outcome: .accountUnavailable, consecutiveTransients: 0)
                == .stopUntilRelaunch)
    }

    // MARK: - Fase 2 · 2.1 Notificaciones de grupo desde el apply del backend

    /// Colector del `RemoteChangeSet` emitido por el apply (mismo motivo que `CallCounter`: var local
    /// capturada en closure escapante bajo Swift 6).
    final class ChangeSetCollector: @unchecked Sendable { var sets: [RemoteChangeSet] = [] }

    private func expenseDelta(
        id: UUID, group: String = "SplitGroup-A", op: SyncOutboxOp = .upsert, serverSeq: Int64 = 3,
        amount: String = "25.0000"
    ) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitExpense.table, groupID: group,
            rawSyncID: id.uuidString.lowercased(), syncID: id, op: op,
            fields: ["expense_description": .string("Cena"), "amount": .string(amount),
                     "currency_code": .string("PEN"), "paid_by_member_key": .string("m1")],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000d",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    private func settlementDelta(
        id: UUID, group: String = "SplitGroup-A", serverSeq: Int64 = 3
    ) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitSettlement.table, groupID: group,
            rawSyncID: id.uuidString.lowercased(), syncID: id, op: .upsert,
            fields: ["from_member_key": .string("m1"), "to_member_key": .string("m2"),
                     "amount": .string("10.0000"), "currency_code": .string("PEN")],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000e",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// Un gasto que este device no tenía → `newExpenses`, indexado por el `SplitGroup.id` LOCAL (no por el
    /// `group_id` del wire, que es el `cloudKitZoneID`): es lo que el consumidor usa para el nombre del
    /// grupo, el rate-limit y el deep-link.
    @Test func applyPulledPage_newExpense_emitsNewExpenseKeyedByLocalGroupID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        let expenseID = UUID()
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: expenseID)], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.count == 1)
        let set = try #require(collector.sets.first)
        #expect(set.newExpenses.count == 1)
        #expect(set.newExpenses.first?.id == expenseID)
        #expect(set.newExpenses.first?.groupID == group.id)
        #expect(set.modifiedExpenses.isEmpty)
    }

    /// Segunda entrega del MISMO gasto (edición ajena o eco) → `modifiedExpenses`, no `newExpenses`.
    @Test func applyPulledPage_knownExpense_emitsModified() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        let expenseID = UUID()
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: expenseID)], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: expenseID, serverSeq: 4, amount: "30.0000")],
                            cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.count == 2)
        #expect(collector.sets.last?.newExpenses.isEmpty == true)
        #expect(collector.sets.last?.modifiedExpenses.first?.id == expenseID)
    }

    /// Una liquidación nueva notifica; su modificación NO (paridad con la clasificación del fetch CloudKit).
    @Test func applyPulledPage_settlement_notifiesOnlyOnInsert() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        let settlementID = UUID()
        client.applyPulledPage(
            GroupPulledPage(deltas: [settlementDelta(id: settlementID)], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [settlementDelta(id: settlementID, serverSeq: 4)],
                            cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.first?.newSettlements.first?.id == settlementID)
        #expect(collector.sets.count == 1)  // la 2ª página no tuvo NADA que notificar
    }

    /// Un tombstone no notifica (el consumidor no podría resolver la fila borrada).
    @Test func applyPulledPage_tombstone_doesNotNotify() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: UUID(), op: .tombstone)], cursors: [:],
                            memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.isEmpty)
    }

    /// Zona sin `SplitGroup` local: se descarta en la traducción (sin grupo no hay nombre ni deep-link).
    /// El delta SÍ se aplica — solo se calla la notificación.
    @Test func applyPulledPage_unknownZone_appliesButDoesNotNotify() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        let expenseID = UUID()
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: expenseID, group: "SplitGroup-Huerfana")],
                            cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.isEmpty)
        #expect(try context.fetch(FetchDescriptor<SplitExpense>()).count == 1)
    }

    /// El `GroupMeta` de la MISMA página basta para resolver el grupo: la traducción corre al cierre, con
    /// todos los inserts de la página ya en el contexto (un grupo recién descubierto también notifica).
    @Test func applyPulledPage_groupMetaInSamePage_resolvesGroupID() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        let expenseID = UUID()
        client.applyPulledPage(
            GroupPulledPage(deltas: [expenseDelta(id: expenseID), groupMetaDelta(serverSeq: 5)],
                            cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let group = try #require(try context.fetch(FetchDescriptor<SplitGroup>()).first)
        #expect(collector.sets.first?.newExpenses.first?.groupID == group.id)
    }

    // MARK: - Fase 2 · 2.2 Notificaciones de miembro desde el apply del backend

    private func memberDelta(
        memberKey: String, status: SplitMemberStatus, userID: String?, role: String = "member",
        group: String = "SplitGroup-A", serverSeq: Int64 = 3
    ) -> GroupPulledDelta {
        var fields: [String: WireValue] = [
            "display_name": .string("Alice"),
            "role": .string(role),
            "status": .string(status.rawValue),
            "joined_at": .string("2026-07-15T00:00:00.000Z"),
        ]
        if let userID { fields["user_id"] = .string(userID) }
        return GroupPulledDelta(
            entityType: "group_members", groupID: group, rawSyncID: memberKey, syncID: nil,
            op: .upsert, fields: fields, fieldHlcs: [:],
            hlc: "2026-07-15T00:00:00.000Z-0000-000000000000000f",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// Miembro activo ajeno en una zona ASENTADA → «se unió al grupo».
    @Test func applyMember_newActive_inEstablishedZone_emitsJoined() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-me" },
                                      onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(
                deltas: [memberDelta(memberKey: "11111111-1111-1111-1111-111111111111",
                                     status: .active, userID: "auth-uid-otro")],
                cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.first?.newMembers.count == 1)
        #expect(collector.sets.first?.newPendingMembers.isEmpty == true)
    }

    /// AUTOEXCLUSIÓN por identidad: el miembro del PROPIO usuario jamás notifica. En este canal la
    /// identidad es el `sub` (`user_id` del wire), no el record name de CloudKit. Case-insensitive.
    @Test func applyMember_ownMember_neverNotifies() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(currentUserIDProvider: { "AUTH-UID-ME" },
                                      onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(
                deltas: [memberDelta(memberKey: "11111111-1111-1111-1111-111111111111",
                                     status: .active, userID: "auth-uid-me")],
                cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.isEmpty)
    }

    /// BASELINE: durante el primer import de la zona se suprime TODO (joined y pending) — los miembros
    /// preexistentes del grupo al que uno acaba de unirse no son altas nuevas.
    @Test func applyMember_duringInitialImport_suppressesJoinedAndPending() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        group.initialMemberImportStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        // Admin del propio usuario: sin el baseline, el pending SÍ notificaría.
        let me = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Yo", role: "admin")
        me.userID = "auth-uid-me"
        context.insert(me)
        try context.save()

        let collector = ChangeSetCollector()
        let client = GroupsSyncClient(
            currentUserIDProvider: { "auth-uid-me" },
            now: { Date(timeIntervalSince1970: 1_700_000_060) },  // 1 min dentro de la ventana de 15
            onRemoteChanges: { collector.sets.append($0) })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(
                deltas: [memberDelta(memberKey: "11111111-1111-1111-1111-111111111111",
                                     status: .active, userID: "auth-uid-otro"),
                         memberDelta(memberKey: "22222222-2222-2222-2222-222222222222",
                                     status: .pendingApproval, userID: "auth-uid-tercero", serverSeq: 4)],
                cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(collector.sets.isEmpty)
    }

    /// Una solicitud pendiente solo notifica al ADMIN. El admin se resuelve por el `sub`, no por
    /// `isCurrentUser` (que el apply del backend jamás setea).
    @Test func applyMember_pendingApproval_notifiesAdminOnly() throws {
        for (role, expected) in [("admin", 1), ("member", 0)] {
            let dir = freshDir(); defer { cleanup(dir) }
            let context = try makeContext(dir)
            makeBackendGroup(zoneID: "SplitGroup-A", context: context)
            let me = SplitMember(groupZoneID: "SplitGroup-A", displayName: "Yo", role: role)
            me.userID = "auth-uid-me"
            context.insert(me)
            try context.save()

            let collector = ChangeSetCollector()
            let client = GroupsSyncClient(currentUserIDProvider: { "auth-uid-me" },
                                          onRemoteChanges: { collector.sets.append($0) })
            let cursor = try client.loadOrCreateCursor(context)
            client.applyPulledPage(
                GroupPulledPage(
                    deltas: [memberDelta(memberKey: "11111111-1111-1111-1111-111111111111",
                                         status: .pendingApproval, userID: "auth-uid-otro")],
                    cursors: [:], memberships: []),
                cursor: cursor, context: context)

            #expect(collector.sets.first?.newPendingMembers.count ?? 0 == expected,
                    "role=\(role) debía producir \(expected) solicitudes notificadas")
            #expect(collector.sets.first?.newMembers.isEmpty ?? true)
        }
    }

    /// Un grupo que NACE del pull arma el baseline: sus miembros preexistentes vienen detrás.
    @Test func applyGroupMeta_bornRemote_armsInitialImportBaseline() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let client = GroupsSyncClient(now: { stamp })
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [groupMetaDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        let group = try #require(try context.fetch(FetchDescriptor<SplitGroup>()).first)
        #expect(group.initialMemberImportStartedAt == stamp)
        #expect(group.isBackendGroup)
    }

    /// Agotar el pull cierra el baseline (gemelo de `didFetchRecordZoneChanges`): las notificaciones de
    /// membership se reanudan sin esperar a que venza la ventana de 15 min.
    @Test func pullUntilExhausted_withDeltas_clearsInitialImportBaseline() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        group.initialMemberImportStartedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try context.save()

        let stub = SequenceStubHTTPSession([
            .init(data: pageJSON(shareID: UUID(), group: "SplitGroup-A", serverSeq: 5, cursor: 5), status: 200),
            .init(data: emptyPageJSON, status: 200),
        ], fallback: .init(data: emptyPageJSON, status: 200))
        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: stub)
        let outcome = await client.pullUntilExhausted(context: context, limit: 1)

        #expect(outcome == .completed(pages: 1, deltasApplied: 1))
        #expect(group.initialMemberImportStartedAt == nil)
    }

    /// Un ciclo OCIOSO (sin deltas) no toca el baseline — el import inicial sigue abierto y no paga fetch.
    @Test func pullUntilExhausted_idleCycle_leavesBaselineIntact() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        group.initialMemberImportStartedAt = stamp
        try context.save()

        let client = GroupsSyncClient(tokenProvider: { "jwt" }, urlSession: StubHTTPSession())
        _ = await client.pullUntilExhausted(context: context, limit: 1)

        #expect(group.initialMemberImportStartedAt == stamp)
    }

    // MARK: - Fase 2 · 2.3 Freeze del bridge personal por soft-delete remoto

    private func hiddenGroupMetaDelta(
        group: String = "SplitGroup-A", hidden: Bool, serverSeq: Int64 = 5
    ) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: group,
            rawSyncID: nil, syncID: nil, op: .upsert,
            fields: ["name": .string("Viaje"), "is_hidden_for_all": .bool(hidden)],
            fieldHlcs: [:], hlc: "2026-07-15T00:00:00.000Z-0000-0000000000000010",
            serverSeq: serverSeq, schemaVersion: 1)
    }

    /// Siembra una TX de cuenta REAL bridgeada a la zona (la que el freeze debe soltar).
    @discardableResult
    private func makeBridgedTx(zone: String, context: ModelContext) -> TransactionItem {
        let account = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#111111",
                              iconName: "banknote", type: "cash", isSystemAccount: false)
        context.insert(account)
        let tx = TransactionItem(date: Date(timeIntervalSince1970: 1_700_000_000), amount: -40,
                                 currencyCode: "PEN", account: account)
        tx.splitExpenseID = UUID().uuidString
        tx.splitGroupZoneID = zone
        context.insert(tx)
        return tx
    }

    /// El grupo pasa a oculto-para-todos en el pull → la TX personal bridgeada queda LIBERADA (conserva
    /// monto, fecha y cuenta; solo se sueltan los punteros al grupo).
    @Test func applyGroupMeta_flipsToHidden_freezesPersonalBridge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        let tx = makeBridgedTx(zone: "SplitGroup-A", context: context)
        try context.save()
        GroupTransactionBridge.shared.setContext(context)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [hiddenGroupMetaDelta(hidden: true)], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(tx.splitGroupZoneID == nil)
        #expect(tx.splitExpenseID == nil)
        #expect(tx.amount == -40)  // el freeze libera punteros, no destruye la transacción
    }

    /// Un grupo que YA estaba oculto y vuelve a llegar no re-dispara el freeze; y uno visible tampoco.
    @Test func applyGroupMeta_noFlip_leavesBridgeAlone() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let group = makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        group.isHiddenForAll = true
        let tx = makeBridgedTx(zone: "SplitGroup-A", context: context)
        try context.save()
        GroupTransactionBridge.shared.setContext(context)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [hiddenGroupMetaDelta(hidden: true)], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(tx.splitGroupZoneID == "SplitGroup-A")  // sin flip → sin freeze
    }

    /// Invitado con fresh-install POSTERIOR al soft-delete: el grupo NACE oculto y el freeze igual corre
    /// (el valor previo de un born-remote es `false`).
    @Test func applyGroupMeta_bornHidden_freezesPersonalBridge() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tx = makeBridgedTx(zone: "SplitGroup-A", context: context)
        try context.save()
        GroupTransactionBridge.shared.setContext(context)

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        client.applyPulledPage(
            GroupPulledPage(deltas: [hiddenGroupMetaDelta(hidden: true)], cursors: [:], memberships: []),
            cursor: cursor, context: context)

        #expect(tx.splitGroupZoneID == nil)
    }

    // MARK: - Test 12 · «Me sacaron del grupo»: la remoción llega en NEGATIVO por `memberships` (S4)

    // `remove_member` deja la fila del miembro en `removed` y a partir de ahí la RLS no la entrega ⇒ el pull
    // NO trae ni un delta. Lo único que cambia es que el grupo desaparece de `memberships`, un campo que este
    // cliente decodificaba y no leía nadie (bug B-1 de la re-medición del 2026-08-04). Sin lector, el usuario
    // se queda un grupo FANTASMA editable: lo que apunte ahí se guarda local y no viaja.

    /// Grupo backend + una hija de cada clase, para poder afirmar que la limpieza barre la ZONA entera y no
    /// solo la fila del grupo.
    private func seedBackendZone(_ zone: String, context: ModelContext) {
        makeBackendGroup(zoneID: zone, context: context)
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
        let expense = SplitExpense(groupZoneID: zone, amount: 40, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: "member-1")
        context.insert(expense)
        context.insert(SplitShare(expenseID: expense.id, memberID: "member-1", amount: 20, groupZoneID: zone))
        context.insert(SplitSettlement(groupZoneID: zone, fromMemberID: "member-1",
                                       toMemberID: "member-2", amount: 20))
    }

    private func zoneCounts(
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

    /// Deja las zonas registradas en `groupCursorsJSON` — la evidencia de que el backend YA las enumeró para
    /// este device. Es el tercer gate de `reconcileLostMemberships`, el que distingue una remoción real de un
    /// grupo recién creado que todavía no ha pasado por ningún pull.
    private func markZonesEnumerated(
        _ zones: [String: Int64], cursor: GroupSyncCursor, context: ModelContext
    ) throws {
        cursor.groupCursorsJSON = String(decoding: try JSONEncoder().encode(zones), as: UTF8.self)
        try context.save()
    }

    /// Cede el hilo hasta que la condición se cumpla. La limpieza corre en un `Task { @MainActor }` (el
    /// cleanup es `async`, molde del canal viejo), así que no está en disco al volver de `applyPulledPage`.
    /// Sin sleeps (regla de testing): cesiones deterministas.
    private func settle(until condition: () -> Bool, yields: Int = 200) async {
        for _ in 0..<yields {
            if condition() { return }
            await Task.yield()
        }
    }

    /// Da margen a cualquier `Task` espurio antes de afirmar que NO pasó nada. Sin esto, un test negativo
    /// pasaría en verde simplemente por llegar antes que el borrado.
    private func drainPendingTasks(yields: Int = 40) async {
        for _ in 0..<yields { await Task.yield() }
    }

    private func groupsInZone(_ context: ModelContext, _ zone: String) -> Int {
        (try? context.fetchCount(
            FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone }))) ?? -1
    }

    /// **La aserción que carga el peso.** Página del ciclo IDLE —cero deltas, cero cursores, que es la forma
    /// EXACTA que toma una remoción— cuyo `memberships` ya no lista mi zona: se dispara
    /// `performRemovedSelfCleanup` y la zona desaparece entera, mientras la vecina que SÍ sigue listada queda
    /// intacta (sin ese segundo grupo, un barrido global pasaría igual de verde).
    ///
    /// MUTACIÓN: quitar la llamada a `reconcileLostMemberships` de la salida idle, o hacerla `return` antes de
    /// leer `page.memberships`, deja este test en rojo (exit 65).
    @Test func pull_membershipsWithoutMyZone_cleansTheZone_andResetsItsCursor() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-Gone", context: context)
        seedBackendZone("SplitGroup-Stays", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-Gone": 12, "SplitGroup-Stays": 7],
                                cursor: cursor, context: context)

        client.applyPulledPage(
            GroupPulledPage(deltas: [], cursors: [:], memberships: ["SplitGroup-Stays"]),
            cursor: cursor, context: context)
        await settle { self.groupsInZone(context, "SplitGroup-Gone") == 0 }

        #expect(try zoneCounts(context, zone: "SplitGroup-Gone") == (0, 0, 0, 0, 0))
        #expect(try zoneCounts(context, zone: "SplitGroup-Stays") == (1, 1, 1, 1, 1))
        // El cursor de la zona perdida vuelve a 0: sin eso, un re-join posterior no re-baja ni el
        // `split_groups` ni su contenido (todo tiene `server_seq` por debajo de la marca alta) y el
        // re-admitido se queda sin grupo.
        #expect(decodedCursor(cursor, group: "SplitGroup-Gone") == 0)
        #expect(decodedCursor(cursor, group: "SplitGroup-Stays") == 7)
    }

    /// Simétrico: la zona SIGUE en `memberships` ⇒ no se toca nada. Es lo que separa «leer la señal» de
    /// «borrar cada vez que pasa un pull».
    @Test func pull_membershipsWithMyZone_doesNotClean() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-A", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-A": 12], cursor: cursor, context: context)

        client.applyPulledPage(
            GroupPulledPage(deltas: [], cursors: [:], memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)
        await drainPendingTasks()

        #expect(try zoneCounts(context, zone: "SplitGroup-A") == (1, 1, 1, 1, 1))
        #expect(decodedCursor(cursor, group: "SplitGroup-A") == 12)
    }

    /// **Carrera del ALTA.** `GroupBackendMembershipService.createGroup`/`joinGroup` son server-first pero
    /// materializan la fila local DESPUÉS del `await` del RPC, así que un pull cuya petición salió ANTES vuelve
    /// —legítimamente— con un `memberships` sin el grupo recién creado. La zona no está en `groupCursorsJSON`
    /// (nadie se la ha enumerado todavía) ⇒ no es candidata.
    ///
    /// MUTACIÓN: quitar el gate `enumeratedByServer.contains(zone)` deja este test en rojo.
    @Test func pull_zoneNeverEnumeratedByServer_isNotACandidate() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-JustCreated", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)  // cursor VACÍO: ningún pull la ha listado

        client.applyPulledPage(
            GroupPulledPage(deltas: [], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        await drainPendingTasks()

        #expect(try zoneCounts(context, zone: "SplitGroup-JustCreated") == (1, 1, 1, 1, 1))
    }

    /// **No-regresión de la rama `.icloud`, que es la regla más importante de este release.** `memberships`
    /// es autoritativo para las zonas cuya verdad vive en el backend y no dice NADA de las de CloudKit: un
    /// grupo con `isBackendGroup == false` no se toca aunque no aparezca en la lista.
    ///
    /// MUTACIÓN: quitar el filtro `belongsToBackendChannel` deja este test en rojo.
    @Test func pull_cloudKitZone_isNeverTouchedByMemberships() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let ck = SplitGroup(name: "CK")
        ck.cloudKitZoneID = "SplitGroup-CloudKit"      // isBackendGroup == false (default)
        context.insert(ck)
        context.insert(SplitMember(groupZoneID: "SplitGroup-CloudKit", displayName: "Ana"))
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-CloudKit": 3], cursor: cursor, context: context)

        client.applyPulledPage(
            GroupPulledPage(deltas: [], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        await drainPendingTasks()

        #expect(groupsInZone(context, "SplitGroup-CloudKit") == 1)
        #expect(decodedCursor(cursor, group: "SplitGroup-CloudKit") == 3)
    }

    /// **Invariante del wire.** El gateway construye `deltas` y `cursors` recorriendo `memberGroupIds`
    /// (`routes.ts:455`), así que un grupo presente en la página ES un grupo del que soy miembro: la unión
    /// gana sobre un `memberships` que lo contradiga.
    @Test func pull_zoneInThisPagesDeltas_survivesEvenIfMembershipsOmitsIt() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-A", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-A": 3], cursor: cursor, context: context)

        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: [:], memberships: []),
            cursor: cursor, context: context)
        await drainPendingTasks()

        #expect(groupsInZone(context, "SplitGroup-A") == 1)
    }

    /// **`nil` no es `[]`.** El gateway manda el campo SIEMPRE; su ausencia es una respuesta que no conoce el
    /// contrato, y leerla como «no eres miembro de nada» borraría grupos vivos. Fail-closed.
    ///
    /// MUTACIÓN: devolver el `?? []` a `decodePage`, o el `guard let` a un `?? []`, deja este test en rojo.
    @Test func pull_absentMembershipsField_isNotAnEmptyMembership() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-A", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-A": 3], cursor: cursor, context: context)

        // Envelope SIN el campo — exactamente lo que decodifica `decodePage`.
        let page = try GroupsSyncClient.decodePage(Data(#"{"deltas":[],"cursors":{}}"#.utf8))
        #expect(page.memberships == nil)
        client.applyPulledPage(page, cursor: cursor, context: context)
        await drainPendingTasks()

        #expect(groupsInZone(context, "SplitGroup-A") == 1)
    }

    /// Una página CON deltas (que sí persiste) también reconcilia: el segundo call-site, el de después del
    /// save. La zona perdida no puede estar en esa página por construcción del gateway, así que el sujeto es
    /// una zona vecina.
    @Test func pull_pageWithDeltas_alsoReconcilesTheZonesItDidNotBring() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        seedBackendZone("SplitGroup-A", context: context)
        seedBackendZone("SplitGroup-Gone", context: context)
        try context.save()

        let client = GroupsSyncClient()
        let cursor = try client.loadOrCreateCursor(context)
        try markZonesEnumerated(["SplitGroup-A": 3, "SplitGroup-Gone": 9], cursor: cursor, context: context)

        client.applyPulledPage(
            GroupPulledPage(deltas: [memberDelta()], cursors: ["SplitGroup-A": 4],
                            memberships: ["SplitGroup-A"]),
            cursor: cursor, context: context)
        await settle { self.groupsInZone(context, "SplitGroup-Gone") == 0 }

        #expect(try zoneCounts(context, zone: "SplitGroup-Gone") == (0, 0, 0, 0, 0))
        #expect(groupsInZone(context, "SplitGroup-A") == 1)
    }

    // MARK: - Test 12b · Source-scan del cableado (los DOS call-sites y su orden)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func groupsSyncClientSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"),
            encoding: .utf8)
    }

    /// Cuerpo de `applyPulledPage`, de su firma a la declaración siguiente. `nil` si cambiaron, y el test lo
    /// convierte en rojo con `#require`: un escáner que pierde su sujeto NO debe pasar en verde.
    private static func applyPulledPageBody(_ source: String) -> String? {
        let signature =
            "func applyPulledPage(_ page: GroupPulledPage, cursor: GroupSyncCursor, context: ModelContext) -> Bool {"
        guard let start = source.range(of: signature) else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    /// Espeja «me sacaron del grupo»") else { return nil }
        return String(rest[..<end.lowerBound])
    }

    /// **Lo que decide aquí es QUIÉN llama y en qué ORDEN, así que la red tiene que ser un source-scan** —
    /// molde `AttestWiringTests` / `GroupsSyncHardeningTests`. La salida IDLE es la que cubre el caso
    /// dominante (una remoción no produce deltas ⇒ su página no persiste nada y sale por ahí), y moverla por
    /// debajo del `saveWithAuthor` dejaría los tests de comportamiento de arriba en VERDE.
    ///
    /// MUTACIÓN: borrar cualquiera de los dos call-sites deja este test en rojo (el conteo, o el orden).
    @Test func sourceScan_reconcileHasBothCallSites_andTheIdleOneComesFirst() throws {
        // ACOTADO al cuerpo de `applyPulledPage`: `saveWithAuthor` aparece también en `loadOrCreateCursor`,
        // muy por encima en el fichero, y un escáner global comparaba posiciones de funciones distintas.
        let body = try #require(Self.applyPulledPageBody(try Self.groupsSyncClientSource()),
                                "cambió la firma o el cierre de applyPulledPage: el escáner no tiene sujeto")
        let call = "reconcileLostMemberships(page, cursor: cursor, context: context)"
        // Conteo esperado: sin él, un renombrado o un escáner roto pasan en verde sin comprobar nada.
        #expect(body.components(separatedBy: call).count - 1 == 2,
                "los call-sites de la reconciliación de membresías cambiaron")

        let idle = try #require(body.range(of: "if page.deltas.isEmpty, !cursorsAdvance {"),
                                "cambió la salida idle: el escáner no tiene sujeto")
        let save = try #require(body.range(of: "try saveWithAuthor(context) {"))
        let first = try #require(body.range(of: call))
        #expect(idle.upperBound < first.lowerBound && first.upperBound < save.lowerBound,
                "el call-site de la salida IDLE desapareció: una remoción no trae deltas y su página sale por ahí")
    }

    /// El `?? []` del decode es el defecto que convierte «no sé» en «no eres miembro de nada».
    @Test func sourceScan_decodePageNeverCollapsesAbsentMembershipsToEmpty() throws {
        let source = try Self.groupsSyncClientSource()
        #expect(!source.contains("memberships: decoded.memberships ?? []"),
                "el decode volvió a colapsar la ausencia del campo a un array vacío")
    }
}
