//
//  GroupsOutboxOwnershipTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-outbox-rows-without-a-live-session-have-no-exit` (encargo del 2026-09-28). Dos decisiones y las cuatro
//  frases del criterio del encargo, cada una con su test:
//
//   1. **Caducada con filas y puede entrar → sube, sin cambio**: `push_ownRows_upload_whenTheirAccountIsBack`.
//   2. **Caducada sin poder entrar → descarte avisado con la cifra y cierra**: `lossExit_*` del coordinador.
//   3. **Entra otra cuenta → no sube filas ajenas**: `push_rowsOfAnotherAccount_stayAndAreNotSent` y el reparto del
//      drain por el inicio de sesión (`drain_splitsTheUndrainedHistoryAtTheSignIn`).
//   4. **Cancelar el descarte no borra nada**: `lossExit_notNow_keepsEveryRow`.
//
//  Containers ON-DISK temporales con los tres stores (el History es por-container), `.serialized`: el coordinador de
//  cierre es un singleton con fase observable.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Infra común

@MainActor
private enum OwnershipFixture {
    static func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupsOwnership-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    static func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GO-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GO-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GO-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema, configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    static func makeBackendGroup(zoneID: String, context: ModelContext) {
        let g = SplitGroup(name: "G")
        g.cloudKitZoneID = zoneID
        g.isBackendGroup = true
        context.insert(g)
    }

    static func makeExpense(zoneID: String, desc: String, context: ModelContext) {
        context.insert(SplitExpense(groupZoneID: zoneID, amount: 10, currencyCode: "USD",
                                    expenseDescription: desc, paidByMemberID: "member-1"))
    }

    @discardableResult
    /// `legacy`: una fila de un build anterior al dueño por fila (`schemaVersion` 1), la única a la que se le busca dueño
    /// después.
    static func seedRow(_ context: ModelContext, owner: String?, rejected: String? = nil,
                        legacy: Bool = false) throws -> GroupSyncOutbox {
        let row = GroupSyncOutbox(
            syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
            op: .upsert, hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000aa",
            fieldsJSON: "{\"amount\":\"1.0000\"}", author: "", rejectedReason: rejected,
            schemaVersion: legacy ? CloudSyncSchemaVersions.groupSyncOutboxBeforeOwners : CloudSyncSchemaVersions.groupSyncOutbox,
            ownerUserID: owner)
        context.insert(row)
        try context.save()
        return row
    }

    static func outbox(_ context: ModelContext) throws -> [GroupSyncOutbox] {
        try context.fetch(FetchDescriptor<GroupSyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    static func appliedJSON(_ mids: [UUID]) -> Data {
        let items = mids.map {
            "{\"sync_id\":\"s\",\"client_mutation_id\":\"\($0.uuidString.lowercased())\",\"status\":\"applied\",\"reason\":\"\",\"outcome\":null}"
        }
        return Data("{\"results\":[\(items.joined(separator: ","))]}".utf8)
    }
}

/// Stub del transporte que guarda cada request y contesta siempre lo mismo.
private final class OwnershipStubSession: SyncHTTPSession, @unchecked Sendable {
    var requests: [URLRequest] = []
    let responseData: Data
    init(responseData: Data) { self.responseData = responseData }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (responseData, response)
    }
    var sentBodies: String {
        requests.compactMap { $0.httpBody.flatMap { String(data: $0, encoding: .utf8) } }.joined(separator: "\n")
    }
}

/// La sesión y el registro de sesiones de los tests, cambiables a mitad (una cuenta que caduca y otra que entra).
@MainActor
private final class SessionBox {
    var userID: String?
    var log: SessionSignInLog?
    init(_ userID: String?, log: SessionSignInLog? = nil) {
        self.userID = userID
        self.log = log
    }
}

private func entry(_ sub: String?, _ at: Date) -> SessionSignInLog.Entry { .init(sub: sub, at: at) }

// MARK: - 1 · La regla pura del dueño: el registro de sesiones

@Suite("Outbox de Grupos · de quién es cada cambio (registro de sesiones)")
struct GroupsOutboxOwnershipLogicTests {

    typealias L = GroupsOutboxOwnershipLogic
    private static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let suite = "GroupsOutboxOwnership-\(UUID().uuidString)"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test("MUTACIÓN: el dueño es la cuenta que el teléfono tenía cuando se escribió, no la de ahora")
    func owner_isTheAccountAtWriteTime() {
        let log = SessionSignInLog(entries: [entry("A", .distantPast), entry("B", Self.t0)])
        #expect(L.owner(transactionAt: Self.t0.addingTimeInterval(-0.001), log: log) == "A")
        #expect(L.owner(transactionAt: Self.t0, log: log) == "B", "el instante exacto del inicio de sesión es de B")
        #expect(L.owner(transactionAt: Self.t0.addingTimeInterval(3600), log: log) == "B")
    }

    @Test("Sin registro, o sin entrada anterior, no hay dueño probado")
    func owner_withoutEvidence_isNil() {
        #expect(L.owner(transactionAt: Self.t0, log: nil) == nil)
        #expect(L.owner(transactionAt: Self.t0, log: SessionSignInLog(entries: [])) == nil)
        let later = SessionSignInLog(entries: [entry("B", Self.t0)])
        #expect(L.owner(transactionAt: Self.t0.addingTimeInterval(-1), log: later) == nil,
                "lo escrito antes del primer inicio de sesión conocido no es de B")
    }

