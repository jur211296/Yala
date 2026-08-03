//
//  GroupBatchStepZoneTests.swift
//  YalaTests / CloudSync
//
//  `GroupService.executeBatchStep` — el paso del batch «salir de todos mis grupos» (D10). Tercer miembro de
//  la familia que `GroupZoneCacheGate` (transporte) y `performLocalCleanupAndDelete` (cleanup local) cerraron
//  el 2026-08-03: **decidir sobre una ZONA de Grupos mirando UNA sola fila `SplitGroup`.**
//
//  Los DOS defectos que fija esta suite, medidos en aquel análisis y dejados fuera de aquel commit por
//  alcance atómico:
//
//  (1) **El CANAL salía de una fila arbitraria.** El paso elegía el grupo con `.first` sobre un fetch SIN
//      `sortBy`, y de esa fila salía `batchFacts(isBackendChannel:)` vía `routesMembershipToBackend`, que era
//      `flag && group.isBackendGroup` — POR FILA. Con un `SplitGroup` DUPLICADO **mixto** en la zona (estado
//      documentado, con servicio propio: `SplitGroupDeduplicationService`; la adopción de
//      `GroupsSyncClient.fetchSplitGroup` voltea una fila arbitraria porque tiene `fetchLimit = 1` SIN
//      `sortBy`) un grupo del canal backend se rutaba por el camino CloudKit: `batchLeave` caía a
//      `leaveGroup`, que NO llama al RPC `leave_group` ⇒ **el usuario no salía de verdad server-side y seguía
//      siendo `is_group_writer`**, con el grupo desaparecido de su pantalla. En la rama de owner el daño es
//      otro y también visible: `.transferThenLeave` degradaba a `.needsDecision(.cloudKitOwnerWithCoMembers)`,
//      o sea un motivo FALSO («CloudKit no soporta transferir ownership») sobre un grupo que sí lo soporta.
//      Fix: `GroupBackendIdentityLogic.membershipRoutesToBackend`, criterio ANY-row por zona, molde de
//      `GroupZoneCacheGate.belongsToBackendChannel`.
//
//  (2) **`try?` que silencia** (regla inviolable de CLAUDE.md): un fetch que LANZA daba `nil` ⇒ el
//      `guard let group = existing?.first else { return .done }` devolvía `.done`, tratando un fallo de
//      LECTURA como «ya no existe local ⇒ salida completada». `.done` es TERMINAL
//      (`GroupBatchLeaveLogic.isTerminal`) ⇒ el orquestador daba el grupo por salido y **no lo reintentaba
//      jamás**. El resultado correcto de un transitorio es `.deferred`, que el resume ya retoma.
//
//  Molde de infra: `GroupChannelRoutingTests` (container ON-DISK con los 3 stores + stub del RPC de
//  membership) — el mismo que usa `GroupLocalCleanupZoneTests`, su hermano del cleanup.
//
//  **Lo que estos tests NO prueban, y hay que saberlo antes de leer un verde como una garantía:** el defecto
//  (2) no es unit-asertable —no hay seam para hacer lanzar a `context.fetch` sin fabricar un crash de
//  SwiftData— y el `ownerName` de `performRemovedSelfCleanup` tampoco, porque `leaveShareByZone` habla con un
//  `CKContainer` real. Los dos van por source-scan, que es la herramienta que el repo ya usa cuando lo que
//  decide no es un valor calculado sino la FORMA del código (molde `AttestWiringTests`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupService · executeBatchStep decide por ZONA (D10)", .serialized)
@MainActor
struct GroupBatchStepZoneTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupBatchStep-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GBS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GBS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GBS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Secuencia `transfer_group_ownership` → `leave_group`: los dos RPC devuelven shapes DISTINTOS, así que
    /// un stub de respuesta única haría fallar el decode del segundo y el test mediría otra cosa.
    private func transferThenLeaveStub() -> GroupsSyncClientTests.SequenceStubHTTPSession {
        let transfer = Data(#"{"transferred":true,"already":false,"new_owner_member_key":"mk-ana"}"#.utf8)
        let leave = Data(#"{"group_id":"g","member_key":"mk-me","status":"left"}"#.utf8)
        return GroupsSyncClientTests.SequenceStubHTTPSession(
            [.init(data: transfer, status: 200), .init(data: leave, status: 200)],
            fallback: .init(data: leave, status: 200))
    }

    private func leaveStub() -> GroupsSyncClientTests.SequenceStubHTTPSession {
        let leave = Data(#"{"group_id":"g","member_key":"mk-me","status":"left"}"#.utf8)
        return GroupsSyncClientTests.SequenceStubHTTPSession([], fallback: .init(data: leave, status: 200))
    }

    private func makeService(
        _ session: GroupsSyncClientTests.SequenceStubHTTPSession
    ) -> GroupBackendMembershipService {
        let client = GroupsMembershipClient(baseURL: base, tokenProvider: { "jwt" }, urlSession: session)
        client.sleeper = { _ in }
        return GroupBackendMembershipService(client: client, sessionCheck: { true })
    }

    /// Cablea `GroupService.shared` al contexto del test con el flag del canal en `flagEnabled` y el stub
    /// dado como factory de membership.
    private func arrange(
        _ context: ModelContext,
        session: GroupsSyncClientTests.SequenceStubHTTPSession,
        flagEnabled: Bool = true
    ) {
        GroupService.shared.setContext(context)
        CloudSyncFlags.groupsBackendEnabled = flagEnabled
        GroupService.shared.backendMembershipFactory = { self.makeService(session) }
    }

    @discardableResult
    private func makeGroup(
        zone: String, isBackendGroup: Bool, isOwner: Bool, createdAt: Date, context: ModelContext
    ) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zone
        g.isOwner = isOwner
        g.isBackendGroup = isBackendGroup
        g.createdAt = createdAt
        context.insert(g)
        return g
    }

    /// Co-member ACTIVO y con `userID` ⇒ heredero ELEGIBLE (replica la elegibilidad de
    /// `transfer_group_ownership`). Sin gastos en la zona, `batchHasOutstandingDebt` sale por su early-exit.
    private func seedEligibleHeir(zone: String, context: ModelContext) {
        let heir = SplitMember(groupZoneID: zone, displayName: "Ana", status: .active)
        heir.userID = "11111111-1111-1111-1111-111111111111"
        context.insert(heir)
    }

    private func entry(_ zone: String) -> BatchLeaveEntry {
        BatchLeaveEntry(groupZoneID: zone, groupName: "Viaje", phase: .pending, plannedAction: .leave)
    }

    /// Nombre de la función RPC del n-ésimo request (`POST /groups/rpc/{fn}`). Es la aserción DIRECTA de por
    /// qué canal salió el paso: el `callCount` solo cuenta, y un decode fallido lo enmascara.
    private func rpcName(_ session: GroupsSyncClientTests.SequenceStubHTTPSession, _ index: Int) -> String? {
        guard session.requests.indices.contains(index) else { return nil }
        return session.requests[index].url?.lastPathComponent
    }

    private func groupCount(_ context: ModelContext, zone: String) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone }))
    }

    private func withGroupServiceRestored(_ body: () async throws -> Void) async rethrows {
        let prevFactory = GroupService.shared.backendMembershipFactory
        defer {
            GroupService.shared.backendMembershipFactory = prevFactory
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupService.shared._testResetContext()
        }
        try await body()
    }

    // MARK: - Defecto (1) · el CANAL sale de la ZONA, no de la fila

    /// **La aserción que carga el peso.** Zona con duplicado MIXTO y la fila NO-backend como canónica
    /// (`createdAt` más antiguo): el paso tiene que seguir viendo un grupo del canal BACKEND y transferir +
    /// salir por RPC. Con el criterio por fila, `isBackendChannel` salía `false` y `classify` degradaba a
    /// `.needsDecision(.cloudKitOwnerWithCoMembers)` — un motivo falso, cero red y el usuario dentro del
    /// grupo server-side.
    ///
    /// El duplicado es imprescindible en el fixture: con una sola fila por zona el escenario pasa igual SIN
    /// el fix (corolario de test de `.claude/rules/swiftdata-cloudkit.md`).
    ///
    /// MUTACIÓN: devolver `routesMembershipToBackend` a `CloudSyncFlags.groupsBackendEnabled &&
    /// group.isBackendGroup` → `.needsDecision(.cloudKitOwnerWithCoMembers)` y `callCount == 0`.
    @Test func ownerWithMixedDuplicate_routesToBackend_transfersAndLeaves() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withGroupServiceRestored {
            let session = transferThenLeaveStub()
            arrange(context, session: session)

            let zone = "SplitGroup-OwnerMixed"
            // Canónica (más antigua) SIN marcar + gemela backend: el estado que producía la adopción.
            makeGroup(zone: zone, isBackendGroup: false, isOwner: true,
                      createdAt: Date(timeIntervalSince1970: 1_000), context: context)
            makeGroup(zone: zone, isBackendGroup: true, isOwner: true,
                      createdAt: Date(timeIntervalSince1970: 2_000), context: context)
            seedEligibleHeir(zone: zone, context: context)
            try context.save()

            let result = await GroupService.shared.executeBatchStep(entry(zone))

            #expect(result == .done)
            #expect(rpcName(session, 0) == "transfer_group_ownership")
            #expect(rpcName(session, 1) == "leave_group")
            #expect(session.callCount == 2, "transfer + leave por RPC: la zona ES del canal backend")
            #expect(try groupCount(context, zone: zone) == 0, "el cleanup barre las DOS filas de la zona")
        }
    }

    /// El defecto tal y como se enunció: soy MIEMBRO (no owner) de un grupo backend con duplicado mixto. La
    /// acción es `.leave` en los dos criterios — lo que cambia es POR DÓNDE sale. Con el criterio por fila,
    /// `batchLeave` caía a `leaveGroup` rama CloudKit, que no llama a `leave_group`: el usuario se quedaba
    /// dentro del grupo server-side, `active` y `is_group_writer`, con el grupo borrado de su device.
    ///
    /// MUTACIÓN: la misma de arriba → la rama CloudKit pide la identidad de iCloud
    /// (`ensureCurrentUserMemberExists`), que en el simulador no resuelve ⇒ el paso acaba en `.failed` con
    /// `callCount == 0`. Las dos aserciones caen.
    @Test func memberWithMixedDuplicate_callsLeaveRPC_notTheCloudKitPath() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withGroupServiceRestored {
            let session = leaveStub()
            arrange(context, session: session)

            let zone = "SplitGroup-MemberMixed"
            makeGroup(zone: zone, isBackendGroup: false, isOwner: false,
                      createdAt: Date(timeIntervalSince1970: 1_000), context: context)
            makeGroup(zone: zone, isBackendGroup: true, isOwner: false,
                      createdAt: Date(timeIntervalSince1970: 2_000), context: context)
            try context.save()

            let result = await GroupService.shared.executeBatchStep(entry(zone))

            #expect(result == .done)
            #expect(rpcName(session, 0) == "leave_group",
                    "el RPC `leave_group` es lo único que saca al usuario de verdad")
            #expect(session.callCount == 1)
            #expect(try groupCount(context, zone: zone) == 0)
        }
    }

    /// No-regresión del caso normal (una sola fila, canal backend): sale por RPC y borra la zona. Está aquí
    /// para que un fix futuro no lo rompa, no para probar este fix.
    @Test func singleBackendRow_stillLeavesByRPC() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withGroupServiceRestored {
            let session = leaveStub()
            arrange(context, session: session)

            let zone = "SplitGroup-Single"
            makeGroup(zone: zone, isBackendGroup: true, isOwner: false,
                      createdAt: Date(timeIntervalSince1970: 1_000), context: context)
            try context.save()

            #expect(await GroupService.shared.executeBatchStep(entry(zone)) == .done)
            #expect(session.callCount == 1)
            #expect(try groupCount(context, zone: zone) == 0)
        }
    }

    /// Con el flag OFF el camino CloudKit queda byte-idéntico **también con el criterio nuevo**: la zona no
    /// se enumera y `isBackendChannel` es `false`, así que un owner con co-members cae a `.needsDecision`
    /// con el motivo de CloudKit y NO se toca la red. Es el invariante que protege a la cohorte sin canal.
    ///
    /// MUTACIÓN: quitar el `flagEnabled &&` de `membershipRoutesToBackend` → `.done` con `callCount == 2`.
    @Test func flagOff_neverRoutesToBackend_evenWithBackendRowsInZone() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        try await withGroupServiceRestored {
            let session = transferThenLeaveStub()
            arrange(context, session: session, flagEnabled: false)

            let zone = "SplitGroup-FlagOff"
            makeGroup(zone: zone, isBackendGroup: true, isOwner: true,
                      createdAt: Date(timeIntervalSince1970: 1_000), context: context)
            makeGroup(zone: zone, isBackendGroup: true, isOwner: true,
                      createdAt: Date(timeIntervalSince1970: 2_000), context: context)
            seedEligibleHeir(zone: zone, context: context)
            try context.save()

            let result = await GroupService.shared.executeBatchStep(entry(zone))

            #expect(result == .needsDecision(.cloudKitOwnerWithCoMembers))
            #expect(session.callCount == 0, "cero red con el flag OFF")
            #expect(try groupCount(context, zone: zone) == 2, "sin mutación local")
        }
    }

    /// Idempotencia real conservada: la zona SIN filas es «ya salí en otro device» ⇒ `.done`. Es la rama que
    /// el `try?` confundía con un fallo de lectura, y tiene que seguir dando `.done`.
    @Test func emptyZone_isStillDone() async throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        await withGroupServiceRestored {
            arrange(context, session: leaveStub())
            #expect(await GroupService.shared.executeBatchStep(entry("SplitGroup-Nope")) == .done)
        }
    }

    // MARK: - La lógica pura del cuantificador

    @Test func membershipRoutesToBackend_isAnyRowOverTheZone() {
        // Flag OFF ⇒ SIEMPRE false, aunque la zona entera sea backend.
        #expect(!GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: false, inHandIsBackendGroup: true, rowsInZone: [true, true]))
        // ANY-row: la gemela marcada arrastra a la zona aunque la fila en mano no lo esté.
        #expect(GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: true, inHandIsBackendGroup: false, rowsInZone: [false, true]))
        // Ninguna fila marcada ⇒ canal CloudKit.
        #expect(!GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: true, inHandIsBackendGroup: false, rowsInZone: [false, false]))
        // Degradación: sin filas enumeradas (fetch que lanzó, o objeto no persistido) manda la fila en mano
        // — el comportamiento ANTERIOR al fix, nunca peor.
        #expect(GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: true, inHandIsBackendGroup: true, rowsInZone: []))
        #expect(!GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: true, inHandIsBackendGroup: false, rowsInZone: []))
    }

    // MARK: - Source-scan (lo que ningún test de comportamiento puede fijar)

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

    /// Cuerpo de una función de `GroupService`, desde su firma hasta la siguiente declaración de nivel
    /// `MARK`. `nil` si la firma o el cierre cambiaron — los tests lo convierten en rojo con `#require`, para
    /// que un escáner que deja de encontrar su sujeto NO pase en verde («Executed 0 tests»).
    private static func body(_ source: String, from signature: String) -> String? {
        guard let start = source.range(of: signature) else { return nil }
        let rest = source[start.upperBound...]
        guard let end = rest.range(of: "\n    // MARK:") else { return nil }
        return String(rest[..<end.lowerBound])
    }

    private static let stepSignature =
        "func executeBatchStep(_ entry: BatchLeaveEntry) async -> GroupBatchLeaveLogic.StepResult {"

    /// **Defecto (2), y el único pin que tiene.** No hay seam para hacer lanzar a `context.fetch` sin
    /// fabricar un crash de SwiftData, así que lo que se fija es la FORMA: ningún `try?` sobre el fetch, y un
    /// `catch` que devuelve `.deferred` — nunca `.done`, que es terminal y no se reintenta.
    ///
    /// MUTACIÓN: volver a `let existing = try? context.fetch(...)` deja las dos aserciones en rojo; cambiar
    /// el `return .deferred` del `catch` por `return .done` deja la segunda en rojo.
    @Test func sourceScan_readFailureIsDeferredNeverDone() throws {
        let step = try #require(Self.body(try Self.groupServiceSource(), from: Self.stepSignature),
                                "cambió la firma o el cierre de executeBatchStep: el escáner no tiene sujeto")
        #expect(!step.contains("try? context.fetch"),
                "`try?` que silencia: un fetch que lanza volvería a leerse como «el grupo ya no existe»")
        // El primer `.deferred` del cuerpo es el del `guard let context` — se busca a partir del fetch, que
        // es el sujeto: lo que se fija es que el `catch` DE ESE fetch resuelva a transitorio y no a terminal.
        let fetch = try #require(step.range(of: "rows = try context.fetch("))
        let afterFetch = step[fetch.upperBound...]
        let deferred = try #require(afterFetch.range(of: "return .deferred"),
                                    "el fallo de lectura del fetch debe dar .deferred (transitorio)")
        let done = try #require(afterFetch.range(of: "return .done"))
        #expect(deferred.lowerBound < done.lowerBound,
                "el `catch` del fetch va ANTES del `.done` de la zona vacía")
    }

    /// La fila del paso se elige por `createdAt` ASC (canónica), igual que `group(for:)`.
    ///
    /// **Este escáner es el ÚNICO pin posible, y eso se MIDIÓ.** Hubo aquí un test de comportamiento que
    /// insertaba las dos filas en orden inverso al cronológico y hacía divergir su `isOwner`, para que la
    /// elección cambiara la acción. Con el `sortBy` quitado daba **rojo 3/3 corriéndolo AISLADO y VERDE
    /// dentro de esta misma suite**: el orden natural de un fetch sin `ORDER BY` no es estable ni siquiera
    /// entre dos ejecuciones del mismo proceso, así que un test de comportamiento sobre él es un flake
    /// disfrazado de pin — pasaría en el gate y fallaría en el CI de otro, o al revés. Se retiró. (Y de paso
    /// es la evidencia empírica de por qué el `sortBy` hace falta: sin él la fila la elige el store.)
    ///
    /// MUTACIÓN: quitar el `sortBy` del descriptor → rojo, 1 issue, determinista.
    @Test func sourceScan_stepFetchIsOrderedByCreatedAt() throws {
        let step = try #require(Self.body(try Self.groupServiceSource(), from: Self.stepSignature))
        #expect(step.contains("sortBy: [SortDescriptor(\\.createdAt, order: .forward)]"),
                "el fetch del paso volvió a elegir una fila arbitraria de la zona")
        #expect(step.contains("$0.cloudKitZoneID == zoneID"), "`#Predicate` CONCRETO por zona")
    }

    /// El routing de membresía no puede volver a decidir por la fila del parámetro. `CloudSyncFlags.
    /// groupsBackendEnabled && group.isBackendGroup` es exactamente la expresión que se retiró, y la
    /// consulta a la zona (`backendFlagsInZone`) es lo que la sustituye.
    ///
    /// MUTACIÓN: reintroducirla deja la primera aserción en rojo; borrar la llamada a `backendFlagsInZone`,
    /// la segunda.
    @Test func sourceScan_membershipRoutingAsksTheZone() throws {
        let routing = try #require(
            Self.body(try Self.groupServiceSource(),
                      from: "private func routesMembershipToBackend(_ group: SplitGroup) -> Bool {"),
            "cambió la firma o el cierre de routesMembershipToBackend")
        #expect(!routing.contains("CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup"),
                "el canal volvió a decidirse con la fila en mano")
        #expect(routing.contains("backendFlagsInZone(group.cloudKitZoneID)"),
                "el canal debe leer TODAS las filas de la zona")
        #expect(routing.contains("GroupBackendIdentityLogic.membershipRoutesToBackend("),
                "el cuantificador ANY-row vive en la lógica pura, no inline")
    }

    /// El hermano del enunciado: `performRemovedSelfCleanup` elegía también con `.first` sin `sortBy`. Su
    /// barrido ya es por zona desde 2026-08-03, así que la fila no cambia QUÉ se borra — pero sí alimenta el
    /// `ownerName` del `leaveShareByZone`, y una fila born-backend no tiene identidad CloudKit con la que
    /// resolverlo. No es unit-asertable (ese camino habla con un `CKContainer` real), así que va aquí.
    ///
    /// MUTACIÓN: quitar el `sortBy` deja la primera aserción en rojo; resolver el owner sobre `group` en vez
    /// de sobre `shareRow`, la segunda.
    @Test func sourceScan_removedSelfCleanupIsOrderedAndResolvesTheShareRow() throws {
        let cleanup = try #require(
            Self.body(try Self.groupServiceSource(),
                      from: "func performRemovedSelfCleanup(zoneName: String, context providedContext: ModelContext? = nil) async {"),
            "cambió la firma o el cierre de performRemovedSelfCleanup")
        #expect(cleanup.contains("sortBy: [SortDescriptor(\\.createdAt, order: .forward)]"),
                "la fila canónica de la zona volvió a elegirla el store")
        #expect(cleanup.contains("ownerName(for: shareRow)"),
                "el ownerName del leaveShare debe salir de la fila con identidad CloudKit")
    }
}
