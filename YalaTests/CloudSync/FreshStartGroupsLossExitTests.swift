//
//  FreshStartGroupsLossExitTests.swift
//  YalaTests / CloudSync
//
//  Ticket `fresh-start-has-no-way-out-when-group-writes-can-never-upload`: desde el 2026-09-26 «Empezar de cero» no borra
//  con cambios de grupos sin subir, y quien no iba a poder subirlos nunca —un iPhone heredado, una sesión que el SDK
//  borró— se quedaba atrapado. Ahora, con los motivos que esperar no arregla, se ofrece perderlos: con la cifra, con un
//  «¿seguro?» y por fila.
//
//  Tres suites:
//   1. La lógica pura: qué motivos ofrecen la salida y qué cubre lo aceptado.
//   2. El servicio y el cinturón, con filas de verdad y sin red: la oferta, lo aceptado, lo que se consume y lo que el
//      escritor deja pasar. La subida que precede a `settleFreshStartBlock` habla con el gateway y no se prueba aquí (el
//      mismo motivo que en `FreshStartUnsentGroupWritesTests`); el guion de device-QA la cubre.
//   3. El cableado de las pantallas (source-scan): que el «¿seguro?» sea el único sitio que acepta, que «Mejor no» y
//      «Dejarlo por ahora» no acepten nada, y que lo aceptado llegue hasta el cinturón en los dos borrados.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - 1. La lógica pura

@Suite("«Empezar de cero y perderlos» · qué motivos la ofrecen y qué cubre lo aceptado")
struct FreshStartGroupsLossLogicTests {

    typealias Loss = CloudSignOutFlowLogic.FreshStartGroupsLoss

    /// **Los tres que esperar no arregla, y ni uno más.** Recorre `allCases`: un motivo nuevo que se colara en la salida
    /// sin decidirlo pondría esto en rojo.
    @Test func offers_onlyTheThreeReasonsThatWaitingDoesNotFix() {
        let offering: Set<CloudSignOutFlowLogic.BlockReason> = [.sessionExpired, .permanent, .attestUnavailable]
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(reason) == offering.contains(reason),
                    "\(reason)")
        }
    }

    /// El canal en pausa y lo pasajero, explícitos: son los que el encargo nombra para NO ofrecer.
    @Test func doesNotOffer_channelPausedNorTransient() {
        #expect(!CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(.channelPaused))
        #expect(!CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(.uploadRetryLater))
        #expect(!CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(.transient))
    }

    /// La cifra suma las dos mitades que el borrado se lleva; sin leer una, es «no se pudo contar».
    @Test func count_sumsRowsAndMirror_orIsUncounted() {
        let a = UUID(), b = UUID()
        #expect(Loss(rows: [a, b], mirrorKeys: ["m1"]).count == 3)
        #expect(Loss(rows: nil, mirrorKeys: []).count == Int.max)
        #expect(Loss(rows: [], mirrorKeys: nil).count == Int.max)
        #expect(Loss(rows: [], mirrorKeys: []).isEmpty)
        #expect(!Loss(rows: [a], mirrorKeys: []).isEmpty)
    }

    /// **Por fila, no por cifra.** Aceptar dos cambios no cubre OTRO par: el bug que la review le cazó al cierre.
    @Test func covers_isPerRow_notPerCount() {
        let a = UUID(), b = UUID(), c = UUID()
        let accepted = Loss(rows: [a, b], mirrorKeys: ["m1"])
        #expect(accepted.covers(Loss(rows: [a, b], mirrorKeys: ["m1"])))
        #expect(accepted.covers(Loss(rows: [a], mirrorKeys: [])), "lo que subió entre medias no estorba")
        #expect(!accepted.covers(Loss(rows: [a, c], mirrorKeys: ["m1"])), "una fila nueva, aunque la cifra sea la misma")
        #expect(!accepted.covers(Loss(rows: [a], mirrorKeys: ["m2"])), "una entrada del espejo nueva, lo mismo")
        #expect(accepted.covers(Loss(rows: [], mirrorKeys: [])), "sin nada que perder, siempre")
    }

    /// Lo que no se pudo leer: una mitad AHORA sin leer solo la cubre una aceptada sin cifra.
    @Test func covers_unreadableHalves() {
        let a = UUID()
        #expect(!Loss(rows: [a], mirrorKeys: []).covers(Loss(rows: nil, mirrorKeys: [])))
        #expect(Loss(rows: nil, mirrorKeys: []).covers(Loss(rows: nil, mirrorKeys: [])))
        #expect(Loss(rows: nil, mirrorKeys: []).covers(Loss(rows: [UUID()], mirrorKeys: [])))
        #expect(!Loss(rows: nil, mirrorKeys: []).covers(Loss(rows: [], mirrorKeys: ["m"])),
                "la mitad del espejo aceptada con cifra no cubre una entrada que no enseñó")
    }

    /// **El motivo se mide en el gesto**: lo aceptado solo vale si el bloqueo de ESTE intento sigue siendo uno de los tres.
    @Test func continuesDiscarding_needsAnOfferingReasonNow_andACoveringAcceptance() {
        let a = UUID()
        let now = Loss(rows: [a], mirrorKeys: [])
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            #expect(CloudSignOutFlowLogic.freshStartContinuesDiscarding(reason: reason, now: now, accepted: now)
                    == CloudSignOutFlowLogic.freshStartOffersGroupsLossExit(reason), "\(reason)")
        }
        #expect(!CloudSignOutFlowLogic.freshStartContinuesDiscarding(reason: .sessionExpired, now: now, accepted: nil),
                "sin aceptar nada, nada se pierde")
        #expect(!CloudSignOutFlowLogic.freshStartContinuesDiscarding(
            reason: .sessionExpired, now: Loss(rows: [a, UUID()], mirrorKeys: []), accepted: now))
    }
}

