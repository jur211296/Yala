//
//  FreshStartSplitCopyTests.swift
//  YalaTests / CloudSync
//
//  Ticket `fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason` (decisión A de Jürgen, 2026-10-05).
//  Desde el 2026-10-05 «Empezar de cero» cuenta también los cambios de grupos de OTRA cuenta que guarda el teléfono. Cuando
//  además hay cambios tuyos que no suben por otro motivo, la cifra sumaba las dos clases y el texto explicaba solo el
//  motivo de los tuyos: con tu cuenta no disponible decía que «volver a intentarlo no lo va a arreglar» también de los de
//  la otra cuenta, y con un motivo pasajero prometía que esperar subía N cambios cuando solo subía los tuyos.
//
//  Los tests de gesto corren con el espejo REAL en un directorio temporal, el filtro REAL de cada alcance y las filas
//  retenidas contadas con la regla REAL de dueño (`GroupsSyncClient.liveRowsHeldForAnotherAccount`): lo que decide el
//  texto es cuántos de cada clase cuenta cada sitio.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("«Empezar de cero» separa los cambios tuyos de los de otra cuenta", .serialized, .wipeAppGroupMirrorIsolated)
struct FreshStartSplitCopyTests {

    typealias Block = CloudSessionSignOut.FreshStartGroupsBlock
    typealias Copy = SignOutBlockedCopy
    typealias Text = L10n.Groups.FreshStartPending

    // MARK: - Montaje

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FSSplit-\(UUID().uuidString)", isDirectory: true)
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

    /// Filas vivas del outbox con su dueño: `sub-a` es la sesión, `sub-b` otra cuenta.
    private func rows(own: Int, foreign: Int, in context: ModelContext) throws {
        for _ in 0..<own { context.insert(row(owner: "sub-a")) }
        for _ in 0..<foreign { context.insert(row(owner: "sub-b")) }
        try context.save()
    }

    private func row(owner: String) -> GroupSyncOutbox {
        GroupSyncOutbox(syncID: UUID(), groupID: "g1", entityType: "SplitExpense", op: .upsert, hlc: "hlc",
                        fieldsJSON: "{\"amount\":300}", author: "a", rejectedReason: nil, ownerUserID: owner)
    }

    /// El testigo con el espejo, el filtro y la regla de dueño REALES y la sesión `owner` (`nil` = sin sesión). La captura
    /// termina, el History no esconde nada y el canal está sano.
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
        witness.heldForAnotherAccount = { context in
            GroupsSyncClient.liveRowsHeldForAnotherAccount(sessionOwner: owner, context: context)
        }
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

    private func blocked(_ verdict: CloudSessionSignOut.FreshStartGroupsDrain) -> Block? {
        guard case .blocked(let block) = verdict else { return nil }
        return block
    }

    // MARK: - Caso 1: tu cuenta no está disponible y hay cambios de otra cuenta

    /// **El único caso en que alguien podía aceptar perder cambios recuperables creyendo que no tenían arreglo.** Una
    /// fila tuya, una fila retenida de otra cuenta, una entrada tuya del espejo y dos de otra cuenta, con `.permanent`.
    /// El aviso dice 2 tuyos y 3 de otra cuenta, y «volver a intentarlo no lo va a arreglar» solo de los tuyos.
    @Test func permanent_withAnotherAccount_splitsTheCountAndTheReason() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        defer { try? clearOutbox(context) }
        let dir = freshDir(); defer { cleanup(dir) }
        try rows(own: 1, foreign: 1, in: context)
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let verdict = await CloudSessionSignOut.shared.settleFreshStartBlock(
            Block(pendingCount: 1, reason: .permanent, readsUncaptured: false, anotherAccountCount: 0), accepted: nil,
            context: context, witness: witness(mirror, owner: "sub-a"))
        let block = try #require(blocked(verdict))
        #expect(block.pendingCount == 5, "la cifra total no cambia: lo que el borrado se lleva")
        #expect(block.offersLossExit, "la salida sigue en pantalla")

