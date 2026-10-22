//
//  GroupCreateRaceZoneTests.swift
//  YalaTests / CloudSync
//
//  `GroupBackendMembershipService.createGroup` — la VENTANA del `await`, que es el productor ALCANZABLE del
//  duplicado de zona. Séptimo miembro de la familia «decidir sobre una ZONA de Grupos mirando UNA sola fila»,
//  y el primero que no arregla un receptor sino al emisor.
//
//  El defecto: `createGroup` es server-first, así que entre «el servidor ya tiene el grupo» y «este device
//  inserta su fila» hay un punto de suspensión (`GroupBackendMembershipService:104`). El método es
//  `@MainActor` y el ciclo de sync de Grupos corre en el MISMO actor sin ninguna exclusión mutua
//  (`isCycling` es ciclo-contra-ciclo por su propio docblock), y el alcance del pull lo deriva el SERVIDOR de
//  `group_members` con `cursors[gid] ?? 0` ⇒ un grupo recién creado entra en el pull siguiente aunque el
//  cliente no conozca su cursor. Con la zona todavía vacía localmente, `GroupsSyncClient.applyGroupMeta`
//  toma su rama born-remote e INSERTA; al reanudarse, el `context.insert` ciego dejaba la SEGUNDA fila.
//
//  Por qué no lo tapaba nada, medido y no inferido:
//   · el duplicado es de canal HOMOGÉNEO (las dos con `isBackendGroup = true`) ⇒ los seis gates ANY-row de
//     los fixes anteriores dan el mismo resultado con una fila o con dos: no hay corrupción de canal, pero
//     `GroupService.fetchAllGroups` no lleva predicado ⇒ el usuario ve el grupo REPETIDO;
//   · `isOwner` NO lo escribe ningún otro sitio del repo (los dos `createGroup` son sus únicos escritores) y
//     `applyGroupMeta` lo deja intacto A PROPÓSITO ⇒ la fila born-remote nace `isOwner = false`;
//   · el gemelo del `SplitMember` owner —la otra mitad de la MISMA función— es peor: `applyMember` deriva su
//     `id` del MISMO `deterministicMemberID`, así que las dos filas comparten `id`, y **no existe ningún
//     servicio de dedup de `SplitMember` en el repo** (`SplitGroupDeduplicationService` solo mira grupos)
//     ⇒ ese duplicado no se cura NUNCA, mientras que el del grupo lo colapsa el dedup del siguiente arranque.
//
//  Molde de infra: `GroupBackendMembershipServiceTests` (container ON-DISK con los 3 stores) + el helper de
//  página de `GroupsSyncApplyZoneTests`. La carrera se monta con un stub HTTP que ejecuta un hook DENTRO de
//  `data(for:)`: es la única forma determinista de reproducirla, porque el `zoneID` lo genera `createGroup`
//  por dentro y solo se conoce leyendo el `p_group_id` del request. Nada de sleeps ni de timing real.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupBackendMembershipService · la ventana del await de createGroup", .serialized)
@MainActor
struct GroupCreateRaceZoneTests {

    private let base = URL(string: "https://gw.test")!
    /// El `member_key` de un grupo NUEVO es SIEMPRE el `sub` del auth, o sea un UUID. Importa que el fixture
    /// lo sea: `applyMember` discrimina con `GroupBackendIdentityLogic.isLegacyMemberKey` (parseabilidad de
    /// UUID) y con una clave no-UUID derivaría el `id` en el namespace CloudKit-era, que es otro. Ese camino
    /// existe para los members de grupos MIGRADOS y no lo puede tomar el creador de un grupo que acaba de
    /// nacer — con `"sub-99"` el test mediría una derivación que producción nunca ejecuta aquí.
    private let memberKey = "7f1d2c3b-4a5e-4f60-9182-0d3e4f5a6b7c"

    // MARK: - Infra

