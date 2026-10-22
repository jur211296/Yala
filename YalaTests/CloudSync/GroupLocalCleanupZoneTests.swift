//
//  GroupLocalCleanupZoneTests.swift
//  YalaTests / CloudSync
//
//  `GroupService.performLocalCleanupAndDelete` — el cleanup local al salir de un grupo o al ser removido.
//
//  Hermano exacto del defecto que `GroupZoneCacheGate` cerró en el TRANSPORTE el 2026-08-03, y con menos
//  red: la primitiva cascadeaba las hijas POR ZONA pero borraba UNA sola fila `SplitGroup` (la que recibe
//  por parámetro) y NO tiene guard de canal. Con un `SplitGroup` DUPLICADO —estado documentado, con
//  servicio propio (`SplitGroupDeduplicationService`)— la fila superviviente mantiene la zona dentro de
//  `GroupsSyncClient.backendGroupZoneIDs` (un fetch de filas VIVAS) ⇒ el `save()` del caller, con el autor
//  por DEFECTO, se convierte en tombstones de `split_expenses`/`split_shares`/`split_settlements` con HLC
//  fresco. El `guard !updateOnly` de `translateChange` no cubre esto y no puede: el tombstone de un gasto SÍ
//  tiene que viajar (`GroupsSyncHardeningTests` lo exige por escrito).
//
//  Lo que NO prueban estos tests, y hay que saberlo antes de leer un verde como una garantía end-to-end: el
//  servidor rechaza esos tombstones cuando el usuario ya salió (`is_group_writer` exige `status = 'active'`
//  y `apply_group_delta` NO es `security definer` ⇒ corre bajo la RLS del usuario), así que de los cinco
//  call-sites solo la rama CloudKit de `leaveGroup` —la que NO llama a ningún RPC de salida— podía llegar a
//  destruir datos ajenos. Los otros cuatro producían dead-letters. Eso vive en la RLS de producción, no
//  aquí; la superficie declarada es `qa/cloud/cross-member-rls-test.sh`.
//
//  Molde de infra: `GroupChannelRoutingTests` (container ON-DISK con los 3 stores + stub del RPC de
//  membership) × `GroupsSyncClientTests` (drain real contra `GroupSyncOutbox`). Hace falta el cruce de los
//  dos porque el sujeto es precisamente que una acción de MEMBRESÍA no se traduzca en EMISIÓN.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupService · cleanup local por ZONA (hermano de GroupZoneCacheGate)", .serialized)
@MainActor
struct GroupLocalCleanupZoneTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupCleanup-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func stub(_ json: String, status: Int = 200) -> GroupsSyncClientTests.StubHTTPSession {
        GroupsSyncClientTests.StubHTTPSession(responseData: Data(json.utf8), statusCode: status)
    }

    /// Servicio de membership con `sessionCheck` forzado y sin sleeps (molde `GroupChannelRoutingTests`).
    private func makeService(_ session: GroupsSyncClientTests.StubHTTPSession) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    /// Un `SplitGroup` de la zona. `isOwner = false` porque `leaveGroup` lo exige (el owner no sale, cede).
    @discardableResult
    private func makeGroup(
        zone: String, isBackendGroup: Bool = true, context: ModelContext
    ) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zone
        g.isOwner = false
        g.isBackendGroup = isBackendGroup
        context.insert(g)
        return g
    }

    /// Un hijo de cada clase emisible + el member (que es pull-only y no emite, pero sí debe morir).
    private func seedChildren(zone: String, context: ModelContext) {
        let expense = SplitExpense(groupZoneID: zone, amount: 40, currencyCode: "USD",
                                   expenseDescription: "Cena", paidByMemberID: "member-1")
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

    private func tombstones(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>())
            .filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
    }

    /// Deja `GroupService.shared` cableado al contexto del test con el canal backend encendido y el RPC de
    /// `leave_group` respondiendo OK. Devuelve el stub para poder afirmar que el RPC se llamó.
    private func arrangeBackendLeave(_ context: ModelContext) -> GroupsSyncClientTests.StubHTTPSession {
        GroupService.shared.setContext(context)
        CloudSyncFlags.groupsBackendEnabled = true
        let session = stub(#"{"group_id":"g","member_key":"mk","status":"left"}"#)
        GroupService.shared.backendMembershipFactory = { self.makeService(session) }
        return session
    }

    // MARK: - El defecto: decidir el barrido con UNA fila

    /// **La aserción que carga el peso.** Zona con `SplitGroup` DUPLICADO, las DOS del canal backend: al
    /// borrar solo la del parámetro, la superviviente mantiene la zona dentro de `backendGroupZoneIDs` (un
    /// fetch de filas VIVAS) y el cascade —que corre bajo el autor por DEFECTO— se traduce en tombstones de
    /// gastos, shares y liquidaciones. Server-side los aplica `is_group_writer`, más laxo que el
    /// `is_group_admin` que protege la meta: el blast radius son los GASTOS del grupo, para todos.
    ///
    /// El duplicado es imprescindible en el fixture: con una sola fila por zona el escenario limpio pasa
    /// igual SIN el fix, que es el corolario de test que la regla dejó escrito el 2026-08-02.
    ///
    /// MUTACIÓN: devolver la primitiva a `context.delete(group)` (una fila) deja DOS aserciones en rojo —
    /// aparecen 3 tombstones y sobrevive 1 `SplitGroup`.
    @Test func leaveBackendGroup_withDuplicateRows_emitsNoChildTombstones() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        let session = arrangeBackendLeave(context)

        let zone = "SplitGroup-Dup"
        let inHand = makeGroup(zone: zone, context: context)
        makeGroup(zone: zone, context: context)          // la gemela que sobrevivía y mantenía la zona viva
        seedChildren(zone: zone, context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)               // consume el History de la siembra
        let before = try context.fetchCount(FetchDescriptor<GroupSyncOutbox>())

        try await GroupService.shared.leaveGroup(inHand)
        client.drainOnce(context: context)

        #expect(session.callCount == 1)                  // el leave sí fue server-first
        #expect(try tombstones(context).isEmpty,
                "el cascade del leave se filtró al outbox: la zona seguía en backendGroupZoneIDs")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == before)
        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    /// Duplicado MIXTO con la fila BACKEND en la mano: la gemela sin marcar también tiene que morir. Aquí no
    /// hay emisión que observar —la superviviente sería NO-backend, así que la zona sale del set igual— y
    /// por eso el sujeto es el CASCARÓN: la fila del grupo viva con todas sus hijas muertas, que
    /// `fetchAllGroups` (sin uniquing) sigue listando en la UI después de haber salido.
    ///
    /// MUTACIÓN: la misma de arriba deja `groups == 1`.
    @Test func leaveBackendGroup_mixedDuplicate_leavesNoShellRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        _ = arrangeBackendLeave(context)

        let zone = "SplitGroup-Mixed"
        let inHand = makeGroup(zone: zone, isBackendGroup: true, context: context)
        makeGroup(zone: zone, isBackendGroup: false, context: context)
        seedChildren(zone: zone, context: context)
        try context.save()

        try await GroupService.shared.leaveGroup(inHand)

        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    /// El barrido es por ZONA, no global: un grupo vecino queda INTACTO, filas e hijas. Sin esta aserción un
    /// `#Predicate` mal escrito (o un fetch sin predicado) pasaría los dos tests de arriba en verde.
    ///
    /// MUTACIÓN: quitar el `predicate` del `FetchDescriptor<SplitGroup>` de la primitiva → `otherAfter.groups == 0`.
    @Test func leaveBackendGroup_doesNotTouchAnotherZone() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        _ = arrangeBackendLeave(context)

        let zone = "SplitGroup-Leaving"
        let other = "SplitGroup-Neighbour"
        let inHand = makeGroup(zone: zone, context: context)
        makeGroup(zone: zone, context: context)
        seedChildren(zone: zone, context: context)
        makeGroup(zone: other, context: context)
        seedChildren(zone: other, context: context)
        try context.save()

        try await GroupService.shared.leaveGroup(inHand)

        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
        #expect(try counts(context, zone: other) == (1, 1, 1, 1, 1))
    }

    /// No-regresión del caso normal (una fila por zona): sigue borrándose todo y sigue sin emitir nada. Es
    /// el escenario que ya pasaba ANTES del fix — está aquí para que un fix futuro no lo rompa, no para
    /// probar el fix.
    @Test func leaveBackendGroup_singleRow_stillClearsEverythingAndEmitsNothing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        }
        _ = arrangeBackendLeave(context)

        let zone = "SplitGroup-Single"
        let inHand = makeGroup(zone: zone, context: context)
        seedChildren(zone: zone, context: context)
        try context.save()

        let client = GroupsSyncClient()
        client.drainOnce(context: context)
        try await GroupService.shared.leaveGroup(inHand)
        client.drainOnce(context: context)

        #expect(try tombstones(context).isEmpty)
        #expect(try counts(context, zone: zone) == (0, 0, 0, 0, 0))
    }

    // MARK: - Source-scan del cableado y del ORDEN

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func groupServiceSource() throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent("Yala/Services/Groups/GroupService.swift"),
                   encoding: .utf8)
    }

    /// Cuerpo de `performLocalCleanupAndDelete`, desde su firma hasta la siguiente declaración de nivel
    /// `MARK`. Acotarlo importa: `GroupService` tiene otros borrados de `SplitGroup` legítimos.
    /// `nil` si la firma o el cierre cambiaron — el test lo convierte en rojo con `#require`, para que un
    /// escáner que deja de encontrar su sujeto NO pase en verde.
    private static func primitiveBody(_ source: String) -> String? {
        let signature = "private func performLocalCleanupAndDelete(group: SplitGroup, context: ModelContext) throws {"
        guard let start = source.range(of: signature) else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    // MARK:") else { return nil }
        return String(rest[..<end.lowerBound])
    }

    /// El invariante que NINGÚN test de comportamiento puede fijar: el borrado de las filas `SplitGroup` va
    /// ANTES del cascade de las hijas. `BridgeModeResolver.clearOverride` hace su propio `context.save()`,
    /// así que con el grupo al final se COMITEA «hijas muertas + fila del grupo viva» — el estado exacto que
    /// el drain traduce a tombstones. Hoy ningún drain se cuela en medio (todo es `@MainActor` síncrono),
    /// pero ese commit intermedio SOBREVIVE si el `save()` del caller lanza: ningún call-site hace
    /// `rollback()`, y la vuelta siguiente del drain sí lo ve. Molde: `GroupZoneCacheGate.deleteCache` y
    /// `GroupsIdentityPurgeGate.deleteRows` borran el grupo primero por esta misma razón.
    ///
    /// MUTACIÓN: mover el bucle `for row in rows { context.delete(row) }` por debajo de
    /// `cascadeDeleteGroupData` deja este test en rojo, y los cuatro de comportamiento en VERDE.
    @Test func sourceScan_groupRowsAreDeletedBeforeTheChildren() throws {
        let body = try #require(Self.primitiveBody(try Self.groupServiceSource()),
                                "cambió la firma o el cierre de la primitiva: el escáner no tiene sujeto")
        let deleteRows = try #require(body.range(of: "for row in rows { context.delete(row) }"),
                                      "la primitiva ya no barre TODAS las filas de la zona")
        let cascade = try #require(body.range(of: "cascadeDeleteGroupData(zoneName:"))
        let clearOverride = try #require(body.range(of: "clearOverride(forZoneID:"))
        #expect(deleteRows.lowerBound < cascade.lowerBound,
                "el barrido del grupo debe ir ANTES del cascade de las hijas")
        #expect(deleteRows.lowerBound < clearOverride.lowerBound,
                "el barrido del grupo debe ir ANTES del save() interno de clearOverride")
    }

    /// La primitiva no puede volver a decidir por la fila del parámetro. `context.delete(group)` es
    /// exactamente la línea que se retiró.
    ///
    /// MUTACIÓN: reintroducirla (aunque sea junto al barrido) deja esta aserción en rojo.
    @Test func sourceScan_primitiveNeverDeletesTheParameterRow() throws {
        let body = try #require(Self.primitiveBody(try Self.groupServiceSource()),
                                "cambió la firma o el cierre de la primitiva: el escáner no tiene sujeto")
        #expect(!body.contains("context.delete(group)"),
                "el cleanup volvió a borrar la fila del parámetro en vez de la ZONA")
        #expect(body.contains("$0.cloudKitZoneID == zoneID"),
                "el barrido debe ir por zona, con `#Predicate` concreto")
    }

    /// **Conteo esperado de call-sites.** Sin él, un renombrado o un escáner roto pasarían en verde sin
    /// comprobar nada — la familia de «Executed 0 tests». Los cinco son: rama backend de `leaveGroup`, rama
    /// CloudKit de `leaveGroup`, `performRemovedSelfCleanup`, `batchLeave` y `transferOwnershipThenLeave`.
    /// Un sexto camino que borre un grupo tiene que pasar por aquí y subir este número a conciencia.
    @Test func sourceScan_callSiteCountIsPinned() throws {
        let source = try Self.groupServiceSource()
        let calls = source.components(separatedBy: "try performLocalCleanupAndDelete(group:").count - 1
        #expect(calls == 5, "los call-sites del cleanup cambiaron: \(calls) (esperados 5)")
    }
}
