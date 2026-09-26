//
//  GroupsDrainFailureReadsAsPendingTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-drain-failure-reads-as-nothing-pending`: el cierre de sesión, el desasociar y «Empezar de cero» drenan
//  el History al outbox de grupos y cuentan las filas vivas antes de borrar. Hasta el 2026-09-26 `drainOnce` no devolvía
//  nada: un drain que lanzaba o que cortaba el reloj dejaba el gasto solo en el History, el recuento daba 0 y el borrado
//  seguía. Su gemelo era el espejo del App Group: un cambio que solo vivía ahí no contaba y `resetSyncState` lo purgaba.
//
//  Tres capas, de abajo arriba:
//   1. El cliente REAL, con stores en disco y un espejo temporal: `drainOnce` dice si terminó, la captura previa
//      rehidrata el espejo, y el recuento del espejo respeta su alcance.
//   2. El veredicto puro (`CloudSignOutFlowLogic.groupsCaptureVerdict`), cada celda.
//   3. Los gestos (`CloudSessionSignOut`, `DataWipeService`) con el testigo inyectado: el espejo real del simulador
//      guarda lo que otras suites dejan (48 entradas de `auth-uid-1` medidas el 2026-09-26), así que un test que lo
//      leyera dependería del orden de las demás.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

extension CloudSessionSignOut.GroupsExitWitness {
    /// Sin canal: la captura termina y el espejo no guarda nada fuera del outbox. Para las suites que miden el recuento
    /// del outbox y no el canal.
    static var quiet: Self { Self(capture: { _ in true }, mirrorPending: { _, _ in 0 }) }
}

// MARK: - 1. El cliente real

