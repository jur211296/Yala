//
//  GroupsStuckDrainUncountedOfferTests.swift
//  YalaTests / CloudSync
//
//  Ticket `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice` (decisión A de Jürgen, 2026-10-05).
//  Con la captura de Grupos atascada, la oferta de perder los cambios vuelve a leer el History para contar lo que el drain
//  no capturó. Si esa lectura fallaba (`nil`), el aviso salía sin cifra y lo aceptado (`uncaptured: nil`) cubría cualquier
//  cambio: un gasto apuntado después del aviso, y que tampoco se preparaba, se iba con el cierre sin que nadie lo contara.
//
//  Ahora, con la salida abierta y el History sin leer, sale el aviso del atasco sin salida
//  (`CloudSignOutFlowLogic.groupsLossShownReason`); y lo aceptado sin leer ya no cubre cambios nuevos.
//
//  Tres capas:
//   1. Lógica pura: el motivo que enseña la oferta y lo que cubre lo aceptado sin leer.
//   2. «Empezar de cero» por el coordinador, con el History que se lee en la captura y falla en la oferta.
//   3. Cableado (source-scan): las tres ofertas de los cierres pasan por la función pura. La celda privada C se recorre de
//      verdad en `GroupsOutboxOwnershipTests` (`GroupsNoSessionLossExitTests`), que tiene su fixture.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1. Lógica pura

@Suite("Grupos · sin poder contar el History, la oferta no abre la salida (lógica pura)")
struct GroupsUncountedOfferLogicTests {

    private typealias L = CloudSignOutFlowLogic

    private static let exitReasons: [L.BlockReason] = [.attestUnavailable, .sessionExpired, .cloudSessionExpired,
                                                       .groupsChangesFromAnotherAccount]

    @Test("MUTACIÓN: con la salida abierta y el History sin leer, el atasco sin salida, para las cuatro causas")
    func anUnreadHistory_turnsTheOfferIntoTheStuckNotice() {
        for reason in Self.exitReasons {
            let shown = L.groupsLossShownReason(reason, opensExit: true, uncaptured: nil)
            #expect(shown == .groupsCaptureUnfinished, "\(reason): \(shown)")
            #expect(L.lossCause(shown) == nil, "\(reason): el motivo que sale no puede abrir la salida")
        }
        #expect(L.groupsLossShownReason(.permanent, opensExit: true, uncaptured: nil) == .groupsCaptureUnfinished,
                "«Empezar de cero» ofrece la salida también con `.permanent`")
    }

    @Test("control: con el History leído, la salida sigue con su motivo")
    func aReadHistory_keepsTheReason() {
        for reason in Self.exitReasons {
            #expect(L.groupsLossShownReason(reason, opensExit: true, uncaptured: []) == reason, "\(reason)")
            #expect(L.groupsLossShownReason(reason, opensExit: true, uncaptured: ["h1"]) == reason, "\(reason)")
        }
    }

    @Test("control: un motivo que no abre la salida no se toca, lea o no el History")
    func aReasonWithoutTheExit_staysPut() {
        for reason in [L.BlockReason.uploadRetryLater, .channelPaused, .transient, .permanent] {
            #expect(L.groupsLossShownReason(reason, opensExit: false, uncaptured: nil) == reason, "\(reason)")
        }
    }

    @Test("MUTACIÓN: lo aceptado sin leer el History no cubre un cambio nuevo, ni un History que sigue sin leerse")
    func anAcceptanceWithoutTheHistory_coversNothingNew() {
        let caused = L.CausedLossAcceptance(rows: .uncounted, cause: .attestUnavailable, uncaptured: nil)
        #expect(!caused.coversUncaptured(["h7"]), "el gasto apuntado después del aviso se iba sin contarlo")
        #expect(!caused.coversUncaptured(nil))
        #expect(caused.coversUncaptured([]), "sin nada fuera del outbox no hay nada que cubrir")
        #expect(caused.readsUncaptured, "lo aceptado sin leer obliga a releer el History antes del borrado")
        #expect(!L.groupsResidualUncapturedAllowsSignOut(now: ["h7"], acceptance: caused))
        #expect(!L.groupsLossAcceptanceContinues(caused, reason: .attestUnavailable, pendingRows: [],
                                                 uncaptured: ["h7"]))

        let freshStart = L.FreshStartGroupsLoss(rows: nil, mirrorKeys: nil, uncaptured: nil)
        #expect(!freshStart.covers(L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: ["h7"])))
        #expect(!freshStart.covers(L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: nil)))
        #expect(freshStart.covers(L.FreshStartGroupsLoss(rows: [UUID()], mirrorKeys: ["m1"], uncaptured: [])),
                "control: las filas y el espejo sin cifra siguen como estaban (decisión B2)")
    }

    @Test("control: lo aceptado con el History leído cubre exactamente lo que contó")
    func anAcceptanceWithTheHistory_coversExactlyThat() {
        let caused = L.CausedLossAcceptance(rows: .uncounted, cause: .noSession, uncaptured: ["h1"])
        #expect(caused.coversUncaptured(["h1"]))
        #expect(!caused.coversUncaptured(["h1", "h2"]))
        let freshStart = L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: ["h1"])
        #expect(freshStart.covers(L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: ["h1"])))
        #expect(!freshStart.covers(L.FreshStartGroupsLoss(rows: [], mirrorKeys: [], uncaptured: ["h1", "h2"])))
    }
}