    @Test("MUTACIÓN: una sesión que entra y se cierra sin usarse no se queda con lo que se escriba después")
    func signOut_revertsToTheAccountBefore() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        SessionSignInLog.seedIfAbsent(sub: "A", defaults: defaults)
        SessionSignInLog.recordSignIn(sub: "B", previousSub: nil, at: Self.t0, defaults: defaults)
        SessionSignInLog.recordSignOut(closingSub: "B", at: Self.t0.addingTimeInterval(10), defaults: defaults)
        let log = try #require(SessionSignInLog.read(defaults: defaults))
        #expect(log.owner(at: Self.t0.addingTimeInterval(5)) == "B", "lo escrito con la sesión de B abierta es de B")
        #expect(log.owner(at: Self.t0.addingTimeInterval(20)) == "A", "tras cerrarse, lo de después vuelve a ser de A")
        // Cerrar una sesión que el registro no conoce no cambia nada.
        SessionSignInLog.recordSignOut(closingSub: "Z", at: Self.t0.addingTimeInterval(30), defaults: defaults)
        #expect(SessionSignInLog.read(defaults: defaults)?.entries.count == log.entries.count)
    }

    @Test("MUTACIÓN: la primera vez que este build ve el teléfono, lo anterior es de la cuenta que ya estaba")
    func seed_givesThePastToTheAccountThatWasThere() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        // Actualiza con la sesión de A caducada y entra B: sin semilla, lo que A dejó sin drenar sería de B o de nadie.
        SessionSignInLog.recordSignIn(sub: "B", previousSub: "A", at: Self.t0, defaults: defaults)
        let log = try #require(SessionSignInLog.read(defaults: defaults))
        #expect(log.owner(at: Self.t0.addingTimeInterval(-3600)) == "A")
        #expect(log.owner(at: Self.t0) == "B")
        // Idempotente: una semilla posterior no reescribe la historia.
        SessionSignInLog.seedIfAbsent(sub: "C", defaults: defaults)
        #expect(SessionSignInLog.read(defaults: defaults) == log)
    }

    @Test("Sin cuenta que sembrar, el registro nace vacío y lo anterior se retiene")
    func seed_withoutAnAccount_isEmpty() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        SessionSignInLog.seedIfAbsent(sub: nil, defaults: defaults)
        #expect(SessionSignInLog.read(defaults: defaults) == SessionSignInLog(entries: []))
    }

    @Test("El registro no crece sin tope: lo más viejo se va")
    func log_isCapped() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        SessionSignInLog.seedIfAbsent(sub: "A", defaults: defaults)
        for i in 0..<(SessionSignInLog.maxEntries + 5) {
            SessionSignInLog.recordSignIn(sub: "S\(i)", previousSub: nil, at: Self.t0.addingTimeInterval(Double(i)),
                                          defaults: defaults)
        }
        #expect(SessionSignInLog.read(defaults: defaults)?.entries.count == SessionSignInLog.maxEntries)
    }

    @Test("Qué sube una sesión: solo lo suyo; sin sesión no se filtra (lo dice el token)")
    func uploadable_andHeld() {
        #expect(L.isUploadable(rowOwner: "A", sessionOwner: "A"))
        #expect(!L.isUploadable(rowOwner: "A", sessionOwner: "B"))
        #expect(!L.isUploadable(rowOwner: nil, sessionOwner: "B"), "sin dueño probado no se sube con nadie")
        #expect(L.isUploadable(rowOwner: "A", sessionOwner: nil))
        #expect(L.isUploadable(rowOwner: nil, sessionOwner: nil))
        #expect(L.isHeldForAnotherAccount(rowOwner: "A", sessionOwner: "B"))
        #expect(!L.isHeldForAnotherAccount(rowOwner: "A", sessionOwner: nil), "sin sesión el motivo es la sesión")
    }
}

// MARK: - 2 · Las salidas: qué motivo abre la pérdida y con qué causa

@MainActor
@Suite("Cierre de sesión · la salida que pierde los cambios de grupos, por causa")
struct GroupsLossCauseLogicTests {

    typealias L = CloudSignOutFlowLogic

    @Test("MUTACIÓN: exactamente cuatro motivos abren la salida, con su causa")
    func lossCause_table() {
        let expected: [L.BlockReason: L.LossCause] = [
            .attestUnavailable: .attestUnavailable,
            .sessionExpired: .noSession,
            .cloudSessionExpired: .noSession,
            .groupsChangesFromAnotherAccount: .otherAccount,
        ]
        for reason in L.BlockReason.allCases {
            #expect(L.lossCause(reason) == expected[reason], "\(reason)")
        }
    }

