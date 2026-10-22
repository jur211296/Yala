//
//  GroupLeaveOwnershipReconcileTests.swift
//  YalaTests / CloudSync
//
//  Reproduce el device-QA del 2026-08-28 (TestFlight 2.1 build 12) de punta a punta y fija el arreglo.
//
//  EL ESCENARIO. El teléfono cree que NO es el dueño del grupo (`SplitGroup.isOwner == false`) porque ese
//  flag es DEVICE-LOCAL: solo lo escribe quien crea el grupo (`GroupBackendMembershipService`) y el pull lo
//  deja intacto a propósito. El SERVIDOR, en cambio, sí lo tiene por dueño, así que `leave_group` responde
//  `yala_owner_cannot_leave` (`supabase-groups-staging.ddl`, guard `owner_user_id = auth.uid()`).
//
//  El resultado ANTES del fix: el usuario no podía salir (el servidor lo rechaza) y tampoco podía borrar el
//  grupo, porque `GroupSettingsView` enseña «Eliminar grupo» solo si `isOwner` es `true`. Sin salida por los
//  dos lados, y el alert era el discriminante crudo del enum.
//
//  Molde de infra: `GroupBatchStepZoneTests` (container ON-DISK con los 3 stores + stub del RPC).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("GroupService · leaveGroup reconcilia el ownership que el servidor afirma", .serialized)
@MainActor
struct GroupLeaveOwnershipReconcileTests {

    private let base = URL(string: "https://gw.test")!

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GLOR-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GLOR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GLOR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GLOR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// El envelope EXACTO del gateway para el rechazo del guard de `leave_group`.
    private func ownerCannotLeaveStub() -> GroupsSyncClientTests.SequenceStubHTTPSession {
        let body = Data(
            #"{"error":{"message":"yala_owner_cannot_leave","type":"yala_rpc_error","code":"yala_owner_cannot_leave"}}"#
                .utf8)
        return GroupsSyncClientTests.SequenceStubHTTPSession([], fallback: .init(data: body, status: 400))
    }

    /// 500 → `.transient`. Contraprueba: un fallo que NO afirma ownership no debe tocar el flag.
    private func transientStub() -> GroupsSyncClientTests.SequenceStubHTTPSession {
        GroupsSyncClientTests.SequenceStubHTTPSession(
            [], fallback: .init(data: Data(#"{"error":"boom"}"#.utf8), status: 500))
    }

    private func arrange(
        _ context: ModelContext, session: GroupsSyncClientTests.SequenceStubHTTPSession
    ) {
        GroupService.shared.setContext(context)
        CloudSyncFlags.groupsBackendEnabled = true
        GroupService.shared.backendMembershipFactory = {
            let client = GroupsMembershipClient(
                baseURL: self.base, tokenProvider: { "jwt" }, urlSession: session)
            client.sleeper = { _ in }
            return GroupBackendMembershipService(client: client, sessionCheck: { true })
        }
    }

    @discardableResult
    private func makeGroup(
        zone: String, isOwner: Bool, createdAt: Date = .now, context: ModelContext
    ) -> SplitGroup {
        let g = SplitGroup(name: "Viaje")
        g.cloudKitZoneID = zone
        g.isOwner = isOwner
        g.isBackendGroup = true
        g.createdAt = createdAt
        context.insert(g)
        return g
    }

    private func groupCount(_ context: ModelContext, zone: String) throws -> Int {
        try context.fetchCount(
            FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone }))
    }

    // MARK: - El caso del device

    /// El corazón del ticket: el servidor dice «eres el dueño», el flag local decía lo contrario, y tras el
    /// intento el device queda SABIÉNDOLO. Es lo que hace que la próxima vez que se abra la pantalla
    /// aparezca «Eliminar grupo» —la acción que su rol real sí permite— en vez del botón «Salir» que el
    /// servidor rechaza siempre.
    @Test func leaveRejectedAsOwner_reconcilesLocalFlag_andKeepsGroup() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = ownerCannotLeaveStub()
        arrange(context, session: session)

        let group = makeGroup(zone: "zone-A", isOwner: false, context: context)
        try context.save()

        await #expect(throws: GroupsRPCError.ownerCannotLeave) {
            try await GroupService.shared.leaveGroup(group)
        }