    /// Stub que ejecuta `duringRequest` DENTRO de `data(for:)`, o sea con `createGroup` suspendido en su
    /// `await`. El hook recibe el `URLRequest` del RPC: de su body sale el `p_group_id`, que ES el
    /// `cloudKitZoneID` que `createGroup` acaba de generar y que no se puede conocer desde fuera.
    final class RaceStubHTTPSession: SyncHTTPSession, @unchecked Sendable {
        let responseData: Data
        let statusCode: Int
        private let duringRequest: (@MainActor (URLRequest) -> Void)?
        var callCount = 0

        init(responseData: Data, statusCode: Int = 200,
             duringRequest: (@MainActor (URLRequest) -> Void)? = nil) {
            self.responseData = responseData
            self.statusCode = statusCode
            self.duringRequest = duringRequest
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            callCount += 1
            if let duringRequest {
                await MainActor.run { duringRequest(request) }
            }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (responseData, response)
        }
    }

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupCreateRace-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GCR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GCR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GCR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func makeService(_ session: RaceStubHTTPSession) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt-token" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    private var okBody: Data {
        Data(#"{"group_id":"ignored-echo","member_key":"\#(memberKey)"}"#.utf8)
    }

    /// El `p_group_id` que `createGroup` mandó al RPC = el `cloudKitZoneID` de la fila que va a materializar.
    private func sentZoneID(_ request: URLRequest) -> String {
        guard let body = request.httpBody,
              let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let zone = json["p_group_id"] as? String else { return "" }
        return zone
    }

    // MARK: - El pull, ejercitado por el PRODUCTOR REAL (no un estado montado a mano)