    @Test("MUTACIÓN: lo aceptado sin sesión sigue solo mientras siga sin sesión, en los dos textos de la sesión caducada")
    func continuesOnlyWhileTheCauseHolds() {
        let a = UUID()
        #expect(L.continuesAfterBlockedUpload(reason: .sessionExpired, cause: .noSession, pendingRows: [a], acceptance: .rows([a])))
        #expect(L.continuesAfterBlockedUpload(reason: .cloudSessionExpired, cause: .noSession, pendingRows: [a], acceptance: .rows([a])))
        // La persona volvió a entrar y la subida falla por la red: esos cambios ya pueden subir.
        #expect(!L.continuesAfterBlockedUpload(reason: .uploadRetryLater, cause: .noSession, pendingRows: [a], acceptance: .rows([a])))
        // Otra causa no cubre lo aceptado por ésta.
        #expect(!L.continuesAfterBlockedUpload(reason: .groupsChangesFromAnotherAccount, cause: .noSession,
                                               pendingRows: [a], acceptance: .rows([a])))
        #expect(L.continuesAfterBlockedUpload(reason: .groupsChangesFromAnotherAccount, cause: .otherAccount,
                                              pendingRows: [a], acceptance: .rows([a])))
        // Una fila que no estaba en el aviso vuelve a avisar.
        #expect(!L.continuesAfterBlockedUpload(reason: .sessionExpired, cause: .noSession,
                                               pendingRows: [a, UUID()], acceptance: .rows([a])))
    }

    @Test("Lo que la sesión puede subir es el outbox menos lo ajeno, y un recuento fallido no se resta")
    func uploadableAfterHeld() {
        #expect(L.uploadableAfterHeld(live: 5, held: 2) == 3)
        #expect(L.uploadableAfterHeld(live: 2, held: 2) == 0)
        #expect(L.uploadableAfterHeld(live: 1, held: 3) == 0)
        #expect(L.uploadableAfterHeld(live: .max, held: 0) == .max)
        #expect(L.uploadableAfterHeld(live: 2, held: .max) == .max)
    }

    @Test("MUTACIÓN: drenado lo de la sesión, las filas ajenas bloquean con su motivo y la cifra del outbox entero")
    func heldRowsVerdict() {
        #expect(L.heldRowsVerdict(.drained, livePendingCount: 3, heldCount: 3)
                == .blocked(pendingCount: 3, reason: .groupsChangesFromAnotherAccount))
        #expect(L.heldRowsVerdict(.drained, livePendingCount: 0, heldCount: 0) == .drained)
        let other = L.PushAllVerdict.blocked(pendingCount: 2, reason: .uploadRetryLater)
        #expect(L.heldRowsVerdict(other, livePendingCount: 2, heldCount: 1) == other)
    }

    @Test("Los cambios de otra cuenta se enseñan al momento, viajan tal cual en la nube y «Empezar de cero» ofrece perderlos")
    func otherAccount_isSurfacedAtOnce() {
        #expect(GroupsSignOutRetryDecision.decide(elapsedSeconds: 0, budgetSeconds: 45,
                                                  reason: .groupsChangesFromAnotherAccount) == .surfacePermanent)
        #expect(L.cloudSignOutGroupsBlockReason(.groupsChangesFromAnotherAccount) == .groupsChangesFromAnotherAccount)
        #expect(L.freshStartOffersGroupsLossExit(.groupsChangesFromAnotherAccount))
    }

    @Test("El aviso cuenta con la cifra de su causa, y sin ella cuando no hay número honesto")
    func lossCopy_perCause() {
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .sessionExpired, pending: 3)
                == L10n.Groups.Errors.noSessionSignOutLoss(3))
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .groupsChangesFromAnotherAccount, pending: 3)
                == L10n.Groups.Errors.noSessionSignOutLoss(3))
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .cloudSessionExpired, pending: 3)
                == L10n.Settings.signOutCloudSessionExpiredGroupsLoss(3))
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .attestUnavailable, pending: 3)
                == SignOutBlockedCopy.attestLossMessage(pending: 3))
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .sessionExpired, pending: .max)
                == L10n.Groups.Errors.noSessionSignOutLossUnknown)
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .cloudSessionExpired, pending: .max)
                == L10n.Settings.signOutCloudSessionExpiredGroupsLossUnknown)
        #expect(SignOutBlockedCopy.groupsLossTitle(for: .attestUnavailable) == L10n.Groups.Errors.attestUnavailableTitle)
        #expect(SignOutBlockedCopy.groupsLossTitle(for: .sessionExpired) == L10n.Settings.signOutBlockedTitle)
        #expect(SignOutBlockedCopy.message(for: .groupsChangesFromAnotherAccount)
                == L10n.Groups.Errors.groupsChangesFromAnotherAccount)
        #expect(SignOutBlockedCopy.welcomeNoSessionLossMessage(pending: 2) == L10n.Welcome.Groups.neutralNoSessionLossBody(2))
        #expect(SignOutBlockedCopy.welcomeNoSessionLossMessage(pending: .max) == L10n.Welcome.Groups.neutralNoSessionLossBodyUnknown)
        #expect(!L10n.Groups.Errors.noSessionSignOutLoss(3).contains("%d"))
    }

    @Test("La hoja del cambio de Apple ID enseña la pérdida también con la sesión caducada, y solo con la salida viva")
    func appleIDSheet_showsTheLossForAnExpiredSession() {
        let phase = CloudSessionSignOut.Phase.blocked(pendingCount: 2, reason: .sessionExpired)
        #expect(AppleIDCloseNoticeLogic.stage(notice: .closing, phase: phase, offersGroupsLossExit: true)
                == .losingGroupChanges(pending: 2, reason: .sessionExpired))
        #expect(AppleIDCloseNoticeLogic.stage(notice: .closing, phase: phase, offersGroupsLossExit: false)
                == .blocked(.sessionExpired))
    }
}

// MARK: - 3 · El canal: el drain estampa el dueño y la subida solo manda lo de la sesión

/// Stub del transporte con una secuencia de estados HTTP: cada request toma el siguiente, y el último se repite.
private final class OwnershipSequenceSession: SyncHTTPSession, @unchecked Sendable {
    var requests: [URLRequest] = []
    private var replies: [(Int, Data)]
    init(_ replies: [(Int, Data)]) { self.replies = replies }
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let reply = replies.count > 1 ? replies.removeFirst() : replies[0]
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.0, httpVersion: nil, headerFields: nil)!
        return (reply.1, response)
    }
}

@MainActor
@Suite("Outbox de Grupos · el drain estampa el dueño y la subida respeta al dueño", .serialized)
struct GroupsOutboxOwnershipChannelTests {

    private typealias F = OwnershipFixture

