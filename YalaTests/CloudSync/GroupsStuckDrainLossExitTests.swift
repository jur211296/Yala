//
//  GroupsStuckDrainLossExitTests.swift
//  YalaTests / CloudSync
//
//  Ticket `groups-drain-that-always-aborts-takes-the-loss-exit-away` (gemelo de Grupos del #358). Con el drain de Grupos que
//  no termina en ningún intento, todo intento de salir leía la captura fallida como «inténtalo en un rato»
//  (`.uploadRetryLater`), y eso le quitaba para siempre la salida «Cerrar sesión y perderlos» al teléfono sin App Attest, a
//  la sesión caducada y a los cambios de otra cuenta: esperar no cura un drain atascado.
//
//  Cuatro capas:
//   1. La sonda REAL del History (`GroupsSyncClient.uncapturedGroupsChanges`), con stores en disco: cuenta lo que el drain
//      no capturó, solo lee, y fecha cada transacción contra el registro de sesiones como el drain.
//   2. La lógica pura: los reintentos de la captura, el veredicto con la captura atascada, las dos mitades de lo que se pierde
//      y de lo aceptado.
//   3. El push-all, por la subida de «Empezar de cero», con el ciclo sustituido (`GroupsExitWitness.cycle`): los tres
//      casos que abren la salida, y los dos que no.
//   4. Cableado (source-scan): los sitios que ofrecen, aceptan y recuentan la pérdida de grupos usan las dos mitades.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1. La sonda real del History