@Suite("Grupos · el drain dice si terminó, y la captura previa rehidrata el espejo", .serialized)
@MainActor
struct GroupsDrainCaptureTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSDrainFail-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GDF-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GDF-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GDF-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Sin red: ningún test de aquí empuja. El transporte lanza si alguien lo intenta.
    private final class NoNetwork: SyncHTTPSession, @unchecked Sendable {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            throw URLError(.notConnectedToInternet)
        }
    }

    private func makeClient(mirrorDir: URL, userID: String? = "sub-a") -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: NoNetwork(), sessionCheck: { false },
            currentUserIDProvider: { userID },
            outboxMirror: GroupsOutboxMirror(directoryURL: mirrorDir),
            forceRefreshTokenProvider: { nil }, canRenewSession: { false })
    }

    /// Un grupo del canal backend (C2-bis: solo esos drenan) y un gasto nuevo en él, guardados: el gasto queda en el
    /// History esperando al drain.
    private func seedBackendExpense(_ context: ModelContext, zone: String = "SplitGroup-A") throws {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = zone
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
        context.insert(SplitExpense(groupZoneID: zone, amount: 30, currencyCode: "PEN",
                                    expenseDescription: "Taxi", paidByMemberID: "m1"))
        try context.save()
    }

    private func mirrorEntry(
        user: String, syncID: UUID = UUID(), hlc: String = "2026-09-26T00:00:00.000Z-0001-00000000000000aa",
        entity: String = GroupSyncEntityType.splitExpense, op: String = SyncOutboxOp.upsert.rawValue
    ) -> GroupsOutboxMirrorEntry {
        GroupsOutboxMirrorEntry(
            userID: user, syncID: syncID, groupID: "SplitGroup-A", entityType: entity, op: op, hlc: hlc,
            clientMutationID: UUID(), fieldsJSON: "{\"amount\":\"30.0000\"}", fieldHlcsJSON: nil,
            tombstoneReason: nil, author: GroupsOutboxMirror.author, createdAt: .now)
    }

    private func liveRows(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.rejectedReason == nil }))
    }

    /// Control positivo: con todo traducido, `true` y la fila en el outbox.
    @Test func drainOnce_translatesEverything_returnsTrue() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(mirrorDir: mirrorDir)
        try seedBackendExpense(context)

        #expect(client.drainOnce(context: context))
        #expect(try liveRows(context) == 1)
    }

    /// **El canario del ticket, en el reloj.** Con el reloj lógico una hora por delante, `clock.send` lanza al traducir
    /// y la vuelta corta en la frontera de la transacción: el gasto NO llega al outbox. Antes el llamador leía un
    /// outbox a 0 y borraba; ahora la vuelta dice `false`. Y el gasto sigue en el History: un cliente sano lo captura
    /// después, que es lo que el borrado se llevaba.
    @Test func drainOnce_whenTheClockCutsTheTranslation_returnsFalse_andTheExpenseStaysInTheHistory() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(mirrorDir: mirrorDir)
        let cursor = try client.loadOrCreateCursor(context)
        let ahead = try HLC(physicalMs: Int64((Date().timeIntervalSince1970 + 3600) * 1000),
                            counter: 0, nodeID: NodeID.generate())
        cursor.clockLatestHLC = ahead.description
        try context.save()
        try seedBackendExpense(context)

        #expect(!client.drainOnce(context: context), "la traducción se cortó: la captura no terminó")
        #expect(try liveRows(context) == 0, "control: el gasto no llegó al outbox (es el recuento que mentía)")

        cursor.clockLatestHLC = nil
        try context.save()
        let healthy = makeClient(mirrorDir: mirrorDir)
        #expect(healthy.drainOnce(context: context))
        #expect(try liveRows(context) == 1, "el gasto seguía en el History: es lo que el borrado se habría llevado")
    }

    /// Un `save` del drain que no puede escribir es captura sin terminar. Es el `catch` general de `performDrain`, el
    /// mismo por el que salen `fetchHistory` y `buildLookups`.
    @Test func drainOnce_whenTheSaveThrows_returnsFalse() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(mirrorDir: mirrorDir)
        try seedBackendExpense(context)
        client._testThrowOnDrainSave = true

        #expect(!client.drainOnce(context: context))
        context.rollback()
    }

    /// **El gemelo del espejo.** Un cambio que solo vive en el espejo —un kill entre el espejo y el `save`— entra al
    /// outbox con la captura previa, aunque `startIfEligible` no haya corrido (flag compuesto apagado). Después ya no
    /// queda nada del espejo fuera del outbox.
    @Test func captureForExit_rehydratesTheMirror_intoTheOutbox() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(mirrorDir: mirrorDir)
        try GroupsOutboxMirror(directoryURL: mirrorDir).write(mirrorEntry(user: "sub-a"))
        #expect(client.mirrorEntriesMissingFromOutbox(context: context, scope: .sessionOwner) == 1,
                "control: el cambio solo vive en el espejo")
        #expect(try liveRows(context) == 0, "control: el outbox no lo ve — el recuento de antes daba 0")

        #expect(client.captureLocalWritesForExit(context: context))

        #expect(try liveRows(context) == 1, "la captura lo rehidrató: ahora lo sube el push-all")
        #expect(client.mirrorEntriesMissingFromOutbox(context: context, scope: .sessionOwner) == 0)
    }

    /// La captura devuelve lo que devuelve el drain: con el reloj por delante, `false` aunque la rehidratación fuera bien.
    @Test func captureForExit_returnsTheDrainVerdict() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let client = makeClient(mirrorDir: mirrorDir)
        let cursor = try client.loadOrCreateCursor(context)
        cursor.clockLatestHLC = try HLC(physicalMs: Int64((Date().timeIntervalSince1970 + 3600) * 1000),
                                        counter: 0, nodeID: NodeID.generate()).description
        try context.save()
        try seedBackendExpense(context)

        #expect(!client.captureLocalWritesForExit(context: context))
    }

    /// El alcance del recuento del espejo, celda a celda. Cuentan las entradas SIN fila; no cuentan las que tienen fila
    /// (viva o dead-letter), ni los tombstones de `split_groups` (veneno que el rehydrate nunca re-inserta), ni un `op`
    /// ilegible. Con sesión, solo las suyas; sin sesión, ninguna para el push-all y todas para el borrado.
    @Test func mirrorCount_respectsItsScope() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let mirror = GroupsOutboxMirror(directoryURL: mirrorDir)

        // sub-a: una sin fila, una con fila viva, una con fila dead-letter, un veneno y un `op` ilegible.
        try mirror.write(mirrorEntry(user: "sub-a", hlc: "2026-09-26T00:00:00.000Z-0001-00000000000000aa"))
        let withRow = mirrorEntry(user: "sub-a", hlc: "2026-09-26T00:00:00.000Z-0002-00000000000000aa")
        let withDeadLetter = mirrorEntry(user: "sub-a", hlc: "2026-09-26T00:00:00.000Z-0003-00000000000000aa")
        try mirror.write(withRow)
        try mirror.write(withDeadLetter)
        try mirror.write(mirrorEntry(user: "sub-a", hlc: "2026-09-26T00:00:00.000Z-0004-00000000000000aa",
                                     entity: GroupSyncEntityType.splitGroup, op: SyncOutboxOp.tombstone.rawValue))
        try mirror.write(mirrorEntry(user: "sub-a", hlc: "2026-09-26T00:00:00.000Z-0005-00000000000000aa",
                                     op: "rename"))
        // sub-b: dos sin fila.
        try mirror.write(mirrorEntry(user: "sub-b", hlc: "2026-09-26T00:00:00.000Z-0006-00000000000000aa"))
        try mirror.write(mirrorEntry(user: "sub-b", hlc: "2026-09-26T00:00:00.000Z-0007-00000000000000aa"))
        for (entry, rejected) in [(withRow, nil as String?), (withDeadLetter, "upstream_400:x")] {
            context.insert(GroupSyncOutbox(
                syncID: entry.syncID, groupID: entry.groupID, entityType: entry.entityType, op: .upsert,
                hlc: entry.hlc, fieldsJSON: entry.fieldsJSON, author: "", rejectedReason: rejected))
        }
        try context.save()

        func count(_ owner: String?, _ scope: GroupsSyncClient.MirrorPendingScope) -> Int {
            GroupsSyncClient.mirrorEntriesMissingFromOutbox(mirror: mirror, ownerID: owner, scope: scope, context: context)
        }
        #expect(count("sub-a", .sessionOwner) == 1)
        #expect(count("sub-a", .sessionOwnerOrEveryoneWhenSignedOut) == 1, "con sesión, las de otra identidad no cuentan")
        #expect(count(nil, .sessionOwner) == 0, "sin sesión, el push-all no puede subir ninguna")
        #expect(count(nil, .sessionOwnerOrEveryoneWhenSignedOut) == 3, "sin sesión, el borrado cuenta las de todos")
        #expect(count("sub-b", .sessionOwner) == 2)
        #expect(GroupsSyncClient.mirrorEntriesMissingFromOutbox(
            mirror: nil, ownerID: nil, scope: .sessionOwnerOrEveryoneWhenSignedOut, context: context) == 0,
                "sin App Group no hay espejo que contar")
    }
}