// MARK: - 2. «Empezar de cero», por el coordinador

/// El push-all es privado y su ciclo habla con el gateway: se recorre por `drainGroupsBeforeFreshStart` con el ciclo
/// sustituido. **El History se lee bien justo después de cada intento de captura y falla en la lectura siguiente**: así la
/// captura prueba el atasco (exige leerlo en cada intento) y es la OFERTA la que no puede contar, que es el caso del ticket.
@MainActor
@Suite("Grupos · «Empezar de cero» con el drain atascado y el History ilegible en la oferta",
       .serialized, .wipeAppGroupMirrorIsolated)
struct GroupsUncountedFreshStartOfferTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock
    private let coordinator = CloudSessionSignOut.shared

    /// Cuántas lecturas del History van desde el último intento de captura, y si la segunda falla.
    private final class Reads {
        var sinceCapture = 0
        var failsAfterTheCapture = true
    }

    private final class History { var keys: [String] = [] }

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

    private static func reading(_ outcome: SyncCadencePolicy.CadenceOutcome,
                                attest: Bool = false) -> CloudSessionSignOut.GroupsCycleReading {
        .init(outcome: outcome, channelKilled: false, attestUnavailable: attest, uploadFailed: false)
    }

    /// La captura no termina nunca; el History guarda los cambios propios de `history`, y con `reads.failsAfterTheCapture`
    /// solo se deja leer justo tras un intento de captura.
    private func witness(history: History, reads: Reads,
                         cycle: CloudSessionSignOut.GroupsCycleReading) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in reads.sinceCapture = 0; return false },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in
            reads.sinceCapture += 1
            guard reads.sinceCapture == 1 || !reads.failsAfterTheCapture else { return nil }
            return history.keys.map { .init(key: $0, heldForAnotherAccount: false) }
        }
        witness.cycle = { _ in cycle }
        return witness
    }

    /// **El caso del ticket, con el teléfono sin App Attest y una fila viva.** Antes: «Empezar de cero y perderlos» sin
    /// cifra, y lo aceptado cubría cualquier cambio del History. Ahora: el atasco, sin salida; y cuando el History vuelve a
    /// leerse, la salida vuelve con la cifra exacta y lo aceptado cubre exactamente eso.
    @Test("MUTACIÓN: sin App Attest y el History ilegible en la oferta, el atasco sin salida; legible, la salida con su cifra")
    func attest_withAnUnreadHistoryAtTheOffer_showsTheStuckNoticeUntilItCanCount() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context); try? clearOutbox(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        context.insert(liveRow())
        try context.save()
        let history = History()
        history.keys = ["h1", "h2"]
        let reads = Reads()
        let cycle = Self.reading(.transient, attest: true)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(history: history, reads: reads, cycle: cycle))

        #expect(verdict == .blocked(Block(pendingCount: Int.max, reason: .groupsCaptureUnfinished, readsUncaptured: false)),
                "con el History ilegible en la oferta, el aviso no puede contar lo que se perdería: \(verdict)")
        #expect(!coordinator.acceptFreshStartGroupsLoss(), "sin cifra no queda oferta que aceptar")

        // El History vuelve a leerse: la salida, con la fila y los dos cambios.
        reads.failsAfterTheCapture = false
        let readable = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(history: history, reads: reads, cycle: cycle))
        #expect(readable == .blocked(Block(pendingCount: 3, reason: .attestUnavailable, readsUncaptured: true)),
                "\(readable)")
        #expect(coordinator.acceptFreshStartGroupsLoss())
        let accepted = try #require(coordinator.takeFreshStartAcceptedLoss())
        #expect(accepted.uncaptured == ["h1", "h2"])

        // Lo aceptado cubre exactamente eso: un cambio apuntado después vuelve a parar, con la cifra nueva.
        history.keys = ["h1", "h2", "h3"]
        let newer = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(history: history, reads: reads, cycle: cycle), accepted: accepted)
        #expect(newer == .blocked(Block(pendingCount: 4, reason: .attestUnavailable, readsUncaptured: true)),
                "el cambio apuntado después del aviso se iba con el borrado: \(newer)")
    }

    /// **La sesión caducada con el outbox a 0**: el motivo lo da el ciclo (`stuckCaptureVerdict`), y era la otra causa del
    /// ticket. Lo mismo: el atasco sin salida.
    @Test("MUTACIÓN: sin sesión y el outbox a 0, con el History ilegible en la oferta, el atasco sin salida")
    func sessionExpired_withAnUnreadHistoryAtTheOffer_showsTheStuckNotice() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let history = History()
        history.keys = ["h1"]

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(history: history, reads: Reads(), cycle: Self.reading(.sessionExpired)))

        #expect(verdict == .blocked(Block(pendingCount: Int.max, reason: .groupsCaptureUnfinished, readsUncaptured: false)),
                "\(verdict)")
        #expect(!coordinator.acceptFreshStartGroupsLoss())
    }

    /// **Una aceptación vieja sin cifra no se lleva un cambio nuevo**: lo aceptado con las tres mitades sin leer, y ahora un
    /// cambio del History que nadie contó. Antes el borrado seguía sin él (`.lossAccepted`); ahora vuelve el aviso, con cifra.
    @Test("MUTACIÓN: lo aceptado sin cifra no cubre un cambio del History apuntado después")
    func anOldAcceptanceWithoutACount_doesNotCoverANewChange() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let history = History()
        history.keys = ["h9"]
        let reads = Reads()
        reads.failsAfterTheCapture = false
        let old = CloudSignOutFlowLogic.FreshStartGroupsLoss(rows: nil, mirrorKeys: nil, uncaptured: nil)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(history: history, reads: reads, cycle: Self.reading(.sessionExpired)),
            accepted: old)

        #expect(verdict == .blocked(Block(pendingCount: 1, reason: .sessionExpired, readsUncaptured: true)), """
            un cambio que ningún aviso contó se iba con el borrado bajo una aceptación sin cifra: \(verdict)
            """)
    }
}

// MARK: - 3. Cableado

@Suite("Grupos · las ofertas de los cierres pasan por el motivo que mira el History (source-scan)")
struct GroupsUncountedOfferWiringTests {

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

    /// Las tres ofertas de los cierres (celda C, `pushGroupsForSignOut` y el paso 2 de la nube) y la de «Empezar de cero».
    @Test("MUTACIÓN: las cuatro ofertas deciden el motivo con la mitad del History que van a ofrecer")
    func everyOffer_decidesItsReasonWithTheHistoryHalf() throws {
        let code = try Self.source()
        #expect(Self.count("CloudSignOutFlowLogic.groupsLossShownReason(", in: code) == 4)
        #expect(Self.count("opensExit: true, uncaptured: loss.uncaptured)", in: code) == 1, "celda C")
        #expect(Self.count("opensExit: lossCause != nil, uncaptured: loss.uncaptured)", in: code) == 1,
                "`pushGroupsForSignOut`")
        #expect(Self.count("opensExit: cycleLossCause != nil, uncaptured: offerLoss.uncaptured)", in: code) == 1,
                "paso 2 de la nube")
        #expect(Self.count("opensExit: true, uncaptured: loss.uncaptured)", in: code)
                + Self.count("opensExit: block.offersLossExit, uncaptured: loss.uncaptured)", in: code) == 2,
                "«Empezar de cero»")
    }
}