    private func makeClient(session: SessionBox, stub: SyncHTTPSession? = nil, mirror: GroupsOutboxMirror? = nil,
                            forceRefresh: @escaping @MainActor () async -> String? = { nil }) -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { session.userID == nil ? nil : "jwt" },
            urlSession: stub ?? OwnershipStubSession(responseData: Data("{\"results\":[]}".utf8)),
            currentUserIDProvider: { session.userID },
            signInLogProvider: { session.log },
            outboxMirror: mirror,
            forceRefreshTokenProvider: forceRefresh,
            canRenewSession: { session.userID != nil })
    }

    @Test("MUTACIÓN: cada fila nace con la cuenta que el registro dice que tenía el teléfono")
    func drain_stampsTheOwnerFromTheLog() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        F.makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        F.makeExpense(zoneID: "SplitGroup-A", desc: "Cena", context: context)
        try context.save()

        let client = makeClient(session: SessionBox("user-a", log: SessionSignInLog(entries: [entry("user-a", .distantPast)])))
        #expect(client.drainOnce(context: context))
        #expect(try F.outbox(context).map(\.ownerUserID) == ["user-a"])
    }

    @Test("MUTACIÓN: sin sesión, lo capturado es de la cuenta que había, y el espejo lo sella con ella")
    func drain_withoutASession_goesToTheLastAccount_andSealsTheMirror() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        F.makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        F.makeExpense(zoneID: "SplitGroup-A", desc: "Sin red", context: context)
        try context.save()

        // El SDK borró la sesión de A: no hay sesión, pero el registro dice que el teléfono era de A.
        let client = makeClient(session: SessionBox(nil, log: SessionSignInLog(entries: [entry("user-a", .distantPast)])),
                                mirror: mirror)
        #expect(client.drainOnce(context: context))
        #expect(try F.outbox(context).map(\.ownerUserID) == ["user-a"])
        #expect(mirror.entriesForUser("user-a").count == 1, "sin sesión el espejo tampoco se quedaba sin sellar")
    }

    @Test("MUTACIÓN: entra otra cuenta — lo escrito antes de su inicio de sesión se queda con la anterior")
    func drain_splitsTheUndrainedHistoryAtTheSignIn() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        F.makeBackendGroup(zoneID: "SplitGroup-A", context: context)
        try context.save()

        // La sesión de A caduca y A apunta un gasto sin red: se queda en el History, sin drenar.
        let session = SessionBox(nil, log: SessionSignInLog(entries: [entry("user-a", .distantPast)]))
        F.makeExpense(zoneID: "SplitGroup-A", desc: "De A", context: context)
        try context.save()
        try await Task.sleep(for: .milliseconds(30))

        // Entra B en este teléfono y apunta el suyo. El primer drain, ya con la sesión de B, ve los dos.
        session.userID = "user-b"
        session.log?.entries.append(entry("user-b", Date()))
        try await Task.sleep(for: .milliseconds(30))
        F.makeExpense(zoneID: "SplitGroup-A", desc: "De B", context: context)
        try context.save()
        let client = makeClient(session: session)
        #expect(client.drainOnce(context: context))

        let rows = try F.outbox(context)
        #expect(rows.count == 2)
        let deA = rows.first { $0.fieldsJSON.contains("De A") }
        let deB = rows.first { $0.fieldsJSON.contains("De B") }
        #expect(deA?.ownerUserID == "user-a", "el gasto que A apuntó sin sesión salió como de \(deA?.ownerUserID ?? "nadie")")
        #expect(deB?.ownerUserID == "user-b", "el gasto de B salió como de \(deB?.ownerUserID ?? "nadie")")
    }

    @Test("MUTACIÓN: entra otra cuenta — sus filas suben y las de la cuenta anterior se quedan, sin re-sellar")
    func push_rowsOfAnotherAccount_stayAndAreNotSent() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let deA = try F.seedRow(context, owner: "user-a")
        let deB = try F.seedRow(context, owner: "user-b")
        let sinDueno = try F.seedRow(context, owner: nil)
        let stub = OwnershipStubSession(responseData: F.appliedJSON([deB.clientMutationID]))
        let client = makeClient(session: SessionBox("user-b"), stub: stub)

        #expect(client.liveRowsHeldForAnotherAccount(context: context) == 2)
        _ = await client.pushPending(context: context)

        #expect(stub.requests.count == 1)
        #expect(stub.sentBodies.contains(deB.clientMutationID.uuidString.lowercased()))
        #expect(!stub.sentBodies.contains(deA.clientMutationID.uuidString.lowercased()), "subió un cambio de A con la sesión de B")
        #expect(!stub.sentBodies.contains(sinDueno.clientMutationID.uuidString.lowercased()), "subió un cambio sin dueño probado")
        let left = try F.outbox(context)
        #expect(Set(left.map(\.clientMutationID)) == [deA.clientMutationID, sinDueno.clientMutationID])
        #expect(left.first { $0.clientMutationID == deA.clientMutationID }?.ownerUserID == "user-a", "se re-selló")
        #expect(left.first { $0.clientMutationID == sinDueno.clientMutationID }?.ownerUserID == nil, "se re-selló")
    }

    @Test("Con solo filas ajenas, la subida no hace ninguna petición")
    func push_onlyForeignRows_sendsNothing() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        let stub = OwnershipStubSession(responseData: Data("{\"results\":[]}".utf8))
        let client = makeClient(session: SessionBox("user-b"), stub: stub)

        #expect(await client.pushPending(context: context) == .completed([]))
        #expect(stub.requests.isEmpty)
        #expect(try F.outbox(context).count == 1)
    }

    @Test("Caducada y puede entrar: cuando su cuenta vuelve, sus filas suben y se purgan, sin cambio")
    func push_ownRows_upload_whenTheirAccountIsBack() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let uno = try F.seedRow(context, owner: "user-a")
        let dos = try F.seedRow(context, owner: "user-a")
        let session = SessionBox(nil)
        let stub = OwnershipStubSession(responseData: F.appliedJSON([uno.clientMutationID, dos.clientMutationID]))
        let client = makeClient(session: session, stub: stub)

        // Sin sesión no se filtra: el token dice «caducada», como siempre.
        #expect(await client.pushPending(context: context) == .sessionExpired(pending: 2))
        #expect(stub.requests.isEmpty)
        #expect(client.liveRowsHeldForAnotherAccount(context: context) == 0, "sin sesión el motivo es la sesión")

        session.userID = "user-a"  // vuelve a entrar
        _ = await client.pushPending(context: context)
        #expect(stub.requests.count == 1)
        #expect(try F.outbox(context).isEmpty)
    }

    @Test("MUTACIÓN: una fila sin dueño de un build anterior lo toma del registro, y sube cuando su cuenta vuelve")
    func legacyRowWithoutMirror_takesTheLogOwner_andUploads() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        // Capturada sin sesión por un build anterior: el espejo no la guardó, así que solo el registro sabe de quién es.
        let legado = try F.seedRow(context, owner: nil, legacy: true)
        let session = SessionBox("user-a", log: SessionSignInLog(entries: [entry("user-a", .distantPast)]))
        let stub = OwnershipStubSession(responseData: F.appliedJSON([legado.clientMutationID]))
        let client = makeClient(session: session, stub: stub)

        #expect(client.drainOnce(context: context))
        #expect(try F.outbox(context).first?.ownerUserID == "user-a")
        _ = await client.pushPending(context: context)
        #expect(stub.sentBodies.contains(legado.clientMutationID.uuidString.lowercased()))
        #expect(try F.outbox(context).isEmpty)
    }

    @Test("MUTACIÓN: una dead-letter antigua sin dueño también lo toma, para que el re-drive pueda subirla")
    func legacyDeadLetter_takesAnOwnerToo() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: nil, rejected: "upstream_400:yala_not_authorized", legacy: true)
        let client = makeClient(session: SessionBox("user-a", log: SessionSignInLog(entries: [entry("user-a", .distantPast)])))
        #expect(client.drainOnce(context: context))
        #expect(try F.outbox(context).first?.ownerUserID == "user-a")
    }

    @Test("MUTACIÓN: la entrada del espejo gana al registro; sin ninguna de las dos, la fila se queda sin dueño")
    func adoption_prefersTheMirror_andNeverInventsAnOwner() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        let conEntrada = try F.seedRow(context, owner: nil, legacy: true)
        let sinNada = try F.seedRow(context, owner: nil, legacy: true)
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "user-a", syncID: conEntrada.syncID, groupID: conEntrada.groupID, entityType: conEntrada.entityType,
            op: conEntrada.opRaw, hlc: conEntrada.hlc, clientMutationID: conEntrada.clientMutationID,
            fieldsJSON: conEntrada.fieldsJSON, fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: conEntrada.createdAt))

        // Registro que empieza DESPUÉS de las dos filas: no prueba nada de ellas.
        let client = makeClient(session: SessionBox("user-b", log: SessionSignInLog(entries: [entry("user-b", Date().addingTimeInterval(60))])),
                                mirror: mirror)
        #expect(client.drainOnce(context: context))

        let rows = try F.outbox(context)
        #expect(rows.first { $0.clientMutationID == conEntrada.clientMutationID }?.ownerUserID == "user-a")
        #expect(rows.first { $0.clientMutationID == sinNada.clientMutationID }?.ownerUserID == nil)
    }

    @Test("MUTACIÓN: una fila de este build que el drain dejó sin dueño no lo recibe después de la sesión de ahora")
    func newRowLeftUnowned_isNeverAdoptedLater() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        // La regla del drain la dejó sin dueño (nadie tenía el teléfono cuando se escribió). Luego entró B.
        try F.seedRow(context, owner: nil)
        let client = makeClient(session: SessionBox("user-b", log: SessionSignInLog(entries: [entry("user-b", .distantPast)])))
        #expect(client.drainOnce(context: context))
        #expect(client.drainOnce(context: context))
        #expect(try F.outbox(context).first?.ownerUserID == nil, "una fila sin dueño probado acabó siendo de B")
    }

    @Test("MUTACIÓN: si durante el `await` del token entra otra cuenta, no se sube nada con ella")
    func push_accountChangedWhileGettingTheToken_sendsNothing() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        let session = SessionBox("user-a")
        let stub = OwnershipStubSession(responseData: Data("{\"results\":[]}".utf8))
        let client = GroupsSyncClient(
            tokenProvider: { session.userID = "user-b"; return "jwt-b" },
            urlSession: stub,
            currentUserIDProvider: { session.userID },
            signInLogProvider: { session.log },
            outboxMirror: nil,
            canRenewSession: { true })

        #expect(await client.pushPending(context: context) == .transient)
        #expect(stub.requests.isEmpty, "el cambio de A salió con el token de B")
    }

    @Test("MUTACIÓN: si mientras se renueva el token entra otra cuenta, el chunk no se reenvía con ella")
    func push_refreshThatReturnsAnotherAccount_doesNotResend() async throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let deA = try F.seedRow(context, owner: "user-a")
        let session = SessionBox("user-a")
        let stub = OwnershipSequenceSession([
            (401, Data("{\"error\":{\"type\":\"yala_attest_invalid\"}}".utf8)),
            (200, F.appliedJSON([deA.clientMutationID])),
        ])
        let client = makeClient(session: session, stub: stub, forceRefresh: {
            session.userID = "user-b"  // entra B mientras el refresh vuela
            return "jwt-b"
        })

        #expect(await client.pushPending(context: context) == .transient)
        #expect(stub.requests.count == 1, "el chunk de A se reenvió con el token de B")
        #expect(try F.outbox(context).count == 1)
    }

    @Test("La rehidratación del espejo devuelve la fila con el dueño que la selló")
    func rehydrate_keepsTheOwner() throws {
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        try mirror.write(GroupsOutboxMirrorEntry(
            userID: "user-a", syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
            op: SyncOutboxOp.upsert.rawValue, hlc: "2026-07-15T00:00:00.000Z-0000-00000000000000ab",
            clientMutationID: UUID(), fieldsJSON: "{}", fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: .now))

        makeClient(session: SessionBox("user-a"), mirror: mirror).rehydrateOutboxFromMirror(context: context)
        #expect(try F.outbox(context).map(\.ownerUserID) == ["user-a"])
    }
}