// MARK: - 2. El veredicto puro

@Suite("Grupos · el veredicto de la captura previa a una salida")
struct GroupsCaptureVerdictTests {

    /// Con filas vivas, a subir: el recuento manda y el bucle las empuja, termine o no la captura.
    @Test func withLiveRows_itIsForThePushToDecide() {
        for completed in [true, false] {
            for mirror in [0, 2, Int.max] {
                #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
                    captureCompleted: completed, livePendingCount: 1, unrehydratedMirrorCount: mirror) == nil)
            }
        }
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: true, livePendingCount: Int.max, unrehydratedMirrorCount: 0) == nil,
                "un outbox que no se pudo contar no se da por vacío")
    }

    /// `.drained` SOLO con la captura completa, el outbox a 0 y el espejo sin nada fuera.
    @Test func drainedOnlyWhenNothingIsLeftAnywhere() {
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: true, livePendingCount: 0, unrehydratedMirrorCount: 0) == .drained)
    }

    /// **El canario del ticket.** Outbox a 0 con un drain que no terminó: antes `.drained`, ahora bloquea sin cifra.
    @Test func anUnfinishedCapture_blocksWithoutACount() {
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: false, livePendingCount: 0, unrehydratedMirrorCount: 0)
                == .blocked(pendingCount: Int.max, reason: .uploadRetryLater))
    }

    /// **La salida «perderlos» no puede llevarse lo que el aviso no enseñó.** Tras volver a capturar, el bloqueo por
    /// attest solo sigue siendo attest —el único que un caller deja seguir con la pérdida aceptada— si no queda nada
    /// fuera del outbox. La cifra es la del outbox recapturado.
    @Test func attestBlock_staysAttestOnlyWhenNothingIsLeftOutside() {
        #expect(CloudSignOutFlowLogic.attestBlockAfterRecapture(
            captureCompleted: true, livePendingCount: 2, unrehydratedMirrorCount: 0)
                == .blocked(pendingCount: 2, reason: .attestUnavailable))
        #expect(CloudSignOutFlowLogic.attestBlockAfterRecapture(
            captureCompleted: false, livePendingCount: 2, unrehydratedMirrorCount: 0)
                == .blocked(pendingCount: 2, reason: .uploadRetryLater))
        #expect(CloudSignOutFlowLogic.attestBlockAfterRecapture(
            captureCompleted: true, livePendingCount: 3, unrehydratedMirrorCount: 1)
                == .blocked(pendingCount: 3, reason: .uploadRetryLater))
    }

    /// El motivo del residuo de «Empezar de cero»: solo entradas que esta sesión no puede subir ⇒ volver a entrar; con
    /// filas vivas o entradas de la sesión, otro intento.
    @Test func freshStartResidual_namesWhatCuresIt() {
        #expect(CloudSignOutFlowLogic.freshStartResidualReason(livePendingCount: 0, sessionMirrorCount: 0) == .sessionExpired)
        #expect(CloudSignOutFlowLogic.freshStartResidualReason(livePendingCount: 1, sessionMirrorCount: 0) == .uploadRetryLater)
        #expect(CloudSignOutFlowLogic.freshStartResidualReason(livePendingCount: 0, sessionMirrorCount: 2) == .uploadRetryLater)
    }

    /// El gemelo: entradas del espejo sin fila bloquean, con su cifra si la hay.
    @Test func mirrorEntriesOutsideTheOutbox_block() {
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: true, livePendingCount: 0, unrehydratedMirrorCount: 2)
                == .blocked(pendingCount: 2, reason: .uploadRetryLater))
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: false, livePendingCount: 0, unrehydratedMirrorCount: 3)
                == .blocked(pendingCount: 3, reason: .uploadRetryLater))
        #expect(CloudSignOutFlowLogic.groupsCaptureVerdict(
            captureCompleted: true, livePendingCount: 0, unrehydratedMirrorCount: Int.max)
                == .blocked(pendingCount: Int.max, reason: .uploadRetryLater))
    }
}

