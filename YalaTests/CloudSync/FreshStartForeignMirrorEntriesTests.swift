//
//  FreshStartForeignMirrorEntriesTests.swift
//  YalaTests / CloudSync
//
//  Ticket `fresh-start-drops-mirror-entries-of-another-identity-without-counting-them` (decisión A de Jürgen, 2026-10-04).
//  El espejo del App Group puede guardar cambios de grupos de OTRA cuenta que nunca llegaron a su fila. «Empezar de cero»
//  purga el espejo entero (`DataWipeService.wipeLocalGroupsDomain` → `GroupsOutboxMirror.purgeAll()`), pero hasta este
//  ticket contaba solo las entradas del dueño de la sesión: con sesión, las ajenas se borraban sin aviso y sin cifra.
//
//  Los tests de gesto corren con el espejo REAL en un directorio temporal y el filtro REAL
//  (`GroupsSyncClient.mirrorEntriesMissingFromOutbox`), con la sesión inyectada: el alcance que pide cada sitio es lo que
//  se mide, así que un testigo que contestase lo mismo a todos los alcances no probaría nada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("«Empezar de cero» cuenta las entradas del espejo de otra cuenta", .serialized, .wipeAppGroupMirrorIsolated)
struct FreshStartForeignMirrorEntriesTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock

    // MARK: - Montaje

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FSForeign-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    /// Ninguna prueba hereda la oferta ni lo aceptado de otra: el coordinador es un singleton.
    private func resetCoordinator(_ context: ModelContext) {
        _ = CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: .quiet)
    }

    private func entry(user: String, hlc: String) -> GroupsOutboxMirrorEntry {
        GroupsOutboxMirrorEntry(
            userID: user, syncID: UUID(), groupID: "SplitGroup-A", entityType: GroupSyncEntityType.splitExpense,
            op: SyncOutboxOp.upsert.rawValue, hlc: hlc, clientMutationID: UUID(),
            fieldsJSON: "{\"amount\":\"30.0000\"}", fieldHlcsJSON: nil, tombstoneReason: nil,
            author: GroupsOutboxMirror.author, createdAt: .now)
    }

    /// Un espejo en disco con `own` entradas de la sesión (`sub-a`) y `foreign` de otra cuenta (`sub-b`), ninguna con fila.
    private func mirror(own: Int = 0, foreign: Int, in dir: URL) throws -> GroupsOutboxMirror {
        let mirror = GroupsOutboxMirror(directoryURL: dir)
        for i in 0..<own {
            try mirror.write(entry(user: "sub-a", hlc: "2026-10-05T00:00:00.000Z-\(String(format: "%04d", i))-00000000000000aa"))
        }
        for i in 0..<foreign {
            try mirror.write(entry(user: "sub-b", hlc: "2026-10-05T00:00:00.000Z-\(String(format: "%04d", 100 + i))-00000000000000bb"))
        }
        return mirror
    }

    /// El testigo con el espejo y el filtro REALES y la sesión `owner` (`nil` = sin sesión). La captura termina, el
    /// History no esconde nada y el canal está sano: lo único que decide es qué entradas cuenta cada alcance.
    private func witness(_ mirror: GroupsOutboxMirror, owner: String?) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in true },
            mirrorPending: { context, scope in
                GroupsSyncClient.mirrorEntriesMissingFromOutbox(
                    mirror: mirror, ownerID: owner, scope: scope, context: context)
            },
            mirrorPendingKeys: { context, scope in
                GroupsSyncClient.mirrorEntryKeysMissingFromOutbox(
                    mirror: mirror, ownerID: owner, scope: scope, context: context)
            })
        witness.mirrorPendingOfAnotherAccount = { context in
            GroupsSyncClient.mirrorEntriesMissingFromOutbox(
                mirror: mirror, ownerID: owner, scope: .anotherAccount, context: context)
        }
        witness.uncapturedChanges = { _ in [] }
        witness.cycle = { _ in
            CloudSessionSignOut.GroupsCycleReading(
                outcome: .completed, channelKilled: false, attestUnavailable: false, uploadFailed: false)
        }
        return witness
    }

    // MARK: - El caso del ticket: sesión abierta y solo entradas de otra cuenta

    /// **El canario del alert del shell.** Hasta este ticket, con sesión y dos entradas ajenas, el pre-check daba
    /// «nada que subir» y el botón borraba en el mismo tap: el espejo entero se iba sin aviso.
    @Test func settledEmpty_isFalse_withForeignEntriesUnderASession() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 2, in: dir)
        #expect(!CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(
            context: context, witness: witness(mirror, owner: "sub-a")))
    }

    /// **La subida bloquea con la cifra exacta y el motivo que ofrece perderlos.** El motivo es el de «la sesión abierta
    /// es de otra cuenta», que es literalmente el caso: `.sessionExpired` diría que no hay sesión a quien sí la tiene.
    @Test func drain_blocksWithEveryEntryTheWipeTakes_andTheOtherAccountReason() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 2, in: dir)
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))
        let expected = Block(pendingCount: 2, reason: .groupsChangesFromAnotherAccount, readsUncaptured: false)
        #expect(verdict == .blocked(expected))
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == expected)
        #expect(expected.offersLossExit, "la salida «perderlos» está en pantalla")
        #expect(mirror.allEntries().count == 2, "la subida no borra nada")
    }

    /// **Aceptar y volver a lanzar el borrado deja pasar exactamente esas dos**, y el borrado del dominio las purga.
    @Test func acceptedLoss_letsTheWipePurgeThoseEntries_andNothingElse() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 2, in: dir)
        let foreignSession = witness(mirror, owner: "sub-a")

        _ = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: foreignSession)
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())
        let accepted = CloudSessionSignOut.shared.takeFreshStartAcceptedLoss()
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: foreignSession, accepted: accepted)
        guard case .lossAccepted(let loss) = verdict else {
            Issue.record("esperaba .lossAccepted, llegó \(verdict)")
            return
        }
        #expect(loss.count == 2)
        #expect(loss.mirrorKeys?.count == 2)

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: makeIsolatedDefaults(), retireCloudSession: {},
            resetSyncState: { mirror.purgeAll() }, witness: foreignSession, acceptedGroupsLoss: loss)
        #expect(mirror.allEntries().isEmpty, "con lo aceptado, el borrado se las lleva")
    }

    /// **El cinturón del escritor las cuenta**: sin aceptar, se niega antes de `resetSyncState` y el espejo sigue entero.
    @Test func writerBelt_refusesForeignEntries_andNeverReachesThePurge() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 2, in: dir)
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 2)) {
            try DataWipeService.wipeLocalGroupsDomain(
                in: context, defaults: makeIsolatedDefaults(), retireCloudSession: {},
                resetSyncState: { mirror.purgeAll() }, witness: witness(mirror, owner: "sub-a"))
        }
        #expect(mirror.allEntries().count == 2)
    }

    /// **Una entrada ajena que llega DESPUÉS del aviso no la cubre lo aceptado**: el cinturón vuelve a negarse.
    @Test func writerBelt_refusesAForeignEntryThatArrivedAfterTheOffer() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 1, in: dir)
        let foreignSession = witness(mirror, owner: "sub-a")
        _ = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: foreignSession)
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())
        let accepted = try #require(CloudSessionSignOut.shared.takeFreshStartAcceptedLoss())

        try mirror.write(entry(user: "sub-b", hlc: "2026-10-05T00:00:00.000Z-0900-00000000000000bb"))
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 2)) {
            try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: foreignSession, accepting: accepted)
        }
    }

    /// **Un bloqueo que no ofrece perderlos también las cuenta**: el texto dice «hay cambios (N) y empezar de cero se los
    /// llevaría», y se llevaría también las ajenas. Una propia sin fila hace bloquear a la subida con «inténtalo en un
    /// rato» y su cifra (1); el bloqueo enseña además las dos de otra cuenta.
    @Test func blockWithoutTheLossExit_addsTheForeignEntriesToItsCount() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))
        #expect(verdict == .blocked(Block(pendingCount: 3, reason: .uploadRetryLater, readsUncaptured: false)))
    }

    /// **El residuo no las cuenta dos veces** (review adversarial del 2026-10-05, lente de copy). La subida termina y DESPUÉS
    /// aparece una entrada propia: el residuo ya cuenta el espejo entero (1 propia + 2 ajenas = 3) y su motivo es «inténtalo
    /// en un rato»; sumar otra vez las ajenas en el bloqueo sin salida enseñaba 5.
    @Test func residualBlock_countsForeignEntriesOnce() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        final class Calls { var sessionOwner = 0 }
        let calls = Calls()
        // La propia no existe en la primera pregunta de la subida (que así da `.drained`) y sí después.
        func own() -> Int { calls.sessionOwner > 0 ? 1 : 0 }
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in true },
            mirrorPending: { _, scope in
                switch scope {
                case .sessionOwner:
                    defer { calls.sessionOwner += 1 }
                    return own()
                case .wholeMirror: return own() + 2
                case .anotherAccount, .sessionOwnerOrEveryoneWhenSignedOut: return 2
                }
            },
            mirrorPendingKeys: { _, _ in nil })
        witness.mirrorPendingOfAnotherAccount = { _ in 2 }
        witness.uncapturedChanges = { _ in [] }
        witness.cycle = { _ in
            CloudSessionSignOut.GroupsCycleReading(
                outcome: .completed, channelKilled: false, attestUnavailable: false, uploadFailed: false)
        }
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: witness)
        #expect(calls.sessionOwner >= 2, "control: la subida preguntó antes de que apareciera, y el residuo después")
        #expect(verdict == .blocked(Block(pendingCount: 3, reason: .uploadRetryLater, readsUncaptured: false)))
    }

    /// **Con un motivo que ofrece perderlos, la oferta cuenta propias y ajenas**: el aviso enseña lo que el borrado se
    /// lleva entero, y lo aceptado las cubre por clave. Una propia sin fila y dos ajenas ⇒ 3, con el motivo de la subida.
    @Test func lossOffer_countsOwnAndForeignEntries() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let verdict = await CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: .attestUnavailable, readsUncaptured: false), accepted: nil,
            context: context, witness: witness(mirror, owner: "sub-a"))
        #expect(verdict == .blocked(Block(pendingCount: 3, reason: .attestUnavailable, readsUncaptured: false)))
    }

    /// La suma no inventa un número: si cualquiera de las dos mitades no se pudo contar, «no se pudo contar».
    @Test func blockCount_keepsTheUnknown() throws {
        let context = try makeTestContext()
        func counted(_ pending: Int, foreign: Int) -> Int {
            var witness = CloudSessionSignOut.GroupsExitWitness.quiet
            witness.mirrorPendingOfAnotherAccount = { _ in foreign }
            return CloudSessionSignOut.freshStartBlockCountingAnotherAccount(
                Block(pendingCount: pending, reason: .transient, readsUncaptured: false), context: context, witness: witness).pendingCount
        }
        #expect(counted(1, foreign: 0) == 1)
        #expect(counted(1, foreign: 2) == 3)
        #expect(counted(Int.max, foreign: 2) == Int.max)
        #expect(counted(1, foreign: Int.max) == Int.max)
        #expect(counted(Int.max - 1, foreign: 5) == Int.max, "un desbordamiento tampoco es una cifra")
    }

    // MARK: - Controles

    /// **Sin entradas ajenas nada cambia**: con sesión y el espejo vacío, «vacío» y `.drained` sin red.
    @Test func control_noForeignEntries_drainsAsBefore() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 0, in: dir)
        let session = witness(mirror, owner: "sub-a")
        #expect(CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: session))
        #expect(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(context: context, witness: session) == .drained)
        #expect(throws: Never.self) { try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: session) }
    }

    /// **Un bloqueo que no ofrece perderlos, sin ajenas, conserva su cifra** (la de la subida).
    @Test func control_blockWithoutTheLossExit_keepsItsCount_withoutForeignEntries() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 0, in: dir)
        let block = Block(pendingCount: 4, reason: .channelPaused, readsUncaptured: false)
        let verdict = await CloudSessionSignOut.shared.settleFreshStartBlock(
            block, accepted: nil, context: context, witness: witness(mirror, owner: "sub-a"))
        #expect(verdict == .blocked(block))
    }

    /// **Sin sesión, como antes**: las cuenta todas y el motivo es la sesión que ya no está.
    @Test func control_signedOut_countsEveryEntry_withTheSessionExpiredReason() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: nil))
        #expect(verdict == .blocked(Block(pendingCount: 3, reason: .sessionExpired, readsUncaptured: false)))
    }
}