// MARK: - 4 · El cierre: descarte AVISADO con la cifra, y cancelar no borra nada

/// Cierre privado (C) de verdad sobre el coordinador compartido, con cambios de grupos sin subir y sin sesión — el estado
/// real que lo bloquea. **No llega a armar el borrado**: la lectura de la migración se sustituye para que diga «en reposo»
/// en las dos primeras consultas y «en vuelo» en la tercera, que es la de la entrada de `finalizeSessionExit`. Llegar ahí
/// con el motivo de la migración PRUEBA que lo aceptado dejó pasar el bloqueo de grupos, sin teardown ni `signOut`.
@MainActor
@Suite("Cierre de sesión · salir perdiendo los cambios de grupos sin sesión", .serialized)
struct GroupsNoSessionLossExitTests {

    private typealias F = OwnershipFixture
    private let coordinator = CloudSessionSignOut.shared

    private final class Calls { var count = 0 }

    private static let atRest = MigrationRestReading(
        controllerState: nil, controllerIsWorking: false, journalRead: .phase(.notStarted),
        persistedStorageMode: .icloud, mirrorOffArmed: false, mountedDecision: .iCloudMirror)
    private static let inFlight = MigrationRestReading(
        controllerState: nil, controllerIsWorking: false, journalRead: .phase(.uploadingSnapshot),
        persistedStorageMode: .icloud, mirrorOffArmed: false, mountedDecision: .iCloudMirror)