// MARK: - 3. Los gestos

@MainActor
@Suite("Grupos · los gestos que borran no dan por vacío un drain a medias", .serialized, .wipeAppGroupMirrorIsolated)
struct GroupsExitGesturesCaptureTests {

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    /// Guarda los alcances que el gesto pregunta, para fijar que cada uno pide el suyo.
    private final class Scopes { var asked: [GroupsSyncClient.MirrorPendingScope] = [] }

    private func witness(capture: Bool, mirror: @escaping (GroupsSyncClient.MirrorPendingScope) -> Int = { _ in 0 },
                         scopes: Scopes? = nil) -> CloudSessionSignOut.GroupsExitWitness {
        CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in capture },
            mirrorPending: { _, scope in
                scopes?.asked.append(scope)
                return mirror(scope)
            })
    }

    /// **El canario del ticket en el alert del shell.** Outbox vacío y un drain que no terminó: antes el borrado seguía
    /// en el mismo tap; ahora pasa por la subida, que lo dice.
    @Test func settledEmpty_isFalse_whenTheCaptureDidNotFinish() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        #expect(CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: witness(capture: true)),
                "control: con la captura completa, vacío")
        #expect(!CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: witness(capture: false)))
    }

    /// El gemelo en el alert: entradas del espejo sin fila, con el alcance del BORRADO (que purga el espejo entero).
    @Test func settledEmpty_isFalse_withMirrorEntriesOutsideTheOutbox_askingTheWipeScope() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let scopes = Scopes()
        #expect(!CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(
            context: context, witness: witness(capture: true, mirror: { _ in 2 }, scopes: scopes)))
        #expect(scopes.asked == [.sessionOwnerOrEveryoneWhenSignedOut])
    }

    /// La subida de «Empezar de cero» con la captura a medias: bloquea con «no llegaron, inténtalo en un rato» y sin cifra,
    /// y deja el bloqueo a la vista para la pantalla. El push-all pregunta el espejo de la SESIÓN.
    @Test func freshStartDrain_blocks_whenTheCaptureDidNotFinish() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let scopes = Scopes()
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(capture: false, scopes: scopes))
        let expected = CloudSessionSignOut.FreshStartGroupsBlock(pendingCount: Int.max, reason: .uploadRetryLater)
        #expect(verdict == .blocked(expected))
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == expected)
        #expect(scopes.asked.contains(.sessionOwner), "el push-all mira lo que esta sesión puede subir")
    }

    /// **La subida solo mira el espejo de la sesión; el borrado, el de todos.** Una entrada que el push-all no ve pasaba
    /// como `.drained` y el cinturón saltaba después — en la puerta privada, con la zona de iCloud ya borrada. Ahora la
    /// subida se para con el mismo recuento que el cinturón, y con el motivo que lo cura: esas entradas solo las sube
    /// volver a entrar con su cuenta (`.sessionExpired`), no esperar.
    @Test func freshStartDrain_blocks_onMirrorEntriesOnlyTheWipeScopeSees() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let onlyTheWipeSees: (GroupsSyncClient.MirrorPendingScope) -> Int = { $0 == .sessionOwner ? 0 : 3 }
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(capture: true, mirror: onlyTheWipeSees))
        #expect(verdict == .blocked(.init(pendingCount: 3, reason: .sessionExpired)))
    }

    /// El cinturón del escritor cuenta el espejo: con el outbox a 0 y dos entradas sin fila, se niega, y el borrado del
    /// dominio no llega a `resetSyncState`, que es quien purga el espejo.
    @Test func writerBelt_countsMirrorEntries_andNeverReachesThePurge() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let twoInTheMirror = witness(capture: true, mirror: { _ in 2 })
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 2)) {
            try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: twoInTheMirror)
        }
        var purged = 0
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 2)) {
            try DataWipeService.wipeLocalGroupsDomain(
                in: context, defaults: makeIsolatedDefaults(), retireCloudSession: {},
                resetSyncState: { purged += 1 }, witness: twoInTheMirror)
        }
        #expect(purged == 0, "el espejo no se purgó: esas entradas siguen ahí")
    }

    /// Lo que enseña el bloqueo suma filas vivas y espejo; si alguna no se pudo contar, «no se pudo contar».
    @Test func pendingCount_addsLiveRowsAndMirror_andKeepsTheUnknown() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        context.insert(GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert,
                                       hlc: "hlc", fieldsJSON: "{}", author: "a", rejectedReason: nil))
        try context.save()
        #expect(CloudSessionSignOut.freshStartGroupsPendingCount(
            context: context, witness: witness(capture: true, mirror: { _ in 2 })) == 3)
        #expect(CloudSessionSignOut.freshStartGroupsPendingCount(
            context: context, witness: witness(capture: true, mirror: { _ in Int.max })) == Int.max)
        CloudSessionSignOut.shared.noteFreshStartGroupsPending(
            context: context, reason: .uploadRetryLater, witness: witness(capture: true, mirror: { _ in 2 }))
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock?.pendingCount == 3)
        try clearOutbox(context)
    }
}