        let message = Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true)
        #expect(!message.contains(Text.lossPermanent), "el «no tiene arreglo» no puede cubrir los de la otra cuenta")
        #expect(!message.contains(Text.lead(5)), "«tus grupos» con cambios de otra cuenta")
        #expect(Copy.freshStartGroupsLossConfirmMessage(block) != Text.lossConfirmBody(5))

        // El verde exacto: 2 tuyos y 3 de otra cuenta, cada parte con su motivo, y la cola del botón (que pierde los dos).
        #expect(block.anotherAccountCount == 3, "la fila retenida y las dos entradas ajenas")
        #expect(block.copyShape == .mixed(own: 2, anotherAccount: 3))
        #expect(message == [Text.leadSplit(own: 2, anotherAccount: 3), Text.splitOwnPermanent, Text.splitAnotherAccount,
                            Text.splitLossTail].joined(separator: " "))
        #expect(Copy.freshStartGroupsLossConfirmMessage(block) == Text.lossConfirmBodySplit(own: 2, anotherAccount: 3))
        #expect(Copy.freshStartGroupsPendingTitle(block) == Text.titleNeutral)
    }

    // MARK: - Caso 2: un motivo pasajero y cambios de otra cuenta

    /// **Esperar sube los tuyos, no los suyos.** Una entrada tuya del espejo que no se rehidrató (la subida dice
    /// «inténtalo en un rato») y dos de otra cuenta: el texto no puede prometer que esperar sube 3.
    @Test func retryLater_withAnotherAccount_doesNotPromiseWaitingFixesTheirs() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let block = try #require(blocked(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))))
        #expect(block.pendingCount == 3)
        #expect(block.reason == .uploadRetryLater)
        #expect(!block.offersLossExit)

        let message = Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true)
        #expect(message != Text.lead(3) + " " + L10n.Groups.Errors.uploadRetryLater,
                "la cifra suma los de la otra cuenta y el texto promete que esperar los sube")
        #expect(!message.contains(Text.lead(3)))

        // El verde exacto: el «inténtalo en un rato» es de los tuyos; los suyos no suben esperando, y sin botón se dice
        // cuándo se podrá perder solo esos.
        #expect(block.anotherAccountCount == 2)
        #expect(message == [Text.leadSplit(own: 1, anotherAccount: 2), L10n.Groups.Errors.uploadRetryLater,
                            Text.splitAnotherAccount, Text.splitAfterOwnUpload].joined(separator: " "))
        #expect(!message.contains(Text.splitLossTail), "sin la salida en pantalla, no se ofrece perderlos")
    }

    /// **Lo que el texto promete se recorre**: cuando suben los tuyos, el intento siguiente ofrece perder SOLO los de otra
    /// cuenta. Mismo espejo sin la entrada propia (la subió el reintento): «otra cuenta», con la salida y la cifra de 2.
    @Test func afterOwnUpload_theNextAttemptOffersToLoseOnlyTheirs() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 0, foreign: 2, in: dir)
        let block = try #require(blocked(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))))
        #expect(block.reason == .groupsChangesFromAnotherAccount)
        #expect(block.offersLossExit)
        #expect(block.pendingCount == 2)
        #expect(CloudSessionSignOut.shared.acceptFreshStartGroupsLoss(), "la oferta de perder solo esos quedó anotada")
    }

    // MARK: - Caso 3: solo cambios de otra cuenta, con tu sesión abierta

    /// **«Tus grupos» cuando no son tuyos.** Dos entradas de otra cuenta y la sesión abierta.
    @Test func onlyAnotherAccount_doesNotSayYours() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 2, in: dir)
        let block = try #require(blocked(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))))
        #expect(block.reason == .groupsChangesFromAnotherAccount)
        #expect(!Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true).contains(Text.lead(2)))
        #expect(Copy.freshStartGroupsLossConfirmMessage(block) != Text.lossConfirmBody(2))

        // El verde exacto: sin «tus», y el texto de otra cuenta sin número de cuentas.
        #expect(block.copyShape == .anotherAccount)
        #expect(Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true) == Text.leadNeutral(2) + " " + Text.lossOtherAccount)
        #expect(Copy.freshStartGroupsLossConfirmMessage(block) == Text.lossConfirmBodyNeutral(2))
        #expect(Copy.freshStartGroupsPendingTitle(block) == Text.titleNeutral)
    }

    // MARK: - Controles: con una sola clase de lo tuyo, el texto de hoy

    /// **Solo tuyos**: el texto de siempre, con «tus grupos» y su motivo.
    @Test func control_onlyYours_keepsTodaysText() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 2, foreign: 0, in: dir)
        let block = try #require(blocked(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a"))))
        #expect(block.reason == .uploadRetryLater)
        #expect(Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true) == Text.lead(2) + " " + L10n.Groups.Errors.uploadRetryLater)
        #expect(Copy.freshStartGroupsPendingTitle(block) == Text.title)
    }

    /// **Sin sesión no hay «otra cuenta»**: el texto de la sesión que ya no está, con «tus grupos», como antes.
    @Test func control_signedOut_keepsTodaysText() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(own: 1, foreign: 2, in: dir)
        let block = try #require(blocked(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: nil))))
        #expect(block.reason == .sessionExpired)
        #expect(Copy.freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true) == Text.lead(3) + " " + Text.lossSessionExpired)
        #expect(Copy.freshStartGroupsLossConfirmMessage(block) == Text.lossConfirmBody(3))
    }

    /// **Sin nada pendiente, ni aviso**.
    @Test func control_nothingPending_drains() async throws {
        let context = try makeTestContext()
        try clearOutbox(context)
        resetCoordinator(context)
        let dir = freshDir(); defer { cleanup(dir) }
        let mirror = try mirror(foreign: 0, in: dir)
        #expect(await CloudSessionSignOut.shared.drainGroupsBeforeFreshStart(
            context: context, witness: witness(mirror, owner: "sub-a")) == .drained)
    }

    // MARK: - La forma del texto, en puro

    private func block(_ pending: Int, another: Int, _ reason: CloudSignOutFlowLogic.BlockReason,
                       readsUncaptured: Bool = false) -> Block {
        Block(pendingCount: pending, reason: reason, readsUncaptured: readsUncaptured, anotherAccountCount: another)
    }

    /// La tabla entera: sin nada ajeno, la de siempre; con el motivo «otra cuenta», sin «tus»; con las dos clases,
    /// partida; sin cifra, sin partir; con la parte tuya a cero, como «otra cuenta».
    @Test func shape_table() {
        typealias L = CloudSignOutFlowLogic
        #expect(L.freshStartGroupsCopyShape(pendingCount: 3, anotherAccountCount: 0, reason: .permanent) == .own)
        #expect(L.freshStartGroupsCopyShape(pendingCount: 3, anotherAccountCount: 0,
                                            reason: .groupsChangesFromAnotherAccount) == .anotherAccount,
                "el motivo «otra cuenta» nunca dice «tus», aunque la cuenta de ajenos sea 0")
        #expect(L.freshStartGroupsCopyShape(pendingCount: 5, anotherAccountCount: 3, reason: .permanent)
                == .mixed(own: 2, anotherAccount: 3))
        #expect(L.freshStartGroupsCopyShape(pendingCount: 3, anotherAccountCount: 3, reason: .transient) == .anotherAccount)
        #expect(L.freshStartGroupsCopyShape(pendingCount: .max, anotherAccountCount: 3, reason: .permanent)
                == .mixed(own: nil, anotherAccount: nil))
        #expect(L.freshStartGroupsCopyShape(pendingCount: 5, anotherAccountCount: .max, reason: .permanent)
                == .mixed(own: nil, anotherAccount: nil))
        #expect(L.freshStartGroupsCopyShape(pendingCount: 2, anotherAccountCount: 1, reason: .transient)
                == .mixed(own: 1, anotherAccount: 1), "el vecino de abajo: un tuyo")
    }

    /// **Cada motivo, con las dos clases**: el de los tuyos va con su texto, nunca con el de la salida que habla de todos,
    /// y la cola depende de si hay botón.
    @Test(arguments: CloudSignOutFlowLogic.BlockReason.allCases.filter { $0 != .groupsChangesFromAnotherAccount })
    func mixed_everyReason_explainsEachHalf(_ reason: CloudSignOutFlowLogic.BlockReason) {
        let b = block(5, another: 2, reason)
        let message = Copy.freshStartGroupsPendingMessage(b, retryOffersTheLossExit: true)
        #expect(message.hasPrefix(Text.leadSplit(own: 3, anotherAccount: 2)))
        #expect(message.contains(Text.splitAnotherAccount))
        #expect(message.hasSuffix(b.offersLossExit ? Text.splitLossTail : Text.splitAfterOwnUpload))
        for whole in [Text.lossPermanent, Text.lossSessionExpired, Text.lossAttest, Text.lossOtherAccount] {
            #expect(!message.contains(whole), "un texto de la salida que habla de todos: \(reason)")
        }
        #expect(Copy.freshStartGroupsLossConfirmMessage(b) == Text.lossConfirmBodySplit(own: 3, anotherAccount: 2))
    }

    /// Los tres motivos con salida, uno a uno: el de los tuyos es el suyo.
    @Test func mixed_ownReasonPerExitReason() {
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .permanent), retryOffersTheLossExit: true).contains(Text.splitOwnPermanent))
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .sessionExpired), retryOffersTheLossExit: true)
                    .contains(Text.splitOwnSessionExpired))
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .attestUnavailable), retryOffersTheLossExit: true)
                    .contains(L10n.Groups.Errors.attestUnavailable))
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .channelPaused), retryOffersTheLossExit: true)
                    .contains(L10n.Groups.Errors.channelPaused))
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .groupsCaptureUnfinished), retryOffersTheLossExit: true)
                    .contains(L10n.Groups.Errors.captureUnfinished))
        #expect(Copy.freshStartGroupsPendingMessage(block(3, another: 1, .transient), retryOffersTheLossExit: true)
                    .contains(L10n.Settings.signOutPendingMessage))
    }

    /// Sin cifra no se parte: lead sin «tus» y sin número, el resto igual.
    @Test func mixed_unknownCount_neutralLead() {
        let b = block(.max, another: 2, .permanent)
        #expect(Copy.freshStartGroupsPendingMessage(b, retryOffersTheLossExit: true).hasPrefix(Text.leadNeutralUnknown + " " + Text.splitOwnPermanent))
        #expect(Copy.freshStartGroupsLossConfirmMessage(b) == Text.lossConfirmBodyNeutralUnknown)
        #expect(Copy.freshStartGroupsPendingTitle(b) == Text.titleNeutral)
    }

    /// La parte tuya a cero con otro motivo: el texto del motivo hablaría de lo tuyo, que no hay.
    @Test func anotherAccountOnly_withAnotherReason() {
        #expect(Copy.freshStartGroupsPendingMessage(block(2, another: 2, .permanent), retryOffersTheLossExit: true)
                == Text.leadNeutral(2) + " " + Text.lossOtherAccount)
        // Sin salida: el motivo hablaba de lo tuyo («tus grupos», «en un rato») y no hay nada tuyo (review, lente de copy).
        for reason in [CloudSignOutFlowLogic.BlockReason.uploadRetryLater, .channelPaused, .transient,
                       .groupsCaptureUnfinished] {
            #expect(Copy.freshStartGroupsPendingMessage(block(2, another: 2, reason), retryOffersTheLossExit: true)
                    == Text.leadNeutral(2) + " " + Text.splitAnotherAccount, "\(reason)")
        }
        // Sin App Attest, el del teléfono: es verdad para todos, y el botón está.
        #expect(Copy.freshStartGroupsPendingMessage(block(2, another: 2, .attestUnavailable), retryOffersTheLossExit: true)
                == Text.leadNeutral(2) + " " + Text.lossAttest)
        #expect(Copy.freshStartGroupsPendingMessage(block(2, another: 2, .sessionExpired), retryOffersTheLossExit: true)
                == Text.leadNeutral(2) + " " + Text.lossOtherAccount)
        #expect(Copy.freshStartGroupsPendingMessage(block(2, another: 0, .groupsChangesFromAnotherAccount,
                                                          readsUncaptured: true), retryOffersTheLossExit: true)
                == Text.leadNeutral(2) + " " + Text.lossOtherAccountAndCaptureUnfinished)
    }

    /// **El texto de otra cuenta ya no dice «esa cuenta»** (pueden ser varias), en ningún español.
    @Test func otherAccountText_doesNotAssumeOneAccount() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        for locale in ["es-419", "es-AR", "es-ES", "es"] {
            let url = root.appendingPathComponent("Yala/Resources/\(locale).lproj/Localizable.strings")
            let table = try #require(NSDictionary(contentsOf: url) as? [String: String])
            let text = try #require(table["groups.freshStartPending.lossOtherAccount"])
            #expect(!text.contains("esa cuenta"), "\(locale): \(text)")
            for key in ["leadSplit", "lossConfirmBodySplit", "splitAnotherAccount", "splitAfterOwnUpload", "titleNeutral",
                        "leadNeutral", "lossConfirmBodyNeutral", "lossConfirmBodyNeutralUnknown", "leadNeutralUnknown"] {
                let value = try #require(table["groups.freshStartPending.\(key)"], "\(locale) sin \(key)")
                #expect(!value.contains("tus grupos"), "\(locale).\(key) dice «tus grupos»")
                #expect(!value.contains("en un rato") && !value.contains("segundos"), "\(locale).\(key) promete plazo")
            }
        }
    }

    /// **El alert del shell no promete una salida que no tiene**: su reintento nunca ofrece perderlos, así que la cola
    /// «cuando suban los tuyos, podrás perder solo esos» no sale; el resto, igual.
    @Test func shellAlert_mixedWithoutTheExit_promisesNothing() {
        let b = block(3, another: 2, .uploadRetryLater)
        let shell = Copy.freshStartGroupsPendingMessage(b, retryOffersTheLossExit: false)
        #expect(shell == [Text.leadSplit(own: 1, anotherAccount: 2), L10n.Groups.Errors.uploadRetryLater,
                          Text.splitAnotherAccount].joined(separator: " "))
        #expect(!shell.contains(Text.splitAfterOwnUpload))
        // Control: la misma cifra en la puerta sí lo dice.
        #expect(Copy.freshStartGroupsPendingMessage(b, retryOffersTheLossExit: true).hasSuffix(Text.splitAfterOwnUpload))
        // Con la salida en pantalla el parámetro no cambia nada: la cola es la del botón.
        let offering = block(3, another: 2, .permanent)
        #expect(Copy.freshStartGroupsPendingMessage(offering, retryOffersTheLossExit: false)
                == Copy.freshStartGroupsPendingMessage(offering, retryOffersTheLossExit: true))
    }

    /// **Cada pantalla dice lo que ofrece su reintento**: la puerta y el aviso del espejo tardío, `true` (las dos
    /// llamadas de cada una); el alert del shell, `false`. Y las tres leen el título de `freshStartGroupsPendingTitle`.
    @Test func screens_passWhatTheirRetryOffers() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        func code(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
                .split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }
        for path in ["Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift",
                     "Yala/App/Views/Shared/LateICloudMirrorNoticeView.swift"] {
            let body = try code(path)
            #expect(body.components(separatedBy: "freshStartGroupsPendingMessage(block, retryOffersTheLossExit: true)")
                        .count - 1 == 2, "\(path)")
            #expect(body.components(separatedBy: "title: SignOutBlockedCopy.freshStartGroupsPendingTitle(block)")
                        .count - 1 == 2, "\(path)")
            #expect(!body.contains("L10n.Groups.FreshStartPending.title,"), "\(path) pinta el título con «tus»")
        }
        let shell = try code("Yala/App/Views/Shared/ShellDataAlertsModifier.swift")
        #expect(shell.contains("SignOutBlockedCopy.freshStartGroupsPendingMessage($0, retryOffersTheLossExit: false)"))
        #expect(shell.contains("freshStartGroupsBlock.map { SignOutBlockedCopy.freshStartGroupsPendingTitle($0) }"))
    }

    // MARK: - La parte de otra cuenta (review adversarial del 2026-10-05, lente de datos)

    private final class Reads { var history = 0 }

    private func countingWitness(held: Int, mirror: Int, history: [GroupsSyncClient.UncapturedChange]?,
                                 reads: Reads) -> CloudSessionSignOut.GroupsExitWitness {
        var witness = CloudSessionSignOut.GroupsExitWitness.quiet
        witness.heldForAnotherAccount = { _ in held }
        witness.mirrorPendingOfAnotherAccount = { _ in mirror }
        witness.uncapturedChanges = { _ in reads.history += 1; return history }
        return witness
    }

    /// **Lo del History que la cifra cuenta y el registro atribuye a otra cuenta es de otra cuenta**: sin esto, con el
    /// drain atascado y `.attestUnavailable`, «Tuyos: 3. Con otra cuenta: 1» cuando eran 1 y 3. Solo lo que la cifra
    /// contó (las claves de la pérdida), y sin leer el History si la cifra no lo leyó.
    @Test func anotherAccountCount_includesTheHistoryChangesOfAnotherAccount() throws {
        let context = try makeTestContext()
        typealias Change = GroupsSyncClient.UncapturedChange
        let history = [Change(key: "h1", heldForAnotherAccount: true, provenAnotherAccount: true),
                       Change(key: "h2", heldForAnotherAccount: false),
                       Change(key: "h3", heldForAnotherAccount: true)]
        let reads = Reads()
        let witness = countingWitness(held: 1, mirror: 2, history: history, reads: reads)
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(
            context: context, witness: witness, uncapturedKeys: ["h1", "h2"]) == 4,
                "1 fila retenida + 2 del espejo + h1 (h2 es tuyo; h3 no está en la cifra)")
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(context: context, witness: witness) == 3)
        #expect(reads.history == 1, "sin History en la cifra no se lee")
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(
            context: context, witness: witness, uncapturedKeys: nil) == .max, "la cifra no leyó el History: sin partir")
        let unreadable = countingWitness(held: 1, mirror: 0, history: nil, reads: Reads())
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(
            context: context, witness: unreadable, uncapturedKeys: ["h1"]) == .max, "el History ya no se deja leer")
        // Sin nada de otra cuenta conocido, un History sin leer no inventa otra cuenta: el texto de siempre.
        let nothingKnown = countingWitness(held: 0, mirror: 0, history: nil, reads: Reads())
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(
            context: context, witness: nothingKnown, uncapturedKeys: ["h1"]) == 0)
        #expect(CloudSessionSignOut.freshStartAnotherAccountCount(
            context: context, witness: nothingKnown, uncapturedKeys: nil) == 0)
    }

    /// **En la subida sin salida, con filas retenidas, la cifra no se parte**: la de la subida unas veces las incluye y
    /// otras no, y llamarlas «tuyas» sería falso. La cifra total no cambia.
    @Test func pushBlock_withHeldRows_doesNotSplit() throws {
        let context = try makeTestContext()
        let pushed = Block(pendingCount: 3, reason: .transient, readsUncaptured: false, anotherAccountCount: 0)
        let withHeld = CloudSessionSignOut.freshStartBlockCountingAnotherAccount(
            pushed, context: context, witness: countingWitness(held: 2, mirror: 1, history: [], reads: Reads()))
        #expect(withHeld.pendingCount == 4, "la cifra de siempre: la subida más el espejo ajeno")
        #expect(withHeld.copyShape == .mixed(own: nil, anotherAccount: nil))
        #expect(Copy.freshStartGroupsPendingMessage(withHeld, retryOffersTheLossExit: true)
                    .hasPrefix(Text.leadNeutral(4) + " "))
        // Control: sin filas retenidas sí se parte.
        let withoutHeld = CloudSessionSignOut.freshStartBlockCountingAnotherAccount(
            pushed, context: context, witness: countingWitness(held: 0, mirror: 1, history: [], reads: Reads()))
        #expect(withoutHeld.copyShape == .mixed(own: 3, anotherAccount: 1))
    }
}