    private func reset() {
        coordinator.acknowledgeBlocked()
        coordinator.migrationRestReadingOverride = nil
        coordinator.exitWitnessOverride = nil
    }

    /// El canal, hermético: la captura no toca el cliente compartido y el espejo es el de la prueba (el REAL del simulador
    /// guarda lo que otras suites dejan, y sin sesión el recuento de la pérdida lo contaría entero).
    private func hermeticWitness(capture: @escaping @MainActor (ModelContext) -> Bool = { _ in true },
                                 mirror: Set<UUID>? = []) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: capture, mirrorPending: { _, _ in mirror?.count ?? .max }, mirrorPendingKeys: { _, _ in [] })
        witness.mirrorPendingMutationIDs = { _, _ in mirror }
        return witness
    }

    private func disarmIfArmed() {
        guard StorageModePersistence.isSignOutWipeArmed() else { return }
        StorageModePersistence.clearSignOutWipeArm()
        StorageModePersistence.clearSignOutWipeIncludesGroups()
    }

    /// Solo la celda C bloquea por `blockIfGroupsCannotUpload` sin tocar la red. Se exige, no se supone.
    private func requirePrivateOnlyCell() throws {
        let path = CloudSignOutFlowLogic.path(
            for: CloudSyncFlags.storageMode, hasLiveSession: CloudAuthService.shared.hasSession,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability,
            hasPrivateSession: PrivateSessionMark.hasPrivateSession())
        try #require(path == .privateSignOut, "el host de test no está en la celda C (\(path)): este test no mediría nada")
    }

    /// Siembra, cierra y deja el cierre en el aviso. Las consultas de la migración pasan por `calls`.
    private func blockOnGroups(_ context: ModelContext, calls: Calls, inFlightFrom: Int = .max,
                               witness: CloudSessionSignOut.GroupsExitWitness? = nil) async throws {
        coordinator.exitWitnessOverride = witness ?? hermeticWitness()
        coordinator.migrationRestReadingOverride = {
            calls.count += 1
            return calls.count >= inFlightFrom ? Self.inFlight : Self.atRest
        }
        await coordinator.signOut(context: context, confirmedPath: .privateSignOut, confirmedWithoutICloudCopy: true)
    }

    @Test("MUTACIÓN: sin sesión, el aviso cuenta las filas vivas y ofrece perderlas; el camino por defecto no pierde nada")
    func lossExit_isOfferedWithTheRightCount() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle, "el coordinador venía ocupado de otro test")
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        try F.seedRow(context, owner: "user-a")
        try F.seedRow(context, owner: "user-a", rejected: "upstream_400:x")  // dead-letter: no cuenta

        try await blockOnGroups(context, calls: Calls())

        #expect(coordinator.phase == .blocked(pendingCount: 2, reason: .sessionExpired))
        #expect(coordinator.offersGroupsLossExit)
        #expect(!StorageModePersistence.isSignOutWipeArmed())
    }

    @Test("MUTACIÓN: cancelar el descarte («Ahora no») no borra nada ni deja la salida viva")
    func lossExit_notNow_keepsEveryRow() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        try F.seedRow(context, owner: "user-a")
        let calls = Calls()
        try await blockOnGroups(context, calls: calls)
        try #require(coordinator.offersGroupsLossExit)

        coordinator.acknowledgeBlocked()  // «Ahora no»
        #expect(coordinator.phase == .idle)
        #expect(!coordinator.offersGroupsLossExit)
        // Y el botón que llegara tarde tampoco hace nada: ya no hay aviso vivo.
        await coordinator.exitDiscardingUnsyncedGroups(context: context)
        #expect(coordinator.phase == .idle)
        #expect(calls.count == 1, "el descarte retomó el cierre tras «Ahora no»")
        #expect(try F.outbox(context).count == 2)
        #expect(!StorageModePersistence.isSignOutWipeArmed())
    }

    @Test("MUTACIÓN: «Cerrar sesión y perderlos» deja pasar el bloqueo de grupos y el cierre sigue hacia el borrado")
    func lossExit_accepted_continuesTheClose() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        try F.seedRow(context, owner: "user-a")
        // 1 = el cierre; 2 = el cierre retomado; 3 = la entrada de `finalizeSessionExit`, que se para aquí.
        try await blockOnGroups(context, calls: Calls(), inFlightFrom: 3)
        try #require(coordinator.phase == .blocked(pendingCount: 2, reason: .sessionExpired))

        await coordinator.exitDiscardingUnsyncedGroups(context: context)

        #expect(coordinator.phase == .blocked(pendingCount: 0, reason: .migrationInFlight), """
            el cierre no pasó el bloqueo de grupos con la pérdida aceptada: \(coordinator.phase)
            """)
        #expect(try F.outbox(context).count == 2, "aceptar no borra filas: se van con el borrado del arranque")
        #expect(!StorageModePersistence.isSignOutWipeArmed())
    }

    @Test("MUTACIÓN: un cambio que no estaba en el aviso vuelve a avisar, con la cifra nueva")
    func lossExit_newRowAfterTheNotice_asksAgain() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        try await blockOnGroups(context, calls: Calls(), inFlightFrom: 3)
        try #require(coordinator.phase == .blocked(pendingCount: 1, reason: .sessionExpired))

        try F.seedRow(context, owner: "user-a")  // apuntado con el aviso abierto
        await coordinator.exitDiscardingUnsyncedGroups(context: context)

        #expect(coordinator.phase == .blocked(pendingCount: 2, reason: .sessionExpired))
        #expect(coordinator.offersGroupsLossExit)
        #expect(!StorageModePersistence.isSignOutWipeArmed())
    }

    @Test("MUTACIÓN: antes de contar, lo que solo vive en el History entra en la cifra")
    func lossExit_capturesTheHistoryBeforeCounting() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        // La captura drena un gasto que aún estaba solo en el History: aparece una fila más.
        let witness = hermeticWitness(capture: { ctx in
            do {
                try F.seedRow(ctx, owner: "user-a")
                return true
            } catch {
                return false
            }
        })
        try await blockOnGroups(context, calls: Calls(), witness: witness)

        #expect(coordinator.phase == .blocked(pendingCount: 2, reason: .sessionExpired), """
            el aviso no contó lo que la captura acababa de sacar del History: \(coordinator.phase)
            """)
    }

    @Test("MUTACIÓN: las entradas del espejo sin fila también se cuentan y se aceptan")
    func lossExit_countsTheMirrorToo() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        let espejo: Set<UUID> = [UUID(), UUID()]
        try await blockOnGroups(context, calls: Calls(), inFlightFrom: 3, witness: hermeticWitness(mirror: espejo))
        #expect(coordinator.phase == .blocked(pendingCount: 3, reason: .sessionExpired))

        // Aceptadas las tres, el cierre sigue: el borrado se llevaría las tres y el aviso las contó.
        await coordinator.exitDiscardingUnsyncedGroups(context: context)
        #expect(coordinator.phase == .blocked(pendingCount: 0, reason: .migrationInFlight))
    }

    @Test("MUTACIÓN: con cambios solo en el espejo del App Group, el cierre ya no sigue callado")
    func onlyMirrorEntries_block() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try await blockOnGroups(context, calls: Calls(), witness: hermeticWitness(mirror: [UUID()]))
        #expect(coordinator.phase == .blocked(pendingCount: 1, reason: .sessionExpired))
        #expect(coordinator.offersGroupsLossExit)
    }

    @Test("MUTACIÓN: con la captura a medias no se ofrece perder nada: el aviso no podría contarlo")
    func lossExit_notOffered_whenTheCaptureDidNotFinish() async throws {
        reset(); defer { reset(); disarmIfArmed() }
        try #require(coordinator.phase == .idle)
        try requirePrivateOnlyCell()
        let dir = F.freshDir(); defer { F.cleanup(dir) }
        let context = try F.makeContext(dir)
        try F.seedRow(context, owner: "user-a")
        try await blockOnGroups(context, calls: Calls(), witness: hermeticWitness(capture: { _ in false }))

        #expect(coordinator.phase == .blocked(pendingCount: 1, reason: .uploadRetryLater))
        #expect(!coordinator.offersGroupsLossExit)
        #expect(!StorageModePersistence.isSignOutWipeArmed())
    }
}

// MARK: - 5 · El registro de sesiones, en los sitios que abren y cierran una sesión

/// `CloudAuthService` no tiene seam para un inicio de sesión de verdad (Apple y Google son SDK + red), así que lo único que
/// fija que el registro se escribe es el código: sin él, el drain no puede fechar lo que la cuenta anterior dejó sin drenar.
@Suite("Outbox de Grupos · los inicios y cierres de sesión escriben el registro, y el arranque lo siembra")
struct SessionSignInLogWiringTests {

    private static func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    /// Sin comentarios: documentar el registro no puede contar como escribirlo.
    private static func codeOnly(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("MUTACIÓN: Apple y Google apuntan la entrada tras el canje, con la sesión de antes leída ANTES del canje")
    func bothSignInsRecordTheEntry() throws {
        let auth = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudAuthService.swift"))
        #expect(auth.components(separatedBy: "SessionSignInLog.recordSignIn(").count - 1 == 2)
        let pairs = [
            ("let previousUserID = currentUserID", "SessionSignInLog.recordSignIn(sub: currentUserID, previousSub: previousUserID, at: Date())"),
            ("let previousUserID = self.currentUserID", "SessionSignInLog.recordSignIn(sub: self.currentUserID, previousSub: previousUserID, at: Date())"),
        ]
        for (before, record) in pairs {
            let previous = try #require(auth.range(of: before), "falta `\(before)`")
            let recorded = try #require(auth.range(of: record), "falta `\(record)`")
            let exchange = try #require(auth.range(of: "signInWithIdToken(", range: previous.upperBound..<recorded.lowerBound),
                                        "la sesión de antes no se lee ANTES del canje")
            let signedIn = try #require(auth.range(of: "CloudSyncBreadcrumb.authSignedIn()",
                                                   range: exchange.upperBound..<recorded.lowerBound))
            #expect(signedIn.lowerBound < recorded.lowerBound)
        }
    }

    @Test("MUTACIÓN: `signOut()` vuelve a la cuenta de antes solo con una sesión DE PASO ida, y solo la pide el controller")
    func signOutRecordsOnlyWhenTheSessionIsGone() throws {
        let auth = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudAuthService.swift"))
        #expect(auth.contains("func signOut(returningToPreviousAccount: Bool = false) async -> Bool {"))
        let closing = try #require(auth.range(of: "let closingUserID = currentUserID"))
        let sdk = try #require(auth.range(of: "try await client.signOut(scope: .local)"))
        let gone = try #require(auth.range(of: "if gone {", range: sdk.upperBound..<auth.endIndex))
        let record = try #require(auth.range(of: """
            if returningToPreviousAccount {
                            SessionSignInLog.recordSignOut(closingSub: closingUserID, at: Date())
                        }
            """))
        let orElse = try #require(auth.range(of: "} else {", range: record.upperBound..<auth.endIndex))
        #expect(closing.lowerBound < sdk.lowerBound)
        #expect(gone.upperBound < record.lowerBound, "el cierre se apunta fuera de la rama de la sesión ida")
        #expect(record.upperBound < orElse.upperBound)
        #expect(auth.components(separatedBy: "SessionSignInLog.recordSignOut(").count - 1 == 1)
        // Solo la sesión que abrió un intento y se cierra sin usarse vuelve a la de antes: ningún otro cierre lo pide.
        var callers = 0
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Yala")
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            callers += Self.codeOnly(text).components(separatedBy: "signOut(returningToPreviousAccount: true)").count - 1
        }
        #expect(callers == 1)
        let controller = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudMigrationController.swift"))
        #expect(controller.contains("await CloudAuthService.shared.signOut(returningToPreviousAccount: true)"))
    }

    /// El push-all del cierre corre con el cliente compartido y la red de verdad, así que ningún test de comportamiento llega a
    /// su bucle: sin este escáner, contar las filas de otra cuenta como subibles (el mutante M12) dejaba el cierre esperando 20
    /// vueltas un outbox que esta sesión no vacía y acababa en «un momento más», con todos los tests en verde.
    @Test("MUTACIÓN: el bucle del push-all cuenta aparte las filas de otra cuenta, y con solo ésas bloquea con su motivo")
    func pushAllLoopCountsTheHeldRowsApart() throws {
        let signOut = Self.codeOnly(try Self.source("Yala/Services/CloudSync/CloudSessionSignOut.swift"))
        let squashed = signOut.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        func sq(_ text: String) -> String { text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
        #expect(squashed.contains(sq("""
            livePendingCount: CloudSignOutFlowLogic.uploadableAfterHeld(
                live: Self.liveGroupsPendingCount(context: context), held: witness.heldForAnotherAccount(context)),
            """)), "el veredicto del ciclo cuenta las filas de otra cuenta como si esta sesión pudiera subirlas")
        #expect(squashed.contains(sq("""
            livePendingCount: CloudSignOutFlowLogic.uploadableAfterHeld(live: live, held: held),
            unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner)) {
            return CloudSignOutFlowLogic.heldRowsVerdict(settled, livePendingCount: live, heldCount: held)
            """)), "tras vaciar lo de la sesión, las filas de otra cuenta ya no bloquean con su motivo")
    }

    @Test("MUTACIÓN: el arranque siembra el registro antes de arrancar el canal de Grupos y el motor personal")
    func bootstrapSeedsBeforeAnyDrain() throws {
        let boot = Self.codeOnly(try Self.source("Yala/App/AppBootstrapper.swift"))
        let seed = try #require(boot.range(of: """
            SessionSignInLog.seedIfAbsent(
                        sub: CloudAuthService.shared.currentUserID ?? GroupsAccountAssociation.shared.associatedSub)
            """))
        let groups = try #require(boot.range(of: "GroupsSyncClient.shared.startIfEligible(context: context)"))
        let runtime = try #require(boot.range(of: "CloudSyncRuntime.startShared(context: context)"))
        #expect(seed.lowerBound < groups.lowerBound)
        #expect(seed.lowerBound < runtime.lowerBound)
        let client = try Self.source("Yala/Services/CloudSync/Groups/GroupsSyncClient.swift")
        #expect(client.contains("signInLogProvider: @escaping @MainActor () -> SessionSignInLog? = { SessionSignInLog.read() },"))
    }
}