@Suite("Grupos · la sonda del History cuenta lo que el drain no capturó, y solo lee", .serialized)
@MainActor
struct GroupsUncapturedHistoryProbeTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GSStuck-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "GSS-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "GSS-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "GSS-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    /// Sin red: ningún test de aquí empuja.
    private final class NoNetwork: SyncHTTPSession, @unchecked Sendable {
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            throw URLError(.notConnectedToInternet)
        }
    }

    private func makeClient(mirrorDir: URL, session: String? = "sub-a",
                            log: SessionSignInLog? = nil) -> GroupsSyncClient {
        GroupsSyncClient(
            tokenProvider: { "jwt" }, urlSession: NoNetwork(), sessionCheck: { false },
            currentUserIDProvider: { session },
            signInLogProvider: { log },
            outboxMirror: GroupsOutboxMirror(directoryURL: mirrorDir),
            forceRefreshTokenProvider: { nil }, canRenewSession: { false })
    }

    /// Un grupo del canal backend y `expenses` gastos, cada uno en su propio `save()`: transacciones distintas del History.
    private func seedBackendExpenses(_ context: ModelContext, count: Int) throws {
        let group = SplitGroup(name: "Viaje")
        group.cloudKitZoneID = "SplitGroup-A"
        group.isBackendGroup = true
        context.insert(group)
        try context.save()
        for index in 0..<count {
            context.insert(SplitExpense(groupZoneID: "SplitGroup-A", amount: Double(10 + index), currencyCode: "PEN",
                                        expenseDescription: "Gasto \(index)", paidByMemberID: "m1"))
            try context.save()
        }
    }

    private func liveRows(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<GroupSyncOutbox>(predicate: #Predicate { $0.rejectedReason == nil }))
    }

    /// **El canario del ticket, en la sonda.** Con el drain atascado (la traducción se corta en cada intento) nada llega al
    /// outbox, y la sonda cuenta cada cambio que se quedó en el History —más de uno—. Un drain sano los captura después, y
    /// la sonda deja de contarlos: la ventana es la del drain siguiente.
    @Test func aStuckDrain_leavesEveryChangeForTheProbe_andAHealthyDrainConsumesThem() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        let stuck = makeClient(mirrorDir: mirrorDir)
        stuck._testThrowOnClockStamp = true
        try seedBackendExpenses(context, count: 3)

        // Cada intento falla, y la sonda real lee los MISMOS cambios tras cada uno: es «el mismo cambio fallando».
        var readings: [Set<String>?] = []
        for _ in 0..<CloudSignOutFlowLogic.groupsExitCaptureAttempts {
            #expect(!stuck.captureLocalWritesForExit(context: context), "control: el drain no termina en ningún intento")
            readings.append(stuck.uncapturedGroupsChanges(context: context).map { Set($0.map(\.key)) })
        }
        #expect(CloudSignOutFlowLogic.groupsExitCapture(completed: false, failedReadings: readings) == .stuck, """
            con el drain atascado la sonda real tiene que leer las mismas claves en cada intento: \(readings)
            """)
        #expect(try liveRows(context) == 0, "control: nada llegó al outbox")
        let uncaptured = try #require(stuck.uncapturedGroupsChanges(context: context))
        #expect(uncaptured.count >= 3, """
            la sonda tiene que contar los tres gastos que el drain no capturó (\(uncaptured.count)): son lo que el borrado \
            se llevaría
            """)
        #expect(Set(uncaptured.map(\.key)).count == uncaptured.count, "una clave por cambio")

        let healthy = makeClient(mirrorDir: mirrorDir)
        #expect(healthy.captureLocalWritesForExit(context: context))
        #expect(try liveRows(context) >= 3, "el drain sano capturó los gastos")
        #expect(healthy.uncapturedGroupsChanges(context: context) == [], "lo capturado sale de la ventana")
    }

    /// **Solo lee**: sobre un store sin cursor, la sonda no lo crea (el drain sí: `loadOrCreateCursor`).
    @Test func theProbe_doesNotCreateTheCursor() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        try seedBackendExpenses(context, count: 2)

        let changes = makeClient(mirrorDir: mirrorDir).uncapturedGroupsChanges(context: context)

        #expect((changes?.count ?? 0) >= 3, "control: sin cursor, la ventana es el History entero")
        #expect(try context.fetchCount(FetchDescriptor<GroupSyncCursor>()) == 0, "la sonda escribió el cursor")
        #expect(!context.hasChanges)
    }

    /// **El dueño, como el drain**: cada transacción se fecha contra el registro de sesiones. Apuntado por otra cuenta, la
    /// sesión de ahora lo retiene; apuntado por ella, no.
    @Test func theProbe_datesEachTransactionAgainstTheSignInLog() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = freshDir(); defer { cleanup(mirrorDir) }
        let context = try makeContext(dir)
        try seedBackendExpenses(context, count: 2)
        let byA = SessionSignInLog(entries: [.init(sub: "sub-a", at: .distantPast)])

        let seenByB = try #require(makeClient(mirrorDir: mirrorDir, session: "sub-b", log: byA)
            .uncapturedGroupsChanges(context: context))
        #expect(!seenByB.isEmpty)
        #expect(seenByB.allSatisfy { $0.heldForAnotherAccount }, "lo apuntó sub-a: la sesión de sub-b no lo sube")
        #expect(seenByB.allSatisfy { $0.provenAnotherAccount }, "el registro nombra a sub-a: otra cuenta probada")

        let seenByA = try #require(makeClient(mirrorDir: mirrorDir, session: "sub-a", log: byA)
            .uncapturedGroupsChanges(context: context))
        #expect(seenByA.allSatisfy { !$0.heldForAnotherAccount }, "lo apuntó la propia sesión")
        #expect(seenByA.allSatisfy { !$0.provenAnotherAccount })

        let signedOut = try #require(makeClient(mirrorDir: mirrorDir, session: nil, log: byA)
            .uncapturedGroupsChanges(context: context))
        #expect(signedOut.allSatisfy { !$0.heldForAnotherAccount }, "sin sesión no hay otra cuenta: hay sesión caducada")
        #expect(signedOut.allSatisfy { !$0.provenAnotherAccount })

        // **Sin dueño en el registro** (lo apuntado antes de su primera entrada): retenido, pero NO otra cuenta probada. Es el
        // ruido que, mezclado con cambios propios, no puede abrir la salida que pierde cambios (2026-10-05).
        let later = SessionSignInLog(entries: [.init(sub: "sub-a", at: .distantFuture)])
        let unowned = try #require(makeClient(mirrorDir: mirrorDir, session: "sub-b", log: later)
            .uncapturedGroupsChanges(context: context))
        #expect(!unowned.isEmpty)
        #expect(unowned.allSatisfy { $0.heldForAnotherAccount }, "sin dueño probado: retenido, como el drain")
        #expect(unowned.allSatisfy { !$0.provenAnotherAccount }, "sin dueño no es otra cuenta probada")
    }
}

// MARK: - 2. La lógica pura

@Suite("Grupos · la captura atascada conserva la salida, y lo pasajero no la abre")
struct GroupsStuckCaptureLogicTests {

    typealias L = CloudSignOutFlowLogic

    /// **El timing de la decisión de Jürgen** (2026-10-05): reintentos espaciados con espera creciente durante varios segundos.
    @Test func retryDelays_growAndSpanSeveralSeconds() {
        let delays = L.groupsExitCaptureRetryDelays
        #expect(delays.count >= 3, "pocos reintentos no le dan su ocasión a un fallo pasajero")
        #expect(zip(delays, delays.dropFirst()).allSatisfy { $0 < $1 }, "las esperas tienen que crecer: \(delays)")
        let total = delays.reduce(Duration.zero, +)
        #expect(total >= .seconds(5), "«durante varios segundos»: \(total)")
        #expect(total <= .seconds(10), "la persona está mirando «Guardando…»: \(total)")
        #expect(L.groupsExitCaptureAttempts == delays.count + 1, "un intento al momento y uno tras cada espera")
    }

    /// **Atascada solo con el MISMO cambio fallando en todos los intentos**, con el History leído en cada uno.
    @Test func exitCapture_table() {
        let n = L.groupsExitCaptureAttempts
        let same = Array(repeating: Set(["h1", "h2"]) as Set<String>?, count: n)
        #expect(L.groupsExitCapture(completed: false, failedReadings: same) == .stuck)
        // El drain avanza pero un cambio se queda siempre: sigue atascado por ese.
        var shrinking: [Set<String>?] = (0..<n).map { i in Set(["h1", "x\(i)"]) }
        #expect(L.groupsExitCapture(completed: false, failedReadings: shrinking) == .stuck)
        #expect(L.groupsPersistentlyUncaptured(shrinking) == ["h1"])
        // Lo que queda fuera cambia de un intento a otro: no es el mismo cambio fallando.
        let moving: [Set<String>?] = (0..<n).map { Set(["h\($0)"]) }
        #expect(L.groupsExitCapture(completed: false, failedReadings: moving) == .unfinished, "pasajero: el drain avanzaba")
        // Un History que no se deja leer en algún intento: sin cifra exacta no se da por atascada.
        shrinking[n / 2] = nil
        #expect(L.groupsExitCapture(completed: false, failedReadings: shrinking) == .unfinished)
        // Reintentos cortados.
        #expect(L.groupsExitCapture(completed: false, failedReadings: Array(same.dropLast())) == .unfinished,
                "sin todos los intentos no se prueba nada")
        #expect(L.groupsExitCapture(completed: false, failedReadings: []) == .unfinished)
        // Termina, o el fallo no escondía nada.
        #expect(L.groupsExitCapture(completed: true, failedReadings: Array(same.dropLast())) == .completed)
        #expect(L.groupsExitCapture(completed: false, failedReadings: [["h1"], []]) == .completed,
                "el History vacío: el fallo no escondía ningún cambio")
    }

    /// Con el atasco ya probado en el gesto, basta un intento con alguno de esos mismos cambios fuera.
    @Test func stillStuck_needsOneOfTheSameChanges() {
        #expect(L.groupsCaptureStillStuck(provenStuck: ["h1"], reading: ["h1", "h9"]))
        #expect(!L.groupsCaptureStillStuck(provenStuck: ["h1"], reading: ["h9"]), "otro cambio: vuelven los reintentos")
        #expect(!L.groupsCaptureStillStuck(provenStuck: ["h1"], reading: nil))
        #expect(!L.groupsCaptureStillStuck(provenStuck: [], reading: ["h1"]), "sin atasco probado, nada que confirmar")
    }

    /// **Los tres casos del ticket con la captura atascada**: el motivo que abre la salida se conserva.
    @Test(arguments: [L.BlockReason.attestUnavailable, .sessionExpired, .groupsChangesFromAnotherAccount])
    func stuckCapture_keepsTheReasonThatOpensTheExit(reason: L.BlockReason) {
        #expect(L.lossBlockAfterRecapture(reason: reason, capture: .stuck, livePendingCount: 2, unrehydratedMirrorCount: 0)
                == .blocked(pendingCount: 2, reason: reason))
        #expect(L.lossBlockAfterRecapture(reason: reason, capture: .stuck, livePendingCount: 2, unrehydratedMirrorCount: 3)
                == .blocked(pendingCount: 2, reason: reason), "el espejo lo cuenta la oferta por su `clientMutationID`")
        // Lo pasajero, sin salida.
        #expect(L.lossBlockAfterRecapture(reason: reason, capture: .unfinished, livePendingCount: 2,
                                          unrehydratedMirrorCount: 0) == .blocked(pendingCount: 2, reason: .uploadRetryLater))
        #expect(L.lossBlockAfterRecapture(reason: reason, capture: .completed, livePendingCount: 2,
                                          unrehydratedMirrorCount: 1) == .blocked(pendingCount: 2, reason: .uploadRetryLater))
    }

    /// El ciclo vació lo que esta sesión sube y la captura sigue atascada: decide el ciclo, y si no, quién lo apuntó.
    @Test func stuckCaptureVerdict_table() {
        // El ciclo paró por un motivo que abre la salida: ese motivo.
        #expect(L.stuckCaptureVerdict(cycleReason: .sessionExpired, livePendingCount: 0,
                                      heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 0, reason: .sessionExpired))
        #expect(L.stuckCaptureVerdict(cycleReason: .attestUnavailable, livePendingCount: 2,
                                      heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: nil)
                == .blocked(pendingCount: 2, reason: .attestUnavailable))
        // Lo de fuera es de otra cuenta: su motivo, con su salida.
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 1, heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: true)
                == .blocked(pendingCount: 1, reason: .groupsChangesFromAnotherAccount))
        #expect(L.stuckCaptureVerdict(cycleReason: .uploadRetryLater, livePendingCount: 0,
                                      heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: true)
                == .blocked(pendingCount: 0, reason: .groupsChangesFromAnotherAccount),
                "la red caída no sube lo de otra cuenta tampoco")
        // Algo es de esta sesión, o no se sabe: sin salida, y con el motivo del drain que no termina (opción A de Jürgen,
        // 2026-10-05). Hasta ese día salía `.uploadRetryLater`, «inténtalo en un rato», y esperar no lo cura.
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: Int.max, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: nil)
                == .blocked(pendingCount: Int.max, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: .channelPaused, livePendingCount: 3,
                                      heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 3, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: .uploadRetryLater, livePendingCount: 0,
                                      heldRowsForAnotherAccount: 0, uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: Int.max, reason: .groupsCaptureUnfinished),
                "con el drain atascado, que la red vuelva no sube lo que nunca llega al outbox")
    }

    /// Lo que se pierde, en dos mitades: la cifra las suma, y una que no se pudo leer es «no se pudo contar».
    @Test func groupsLoss_countsBothHalves() {
        let rows: Set<UUID> = [UUID(), UUID()]
        #expect(L.GroupsLoss(rows: rows, uncaptured: ["h1", "h2", "h3"]).count == 5)
        #expect(L.GroupsLoss(rows: rows, uncaptured: []).count == 2)
        #expect(L.GroupsLoss(rows: nil, uncaptured: ["h1"]).count == Int.max)
        #expect(L.GroupsLoss(rows: rows, uncaptured: nil).count == Int.max)
        #expect(L.GroupsLoss(rows: [], uncaptured: []).isEmpty)
        #expect(!L.GroupsLoss(rows: [], uncaptured: ["h1"]).isEmpty, "solo el History también se pierde")
        #expect(!L.GroupsLoss(rows: [], uncaptured: nil).isEmpty)
    }

    /// Lo aceptado cubre cada mitad por separado; una aceptación sobre una captura completa no lee el History.
    @Test func causedAcceptance_coversTheHistoryHalfByKey() {
        let row = UUID()
        let accepted = L.CausedLossAcceptance(
            offer: L.GroupsLoss(rows: [row], uncaptured: ["h1", "h2"]), cause: .attestUnavailable)
        #expect(accepted.rows == .rows([row]))
        #expect(accepted.readsUncaptured)
        #expect(accepted.coversUncaptured(["h1", "h2"]))
        #expect(accepted.coversUncaptured([]))
        #expect(!accepted.coversUncaptured(["h1", "h3"]), "un cambio que el aviso no enseñó")
        #expect(!accepted.coversUncaptured(nil), "un History que no se deja leer no lo cubre una cifra")

        let settled = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [row], uncaptured: []), cause: .noSession)
        #expect(!settled.readsUncaptured, "con la captura completa el History no se vuelve a leer")
        #expect(L.groupsResidualUncapturedAllowsSignOut(now: ["h9"], acceptance: settled))
        #expect(L.groupsResidualUncapturedAllowsSignOut(now: ["h9"], acceptance: nil))
        #expect(!L.groupsResidualUncapturedAllowsSignOut(now: ["h1", "h9"], acceptance: accepted))
        #expect(L.groupsResidualUncapturedAllowsSignOut(now: ["h1"], acceptance: accepted))

        let uncounted = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: nil, uncaptured: nil), cause: .otherAccount)
        #expect(uncounted.rows == .uncounted)
        // Hasta el 2026-10-05 «aceptado sin cifra: cubre cualquiera»; desde la decisión A de Jürgen
        // (`stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice`) solo cubre que no quede nada.
        #expect(!uncounted.coversUncaptured(["h7"]), "un cambio que ningún aviso contó no se pierde por una cifra que faltó")
        #expect(uncounted.coversUncaptured([]))
    }

    /// Seguir con lo aceptado tras volver a subir exige la causa, las filas y el History.
    @Test func acceptanceContinues_needsCauseRowsAndHistory() {
        let row = UUID()
        let accepted = L.CausedLossAcceptance(
            offer: L.GroupsLoss(rows: [row], uncaptured: ["h1"]), cause: .attestUnavailable)
        #expect(L.groupsLossAcceptanceContinues(accepted, reason: .attestUnavailable, pendingRows: [row],
                                                uncaptured: ["h1"]))
        #expect(!L.groupsLossAcceptanceContinues(accepted, reason: .attestUnavailable, pendingRows: [row],
                                                 uncaptured: ["h1", "h2"]))
        #expect(!L.groupsLossAcceptanceContinues(accepted, reason: .attestUnavailable, pendingRows: [row, UUID()],
                                                 uncaptured: ["h1"]))
        #expect(!L.groupsLossAcceptanceContinues(accepted, reason: .uploadRetryLater, pendingRows: [row],
                                                 uncaptured: ["h1"]), "con otra causa, otro intento lo sube")
    }

    /// El motivo de un ciclo, o `nil` si no paró: lo que la rama atascada lee del último ciclo real.
    @Test func cycleBlockReason_table() {
        #expect(L.cycleBlockReason(.completed, channelKilled: false, attestUnavailable: true, uploadFailed: true) == nil)
        #expect(L.cycleBlockReason(.coalesced, channelKilled: false, attestUnavailable: true, uploadFailed: false) == nil,
                "un ciclo coalescido no dice por qué paró nada")
        #expect(L.cycleBlockReason(.sessionExpired, channelKilled: false, attestUnavailable: false, uploadFailed: false)
                == .sessionExpired)
        #expect(L.cycleBlockReason(.transient, channelKilled: false, attestUnavailable: true, uploadFailed: false)
                == .attestUnavailable)
        #expect(L.cycleBlockReason(.transient, channelKilled: false, attestUnavailable: false, uploadFailed: true)
                == .uploadRetryLater)
        #expect(L.cycleBlockReason(.accountUnavailable, channelKilled: true, attestUnavailable: false, uploadFailed: false)
                == .channelPaused)
    }

    /// El recuento pegado al borrado solo relee el History con lo aceptado sobre una captura atascada; si no, ni lo toca.
    @Test func residualToCheck_readsOnlyWithAnAcceptanceThatCountedTheHistory() {
        var reads = 0
        let read: () -> Set<String>? = { reads += 1; return ["h9"] }
        #expect(L.groupsResidualUncapturedToCheck(acceptance: nil, read: read) == [])
        let settled = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [], uncaptured: []), cause: .noSession)
        #expect(L.groupsResidualUncapturedToCheck(acceptance: settled, read: read) == [])
        #expect(reads == 0, "sin lo aceptado sobre una captura atascada el History no se lee")
        let stuck = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [], uncaptured: ["h1"]), cause: .noSession)
        #expect(L.groupsResidualUncapturedToCheck(acceptance: stuck, read: read) == ["h9"])
        #expect(reads == 1)
        let unreadable = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [], uncaptured: nil), cause: .noSession)
        #expect(L.groupsResidualUncapturedToCheck(acceptance: unreadable, read: read) == ["h9"])
    }

    /// El canario de lo descartado suma las dos mitades.
    @Test func discardedCount_addsTheHistoryHalf() {
        let accepted = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [UUID()], uncaptured: ["h1", "h2"]),
                                              cause: .attestUnavailable)
        #expect(L.groupsDiscardedCount(rows: 1, acceptance: accepted) == 3)
        #expect(L.groupsDiscardedCount(rows: Int.max, acceptance: accepted) == Int.max)
        let unread = L.CausedLossAcceptance(offer: L.GroupsLoss(rows: [], uncaptured: nil), cause: .noSession)
        #expect(L.groupsDiscardedCount(rows: 0, acceptance: unread) == Int.max)
    }

    /// La comparación compartida, la que usan las tres aceptaciones.
    @Test func lossHalfCovers_table() {
        #expect(L.lossHalfCovers(accepted: Set<String>(), now: []))
        #expect(L.lossHalfCovers(accepted: nil as Set<String>?, now: ["a"]))
        #expect(L.lossHalfCovers(accepted: ["a"], now: Set<String>()))
        #expect(!L.lossHalfCovers(accepted: ["a"], now: nil))
        #expect(L.lossHalfCovers(accepted: nil as Set<String>?, now: nil))
        #expect(L.lossHalfCovers(accepted: ["a", "b"], now: ["b"]))
        #expect(!L.lossHalfCovers(accepted: ["a"], now: ["a", "b"]))
    }

    /// «Empezar de cero» tiene la tercera mitad: la cuenta, la compara y solo la lee si se aceptó.
    @Test func freshStartLoss_hasTheHistoryHalf() {
        let row = UUID()
        let loss = L.FreshStartGroupsLoss(rows: [row], mirrorKeys: ["m1"], uncaptured: ["h1", "h2"])
        #expect(loss.count == 4)
        #expect(loss.readsUncaptured)
        #expect(!loss.isEmpty)
        #expect(loss.covers(L.FreshStartGroupsLoss(rows: [row], mirrorKeys: ["m1"], uncaptured: ["h2"])))
        #expect(!loss.covers(L.FreshStartGroupsLoss(rows: [row], mirrorKeys: ["m1"], uncaptured: ["h3"])))
        #expect(L.FreshStartGroupsLoss(rows: [row], mirrorKeys: []).uncaptured == [], "por defecto no lee el History")
        #expect(!L.FreshStartGroupsLoss(rows: [row], mirrorKeys: []).readsUncaptured)
        #expect(L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: nil).count == Int.max)
        #expect(!L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: ["h1"]).isEmpty)
    }
}

// MARK: - 3. El push-all, por la subida de «Empezar de cero»

/// El push-all es privado y su ciclo habla con el gateway: se recorre por `drainGroupsBeforeFreshStart` con el ciclo
/// sustituido (`GroupsExitWitness.cycle`) y la captura que no termina nunca.
@MainActor
@Suite("Grupos · con el drain atascado vuelve la salida de perderlos", .serialized, .wipeAppGroupMirrorIsolated)
struct GroupsStuckDrainPushAllTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock
    private let coordinator = CloudSessionSignOut.shared

    private final class Count { var value = 0 }

    private func liveRow() -> GroupSyncOutbox {
        GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                        fieldsJSON: "{\"amount\":300}", author: "a", rejectedReason: nil)
    }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    private func reset(_ context: ModelContext) {
        _ = coordinator.groupsOutboxIsSettledEmpty(context: context, witness: .quiet)
        coordinator.exitCaptureDelayOverride = nil
    }

    /// La captura no termina en ningún intento; el History guarda `history` cambios; el ciclo devuelve `cycle`.
    private func stuckWitness(
        history: [GroupsSyncClient.UncapturedChange], cycle: CloudSessionSignOut.GroupsCycleReading,
        captures: Count = Count(), cycles: Count = Count()
    ) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in captures.value += 1; return false },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in history }
        witness.cycle = { _ in cycles.value += 1; return cycle }
        return witness
    }

    private static func reading(_ outcome: SyncCadencePolicy.CadenceOutcome,
                                attest: Bool = false) -> CloudSessionSignOut.GroupsCycleReading {
        .init(outcome: outcome, channelKilled: false, attestUnavailable: attest, uploadFailed: false)
    }

    private static func own(_ keys: [String]) -> [GroupsSyncClient.UncapturedChange] {
        keys.map { .init(key: $0, heldForAnotherAccount: false) }
    }

    private static func held(_ keys: [String]) -> [GroupsSyncClient.UncapturedChange] {
        keys.map { .init(key: $0, heldForAnotherAccount: true) }
    }

    /// **Teléfono sin App Attest con el drain atascado.** Antes: «inténtalo en un rato», sin salida, en cada intento. Ahora:
    /// el motivo del attest con la cifra de las filas MÁS lo que el drain no capturó, y la salida ofrecida.
    @Test func attestUnavailable_withAStuckDrain_offersTheLossCountingTheHistory() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        context.insert(liveRow())
        context.insert(liveRow())
        try context.save()
        let cycles = Count()
        let witness = stuckWitness(history: Self.own(["h1", "h2", "h3"]),
                                   cycle: Self.reading(.transient, attest: true), cycles: cycles)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(cycles.value == 1, "el attest se muestra al momento: un solo ciclo")
        #expect(verdict == .blocked(Block(pendingCount: 5, reason: .attestUnavailable, readsUncaptured: true, anotherAccountCount: 0)), """
            el teléfono sin App Attest con el drain atascado tiene que ver su salida, contando las dos filas y los tres \
            cambios que el drain no capturó: \(verdict)
            """)
        #expect(coordinator.acceptFreshStartGroupsLoss(), "la oferta quedó anotada")
        try clearOutbox(context)
    }

    /// **Sesión caducada con el drain atascado y el outbox a 0.** Antes el pre-check salía sin un solo ciclo, así que ni
    /// se sabía que faltaba la sesión. Ahora cicla, lee la sesión caducada y ofrece perder lo que el drain no capturó.
    @Test func sessionExpired_withAStuckDrainAndAnEmptyOutbox_cyclesAndOffersTheLoss() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let cycles = Count()
        let witness = stuckWitness(history: Self.own(["h1", "h2"]), cycle: Self.reading(.sessionExpired), cycles: cycles)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(cycles.value >= 1, "con la captura atascada el pre-check tiene que ciclar para saber la causa")
        #expect(verdict == .blocked(Block(pendingCount: 2, reason: .sessionExpired, readsUncaptured: true, anotherAccountCount: 0)), "\(verdict)")
        #expect(coordinator.acceptFreshStartGroupsLoss())
    }

    /// **Cambios de otra cuenta, solo en el History.** La sesión de ahora está viva y el ciclo va bien, pero lo que el drain
    /// no capturó lo apuntó otra cuenta: esperar no lo sube nunca. Su motivo, con su salida.
    @Test func otherAccount_withAStuckDrain_offersTheLoss() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let witness = stuckWitness(history: Self.held(["h1", "h2", "h3"]), cycle: Self.reading(.completed))

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        // Los tres cambios del History los apuntó otra cuenta: los tres son la parte de otra cuenta (2026-10-05).
        #expect(verdict == .blocked(Block(pendingCount: 3, reason: .groupsChangesFromAnotherAccount, readsUncaptured: true, anotherAccountCount: 3)), "\(verdict)")
        #expect(coordinator.acceptFreshStartGroupsLoss())
    }

    /// **Un ciclo coalescido no decide** (review adversarial del 2026-10-05): con un ciclo de la cadencia en vuelo, el primero
    /// del push-all sale `.coalesced` y no dice que falte la sesión. La rama atascada da otra vuelta y decide con el ciclo real.
    @Test func aCoalescedFirstCycle_waitsForARealOneBeforeDeciding() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let cycles = Count()
        var witness = stuckWitness(history: Self.own(["h1", "h2"]), cycle: Self.reading(.sessionExpired))
        witness.cycle = { _ in
            cycles.value += 1
            return cycles.value == 1 ? Self.reading(.coalesced) : Self.reading(.sessionExpired)
        }

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(cycles.value == 2, "el ciclo coalescido no tenía que decidir: \(cycles.value) ciclos")
        #expect(verdict == .blocked(Block(pendingCount: 2, reason: .sessionExpired, readsUncaptured: true, anotherAccountCount: 0)), "\(verdict)")
    }

    /// **Un fallo que no esconde nada no bloquea**: la captura falla en todos sus intentos, pero el History no guarda nada que
    /// el drain no capturara (un error antes del fetch, por ejemplo). Es `.completed`: el outbox vacío drena sin ciclar.
    @Test func aFailingCaptureWithNothingInTheHistory_drains() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let cycles = Count()
        let witness = stuckWitness(history: [], cycle: Self.reading(.sessionExpired), cycles: cycles)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(verdict == .drained, "\(verdict)")
        #expect(cycles.value == 0, "sin nada que subir, ni un ciclo")
    }

    /// **Lo que queda fuera cambia de un intento a otro: no es el mismo cambio fallando** (decisión de Jürgen del 2026-10-05).
    /// El drain avanza a trompicones; aunque falte App Attest, la salida del atasco no se abre y el aviso es el de siempre.
    @Test func differentChangesOnEachAttempt_neverOpenTheExit() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        context.insert(liveRow())
        context.insert(liveRow())
        try context.save()
        let reads = Count()
        var witness = stuckWitness(history: [], cycle: Self.reading(.transient, attest: true))
        witness.uncapturedChanges = { _ in reads.value += 1; return Self.own(["h\(reads.value)"]) }

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(verdict == .blocked(Block(pendingCount: 2, reason: .uploadRetryLater, readsUncaptured: false, anotherAccountCount: 0)), "\(verdict)")
        #expect(!coordinator.acceptFreshStartGroupsLoss(), "sin el mismo cambio fallando no hay salida")
        try clearOutbox(context)
    }

    /// **Sin poder leer el History no hay cifra exacta, y sin cifra exacta no hay salida del atasco.**
    @Test func anUnreadableHistory_neverOpensTheExit() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        context.insert(liveRow())
        try context.save()
        var witness = stuckWitness(history: [], cycle: Self.reading(.transient, attest: true))
        witness.uncapturedChanges = { _ in nil }

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(verdict == .blocked(Block(pendingCount: 1, reason: .uploadRetryLater, readsUncaptured: false, anotherAccountCount: 0)), "\(verdict)")
        #expect(!coordinator.acceptFreshStartGroupsLoss())
        try clearOutbox(context)
    }

    /// **Un fallo pasajero que se recupera dentro de los reintentos nunca abre la salida**: la captura falla dos veces y
    /// termina a la tercera, sin nada pendiente; el gesto sigue sin un solo ciclo y sin oferta.
    @Test func aTransientFailureThatRecoversWithinTheRetries_drainsWithoutTheExit() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let captures = Count()
        let cycles = Count()
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in captures.value += 1; return captures.value >= 3 },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in Self.own(["h1"]) }
        witness.cycle = { _ in cycles.value += 1; return Self.reading(.transient, attest: true) }

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(captures.value == 3, "el alert falla una vez, el push-all falla otra y termina a la tercera")
        #expect(verdict == .drained, "\(verdict)")
        #expect(cycles.value == 0)
        #expect(!coordinator.acceptFreshStartGroupsLoss())
    }

    /// **Con algo de esta sesión fuera, sin salida** (decisión A de Jürgen), **y con su propio motivo** (opción A del
    /// 2026-10-05, ticket `groups-stuck-drain-on-a-healthy-phone-says-try-again-later`): con attest y sesión buenos lo único
    /// que impide subir es este teléfono. Hasta ese día salía «inténtalo en un rato», y esperar no lo cura.
    @Test func ownChanges_withAHealthyChannel_sayTheDrainIsStuckWithoutTheExit() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let mixed = Self.held(["h1"]) + Self.own(["h2"])
        let witness = stuckWitness(history: mixed, cycle: Self.reading(.completed))

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(verdict == .blocked(Block(pendingCount: Int.max, reason: .groupsCaptureUnfinished, readsUncaptured: false, anotherAccountCount: 0)), "\(verdict)")
        #expect(!coordinator.acceptFreshStartGroupsLoss(), "sin oferta")
        if case .blocked(let block) = verdict {
            #expect(!block.offersLossExit, "«Empezar de cero» no ofrece perderlos: decisión A")
            #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true).hasSuffix(L10n.Groups.Errors.captureUnfinished))
        }
    }

    /// **Lo pasajero que se cura dentro del gesto**: la captura falla una vez y termina en el intento siguiente. Con el
    /// attest, la salida sale con la cifra EXACTA de filas y el History no se lee.
    @Test func aCaptureThatHealsOnTheNextLap_offersOnlyTheRows() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        context.insert(liveRow())
        context.insert(liveRow())
        try context.save()
        let captures = Count()
        let historyReads = Count()
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in captures.value += 1; return captures.value % 2 == 0 },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in historyReads.value += 1; return Self.own(["h1"]) }
        witness.cycle = { _ in Self.reading(.transient, attest: true) }

        let verdict = await coordinator.drainGroupsBeforeFreshStart(context: context, witness: witness)

        #expect(verdict == .blocked(Block(pendingCount: 2, reason: .attestUnavailable, readsUncaptured: false, anotherAccountCount: 0)), "\(verdict)")
        #expect(historyReads.value == 2, "solo tras los dos intentos fallidos; con la captura completa la oferta no lo lee")
        try clearOutbox(context)
    }
}

// MARK: - 4. Cableado

/// El arreglo vive en varios sitios del coordinador que no se pueden recorrer todos sin un cierre en la nube o en el
/// «equipo» (necesitan sesión y red). Esto fija que cada uno use las dos mitades.
@Suite("Grupos · las ofertas, lo aceptado y los recuentos finales usan las dos mitades (source-scan)")
struct GroupsStuckDrainWiringTests {

    private static func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(
            "Yala/Services/CloudSync/CloudSessionSignOut.swift"), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// Las tres ofertas de grupos (celda C, `pushGroupsForSignOut` y el paso 2 de la nube) salen de `groupsLoss`.
    @Test func everyGroupsOffer_isBuiltFromTheTwoHalves() throws {
        let code = try Self.source()
        #expect(Self.count("GroupsLossOffer(resume:", in: code) == 3, "apareció o se fue una oferta de grupos")
        #expect(Self.count("GroupsLossOffer(resume: lossExit, loss: loss, cause:", in: code)
                + Self.count("GroupsLossOffer(resume: .cloud, loss: offerLoss, cause:", in: code) == 3)
        #expect(Self.count("let loss = groupsLoss(context: context)", in: code) == 2)
        #expect(Self.count("let offerLoss = groupsLoss(context: context)", in: code) == 1)
        #expect(!code.contains("rows: groupsLossRowIDs(context: context), cause:"), "volvió una oferta solo con las filas")
    }

    /// Los dos sitios que retoman con lo aceptado comparan las dos mitades, y la celda C también.
    @Test func everyAcceptanceCheck_coversTheHistory() throws {
        let code = try Self.source()
        #expect(Self.count("CloudSignOutFlowLogic.groupsLossAcceptanceContinues(", in: code) == 2)
        #expect(code.contains("accepted.coversUncaptured(loss.uncaptured)"), "la celda C no compara el History aceptado")
        #expect(!code.contains("CloudSignOutFlowLogic.continuesAfterBlockedUpload("),
                "un sitio de grupos volvió a comparar solo las filas")
    }

    /// Los dos recuentos finales (D/F en `finalizeSessionExit` y el paso 4 de la nube) releen el History aceptado.
    @Test func bothFinalRecounts_rereadTheAcceptedHistory() throws {
        let code = try Self.source()
        #expect(Self.count("CloudSignOutFlowLogic.groupsResidualUncapturedAllowsSignOut(", in: code) == 2)
        #expect(Self.count("now: groupsResidualUncaptured(context: context), acceptance: acceptedGroupsLoss)", in: code) == 2)
    }

    /// **Cada intento tras una espera vuelve a mirar la quiescencia, y las esperas son las de la decisión** (review adversarial
    /// del 2026-10-05, lente 2; decisión de Jürgen del mismo día): la captura es un `save()` del contexto compartido, y
    /// guardar con un import a medio asentar es un `_assertionFailure` sin `catch`. Las esperas salen de
    /// `groupsExitCaptureRetryDelays`, y el seam de los tests solo cambia su duración, no cuántas hay.
    @Test func everyRetry_waitsTheNamedDelays_andRechecksTheQuiescence() throws {
        let code = try Self.source()
        let start = try #require(code.range(of: "func captureGroupsForExit(context: ModelContext, witness: GroupsExitWitness) async"))
        let body = String(code[start.upperBound...].prefix(2500))
        #expect(body.contains("let delays = exitCaptureRetryDelays"))
        let sleep = try #require(body.range(of: "try await Task.sleep(for: delays[attempt - 1])"))
        let check = try #require(body.range(of: "guard Self.personalSaveIsSafeNow() else { break }"))
        let capture = try #require(body.range(of: "if witness.capture(context) {"))
        #expect(sleep.lowerBound < check.lowerBound && check.lowerBound < capture.lowerBound,
                "el orden es esperar, mirar la quiescencia y capturar")
        let delaysStart = try #require(code.range(of: "private var exitCaptureRetryDelays: [Duration] {"))
        let delaysBody = String(code[delaysStart.upperBound...].prefix(300))
        #expect(delaysBody.contains("let production = CloudSignOutFlowLogic.groupsExitCaptureRetryDelays"))
        #expect(delaysBody.contains("return production.map { _ in exitCaptureDelayOverride }"),
                "el seam de los tests tiene que conservar el número de intentos")
        let awaitStart = try #require(code.range(of: "static func awaitPersonalQuiescenceForGroupsSignOut("))
        #expect(code[awaitStart.upperBound...].prefix(400).contains("func safe() -> Bool { personalSaveIsSafeNow() }"),
                "la espera y los reintentos miran dos predicados distintos")
    }

    /// Toda captura de una salida da sus reintentos: la única captura de una sola vez es el pre-check síncrono del alert.
    @Test func everyExitCapture_takesItsLaps() throws {
        let code = try Self.source()
        #expect(Self.count("captureGroupsForExit(context: context, witness:", in: code) >= 5)
        #expect(Self.count("witness.capture(context)", in: code) == 2,
                "dentro de `captureGroupsForExit` y en `groupsOutboxIsSettledEmpty`; ninguna más")
        #expect(!code.contains("exitWitness.capture(context)"))
    }
}

// MARK: - 5. El drain atascado en un teléfono sano tiene su motivo y su texto

/// Ticket `groups-stuck-drain-on-a-healthy-phone-says-try-again-later` (opción A de Jürgen, 2026-10-05). Con el drain de
/// Grupos atascado, App Attest, sesión y cambios propios, los tres gestos decían «no llegaron al servidor… inténtalo de nuevo
/// en un rato» (`.uploadRetryLater`), y esperar no lo cura. Ahora es `.groupsCaptureUnfinished`, el gemelo de
/// `.personalCaptureUnfinished` dicho de tus grupos, sin salida que los pierda.
@MainActor
@Suite("Grupos · el drain atascado en un teléfono sano dice lo que pasa, sin prometer que esperar lo cura")
struct GroupsStuckDrainHealthyPhoneCopyTests {

    private typealias L = CloudSignOutFlowLogic

    /// El texto exacto que eligió Jürgen, en español.
    private static let jurgen = "Algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. "
        + "Siguen guardados en este teléfono y no se pierden. Cierra y vuelve a abrir Yala; si sigue pasando, actualízala."

    private static let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                                  "pt", "pt-BR", "pt-PT", "zh-Hans"]

    /// El valor de `key` en el `.strings` de `locale`, leído del fichero fuente.
    private static func value(_ key: String, locale: String) throws -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings"),
                              encoding: .utf8)
        let prefix = "\"\(key)\" = \""
        guard let line = text.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }) else { return nil }
        return String(line.dropFirst(prefix.count).dropLast(2))
    }

    @Test func theReason_hasItsOwnCopy_notTheFailedUploadOne() {
        #expect(SignOutBlockedCopy.message(for: .groupsCaptureUnfinished) == L10n.Groups.Errors.captureUnfinished)
        #expect(SignOutBlockedCopy.message(for: .groupsCaptureUnfinished) != L10n.Groups.Errors.uploadRetryLater)
        #expect(SignOutBlockedCopy.message(for: .groupsCaptureUnfinished) != L10n.Settings.signOutCaptureUnfinished,
                "el de tus datos no dice que son de tus grupos")
        #expect(SignOutBlockedCopy.title(for: .groupsCaptureUnfinished) == L10n.Settings.signOutBlockedTitle,
                "«No pudimos cerrar tu sesión»: el de «un momento más» promete segundos")
        #expect(L.BlockReason.groupsCaptureUnfinished.breadcrumbSlug == "groups-capture-unfinished")
    }

    /// **Ninguna salida pierde datos** (decisión A): ni los cierres, ni «Empezar de cero», ni el paso 1 de la nube.
    @Test func noExitLosesTheChanges() {
        #expect(L.lossCause(.groupsCaptureUnfinished) == nil)
        #expect(!L.freshStartOffersGroupsLossExit(.groupsCaptureUnfinished))
        #expect(L.personalLossCause(.groupsCaptureUnfinished) == nil)
        let block = CloudSessionSignOut.FreshStartGroupsBlock(pendingCount: 2, reason: .groupsCaptureUnfinished,
                                                             readsUncaptured: false, anotherAccountCount: 0)
        #expect(!block.offersLossExit)
        #expect(SignOutBlockedCopy.groupsLossMessage(for: .groupsCaptureUnfinished, pending: 2, readsUncaptured: false)
                == L10n.Groups.Errors.captureUnfinished, "sin causa de pérdida, el texto sin salida")
    }

    /// Se enseña al momento (el push-all ya probó el atasco) y la nube lo deja viajar tal cual.
    @Test func surfacesAtOnce_andTravelsThroughTheCloudSignOut() {
        for elapsed in [0.0, 44.0] {
            #expect(GroupsSignOutRetryDecision.decide(elapsedSeconds: elapsed, budgetSeconds: 45,
                                                      reason: .groupsCaptureUnfinished) == .surfacePermanent)
        }
        #expect(L.cloudSignOutGroupsBlockReason(.groupsCaptureUnfinished) == .groupsCaptureUnfinished)
        #expect(L.personalPushAllShownReason(.groupsCaptureUnfinished) == .permanent, "el motor personal no lo emite")
    }

    /// **Lo legítimo no se mueve**: la subida que sí falló y la captura que no probó el atasco siguen en «un rato».
    @Test func theLegitimateUploadRetryLater_staysPut() {
        #expect(L.classify(.transient, channelKilled: false, attestUnavailable: false, uploadFailed: true) == .uploadRetryLater)
        #expect(L.lossBlockAfterRecapture(reason: .attestUnavailable, capture: .unfinished, livePendingCount: 1,
                                          unrehydratedMirrorCount: 0) == .blocked(pendingCount: 1, reason: .uploadRetryLater))
        #expect(L.freshStartUncapturedReason == .uploadRetryLater)
        #expect(SignOutBlockedCopy.message(for: .uploadRetryLater) == L10n.Groups.Errors.uploadRetryLater)
    }

    /// **Los 16 locales**, con el texto de Jürgen en español y nada que prometa que esperar lo arregla.
    @Test func theCopy_existsInTheSixteenLocales_andNeverPromisesWaiting() throws {
        for locale in Self.locales {
            let copy = try #require(try Self.value("groups.errors.captureUnfinished", locale: locale),
                                    "falta en \(locale)")
            let upload = try #require(try Self.value("groups.errors.uploadRetryLater", locale: locale))
            #expect(!copy.isEmpty && copy != upload, "\(locale): es el texto de la subida que falló")
            #expect(!copy.contains("NEEDS_TRANSLATION"), "\(locale)")
            #expect(copy.contains("Yala"), "\(locale): tiene que decir qué cerrar y abrir")
        }
        #expect(try Self.value("groups.errors.captureUnfinished", locale: "es") == Self.jurgen)
        #expect(try Self.value("groups.errors.captureUnfinished", locale: "es-419") == Self.jurgen)
        for locale in ["es", "es-419", "es-AR", "es-ES"] {
            let copy = try #require(try Self.value("groups.errors.captureUnfinished", locale: locale))
            #expect(!copy.contains("un rato") && !copy.contains("un momento"), "\(locale): promete que esperar lo cura")
            #expect(copy.contains("grupos"), "\(locale): tiene que decir que son cambios de tus grupos")
        }
    }
}