    private func groupDelta(zone: String, name: String) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: GroupEntityEmissionMap.splitGroup.table, groupID: zone,
            rawSyncID: zone, syncID: nil, op: .upsert,
            fields: [
                "name": .string(name),
                "icon_name": .string("person.2.fill"),
                "color_hex": .string("#8B5CF6"),
                "currency_code": .string("USD"),
            ],
            fieldHlcs: [:], hlc: "2026-08-03T00:00:00.000Z-0000-00000000000000f9",
            serverSeq: 11, schemaVersion: 1)
    }

    private func memberDelta(zone: String, displayName: String) -> GroupPulledDelta {
        GroupPulledDelta(
            entityType: "group_members", groupID: zone,
            rawSyncID: memberKey, syncID: nil, op: .upsert,
            fields: [
                "display_name": .string(displayName),
                "role": .string("admin"),
                "status": .string("active"),
                "user_id": .string(memberKey),
            ],
            fieldHlcs: [:], hlc: "2026-08-03T00:00:01.000Z-0000-00000000000000fa",
            serverSeq: 12, schemaVersion: 1)
    }

    /// Aplica una página del pull tal cual lo haría el ciclo: mismo `applyPulledPage`, mismo autor de save.
    private func applyPull(_ deltas: [GroupPulledDelta], context: ModelContext) {
        let client = GroupsSyncClient()
        guard let cursor = try? client.loadOrCreateCursor(context) else { return }
        client.applyPulledPage(
            GroupPulledPage(deltas: deltas, cursors: [:], memberships: []),
            cursor: cursor, context: context)
    }

    private func groupRows(_ context: ModelContext, zone: String) throws -> [SplitGroup] {
        try context.fetch(FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zone },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
    }

    private func memberRows(_ context: ModelContext, zone: String) throws -> [SplitMember] {
        try context.fetch(FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zone }))
    }

    // MARK: - (1) El pull gana la carrera: se ADOPTA la fila born-remote, no se inserta una gemela

    /// El caso medido: el pull aterriza DENTRO del `await` del RPC y materializa la zona entera (grupo +
    /// member owner) por su camino real. Al reanudarse, `createGroup` tiene que reconocerlas.
    ///
    /// MUTACIÓN: devolver los dos `context.insert` incondicionales de antes del fix → 2 `SplitGroup` y 2
    /// `SplitMember`, y las dos aserciones de conteo caen.
    @Test func createGroup_whenThePullMaterializesTheZoneDuringTheRPC_adoptsItInsteadOfInsertingTwins() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = RaceStubHTTPSession(responseData: okBody) { request in
            let zone = self.sentZoneID(request)
            self.applyPull([self.groupDelta(zone: zone, name: "Trip"),
                            self.memberDelta(zone: zone, displayName: "Alice")], context: context)
        }

        let group = try await makeService(session).createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)

        let zone = group.cloudKitZoneID
        #expect(try groupRows(context, zone: zone).count == 1, "quedó una fila gemela de la misma zona")
        #expect(try memberRows(context, zone: zone).count == 1, "quedó un SplitMember gemelo del owner")
        // Nada más en el store: el fetch por zona no puede ocultar una fila con la zona mal escrita.
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitMember>()) == 1)
    }

    /// La fila que sobrevive es la del PULL, y `createGroup` le escribe lo que el pull no puede escribir.
    /// `isOwner` es el que carga el peso: `applyGroupMeta` lo deja intacto por diseño y sus únicos escritores
    /// en todo el repo son los dos `createGroup` ⇒ adoptar sin ponerlo dejaba al creador sin poder invitar,
    /// renombrar ni transferir su propio grupo, y ningún barrido lo repara después.
    ///
    /// MUTACIÓN: quitar `row.isOwner = true` → rojo. Quitar `row.initialMemberImportStartedAt = nil` → rojo.
    @Test func createGroup_adoptedZoneRow_getsTheCreatorOnlyFields() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let bornID = UnsafeBox<UUID?>(nil)
        let session = RaceStubHTTPSession(responseData: okBody) { request in
            let zone = self.sentZoneID(request)
            self.applyPull([self.groupDelta(zone: zone, name: "Trip")], context: context)
            bornID.value = try? self.groupRows(context, zone: zone).first?.id
        }

        let group = try await makeService(session).createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)

        // Es la MISMA fila que insertó el pull, no una nueva: si `createGroup` hubiera insertado la suya y
        // devuelto esa, el `id` no casaría.
        #expect(group.id == bornID.value)
        #expect(group.isOwner == true, "el creador se quedó sin isOwner en su propio grupo")
        #expect(group.isBackendGroup == true)
        #expect(group.initialMemberImportStartedAt == nil,
                "la ventana de supresión de notificaciones del born-remote no se limpió para el creador")
    }

    /// Gemelo del anterior sobre el `SplitMember`, y el que más daño evita: `isCurrentUser`/`isGroupOwner` son
    /// DEVICE-LOCAL —`applyMember` no los escribe nunca porque no viajan en el wire— y sin `isCurrentUser` el
    /// creador se queda sin balance propio, sin FAB y fuera de `eligibleGroupsForExpense`. El `id` NO se
    /// reescribe: el born-remote ya lo derivó del mismo `deterministicMemberID`.
    ///
    /// MUTACIÓN: quitar el `for row in memberRows` del `else` → rojo en `isCurrentUser`/`isGroupOwner`.
    @Test func createGroup_adoptedOwnerMember_getsTheDeviceLocalFlags() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = RaceStubHTTPSession(responseData: okBody) { request in
            let zone = self.sentZoneID(request)
            self.applyPull([self.memberDelta(zone: zone, displayName: "Alice")], context: context)
        }

        let group = try await makeService(session).createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)

        let members = try memberRows(context, zone: group.cloudKitZoneID)
        #expect(members.count == 1, "el owner quedó duplicado: nada en el repo deduplica SplitMember")
        let owner = try #require(members.first)
        #expect(owner.isCurrentUser == true, "el creador no se reconoce en su propio grupo")
        #expect(owner.isGroupOwner == true)
        #expect(owner.id == GroupBackendIdentityLogic.deterministicMemberID(
            groupID: group.cloudKitZoneID, memberKey: memberKey))
        #expect(owner.memberKey == memberKey)
        // La meta del wire es del servidor y no se pisa.
        #expect(owner.role == "admin")
        #expect(owner.memberStatus == .active)
    }

    /// Zona que ya llega DUPLICADA (dos filas born-remote): se marcan TODAS —criterio ANY-row de la familia—
    /// y se devuelve la CANÓNICA, la más antigua por `createdAt`, que es la que resuelven
    /// `GroupService.group(for:)` y `GroupsSyncClient.fetchSplitGroupRows`. El fetch lleva `sortBy`, así que
    /// esto NO depende del orden natural del store.
    ///
    /// MUTACIÓN: marcar solo `groupRows[0]` → la gemela se queda sin `isOwner` y cae.
    @Test func createGroup_withADuplicatedZone_marksEveryRow_andReturnsTheCanonical() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let oldest = Date(timeIntervalSince1970: 1_000_000)
        let session = RaceStubHTTPSession(responseData: okBody) { request in
            let zone = self.sentZoneID(request)
            for (i, stamp) in [oldest, oldest.addingTimeInterval(60)].enumerated() {
                let row = SplitGroup(name: "Trip \(i)")
                row.cloudKitZoneID = zone
                row.isBackendGroup = true
                row.createdAt = stamp
                context.insert(row)
            }
            try? context.save()
        }

        let group = try await makeService(session).createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)

        let rows = try groupRows(context, zone: group.cloudKitZoneID)
        let everyRowIsOwned = rows.allSatisfy(\.isOwner)
        #expect(rows.count == 2, "createGroup insertó una tercera fila sobre una zona ya duplicada")
        #expect(everyRowIsOwned, "el barrido dejó una gemela sin isOwner")
        #expect(group.createdAt == oldest, "no se devolvió la fila canónica de la zona")
    }

    // MARK: - (2) El RPC falla: ni fantasma ni mutación de lo que trajo el pull

    /// El invariante que impide «reservar la fila ANTES del RPC»: si el servidor RECHAZA, no puede haber
    /// grupo que el pull traiga, y el contexto se queda intacto.
    ///
    /// MUTACIÓN: mover los `insert` antes del `await` → dos aserciones rojas.
    @Test func createGroup_rpcRejected_leavesNoPhantomRow() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = RaceStubHTTPSession(
            responseData: Data(#"{"error":{"code":"yala_invalid_group_id"}}"#.utf8), statusCode: 400)

        await #expect(throws: GroupsRPCError.invalidGroupID) {
            _ = try await self.makeService(session).createGroup(
                name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitMember>()) == 0)
    }

    /// El caso ambiguo, y el que hay que dejar escrito: el servidor SÍ creó el grupo (el pull ya lo trajo)
    /// pero la respuesta llega como error. `createGroup` lanza sin insertar ni mutar nada — no hay gemela
    /// **ni cascarón**, y la fila del pull queda tal cual la dejó el canal. RESIDUAL DECLARADO: esa fila se
    /// queda `isOwner == false` hasta que el usuario reintente, porque nadie más escribe ese campo. Es
    /// preexistente al fix (antes tampoco se escribía en el camino que lanza) y no se cierra aquí: hacerlo
    /// exigiría distinguir «el servidor lo creó» de «el servidor lo rechazó» desde un error de transporte.
    @Test func createGroup_rpcFailsAfterTheZoneLanded_touchesNothing() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let zoneBox = UnsafeBox<String>("")
        let session = RaceStubHTTPSession(
            responseData: Data(#"{"error":{"code":"yala_invalid_group_id"}}"#.utf8), statusCode: 400
        ) { request in
            let zone = self.sentZoneID(request)
            zoneBox.value = zone
            self.applyPull([self.groupDelta(zone: zone, name: "Trip")], context: context)
        }

        await #expect(throws: GroupsRPCError.invalidGroupID) {
            _ = try await self.makeService(session).createGroup(
                name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        }

        let rows = try groupRows(context, zone: zoneBox.value)
        #expect(rows.count == 1, "el camino que lanza insertó una fila")
        #expect(rows.first?.isOwner == false, "residual declarado: el error deja la fila del pull sin isOwner")
    }

    // MARK: - (3) El orden INVERSO: el receptor ya cubre su lado, y aquí queda medido

    /// La pregunta que el fix tenía que contestar: ¿hace falta tocar `applyGroupMeta`/`applyMember`? NO.
    /// `applyGroupMeta` resuelve por ZONA y solo inserta con la zona vacía; `applyMember` resuelve por
    /// `(zona, member_key)`, que es justo lo que `createGroup` deja escrito. Con el emisor arreglado, el pull
    /// que llega DESPUÉS adopta las dos filas en vez de duplicarlas — y no pisa los flags device-local.
    ///
    /// Este test es la MEDICIÓN de esa afirmación: sin él, «basta con el emisor» sería una inferencia.
    @Test func pullAfterCreateGroup_adoptsTheLocalRows_insteadOfDuplicating() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { CloudSyncFlags._testResetGroupsBackendEnabledOverride() }
        CloudSyncFlags.groupsBackendEnabled = true

        let session = RaceStubHTTPSession(responseData: okBody)
        let group = try await makeService(session).createGroup(
            name: "Trip", currencyCode: "USD", displayName: "Alice", context: context)
        let zone = group.cloudKitZoneID

        applyPull([groupDelta(zone: zone, name: "Trip renombrado"),
                   memberDelta(zone: zone, displayName: "Alice")], context: context)

        #expect(try groupRows(context, zone: zone).count == 1)
        #expect(try memberRows(context, zone: zone).count == 1)
        #expect(group.name == "Trip renombrado", "el pull dejó de ser autoritativo sobre la meta")
        #expect(group.isOwner == true, "el pull pisó isOwner")
        let owner = try #require(memberRows(context, zone: zone).first)
        #expect(owner.isCurrentUser == true, "el pull pisó el flag device-local del creador")
        #expect(owner.isGroupOwner == true)
    }

    // MARK: - Source-scan (lo que ningún test de comportamiento puede fijar)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func serviceSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent(
                "Yala/Services/CloudSync/Groups/GroupBackendMembershipService.swift"),
            encoding: .utf8)
    }

    /// **El invariante de ORDEN: resolver la identidad ANTES del `await` reabre la ventana entera.**
    ///
    /// MUTACIÓN, MEDIDA: subir la línea de `Self.groupRows(zoneID:` por encima del `try await
    /// client.createGroup(` → **4 tests rojos**, tres de comportamiento y este. Se escribió primero que los
    /// de comportamiento seguirían VERDES —el argumento habitual para justificar un source-scan— y **es
    /// falso**: el hook del stub corre dentro de `data(for:)`, o sea DESPUÉS de un fetch que se haya subido,
    /// así que el fetch previo ve la zona vacía exactamente igual que en producción y el `insert` duplica.
    /// El montaje ejerce el orden de verdad.
    ///
    /// Se conserva igual, y por una razón más estrecha: los de comportamiento cazan **esta** reordenación,
    /// no la clase. Un movimiento que los deje ciegos —resolver la zona antes de `ensureEligible`, o
    /// cachear el resultado del fetch entre llamadas— seguiría siendo el mismo bug y este escáner es lo
    /// único que lo nombra.
    @Test func sourceScan_identityIsResolvedAfterTheAwait_neverBefore() throws {
        let source = try Self.serviceSource()
        let rpc = try #require(source.range(of: "let result = try await client.createGroup("),
                               "cambió la llamada al RPC: el escáner no tiene sujeto")
        let groupFetch = try #require(source.range(of: "let zoneRows = try Self.groupRows(zoneID: zoneID, context: context)"),
                                      "createGroup ya no resuelve la zona antes de insertar")
        let memberFetch = try #require(source.range(of: "let memberRows = try Self.memberRows("),
                                       "createGroup ya no resuelve el member owner antes de insertar")
        #expect(rpc.upperBound < groupFetch.lowerBound,
                "la zona se resuelve ANTES del await: la ventana vuelve a estar abierta")
        #expect(rpc.upperBound < memberFetch.lowerBound,
                "el member se resuelve ANTES del await: la ventana vuelve a estar abierta")
    }

    /// Ningún `insert` incondicional. Los dos van dentro de su rama `isEmpty`, que es lo que los hace
    /// idempotentes; un `context.insert` suelto es exactamente el código de antes del fix.
    ///
    /// MUTACIÓN: sacar cualquiera de los dos `insert` de su `if` → rojo.
    @Test func sourceScan_insertsAreGuardedByTheirEmptinessCheck() throws {
        let source = try Self.serviceSource()
        #expect(source.contains("if zoneRows.isEmpty {\n                context.insert(group)"),
                "el insert del grupo dejó de estar detrás de la comprobación de la zona")
        #expect(source.contains("if memberRows.isEmpty {"),
                "el insert del owner dejó de estar detrás de la comprobación por member_key")
        // Dos inserts en todo el fichero, y ninguno más: un tercero sería una materialización sin resolver.
        #expect(source.components(separatedBy: "context.insert(").count - 1 == 2,
                "apareció un context.insert nuevo en el service: ¿resuelve su identidad antes?")
    }

    /// Los dos fetch resuelven por la unidad de identidad correcta y SIN truncar. `fetchLimit = 1` sobre
    /// `SplitGroup` es justo lo que esta familia de fixes retiró; el `sortBy` por `createdAt` es lo que
    /// alinea la fila devuelta con la que resuelve `GroupService.group(for:)`.
    ///
    /// MUTACIÓN: añadir `fetchLimit`, quitar el `sortBy`, o cambiar el predicado del member a `$0.id ==` →
    /// rojo.
    @Test func sourceScan_identityFetchesAreOrderedUnboundedAndKeyedRight() throws {
        let source = try Self.serviceSource()
        #expect(!source.contains("fetchLimit"),
                "un fetch de identidad volvió a truncarse: elegiría una fila arbitraria de la zona")
        #expect(source.contains("predicate: #Predicate { $0.cloudKitZoneID == zoneID },\n            sortBy: [SortDescriptor(\\.createdAt, order: .forward)]"),
                "el fetch del grupo dejó de resolver por ZONA ordenada")
        #expect(source.contains("#Predicate { $0.groupZoneID == zoneID && $0.memberKey == memberKey }"),
                "el fetch del member dejó de resolver por (zona, member_key)")
    }

    /// El save sigue siendo UNO y bajo `outboxSaveAuthor`: la resolución nueva no puede haber introducido un
    /// `save()` intermedio, que comitearía filas a medias bajo el autor por defecto y las metería en el drain.
    ///
    /// MUTACIÓN: añadir un `context.save()` dentro del bloque → rojo.
    @Test func sourceScan_theWholeMaterializationStaysInOneAuthoredSave() throws {
        let source = try Self.serviceSource()
        #expect(source.components(separatedBy: "try context.save()").count - 1 == 1,
                "hay más de un save en el service: el segundo iría bajo el autor por defecto")
        #expect(source.contains("context.author = GroupsSyncClient.outboxSaveAuthor"))
        #expect(source.components(separatedBy: "try saveUnderOutboxAuthor(context)").count - 1 == 1,
                "createGroup dejó de materializar en un solo bloque autorizado")
    }
}

/// Caja de referencia para sacar un valor del hook del stub (capturar un `var` local en una closure
/// escapante no compila bajo Swift 6). Mismo motivo que `GroupsSyncClientTests.SleeperCounter`.
final class UnsafeBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
