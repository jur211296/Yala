//
//  OpeningBalanceServerRejectionTests.swift
//  YalaTests / CloudSync
//
//  Card 6n1o (2026-10-31) · el servidor rechaza un saldo inicial (g27_01) y la app lo cuenta con un mensaje claro:
//   (1) el código del servidor → motivo (`OpeningBalanceServerRejectionLogic`), y la prioridad cuando hay varios;
//   (2) la subida deja en el buzón UN motivo por grupo, solo para esos tres códigos y no para el resto de rechazos;
//   (3) el detalle del grupo lo enseña con su título y su texto, y espera si hay una hoja o un aviso delante.
//  El servidor, sus códigos y sus casos viven en `qa/cloud/g27_01-*` (banco local, staging y producción).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Saldos iniciales · rechazo del servidor (card 6n1o)", .serialized)
@MainActor
struct OpeningBalanceServerRejectionTests {

    // MARK: - (1) Lógica

    @Test func slugs_mapToTheirReason_andAnythingElseIsNil() {
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: "yala_opening_balance_not_admin") == .notAdmin)
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: "yala_opening_balance_locked") == .locked)
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: "yala_opening_balance_group_closed") == .groupClosed)
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: "yala_not_authorized") == nil)
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: "yala_bad_request") == nil)
        #expect(OpeningBalanceServerRejectionLogic.reason(forSlug: nil) == nil)
    }

    /// Los tres códigos son los que lanza `qa/cloud/g27_01_opening_balance_managers.sql`: si uno cambia allí, este
    /// caso se pone rojo antes de que la app deje de reconocerlo en silencio.
    @Test func reasons_matchTheMigrationCodes() throws {
        let sql = try String(contentsOf: Self.repoRoot.appendingPathComponent("qa/cloud/g27_01_opening_balance_managers.sql"),
                             encoding: .utf8)
        for reason in OpeningBalanceServerRejectionLogic.Reason.allCases {
            #expect(sql.contains("raise exception '\(reason.rawValue)' using errcode = 'P0001'"), "\(reason.rawValue)")
        }
    }

    @Test func merged_keepsTheReasonThatExplainsMore() {
        typealias L = OpeningBalanceServerRejectionLogic
        #expect(L.merged(nil, with: .locked) == .locked)
        #expect(L.merged(.locked, with: .notAdmin) == .notAdmin)
        #expect(L.merged(.notAdmin, with: .locked) == .notAdmin)
        #expect(L.merged(.notAdmin, with: .groupClosed) == .groupClosed)
        #expect(L.merged(.groupClosed, with: .notAdmin) == .groupClosed)
    }

    // MARK: - (2) La subida llena el buzón

    @Test func push_rejectedOpeningBalance_leavesOneNoticePerGroup_onlyForItsCodes() async throws {
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let aLocked = UUID(), aNotAdmin = UUID(), bClosed = UUID(), cOther = UUID(), dApplied = UUID()
        try seedRow(context, group: "SplitGroup-A", mid: aLocked, hlc: "2026-10-31T00:00:00.000Z-0001-00000000000000aa")
        try seedRow(context, group: "SplitGroup-A", mid: aNotAdmin, hlc: "2026-10-31T00:00:00.000Z-0002-00000000000000aa")
        try seedRow(context, group: "SplitGroup-B", mid: bClosed, hlc: "2026-10-31T00:00:00.000Z-0003-00000000000000aa")
        try seedRow(context, group: "SplitGroup-C", mid: cOther, hlc: "2026-10-31T00:00:00.000Z-0004-00000000000000aa")
        try seedRow(context, group: "SplitGroup-D", mid: dApplied, hlc: "2026-10-31T00:00:00.000Z-0005-00000000000000aa")

        let response = """
        {"results":[\
        \(rejected(aLocked, "yala_opening_balance_locked")),\
        \(rejected(aNotAdmin, "yala_opening_balance_not_admin")),\
        \(rejected(bClosed, "yala_opening_balance_group_closed")),\
        \(rejected(cOther, "yala_not_authorized")),\
        {"sync_id":"s","client_mutation_id":"\(dApplied.uuidString.lowercased())","status":"applied"}\
        ]}
        """
        let client = makeClient(session: StubSession(response))
        let before = notices.revision
        _ = await client.pushPending(context: context)

        // El dead-letter conserva el código, como cualquier rechazo del servidor.
        let reasons = Set(try context.fetch(FetchDescriptor<GroupSyncOutbox>()).compactMap(\.rejectedReason))
        #expect(reasons == ["upstream_400:yala_opening_balance_locked", "upstream_400:yala_opening_balance_not_admin",
                            "upstream_400:yala_opening_balance_group_closed", "upstream_400:yala_not_authorized"])
        // Un aviso por grupo, con el motivo que más explica; nada para los demás rechazos ni para lo aplicado.
        #expect(notices.peek(groupID: "SplitGroup-A") == .notAdmin)
        #expect(notices.peek(groupID: "SplitGroup-B") == .groupClosed)
        #expect(notices.peek(groupID: "SplitGroup-C") == nil)
        #expect(notices.peek(groupID: "SplitGroup-D") == nil)
        #expect(notices.revision > before)
    }

    /// CONTROL: un rechazo que no es de saldos iniciales no toca el buzón (sin él, el caso de arriba podría salir verde
    /// con un `applyResults` que avisara de todo).
    @Test func push_otherRejection_leavesNoNotice() async throws {
        let notices = OpeningBalanceServerRejectionNotices.shared
        notices._testReset(); defer { notices._testReset() }
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let mid = UUID()
        try seedRow(context, group: "SplitGroup-A", mid: mid, hlc: "2026-10-31T00:00:00.000Z-0001-00000000000000aa")

        let client = makeClient(session: StubSession("{\"results\":[\(rejected(mid, "yala_not_authorized"))]}"))
        _ = await client.pushPending(context: context)

        #expect(notices.peek(groupID: "SplitGroup-A") == nil)
        #expect(notices.revision == 0)
    }

    // MARK: - (3) El detalle del grupo lo enseña

    @Test func groupDetail_showsTheReason_withItsTitle_once() {
        let notices = OpeningBalanceServerRejectionNotices()
        let vm = GroupDetailViewModel(group: makeGroup(zone: "SplitGroup-A"))
        notices.record(groupID: "SplitGroup-Otro", reason: .locked)
        notices.record(groupID: "SplitGroup-A", reason: .notAdmin)

        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)

        #expect(vm.showActionError)
        #expect(vm.actionErrorTitle == L10n.Groups.OpeningBalance.serverRejectedTitle)
        #expect(vm.actionErrorMessage == L10n.Groups.OpeningBalance.serverRejectedNotAdmin)
        #expect(notices.peek(groupID: "SplitGroup-A") == nil)
        // El de otro grupo se queda para ese grupo.
        #expect(notices.peek(groupID: "SplitGroup-Otro") == .locked)
    }

    @Test func groupDetail_eachReasonHasItsOwnText() {
        let texts = OpeningBalanceServerRejectionLogic.Reason.allCases.map(OpeningBalanceServerRejectionNotices.message(for:))
        #expect(Set(texts).count == 3)
        #expect(texts.allSatisfy { !$0.hasPrefix("groups.") })  // ninguna clave cruda
    }

    @Test func groupDetail_waitsForTheSheetAndTheOtherAlert() {
        let notices = OpeningBalanceServerRejectionNotices()
        let vm = GroupDetailViewModel(group: makeGroup(zone: "SplitGroup-A"))
        notices.record(groupID: "SplitGroup-A", reason: .locked)

        vm.activeSheet = .members
        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(!vm.showActionError)
        #expect(notices.peek(groupID: "SplitGroup-A") == .locked)

        vm.activeSheet = nil
        vm.actionErrorMessage = "otro"
        vm.showActionError = true
        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(vm.actionErrorMessage == "otro")
        #expect(notices.peek(groupID: "SplitGroup-A") == .locked)

        vm.showActionError = false
        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(vm.showActionError)
        #expect(vm.actionErrorMessage == L10n.Groups.OpeningBalance.serverRejectedLocked)
    }

    /// Con otra presentación de UIKit en la ventana (la hoja de compartir, una hoja de la columna de la lista) el aviso
    /// no se pide y el motivo NO se consume: pedido así no saldría y dejaría `showActionError` pegado.
    @Test func groupDetail_withTheWindowPresenting_keepsTheReasonForLater() {
        let notices = OpeningBalanceServerRejectionNotices()
        let vm = GroupDetailViewModel(group: makeGroup(zone: "SplitGroup-A"))
        notices.record(groupID: "SplitGroup-A", reason: .notAdmin)

        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: true)
        #expect(!vm.showActionError)
        #expect(notices.peek(groupID: "SplitGroup-A") == .notAdmin)

        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(vm.showActionError)
    }

    /// Caduca a los 30 minutos: abrir el grupo horas después no cuenta un rechazo viejo (y lo olvida).
    @Test func groupDetail_staleReason_isDroppedWithoutShowing() {
        let notices = OpeningBalanceServerRejectionNotices()
        let vm = GroupDetailViewModel(group: makeGroup(zone: "SplitGroup-A"))
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        notices.record(groupID: "SplitGroup-A", reason: .locked, now: t0)
        notices.record(groupID: "SplitGroup-B", reason: .locked, now: t0)

        vm.presentOpeningBalanceServerRejectionIfAny(
            notices: notices, windowIsPresenting: false, now: t0.addingTimeInterval(OpeningBalanceServerRejectionNotices.maxAge + 1))
        #expect(!vm.showActionError)
        #expect(notices.peek(groupID: "SplitGroup-A") == nil)

        // Vecino exacto del plazo: a los 30 minutos justos todavía sale.
        #expect(notices.consume(groupID: "SplitGroup-B", now: t0.addingTimeInterval(OpeningBalanceServerRejectionNotices.maxAge)) == .locked)
    }

    /// Un error de otra acción después del rechazo vuelve al título de siempre.
    @Test func groupDetail_laterError_doesNotInheritTheRejectionTitle() {
        let notices = OpeningBalanceServerRejectionNotices()
        let vm = GroupDetailViewModel(group: makeGroup(zone: "SplitGroup-A"))
        notices.record(groupID: "SplitGroup-A", reason: .groupClosed)
        vm.presentOpeningBalanceServerRejectionIfAny(notices: notices, windowIsPresenting: false)
        #expect(vm.actionErrorTitle == L10n.Groups.OpeningBalance.serverRejectedTitle)
        #expect(vm.actionErrorMessage == L10n.Groups.OpeningBalance.serverRejectedGroupClosed)

        vm.showActionError = false
        vm.surfaceActionError("otro fallo")
        #expect(vm.actionErrorTitle == nil)
        #expect(vm.actionErrorMessage == "otro fallo")
    }

    // MARK: - Infra (molde de `GroupsSyncHardeningTests`)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OBReject-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "OBR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "OBR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "OBR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private final class StubSession: SyncHTTPSession, @unchecked Sendable {
        let data: Data
        init(_ json: String) { self.data = Data(json.utf8) }
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }

    private final class Counter: @unchecked Sendable { var count = 0 }

    private func makeClient(session: SyncHTTPSession) -> GroupsSyncClient {
        let checks = Counter()
        return GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: session,
            sessionCheck: { checks.count += 1; return checks.count <= 50 },
            currentUserIDProvider: { "sub-a" },
            signInLogProvider: { SessionSignInLog(entries: [.init(sub: "sub-a", at: .distantPast)]) },
            outboxMirror: nil,
            forceRefreshTokenProvider: { nil },
            canRenewSession: { false })
    }

    private func seedRow(_ context: ModelContext, group: String, mid: UUID, hlc: String) throws {
        context.insert(GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: hlc, clientMutationID: mid,
            fieldsJSON: "{\"is_opening_balance\":true}", author: "", createdAt: .now,
            rejectedReason: nil, ownerUserID: "sub-a"))
        try context.save()
    }

    /// Lo que devuelve el gateway cuando `apply_group_delta` lanza un P0001 (`callApplyGroupDelta` + `redactGroupUpstream`).
    private func rejected(_ mid: UUID, _ code: String) -> String {
        "{\"sync_id\":\"s\",\"client_mutation_id\":\"\(mid.uuidString.lowercased())\",\"status\":\"rejected\","
            + "\"reason\":\"upstream_400\",\"outcome\":{\"code\":\"P0001\",\"message\":\"\(code)\"}}"
    }

    private func makeGroup(zone: String) -> SplitGroup {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zone
        return group
    }
}
