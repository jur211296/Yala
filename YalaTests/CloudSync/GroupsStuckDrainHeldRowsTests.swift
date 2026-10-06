//
//  GroupsStuckDrainHeldRowsTests.swift
//  YalaTests / CloudSync
//
//  Ticket `stuck-groups-drain-hides-held-rows-of-another-account` (decisión A de Jürgen, 2026-10-05). Dos fallos a la vez: en
//  el outbox esperan cambios de grupos apuntados con OTRA cuenta (`held`) y el drain no consigue capturar algún cambio propio.
//  `stuckCaptureVerdict` no miraba las filas retenidas y salía solo el atasco; la persona lo arreglaba, volvía a intentarlo y
//  le salía «otra cuenta». Ahora, con algo de otra cuenta, sale «otra cuenta»: los cierres y «Empezar de cero» ofrecen perder
//  lo ajeno y lo atascado con la cifra exacta, el desasociar dice las dos causas, y los textos nombran las dos.
//
//  **Medido antes del arreglo**, con la tubería ya puesta y `stuckCaptureVerdict` sin mirar las filas retenidas (lo que hacía
//  el código): rojos los casos marcados MUTACIÓN de las suites 1 y 2; verdes los controles.
//
//  Tres suites:
//   1. La lógica pura (`stuckCaptureVerdict`, `GroupsLoss.readsUncaptured`).
//   2. «Empezar de cero» y el desasociar REALES, con el ciclo y la captura sustituidos (`GroupsExitWitness`). Los cierres que
//      suben grupos necesitan una sesión de grupos que el host de test no tiene; comparten este mismo push-all, y la oferta
//      que exponen a las vistas (`groupsLossReadsUncaptured`) la fijan los casos de la celda C en `GroupsOutboxOwnershipTests`.
//   3. El copy: qué texto elige cada pantalla, el español decidido y los 16 locales.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1. La lógica pura

@Suite("Grupos · con el drain atascado, las filas de otra cuenta también deciden (lógica pura)")
struct StuckDrainHeldRowsLogicTests {

    typealias L = CloudSignOutFlowLogic