// MARK: - Cableado del push-all (source-scan)

/// El push-all necesita un ciclo con red para llegar a su bucle, así que la re-captura tras vaciar el outbox se fija
/// leyendo el fuente. Sin ella, un ciclo cuyo drain no terminó dejaba el outbox a 0 y el cierre salía `.drained`.
@Suite("Grupos · el push-all vuelve a capturar antes de dar el outbox por vacío (source-scan)")
struct GroupsPushAllRecaptureWiringTests {

    private static func pushAllBody() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/CloudSessionSignOut.swift"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        let start = try #require(source.range(of: "private func pushAllPendingGroupsForSignOut("))
        let end = try #require(source.range(of: "static func awaitPersonalQuiescenceForGroupsSignOut(",
                                            range: start.upperBound..<source.endIndex))
        return String(source[start.upperBound..<end.lowerBound])
    }

    @Test func aDrainedCycle_isReCapturedBeforeReturning() throws {
        let body = try Self.pushAllBody()
        let loop = try #require(body.range(of: "for iteration in 1...maxIterations {"))
        let afterLoop = String(body[loop.upperBound...])
        let guardDrained = try #require(afterLoop.range(of: "guard verdict == .drained else {"),
                                        "el `.drained` del ciclo se devuelve sin volver a capturar")
        let recapture = try #require(afterLoop.range(of: "captureCompleted: witness.capture(context),"),
                                     "falta la re-captura tras un ciclo que vació el outbox")
        #expect(guardDrained.lowerBound < recapture.lowerBound)
        #expect(afterLoop.contains("unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner)) {\n"
                                   + "                    return settled"),
                "la re-captura decide con el espejo de la sesión y devuelve su veredicto")
        #expect(!afterLoop.contains("return verdict\n            }\n            // S1"),
                "volvió el `return verdict` directo, que da por vacío un ciclo cuyo drain no terminó")
    }

    /// El bloqueo por App Attest pasa por la re-captura antes de salir: es el único que la pérdida aceptada deja seguir.
    @Test func anAttestBlock_isReCapturedBeforeReturning() throws {
        let body = try Self.pushAllBody()
        let attest = try #require(body.range(of: "guard case .blocked(_, .attestUnavailable) = verdict else { return verdict }"),
                                  "el bloqueo por attest sale sin volver a capturar")
        let rest = String(body[attest.upperBound...])
        let capture = try #require(rest.range(of: "let recaptured = witness.capture(context)"))
        let decide = try #require(rest.range(of: "return CloudSignOutFlowLogic.attestBlockAfterRecapture(\n"
                                              + "                        captureCompleted: recaptured,"))
        #expect(capture.lowerBound < decide.lowerBound)
        #expect(rest.contains("unrehydratedMirrorCount: witness.mirrorPending(context, .sessionOwner))"))
    }
}