// MARK: - 2. El servicio y el cinturón

@MainActor
@Suite("«Empezar de cero y perderlos» · la oferta, lo aceptado y el cinturón", .serialized, .wipeAppGroupMirrorIsolated)
struct FreshStartGroupsLossServiceTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock
    typealias Loss = CloudSignOutFlowLogic.FreshStartGroupsLoss

    private func liveRow(_ group: String = "g1") -> GroupSyncOutbox {
        GroupSyncOutbox(
            syncID: UUID(), groupID: group, entityType: "SplitExpense",
            op: .upsert, hlc: "hlc", fieldsJSON: "{\"amount\":300}", author: "a",
            rejectedReason: nil)
    }

    private func clearOutbox(_ context: ModelContext) throws {
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
    }

    /// Un espejo con estas entradas fuera del outbox, y la captura terminada.
    private func witness(mirror keys: Set<String>) -> CloudSessionSignOut.GroupsExitWitness {
        CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in true },
            mirrorPending: { _, _ in keys.count },
            mirrorPendingKeys: { _, _ in keys })
    }

    /// Ninguna prueba hereda la oferta ni lo aceptado de otra: el coordinador es un singleton.
    private func resetCoordinator(_ context: ModelContext) {
        _ = CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: .quiet)
    }

    /// **Con un motivo que ofrece la salida, el bloqueo cuenta lo que el borrado se llevaría**: las filas vivas Y las
    /// entradas del espejo. Antes enseñaba solo lo que devolvía la subida, y el borrado purga el espejo entero.
    @Test(arguments: [CloudSignOutFlowLogic.BlockReason.sessionExpired, .permanent, .attestUnavailable])
    func offeringReason_blocksWithTheWholeLoss_andRecordsTheOffer(reason: CloudSignOutFlowLogic.BlockReason) throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        context.insert(liveRow("g1"))
        context.insert(liveRow("g2"))
        try context.save()

        let verdict = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 2, reason: reason), accepted: nil, context: context, witness: witness(mirror: ["m1"]))

        #expect(verdict == .blocked(Block(pendingCount: 3, reason: reason)), "dos filas y una entrada del espejo")
        #expect(CloudSessionSignOut.shared.freshStartGroupsBlock == Block(pendingCount: 3, reason: reason))
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "la oferta quedó anotada para el «¿seguro?»")
        try clearOutbox(context)
        resetCoordinator(context)
    }

    /// **Con cualquier otro motivo, el bloqueo de siempre**: su cifra, su texto, y ninguna oferta que aceptar. Y lo
    /// aceptado en un intento anterior NO lo convierte en pérdida: con esos motivos, otro intento los sube.
    @Test(arguments: CloudSignOutFlowLogic.BlockReason.allCases.filter {
        !CloudSignOutFlowLogic.freshStartOffersGroupsLossExit($0)
    })
    func nonOfferingReason_keepsTheBlock_andIgnoresAnAcceptance(reason: CloudSignOutFlowLogic.BlockReason) throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let row = liveRow()
        context.insert(row)
        try context.save()
        let accepted = Loss(rows: [row.clientMutationID], mirrorKeys: [])

        let verdict = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: reason), accepted: accepted, context: context, witness: .quiet)

        #expect(verdict == .blocked(Block(pendingCount: 1, reason: reason)))
        #expect(!CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "sin oferta: el botón no tiene qué aceptar")
        try clearOutbox(context)
    }

    /// **Aceptado y cubierto: sigue perdiendo exactamente eso.**
    @Test func offeringReason_withACoveringAcceptance_proceedsWithTheLoss() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let row = liveRow()
        context.insert(row)
        try context.save()
        let accepted = Loss(rows: [row.clientMutationID], mirrorKeys: ["m1"])

        let verdict = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: .sessionExpired), accepted: accepted, context: context,
            witness: witness(mirror: ["m1"]))

        #expect(verdict == .lossAccepted(accepted))
        try clearOutbox(context)
    }

    /// **Un cambio que el aviso no enseñó hace volver el aviso**, con la cifra nueva: nada se pierde sin haberse contado.
    @Test func offeringReason_withANewRow_offersAgainWithTheNewCount() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let shown = liveRow()
        context.insert(shown)
        context.insert(liveRow("g2"))
        try context.save()
        let accepted = Loss(rows: [shown.clientMutationID], mirrorKeys: [])

        let verdict = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 2, reason: .attestUnavailable), accepted: accepted, context: context, witness: .quiet)

        #expect(verdict == .blocked(Block(pendingCount: 2, reason: .attestUnavailable)))
        try clearOutbox(context)
        resetCoordinator(context)
    }

    /// **Lo aceptado vale para UN intento.** El borrado lo toma al empezar y lo retira, salga como salga: una espera del
    /// import que se agota no puede dejarlo vivo para un gesto posterior. Y sin oferta viva, aceptar no deja nada.
    @Test func acceptance_isTakenOnceByTheWipe() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        #expect(!CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "sin oferta no hay nada que aceptar")
        #expect(CloudSessionSignOut.shared.freshStartAcceptedLoss == nil)

        context.insert(liveRow())
        try context.save()
        _ = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: .sessionExpired), accepted: nil, context: context, witness: .quiet)
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())
        #expect(CloudSessionSignOut.shared.freshStartAcceptedLoss != nil, "control: lo aceptado está puesto")

        let taken = CloudSessionSignOut.shared.takeFreshStartAcceptedLoss()
        #expect(taken != nil, "el borrado recibe lo aceptado")
        #expect(CloudSessionSignOut.shared.freshStartAcceptedLoss == nil, "y ya no queda para otro")
        #expect(CloudSessionSignOut.shared.takeFreshStartAcceptedLoss() == nil, "un segundo borrado no lo hereda")

        try clearOutbox(context)
        let verdict = await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: .quiet, accepted: taken)
        #expect(verdict == .drained, "subió todo: no se pierde nada aunque se aceptara perderlo")
        #expect(!CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "y la oferta se fue con el intento")
    }

    /// **Lo que un drain a medias dejó en el History no se puede aceptar perder** (review adversarial del 2026-09-26): el
    /// ciclo solo re-captura tras un bloqueo por App Attest, así que con `.sessionExpired` o `.permanent` ese gasto no
    /// estaba ni en las filas ni en el espejo, y el aviso no lo contaba. Con la captura a medias el bloqueo sale sin salida
    /// de pérdida, también con algo aceptado; con la captura completa, la oferta de siempre.
    @Test(arguments: [CloudSignOutFlowLogic.BlockReason.sessionExpired, .permanent, .attestUnavailable])
    func offeringReason_withAnUnfinishedCapture_blocksWithoutTheExit(reason: CloudSignOutFlowLogic.BlockReason) throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let row = liveRow()
        context.insert(row)
        try context.save()
        let unfinished = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in false }, mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })

        let verdict = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: reason),
            accepted: Loss(rows: [row.clientMutationID], mirrorKeys: []), context: context, witness: unfinished)

        #expect(verdict == .blocked(Block(pendingCount: 1, reason: .uploadRetryLater)))
        #expect(!CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "sin oferta: no se enseñó todo")
        try clearOutbox(context)
    }

    /// Un intento nuevo del alert del shell tampoco hereda lo aceptado.
    @Test func settledEmptyPreCheck_dropsTheOfferAndTheAcceptance() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        context.insert(liveRow())
        try context.save()
        _ = CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: .permanent), accepted: nil, context: context, witness: .quiet)
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())

        _ = CloudSessionSignOut.shared.groupsOutboxIsSettledEmpty(context: context, witness: .quiet)
        #expect(CloudSessionSignOut.shared.freshStartAcceptedLoss == nil)
        #expect(!CloudSessionSignOut.shared.acceptFreshStartGroupsLoss())
        try clearOutbox(context)
    }

    /// **La entrada `.wipeDevice` solo borra una vez por «sí»**: el permiso lo da el tap del alert del shell y se gasta al
    /// leerlo. Sin él —un camino futuro que reabra el Welcome en ese paso— la puerta no borra.
    @Test func deviceWipeHandoff_isSingleUse() {
        _ = WelcomePrivateICloudGateView.consumeDeviceWipeHandoff()
        #expect(!WelcomePrivateICloudGateView.consumeDeviceWipeHandoff(), "sin tap no hay permiso")
        WelcomePrivateICloudGateView.armDeviceWipeHandoff()
        #expect(WelcomePrivateICloudGateView.consumeDeviceWipeHandoff())
        #expect(!WelcomePrivateICloudGateView.consumeDeviceWipeHandoff(), "un segundo montaje no lo hereda")
    }

    // MARK: El cinturón del escritor

    /// **Sin aceptar nada, el cinturón de siempre**: la fila viva no se tira.
    @Test func belt_withoutAcceptance_refuses() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        context.insert(liveRow())
        try context.save()
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 1)) {
            try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: .quiet, accepting: nil)
        }
        try clearOutbox(context)
    }

    /// **Con lo aceptado, deja pasar eso y nada más**: una fila apuntada después lanza, con la cifra de ahora.
    @Test func belt_withAcceptance_passesExactlyWhatWasAccepted() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let row = liveRow()
        context.insert(row)
        try context.save()
        let accepted = Loss(rows: [row.clientMutationID], mirrorKeys: ["m1"])
        try DataWipeService.requireNoUnsentGroupWrites(in: context, witness: witness(mirror: ["m1"]), accepting: accepted)

        // Una fila aceptada más dos entradas del espejo, una que el aviso no enseñó: lanza con las tres.
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 3)) {
            try DataWipeService.requireNoUnsentGroupWrites(
                in: context, witness: witness(mirror: ["m1", "m2"]), accepting: accepted)
        }
        context.insert(liveRow("g2"))
        try context.save()
        #expect(throws: DataWipeService.GroupsDomainWipeError.unsentGroupWrites(pendingCount: 3)) {
            try DataWipeService.requireNoUnsentGroupWrites(
                in: context, witness: witness(mirror: ["m1"]), accepting: accepted)
        }
        try clearOutbox(context)
    }

    /// **El borrado del dominio con lo aceptado se lleva las filas**: es lo único que la salida hace distinto.
    @Test func domainWipe_withAcceptance_deletesTheAcceptedRows() throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        let row = liveRow()
        context.insert(row)
        try context.save()
        let defaults = makeIsolatedDefaults()

        try DataWipeService.wipeLocalGroupsDomain(
            in: context, defaults: defaults, retireCloudSession: {}, resetSyncState: {}, witness: .quiet,
            acceptedGroupsLoss: Loss(rows: [row.clientMutationID], mirrorKeys: []))

        #expect(try context.fetchCount(FetchDescriptor<GroupSyncOutbox>()) == 0)
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsDomainSealedForFreshStart), "el relevo ocurrió entero")
    }

    // MARK: El copy

    /// **Cada motivo que ofrece la salida tiene su texto**, distinto del del cierre de sesión: el de `.sessionExpired`
    /// era «vuelve a iniciar sesión», y en un iPhone heredado esa cuenta no es de quien empieza de cero.
    @Test func message_offeringReasons_explainAndOffer_othersKeepTheSignOutText() {
        for reason in CloudSignOutFlowLogic.BlockReason.allCases {
            let block = Block(pendingCount: 2, reason: reason)
            let message = SignOutBlockedCopy.freshStartGroupsPendingMessage(block)
            #expect(message.hasPrefix(L10n.Groups.FreshStartPending.lead(2)), "\(reason)")
            let signOutTail = SignOutBlockedCopy.message(for: reason)
            #expect(message.hasSuffix(signOutTail) != block.offersLossExit, "\(reason)")
        }
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(Block(pendingCount: 2, reason: .sessionExpired))
                .hasSuffix(L10n.Groups.FreshStartPending.lossSessionExpired))
        #expect(!SignOutBlockedCopy.freshStartGroupsPendingMessage(Block(pendingCount: 2, reason: .sessionExpired))
                .contains(L10n.Groups.Errors.sessionExpired))
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(Block(pendingCount: 2, reason: .permanent))
                .hasSuffix(L10n.Groups.FreshStartPending.lossPermanent))
        #expect(SignOutBlockedCopy.freshStartGroupsPendingMessage(Block(pendingCount: 2, reason: .attestUnavailable))
                .hasSuffix(L10n.Groups.FreshStartPending.lossAttest))
    }

    /// El «¿seguro?» dice la cifra que se acepta, o ninguna si no hay número honesto.
    @Test func confirmMessage_carriesTheCount_orNone() {
        #expect(SignOutBlockedCopy.freshStartGroupsLossConfirmMessage(Block(pendingCount: 3, reason: .permanent))
                == L10n.Groups.FreshStartPending.lossConfirmBody(3))
        let unknown = SignOutBlockedCopy.freshStartGroupsLossConfirmMessage(Block(pendingCount: Int.max, reason: .permanent))
        #expect(unknown == L10n.Groups.FreshStartPending.lossConfirmBodyUnknown)
        #expect(!unknown.contains(String(Int.max)))
    }
}