        // 1) El flag quedó reconciliado con lo que afirmó el servidor.
        #expect(group.isOwner, "el rechazo del servidor es la única afirmación autoritativa de ownership")
        // 2) El usuario NO salió: el grupo sigue local e intacto.
        #expect(try groupCount(context, zone: "zone-A") == 1)
    }

    /// Criterio ANY-row de la familia: una zona puede tener `SplitGroup` DUPLICADOS (estado documentado,
    /// con servicio propio: `SplitGroupDeduplicationService`) y la UI pinta la canónica, no la que se pasó
    /// por parámetro. Corregir solo la fila en mano dejaría la pantalla rota parte de las veces.
    @Test func reconcile_appliesToEveryRowInTheZone_notJustTheOneInHand() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        arrange(context, session: ownerCannotLeaveStub())

        let canonica = makeGroup(
            zone: "zone-B", isOwner: false, createdAt: .now.addingTimeInterval(-3600), context: context)
        let duplicada = makeGroup(zone: "zone-B", isOwner: false, context: context)
        try context.save()

        await #expect(throws: GroupsRPCError.ownerCannotLeave) {
            try await GroupService.shared.leaveGroup(duplicada)
        }

        #expect(canonica.isOwner, "la fila canónica es la que pinta la UI: sin ella el fix no se ve")
        #expect(duplicada.isOwner)
    }

    /// El MISMO defecto por la otra puerta: «salir de todos mis grupos». `GroupBatchLeaveLogic.classify`
    /// eligió `.leave` porque `isOwner` decía `false`; sin reconciliar, el paso cae a `.failed` y
    /// reintentar falla igual para siempre.
    @Test func batchLeave_rejectedAsOwner_alsoReconciles() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        arrange(context, session: ownerCannotLeaveStub())

        let group = makeGroup(zone: "zone-E", isOwner: false, context: context)
        try context.save()

        await #expect(throws: GroupsRPCError.ownerCannotLeave) {
            try await GroupService.shared.batchLeave(group)
        }

        #expect(group.isOwner)
        #expect(try groupCount(context, zone: "zone-E") == 1)

        // Y la consecuencia que importa: con el flag ya corregido, la clasificación del batch deja de
        // mandar a `.leave` —que el servidor rechaza siempre— y pasa a las salidas de un dueño.
        let facts = GroupBatchLeaveLogic.GroupFacts(
            isOwner: group.isOwner, isBackendChannel: true, activeCoMemberCount: 0,
            eligibleHeirCount: 0, hasOutstandingDebt: false)
        #expect(GroupBatchLeaveLogic.classify(facts) == .deleteSolo)
    }

    /// Contraprueba imprescindible: un fallo TRANSITORIO no afirma nada sobre quién es el dueño. Si el flag
    /// se tocara aquí, un 500 pasajero le quitaría al usuario el botón «Salir» para siempre — un bug peor
    /// que el que se está arreglando.
    @Test func transientFailure_doesNotTouchOwnership() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        arrange(context, session: transientStub())

        let group = makeGroup(zone: "zone-C", isOwner: false, context: context)
        try context.save()

        await #expect(throws: (any Error).self) {
            try await GroupService.shared.leaveGroup(group)
        }

        #expect(!group.isOwner, "un 5xx no dice quién es el dueño")
        #expect(try groupCount(context, zone: "zone-C") == 1)
    }

    /// En el canal BACKEND el corte local NO debe existir: `isOwner` es device-local y puede estar mal en
    /// las dos direcciones, así que quien decide es `leave_group`. Sin esto, el propio reconciliador se
    /// convertiría en una cárcel — el primer rechazo cerraría la última puerta y ningún pull la reabre,
    /// porque el pull nunca escribe `isOwner`.
    @Test func backendGroup_alwaysAsksTheServer_evenWhenLocallyOwner() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = ownerCannotLeaveStub()
        arrange(context, session: session)

        let group = makeGroup(zone: "zone-D", isOwner: true, context: context)
        try context.save()

        await #expect(throws: GroupsRPCError.ownerCannotLeave) {
            try await GroupService.shared.leaveGroup(group)
        }
        #expect(session.callCount > 0, "el servidor es la autoridad sobre el ownership del canal backend")
    }

    /// Y donde NO hay servidor a quien preguntar (zona legacy que nunca migró), el guard local sigue: es
    /// la única autoridad que existe ahí.
    @Test func legacyGroup_keepsTheLocalGuard() async throws {
        let dir = freshDir()
        defer { cleanup(dir) }
        let context = try makeContext(dir)
        let session = ownerCannotLeaveStub()
        arrange(context, session: session)
        CloudSyncFlags.groupsBackendEnabled = false

        let g = SplitGroup(name: "Legacy")
        g.cloudKitZoneID = "zone-legacy"
        g.isOwner = true
        g.isBackendGroup = false
        context.insert(g)
        try context.save()

        var capturado: Error?
        do { try await GroupService.shared.leaveGroup(g) } catch { capturado = error }

        let error = try #require(capturado)
        #expect(GroupLeaveErrorLogic.classify(error, attestUnavailable: false) == .ownedByCurrentUser)
        #expect(session.callCount == 0)
        #expect(g.isOwner, "el guard local ya leyó el flag: no hay nada que reconciliar")

        CloudSyncFlags.groupsBackendEnabled = true
    }
}