    @Test("MUTACIÓN: filas de otra cuenta en el outbox y un cambio propio atascado, con el ciclo sano: otra cuenta")
    func heldRowsWithAStuckOwnChange_areAnotherAccount() {
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 2, heldRowsForAnotherAccount: 2,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 2, reason: .groupsChangesFromAnotherAccount), """
            con filas de otra cuenta en el outbox sale solo el atasco: la persona lo arregla y al reintentar le sale lo otro
            """)
        // Con un ciclo que paró por algo que no abre la salida, igual: lo ajeno no lo sube ninguna red.
        #expect(L.stuckCaptureVerdict(cycleReason: .uploadRetryLater, livePendingCount: 3, heldRowsForAnotherAccount: 1,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 3, reason: .groupsChangesFromAnotherAccount))
    }

    @Test("MUTACIÓN: lo que el History apunta a otra cuenta, sin filas retenidas: otra cuenta")
    func theHistoryPointingToAnotherAccount_isAnotherAccount() {
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: 0,
                                      uncapturedPointsToAnotherAccount: true)
                == .blocked(pendingCount: 0, reason: .groupsChangesFromAnotherAccount))
    }

    /// Qué cuenta como «apunta a otra cuenta» en el History. Lo «sin dueño» (anterior al registro de sesiones) solo cuenta si
    /// TODO lo de fuera lo es; mezclado con cambios propios es ruido de la sonda y abriría la salida a un teléfono sano (review
    /// adversarial, lente de datos). Lo de otra cuenta CONCRETA basta aunque haya cambios propios: arreglado el drain, entraría
    /// al outbox como fila retenida, y el aviso volvería a salir de uno en uno.
    @Test("MUTACIÓN: el History apunta a otra cuenta con todo ajeno, o con algo de otra cuenta probada; el ruido sin dueño no")
    func uncapturedPointsToAnotherAccount_table() {
        typealias Change = GroupsSyncClient.UncapturedChange
        let own = Change(key: "own", heldForAnotherAccount: false)
        let unproven = Change(key: "unproven", heldForAnotherAccount: true)
        let proven = Change(key: "proven", heldForAnotherAccount: true, provenAnotherAccount: true)
        #expect(L.uncapturedPointsToAnotherAccount(nil) == nil)
        #expect(L.uncapturedPointsToAnotherAccount([]) == false)
        #expect(L.uncapturedPointsToAnotherAccount([own]) == false)
        #expect(L.uncapturedPointsToAnotherAccount([unproven]) == true, "todo sin dueño: el criterio de siempre")
        #expect(L.uncapturedPointsToAnotherAccount([unproven, proven]) == true)
        #expect(L.uncapturedPointsToAnotherAccount([own, proven]) == true, "una mezcla con otra cuenta probada: otra cuenta")
        #expect(L.uncapturedPointsToAnotherAccount([own, unproven]) == false, """
            el ruido sin dueño mezclado con cambios propios abre la salida que pierde cambios a un teléfono sano
            """)
    }

    @Test("MUTACIÓN: con filas de otra cuenta y el History ilegible, el atasco sin salida")
    func heldRowsWithAnUnreadableHistory_doNotOpenTheExit() {
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 1, heldRowsForAnotherAccount: 1,
                                      uncapturedPointsToAnotherAccount: nil)
                == .blocked(pendingCount: 1, reason: .groupsCaptureUnfinished), """
            sin History legible la oferta sale sin cifra, y lo aceptado sin cifra cubre también lo propio que se apunte después
            """)
    }

    @Test("MUTACIÓN: un recuento de filas ajenas que falló no abre la salida")
    func aFailedHeldCount_provesNothing() {
        // `Int.max` es el «no se pudo contar» de `liveRowsHeldForAnotherAccount`. Leído como «hay», abriría la salida que
        // pierde cambios sin saber de quién son.
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 2, heldRowsForAnotherAccount: .max,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 2, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: .max,
                                      uncapturedPointsToAnotherAccount: nil)
                == .blocked(pendingCount: .max, reason: .groupsCaptureUnfinished))
        // Pero el History que sí prueba algo ajeno decide aunque el recuento falle.
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 2, heldRowsForAnotherAccount: .max,
                                      uncapturedPointsToAnotherAccount: true)
                == .blocked(pendingCount: 2, reason: .groupsChangesFromAnotherAccount))
    }

    @Test("control: sin nada de otra cuenta, el atasco solo y sin salida (decisión A del teléfono sano)")
    func withoutAnythingOfAnotherAccount_theStuckDrainStands() {
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: 0,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: .max, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: nil, livePendingCount: 0, heldRowsForAnotherAccount: 0,
                                      uncapturedPointsToAnotherAccount: nil)
                == .blocked(pendingCount: .max, reason: .groupsCaptureUnfinished))
        #expect(L.stuckCaptureVerdict(cycleReason: .channelPaused, livePendingCount: 3, heldRowsForAnotherAccount: 0,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 3, reason: .groupsCaptureUnfinished))
    }

    @Test("control: un ciclo que paró sin App Attest o sin sesión sigue mandando, haya o no filas de otra cuenta")
    func aCycleReasonThatOpensTheExit_stillWins() {
        #expect(L.stuckCaptureVerdict(cycleReason: .attestUnavailable, livePendingCount: 2, heldRowsForAnotherAccount: 2,
                                      uncapturedPointsToAnotherAccount: true)
                == .blocked(pendingCount: 2, reason: .attestUnavailable))
        #expect(L.stuckCaptureVerdict(cycleReason: .sessionExpired, livePendingCount: 1, heldRowsForAnotherAccount: 1,
                                      uncapturedPointsToAnotherAccount: false)
                == .blocked(pendingCount: 1, reason: .sessionExpired))
    }

    @Test("La oferta dice si cuenta el History: algo leído o una mitad sin leer, sí; nada, no")
    func groupsLoss_readsUncaptured() {
        #expect(!L.GroupsLoss(rows: [UUID()], uncaptured: []).readsUncaptured)
        #expect(L.GroupsLoss(rows: [UUID()], uncaptured: ["h1"]).readsUncaptured)
        #expect(L.GroupsLoss(rows: [UUID()], uncaptured: nil).readsUncaptured)
    }
}

// MARK: - 2. «Empezar de cero» y el desasociar reales

@MainActor
@Suite("Grupos · filas de otra cuenta y el drain atascado: «Empezar de cero» y el desasociar",
       .serialized, .wipeAppGroupMirrorIsolated)
struct StuckDrainHeldRowsGestureTests {

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
        coordinator.acknowledgeBlocked()
        coordinator.exitWitnessOverride = nil
        coordinator.exitCaptureDelayOverride = nil
    }

    private static func reading(_ outcome: SyncCadencePolicy.CadenceOutcome,
                                attest: Bool = false) -> CloudSessionSignOut.GroupsCycleReading {
        .init(outcome: outcome, channelKilled: false, attestUnavailable: attest, uploadFailed: false)
    }

    private static func own(_ keys: [String]) -> [GroupsSyncClient.UncapturedChange] {
        keys.map { .init(key: $0, heldForAnotherAccount: false) }
    }

    private final class History { var keys: [String] = [] }

    /// El outbox guarda `held` filas de otra cuenta (todas las vivas, en estos casos); la captura falla siempre —o termina, con
    /// `captureCompletes`— y el History guarda los cambios propios de `history`. El ciclo va bien.
    private func witness(held: Int, history: History, captureCompletes: Bool = false,
                         cycle: CloudSessionSignOut.GroupsCycleReading? = nil,
                         cycles: Count = Count()) -> CloudSessionSignOut.GroupsExitWitness {
        let cycle = cycle ?? Self.reading(.completed)
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in captureCompletes },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.heldForAnotherAccount = { _ in held }
        witness.uncapturedChanges = { _ in Self.own(history.keys) }
        witness.cycle = { _ in cycles.value += 1; return cycle }
        return witness
    }

    private func seed(_ context: ModelContext, liveRows: Int) throws {
        try clearOutbox(context)
        for _ in 0..<liveRows { context.insert(liveRow()) }
        try context.save()
    }

    // MARK: «Empezar de cero»

    /// **El caso del ticket en «Empezar de cero»**: dos filas de otra cuenta y un cambio propio atascado, con el ciclo sano.
    /// Antes: «algunos de los últimos cambios de tus grupos no se pudieron preparar…», sin salida. Ahora: la salida, con la
    /// cifra de las dos filas MÁS lo atascado, y el texto de las dos causas.
    @Test("MUTACIÓN: «Empezar de cero» ofrece perder lo ajeno y lo atascado, con la cifra exacta y las dos causas")
    func freshStart_offersTheLossOfBoth_withTheExactCount() async throws {
        let context = try makeTestContext()
        reset(context); defer { reset(context); try? clearOutbox(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        try seed(context, liveRows: 2)
        let history = History()
        history.keys = ["h1"]
        let cycles = Count()

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(held: 2, history: history, cycles: cycles))

        #expect(cycles.value >= 1, "control: la captura atascada tiene que ciclar para saber la causa")
        let expected = Block(pendingCount: 3, reason: .groupsChangesFromAnotherAccount, readsUncaptured: true, anotherAccountCount: 2)
        #expect(verdict == .blocked(expected), """
            con filas de otra cuenta y un cambio propio atascado, «Empezar de cero» tiene que ofrecer perder las dos filas y \
            el cambio: \(verdict)
            """)
        #expect(expected.offersLossExit)
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(expected, retryOffersTheLossExit: true)
                    .hasSuffix(L10n.Groups.FreshStartPending.lossOtherAccountAndCaptureUnfinished),
                "el texto nombra una sola causa")
        #expect(coordinator.acceptFreshStartGroupsLoss(), "la oferta quedó anotada")
        let accepted = try #require(coordinator.takeFreshStartAcceptedLoss())
        #expect(accepted.rows?.count == 2)
        #expect(accepted.uncaptured == ["h1"])

        // Lo aceptado cubre exactamente eso: otro intento con lo mismo sigue sin ello…
        let again = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(held: 2, history: history), accepted: accepted)
        #expect(again == .lossAccepted(accepted), "\(again)")

        // …y un cambio que llega después vuelve a parar, con la cifra nueva.
        history.keys = ["h1", "h2"]
        let newer = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(held: 2, history: history), accepted: accepted)
        #expect(newer == .blocked(Block(pendingCount: 4, reason: .groupsChangesFromAnotherAccount,
                                        readsUncaptured: true, anotherAccountCount: 2)), "\(newer)")
    }

    /// Control: las mismas filas de otra cuenta sin atasco —la captura termina— siguen saliendo como antes: otra cuenta, sin
    /// contar el History y con el texto de una causa.
    @Test("control: filas de otra cuenta sin atasco, «Empezar de cero» como antes")
    func freshStart_heldRowsWithoutAStuckDrain_unchanged() async throws {
        let context = try makeTestContext()
        reset(context); defer { reset(context); try? clearOutbox(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        try seed(context, liveRows: 2)

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(held: 2, history: History(), captureCompletes: true))

        let expected = Block(pendingCount: 2, reason: .groupsChangesFromAnotherAccount, readsUncaptured: false, anotherAccountCount: 2)
        #expect(verdict == .blocked(expected), "\(verdict)")
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(expected, retryOffersTheLossExit: true)
                    .hasSuffix(L10n.Groups.FreshStartPending.lossOtherAccount))
    }

    /// Control: el atasco sin nada de otra cuenta sigue siendo el atasco solo, sin salida (decisión A del teléfono sano).
    @Test("control: el atasco sin filas de otra cuenta, sin salida")
    func freshStart_aStuckDrainWithoutHeldRows_unchanged() async throws {
        let context = try makeTestContext()
        reset(context); defer { reset(context); try? clearOutbox(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let history = History()
        history.keys = ["h1"]

        let verdict = await coordinator.drainGroupsBeforeFreshStart(
            context: context, witness: witness(held: 0, history: history))

        guard case .blocked(let block) = verdict else {
            Issue.record("el atasco solo dejó borrar: \(verdict)")
            return
        }
        #expect(block.reason == .groupsCaptureUnfinished, "\(block)")
        #expect(!block.offersLossExit)
        #expect(!coordinator.acceptFreshStartGroupsLoss(), "sin oferta")
    }

    // MARK: El desasociar

    private func detach(_ witness: CloudSessionSignOut.GroupsExitWitness,
                        liveRows: Int) async throws -> CloudSessionSignOut.DetachOutcome {
        let context = try makeTestContext()
        try seed(context, liveRows: liveRows)
        defer { try? clearOutbox(context) }
        try #require(coordinator.phase == .idle, "el coordinador venía ocupado de otro test")
        coordinator.exitWitnessOverride = witness
        let outcome = await coordinator.detachGroupsAccount(context: context, choice: .keep)
        #expect(coordinator.phase == .idle, "el bloqueo del desasociar se quedó en la fase compartida")
        return outcome
    }

    /// **El caso del ticket en el desasociar**: sin salida que perderlos (decisión del 2026-09-15), el aviso de las dos
    /// causas. Antes: el atasco solo.
    @Test("MUTACIÓN: el desasociar con filas de otra cuenta y un cambio propio atascado dice las dos causas")
    func detach_namesBothCauses() async throws {
        let context = try makeTestContext()
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        let history = History()
        history.keys = ["h1"]

        let outcome = try await detach(witness(held: 2, history: history), liveRows: 2)

        #expect(outcome == .blockedBeforeWriting(notice: .alsoCaptureUnfinished(.otherAccount)), """
            el desasociar nombra una sola causa (\(outcome)): la persona arregla el drain y al reintentar le sale la otra
            """)
    }

    /// Control: las filas de otra cuenta sin atasco, la causa sola.
    @Test("control: el desasociar con filas de otra cuenta y la captura completa, una causa")
    func detach_heldRowsWithoutAStuckDrain_oneCause() async throws {
        let context = try makeTestContext()
        reset(context); defer { reset(context) }
        coordinator.exitCaptureDelayOverride = .milliseconds(1)

        let outcome = try await detach(witness(held: 2, history: History(), captureCompletes: true), liveRows: 2)

        #expect(outcome == .blockedBeforeWriting(notice: .reason(.groupsChangesFromAnotherAccount)), "\(outcome)")
    }
}

// MARK: - 3. El copy

@Suite("Grupos · otra cuenta y el drain atascado: el texto nombra las dos causas")
struct StuckDrainHeldRowsCopyTests {

    typealias Copy = SignOutBlockedCopy

    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // CloudSync/
        .deletingLastPathComponent()  // YalaTests/
        .deletingLastPathComponent()  // repo root

    private static func strings(_ locale: String) throws -> [String: String] {
        let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
        return try #require(NSDictionary(contentsOf: url) as? [String: String], "no se pudo leer \(locale)")
    }

    private static func code(_ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
    }

    private static let newKeys = [
        "groups.errors.otherAccountAndCaptureUnfinishedSignOutLoss",
        "groups.errors.otherAccountAndCaptureUnfinishedSignOutLossUnknown",
        "welcome.groups.neutralOtherAccountAndCaptureUnfinishedLossBody",
        "welcome.groups.neutralOtherAccountAndCaptureUnfinishedLossBodyUnknown",
        "groups.freshStartPending.lossOtherAccountAndCaptureUnfinished",
    ]

    @Test("MUTACIÓN: el aviso de los cierres elige las dos causas solo con otra cuenta y el History en la cifra")
    func signOutLossMessage_picksTheTwoCauses() {
        #expect(Copy.groupsLossMessage(for: .groupsChangesFromAnotherAccount, pending: 3, readsUncaptured: true)
                == L10n.Groups.Errors.otherAccountAndCaptureUnfinishedSignOutLoss(3))
        #expect(Copy.groupsLossMessage(for: .groupsChangesFromAnotherAccount, pending: .max, readsUncaptured: true)
                == L10n.Groups.Errors.otherAccountAndCaptureUnfinishedSignOutLossUnknown)
        // Sin el History en la cifra, el de siempre.
        #expect(Copy.groupsLossMessage(for: .groupsChangesFromAnotherAccount, pending: 3, readsUncaptured: false)
                == L10n.Groups.Errors.noSessionSignOutLoss(3))
        // Sin sesión y sin App Attest no cambian: ahí no sube nada, sea de quien sea.
        #expect(Copy.groupsLossMessage(for: .sessionExpired, pending: 3, readsUncaptured: true)
                == L10n.Groups.Errors.noSessionSignOutLoss(3))
        #expect(Copy.groupsLossMessage(for: .cloudSessionExpired, pending: 3, readsUncaptured: true)
                == L10n.Settings.signOutCloudSessionExpiredGroupsLoss(3))
        #expect(Copy.groupsLossMessage(for: .attestUnavailable, pending: 3, readsUncaptured: true)
                == Copy.attestLossMessage(pending: 3))
        #expect(!L10n.Groups.Errors.otherAccountAndCaptureUnfinishedSignOutLoss(3).contains("%d"))
    }

    @Test("MUTACIÓN: la puerta del Welcome elige las dos causas con su texto")
    func welcomeLossMessage_picksTheTwoCauses() {
        #expect(Copy.welcomeNoSessionLossMessage(pending: 2, anotherAccountAndCaptureUnfinished: true)
                == L10n.Welcome.Groups.neutralOtherAccountAndCaptureUnfinishedLossBody(2))
        #expect(Copy.welcomeNoSessionLossMessage(pending: .max, anotherAccountAndCaptureUnfinished: true)
                == L10n.Welcome.Groups.neutralOtherAccountAndCaptureUnfinishedLossBodyUnknown)
        #expect(Copy.welcomeNoSessionLossMessage(pending: 2, anotherAccountAndCaptureUnfinished: false)
                == L10n.Welcome.Groups.neutralNoSessionLossBody(2))
        // Sin la salida (el invitado): el texto de dos causas sin salida, el del desasociar, o el de siempre.
        #expect(Copy.welcomeBlockedMessage(anotherAccountAndCaptureUnfinished: true)
                == L10n.Storage.Groups.detachBlockedOtherAccountAndCaptureUnfinished)
        #expect(Copy.welcomeBlockedMessage(anotherAccountAndCaptureUnfinished: false) == L10n.Welcome.Groups.neutralBlockedBody)
    }

    @Test("MUTACIÓN: «Empezar de cero» elige las dos causas solo con otra cuenta y el History en la cifra")
    func freshStartMessage_picksTheTwoCauses() {
        typealias Block = CloudSessionSignOut.FreshStartGroupsBlock
        let both = Block(pendingCount: 3, reason: .groupsChangesFromAnotherAccount, readsUncaptured: true, anotherAccountCount: 0)
        #expect(Copy.freshStartGroupsPendingMessage(both, retryOffersTheLossExit: true)
                == L10n.Groups.FreshStartPending.leadNeutral(3) + " " + L10n.Groups.FreshStartPending.lossOtherAccountAndCaptureUnfinished)
        let one = Block(pendingCount: 3, reason: .groupsChangesFromAnotherAccount, readsUncaptured: false, anotherAccountCount: 0)
        #expect(Copy.freshStartGroupsPendingMessage(one, retryOffersTheLossExit: true).hasSuffix(L10n.Groups.FreshStartPending.lossOtherAccount))
        let session = Block(pendingCount: 3, reason: .sessionExpired, readsUncaptured: true, anotherAccountCount: 0)
        #expect(Copy.freshStartGroupsPendingMessage(session, retryOffersTheLossExit: true).hasSuffix(L10n.Groups.FreshStartPending.lossSessionExpired))
    }

    @Test("MUTACIÓN: las tres vistas que pintan la oferta pasan lo que cuenta la oferta, no un literal")
    func theViewsPassWhatTheOfferCounts() throws {
        let profile = try Self.code("Yala/App/Views/Profile/ProfileView.swift")
        #expect(profile.contains("signOutGroupsLossReadsUncaptured = signOutCoordinator.groupsLossReadsUncaptured"))
        #expect(profile.contains("readsUncaptured: signOutGroupsLossReadsUncaptured))"))
        let sheet = try Self.code("Yala/App/Views/Shared/AppleIDCloseNoticeView.swift")
        #expect(sheet.contains("readsUncaptured: coordinator.groupsLossReadsUncaptured),"))
        let gate = try Self.code("Yala/App/Views/Onboarding/WelcomeGroupsGateView.swift")
        #expect(gate.contains(
            "let namesBothCauses = cause == .otherAccount && CloudSessionSignOut.shared.groupsLossReadsUncaptured"))
        #expect(gate.contains("pending: pending, anotherAccountAndCaptureUnfinished: namesBothCauses)"), "el dueño")
        #expect(gate.contains("SignOutBlockedCopy.welcomeBlockedMessage(anotherAccountAndCaptureUnfinished: namesBothCauses)"),
                "el invitado, sin la salida, vuelve al texto de una causa")
        for view in [profile, sheet, gate] {
            #expect(!view.contains("readsUncaptured: false") && !view.contains("readsUncaptured: true")
                    && !view.contains("anotherAccountAndCaptureUnfinished: false"), "una vista fija el texto a mano")
        }
        // La oferta del coordinador lee la MISMA pérdida que se acepta.
        let coordinator = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        #expect(coordinator.contains(
            "guard offersGroupsLossExit, let offer = groupsLossExit else { return false } return offer.loss.readsUncaptured"))
        #expect(coordinator.contains("let offered = FreshStartGroupsBlock(pendingCount: loss.count, reason: block.reason, "
                                     + "readsUncaptured: loss.readsUncaptured, anotherAccountCount:"))
    }

    @Test("el español dice las dos causas, sin plazo, y el gemelo del desasociar ya no dice «de ellos»")
    func theSpanishCopy() throws {
        let es = try Self.strings("es-419")
        let signOut = try #require(es["groups.errors.otherAccountAndCaptureUnfinishedSignOutLoss"])
        #expect(signOut.hasPrefix("Cambios de grupos sin subir: %d."))
        let fresh = try #require(es["groups.freshStartPending.lossOtherAccountAndCaptureUnfinished"])
        let detach = try #require(es["storage.groups.detachBlockedOtherAccountAndCaptureUnfinished"])
        for key in Self.newKeys {
            let text = try #require(es[key], "falta \(key)")
            #expect(text.contains("otra cuenta"), "\(key) no nombra la otra cuenta")
            #expect(text.contains("no se pudieron preparar para subirlos"), "\(key) no nombra el atasco")
            #expect(!text.contains("en un rato") && !text.contains("segundos"), "\(key) promete un plazo")
        }
        // Lo tuyo sube reabriendo Yala y volviendo a intentarlo, con tu sesión; lo de la otra cuenta, solo entrando con ella.
        // La primera versión decía «para subirlos… entra con esa otra cuenta», falso para lo tuyo (review, lente de copy).
        for text in [signOut, fresh] {
            #expect(text.lowercased().contains(
                "cierra y vuelve a abrir yala (si sigue pasando, actualízala) y vuelve a intentarlo; "
                + "los de la otra cuenta solo suben si entras con ella"), "no dice qué hacer con cada parte: \(text)")
        }
        // El gemelo del desasociar (#364) decía «algunos de ellos», los de la otra cuenta: falso cuando lo atascado es tuyo.
        #expect(!detach.contains("de ellos"), "el gemelo del desasociar sigue atribuyendo el atasco a la otra cuenta")
        #expect(detach.contains("algunos cambios de grupos no se pudieron preparar para subirlos"))
        #expect(detach.contains("y vuelve a intentarlo; los de esa cuenta solo suben si entras con ella"))
    }

    @Test("los cinco textos están en los 16 locales, con su variante, y no repiten el de una causa")
    func everyLocaleHasTheTexts() throws {
        let locales = ["de", "en-GB", "en", "es-419", "es-AR", "es-ES", "es", "fr", "it", "ja", "nl", "pl", "pt-BR",
                       "pt-PT", "pt", "zh-Hans"]
        for locale in locales {
            let table = try Self.strings(locale)
            let values = Self.newKeys.compactMap { table[$0] }
            #expect(values.count == Self.newKeys.count, "\(locale) no tiene las claves")
            #expect(Set(values).count == values.count, "\(locale) repite un texto")
            for single in ["groups.errors.noSessionSignOutLoss", "groups.errors.noSessionSignOutLossUnknown",
                           "welcome.groups.neutralNoSessionLossBody", "groups.freshStartPending.lossOtherAccount",
                           "groups.errors.captureUnfinished", "storage.groups.detachBlockedOtherAccountAndCaptureUnfinished"] {
                #expect(!values.contains(table[single] ?? "—"), "\(locale): un texto de dos causas es el de \(single)")
            }
            #expect(table["groups.errors.otherAccountAndCaptureUnfinishedSignOutLoss"]?.contains("%d") == true)
            #expect(table["welcome.groups.neutralOtherAccountAndCaptureUnfinishedLossBody"]?.contains("%d") == true)
        }
        // Las variantes no son copias del neutro: el peninsular en pretérito perfecto y el rioplatense con voseo.
        let esES = try Self.strings("es-ES")
        let esAR = try Self.strings("es-AR")
        for key in Self.newKeys {
            #expect(esES[key]?.contains("no se han podido preparar") == true, "es-ES: \(key)")
            #expect(esAR[key]?.contains("anotaron") == true, "es-AR: \(key)")
        }
        #expect(esAR["groups.errors.otherAccountAndCaptureUnfinishedSignOutLoss"]?.lowercased()
                    .contains("cerrá y volvé a abrir yala (si sigue pasando, actualizala) y volvé a intentarlo") == true)
    }
}