// MARK: - 3. El cableado de las pantallas

/// El «¿seguro?», «Mejor no» y «Dejarlo por ahora» en las dos pantallas con fases, y el alert del shell (source-scan,
/// molde `FreshStartUnsentGroupWritesWiringTests`). Un test de comportamiento no llega: el camino entero arrastra CloudKit,
/// la red y tres vistas.
@Suite("«Empezar de cero y perderlos» · cableado de las pantallas (source-scan)")
struct FreshStartGroupsLossWiringTests {

    private static let gate = "Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift"
    private static let late = "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"
    private static let shell = "Yala/App/Views/Shared/ShellDataAlertsModifier.swift"
    private static let container = "Yala/App/Views/Onboarding/WelcomeFlowContainer.swift"
    private static let contentView = "Yala/App/ContentView.swift"

    private static func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Desde `marker` hasta el siguiente marcador de declaración al mismo nivel (o el final).
    private static func slice(from marker: String, to end: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no está: \(marker)")
        let rest = source[start.upperBound...]
        let stop = rest.range(of: end)?.lowerBound ?? rest.endIndex
        return String(rest[..<stop])
    }

    /// **El único sitio que acepta la pérdida es el botón destructivo del «¿seguro?»**, uno por pantalla. Un tercer
    /// llamador —el aviso, un «Reintentar»— perdería cambios sin segunda confirmación.
    @Test func onlyTheConfirmStepAccepts() throws {
        let gate = try Self.source(Self.gate)
        let late = try Self.source(Self.late)
        #expect(gate.components(separatedBy: "acceptFreshStartGroupsLoss()").count - 1 == 1)
        #expect(late.components(separatedBy: "acceptFreshStartGroupsLoss()").count - 1 == 1)

        let gateConfirm = try Self.slice(from: "private func groupsLossConfirmContent(", to: "private static func wipePhase",
                                         in: gate)
        let accept = try #require(gateConfirm.range(of: "acceptFreshStartGroupsLoss()"))
        let relaunch = try #require(gateConfirm.range(of: "phase = Self.wipePhase(for: retry)"))
        #expect(accept.lowerBound < relaunch.lowerBound, "acepta ANTES de relanzar el borrado que lo consume")
        #expect(gateConfirm.contains("L10n.Groups.FreshStartPending.lossConfirmAction"))

        let lateConfirm = try Self.slice(from: "case .confirmingGroupsLoss(let block):", to: "case .groupsPending(let block):",
                                         in: late)
        let lateAccept = try #require(lateConfirm.range(of: "acceptFreshStartGroupsLoss()"))
        let lateRelaunch = try #require(lateConfirm.range(of: "phase = .wiping"))
        #expect(lateAccept.lowerBound < lateRelaunch.lowerBound)
    }

    /// **«Mejor no» vuelve al aviso sin aceptar nada**, y el aviso solo lleva al «¿seguro?»: cancelar en cualquiera de
    /// los dos pasos deja todo como estaba.
    @Test func cancelling_neverAccepts() throws {
        let gate = try Self.source(Self.gate)
        let offer = try Self.slice(from: "private func groupsLossOfferContent(", to: "/// **El «¿seguro?»**", in: gate)
        #expect(!offer.contains("acceptFreshStartGroupsLoss"))
        #expect(offer.contains("leaveGate()"), "«Dejarlo por ahora» sale de la puerta")
        #expect(offer.contains("phase = .confirmingGroupsLoss(block, retry: retry)"))
        let confirm = try Self.slice(from: "private func groupsLossConfirmContent(", to: "private static func wipePhase",
                                     in: gate)
        #expect(confirm.contains("phase = .groupsPending(block, retry: retry)"), "«Mejor no» vuelve al aviso")

        let late = try Self.source(Self.late)
        let lateOffer = try Self.slice(from: "case .groupsPending(let block) where block.offersLossExit:",
                                       to: "case .confirmingGroupsLoss(let block):", in: late)
        #expect(!lateOffer.contains("acceptFreshStartGroupsLoss"))
        #expect(lateOffer.contains("primaryAction: leaveGroupsPending"))
        #expect(lateOffer.contains("destructiveAction: { phase = .confirmingGroupsLoss(block) }"))
        let lateConfirm = try Self.slice(from: "case .confirmingGroupsLoss(let block):", to: "case .groupsPending(let block):",
                                         in: late)
        #expect(lateConfirm.contains("primaryAction: { phase = .groupsPending(block) }"))
    }

    /// **La oferta solo se pinta con un motivo que la ofrece**: el caso con guarda va antes que el genérico.
    @Test func theOfferIsGuardedByTheReason() throws {
        let gate = try Self.source(Self.gate)
        let guarded = try #require(gate.range(of: "case .groupsPending(let block, let retry) where block.offersLossExit:"))
        let generic = try #require(gate.range(of: "case .groupsPending(let block, let retry):\n"))
        #expect(guarded.lowerBound < generic.lowerBound)

        let late = try Self.source(Self.late)
        let lateGuarded = try #require(late.range(of: "case .groupsPending(let block) where block.offersLossExit:"))
        let lateGeneric = try #require(late.range(of: "case .groupsPending(let block):\n"))
        #expect(lateGuarded.lowerBound < lateGeneric.lowerBound)
    }

    /// **Irse desde el «¿seguro?» también desarma**, como desde el aviso: no se borró nada.
    @Test func leavingFromTheConfirmStepDisarms() throws {
        let gate = try Self.source(Self.gate)
        let pending = try Self.slice(from: "private var isGroupsPending: Bool {", to: "\n    }\n", in: gate)
        #expect(pending.contains(".confirmingGroupsLoss"))
        let late = try Self.source(Self.late)
        let latePending = try Self.slice(from: "private var isGroupsPending: Bool {", to: "\n    }\n", in: late)
        #expect(latePending.contains(".confirmingGroupsLoss"))
        #expect(late.contains("if isGroupsPending {\n                                leaveGroupsPending()"),
                "la barra desde «faltan cambios» hace lo de «Dejarlo por ahora»: sin `onKeep`, que retira el testigo")
    }

    /// **Lo aceptado llega hasta los dos cinturones** en los dos borrados de `ContentView`: si uno lo perdiera por el
    /// camino, lanzaría con las filas aceptadas; si lo pasara sin venir de la subida, perdería sin confirmar.
    @Test func contentView_threadsTheAcceptanceToBothBelts() throws {
        let src = try Self.source(Self.contentView)
        let device = try Self.slice(from: "private func performDeviceCorpusWipe() async -> String? {",
                                    to: "/// Post-checks de returning user", in: src)
        #expect(device.contains("case .proceed(let accepted): acceptedGroupsLoss = accepted"))
        #expect(device.contains("requireNoUnsentGroupWrites(in: modelContext, accepting: acceptedGroupsLoss)"))
        #expect(device.contains("wipeLocalGroupsDomain(in: modelContext, acceptedGroupsLoss: acceptedGroupsLoss)"))

        let icloud = try Self.slice(from: "private func performICloudCorpusWipe(_ scope: ICloudWipeScope) async -> String? {",
                                    to: "private func drainGroupsBeforeFreshStart()", in: src)
        #expect(icloud.contains("case .proceed(let accepted): acceptedGroupsLoss = accepted"))
        #expect(icloud.contains("requireNoUnsentGroupWrites(in: modelContext, accepting: acceptedGroupsLoss)"))
        #expect(icloud.contains("wipeLocalGroupsDomain(in: modelContext, acceptedGroupsLoss: acceptedGroupsLoss)"))

        let wrapper = try Self.slice(from: "private func drainGroupsBeforeFreshStart(\n        accepted acceptedInGesture:",
                                     to: "private enum FreshStartGroupsUpload", in: src)
        #expect(wrapper.contains("drainGroupsBeforeFreshStart(\n            context: modelContext, accepted: acceptedInGesture)"))

        // **Lo aceptado se toma ANTES del primer `await` de cada borrado**: consumido más tarde, una espera del import que
        // se agota lo dejaba vivo para un gesto posterior por otra pantalla (review adversarial del 2026-09-26).
        for body in [device, icloud] {
            let take = try #require(body.range(of: "let acceptedInGesture = CloudSessionSignOut.shared.takeFreshStartAcceptedLoss()"))
            let firstAwait = try #require(body.range(of: "await "))
            #expect(take.lowerBound < firstAwait.lowerBound)
            #expect(body.contains("switch await drainGroupsBeforeFreshStart(accepted: acceptedInGesture) {"))
        }
        #expect(wrapper.contains("case .lossAccepted(let loss): accepted = loss"))
        #expect(wrapper.contains("case .blocked: return .stop(CloudSessionSignOut.freshStartGroupsPendingFailure)"))
    }

    /// **El alert del shell, con cambios pendientes, sigue en la puerta** y no se niega en el sitio: allí se suben y, si
    /// no pueden, se ofrece perderlos. Sin pendientes borra en el mismo tap, como siempre.
    @Test func shellAlert_continuesInTheGate() throws {
        let src = try Self.source(Self.shell)
        let button = try Self.slice(from: "Button(L10n.Welcome.FreshStart.alertConfirm, role: .destructive) {",
                                    to: "Button(L10n.Action.cancel, role: .cancel) {", in: src)
        #expect(button.contains("performFreshStartWipe()"))
        #expect(button.contains("continueInTheGateWhileGroupsArePending()"))
        #expect(!button.contains("refuseWhileGroupsArePending()"))

        let route = try Self.slice(from: "private func continueInTheGateWhileGroupsArePending() {",
                                   to: "\n    }\n", in: src)
        #expect(route.contains("welcomeFlowInitialStep = .freshStartDeviceWipe"))
        #expect(route.contains("showWelcomeFlow = true"))

        // El permiso de un uso va ANTES de abrir la puerta, en el mismo tap.
        let arm = try #require(route.range(of: "WelcomePrivateICloudGateView.armDeviceWipeHandoff()"))
        let open = try #require(route.range(of: "welcomeFlowInitialStep = .freshStartDeviceWipe"))
        #expect(arm.lowerBound < open.lowerBound)

        // Y la puerta no borra al montarse sin gastarlo: sin él vuelve atrás.
        let gate = try Self.source(Self.gate)
        let entry = try Self.slice(from: "case .checking where entry == .wipeDevice:", to: "case .checking: await measure()",
                                   in: gate)
        let consume = try #require(entry.range(of: "guard Self.consumeDeviceWipeHandoff() else {"))
        let wipe = try #require(entry.range(of: "phase = .wipingDevice(iCloudUnverified: unverified)"))
        #expect(entry.contains("let unverified = StorageModePersistence.privateChoseWithoutICloud()"),
                "el testigo del espejo tardío sale de lo que dejó la puerta, no de un literal")
        #expect(consume.lowerBound < wipe.lowerBound)
        #expect(entry.contains("onBack()"))

        let container = try Self.source(Self.container)
        let step = try Self.slice(from: "case .freshStartDeviceWipe:", to: "case .mirrorRelaunch:", in: container)
        #expect(step.contains("entry: .wipeDevice"))
        #expect(step.contains("wipe: { await performDeviceCorpusWipe() }"))
    }
}
