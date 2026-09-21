//
//  ReversePreMountExitLogicTests.swift
//  YalaTests / CloudSync
//
//  Lo PURO de la salida de las cuatro fases previas al montaje del espejo en «Volver a iCloud» (ticket
//  `reverse-before-mount-has-no-way-to-abandon-the-return`): qué fases cubre, qué presupuesto elige cada palabra
//  del servidor y qué texto ve la persona. El recorrido del runner vive en `MigrationRunnerTests`; las aristas, en
//  `MigrationStateMachineTests`; el cableado de la pantalla, en `ReverseUploadControllerWiringTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Vuelta a iCloud: salida antes del montaje · lógica pura")
@MainActor
struct ReversePreMountExitLogicTests {

    // MARK: - Qué fases cubre

    /// Las CUATRO anteriores al montaje, y solo esas. El `rawValue` es además el WIRE del canario de la sesión
    /// caducada (`cloudReverseBlockedByExpiredSession`), que existía antes de este ticket: renombrarlo rompería su
    /// serie, así que se afirma letra a letra.
    @Test func preMountPhase_mapsExactlyTheFourPhasesBeforeTheMount() {
        #expect(ReversePreMountPhase(phase: .reverseClaimLeader) == .claim)
        #expect(ReversePreMountPhase(phase: .reverseDrainAll) == .drain)
        #expect(ReversePreMountPhase(phase: .reverseVerify) == .verify)
        #expect(ReversePreMountPhase(phase: .reverseFreezeBackend) == .freeze)
        #expect([ReversePreMountPhase.claim, .drain, .verify, .freeze].map(\.rawValue)
            == ["claim", "drain", "verify", "freeze"], "el rawValue es WIRE de un canario que ya está en la flota")
    }

    /// Y ninguna otra — con `reverseUpload` y las POST-montaje nombradas una a una, porque son las que tientan: ahí
    /// el espejo YA está vivo, y salir sin re-armar su apagado dejaría `.cloud` + mirror montado.
    @Test func preMountPhase_isNilForEveryOtherPhase_postMountIncluded() {
        let others: [MigrationPhase] = [
            .notStarted, .dryRun, .consent, .authenticating, .waitingForLeader, .claimingMigration,
            .assigningIdentity, .uploadingSnapshot, .verifying,
            .cutover(.pending), .cutover(.serverConfirmed), .cutover(.localModeSet),
            .cutover(.markerWritten), .cutover(.mirrorOff),
            .done, .failedRollback,
            .reverseConfirm(.done), .reverseConfirm(.notStarted),
            .reverseMountMirror,
            .reverseReconcile(.awaitingQuiescence), .reverseReconcile(.deletingZombies),
            .reverseReconcile(.rebindingUUIDs), .reverseReconcile(.dedupHealed),
            .reverseUpload, .icloudActive, .reverseFailedRollback,
        ]
        for phase in others {
            #expect(ReversePreMountPhase(phase: phase) == nil, "\(phase) no es una fase previa al montaje")
        }
    }

    // MARK: - Qué presupuesto elige cada palabra del servidor

    /// Los tres motivos que llegan tipados son la palabra del SERVIDOR, así que los tres acortan. Es lo contrario
    /// del fail-open de `ReverseUploadBlocker`, donde la ambigüedad (un token de Drive ausente) nunca acortaba
    /// porque no era una respuesta.
    @Test func blocker_everyServerWordChoosesTheShortBudget() {
        for blocker: ReversePreMountBlocker in [.accountUnavailable, .otherLeader, .refused] {
            #expect(blocker.stallCause == .definitive, "\(blocker)")
        }
        // Y el contraste que le da sentido: la causa de la OTRA espera sí distingue, así que «todo definitivo» no
        // es una propiedad de la familia sino una decisión de ésta. Sin esta línea el caso afirmaba una constante.
        #expect(ReverseUploadBlocker.icloudOff.stallCause == .unknown)
        #expect(ReverseUploadBlocker.unknown.stallCause == .unknown)
    }

    /// Cada motivo con SU porqué. El del relevo NO reusa `otherDeviceReverting`, y ese es el hallazgo de una lente:
    /// ese texto dice «no pudimos EMPEZAR», y desde el congelado la vuelta ya había empezado — el mismo argumento
    /// por el que este ticket no reusa `claimRefused`, aplicado a la otra mitad.
    @Test func blocker_abortReason_perCase() {
        #expect(ReversePreMountBlocker.otherLeader.abortReason == .preMountOtherDevice)
        #expect(ReversePreMountBlocker.accountUnavailable.abortReason == .preMountRefused)
        #expect(ReversePreMountBlocker.refused.abortReason == .preMountRefused)
    }

    // MARK: - El texto

    /// Los dos motivos nuevos tienen texto PROPIO, resuelto (no la key cruda) y distinto del de cualquier otra
    /// salida. Lo segundo es lo que carga el peso: reusar el de `claimRefused` diría «ese intento no cambió nada»,
    /// y aquí el servidor sí llegó a conceder la reserva.
    @Test func note_theTwoNewReasonsHaveTheirOwnText() {
        let refused = L10n.Storage.ReverseAbort.note(for: .preMountRefused)
        let stalled = L10n.Storage.ReverseAbort.note(for: .preMountStalled)
        let otherDevice = L10n.Storage.ReverseAbort.note(for: .preMountOtherDevice)
        let previous: [ReverseAbortReason] = [
            .icloudFull, .icloudUnavailable, .stalled, .claimRetryLater, .claimRefused, .otherDeviceReverting,
        ]
        for text in [refused, stalled, otherDevice] {
            #expect(!text.isEmpty)
            #expect(!text.hasPrefix("storage.reverseAbort."), "la key cruda: falta en el idioma del simulador")
        }
        #expect(Set([refused, stalled, otherDevice]).count == 3)
        for reason in previous {
            let other = L10n.Storage.ReverseAbort.note(for: reason)
            for (name, text) in [("refused", refused), ("stalled", stalled), ("otherDevice", otherDevice)] {
                #expect(other != text, "\(name) no puede decir lo mismo que \(reason): esa empezaba, esta no")
            }
        }
    }

    /// El permanente da el correo de soporte y el del techo largo NO: ahí volver a intentarlo sí puede funcionar,
    /// y mandar a soporte a quien solo se quedó sin cobertura es ruido para los dos lados.
    @Test func note_onlyTheRefusedOneCarriesTheSupportEmail() {
        let refused = L10n.Storage.ReverseAbort.note(for: .preMountRefused)
        #expect(refused.contains(AppConstants.supportEmail))
        #expect(!refused.contains("%@"), "el placeholder se rellena")
        #expect(!L10n.Storage.ReverseAbort.note(for: .preMountStalled).contains(AppConstants.supportEmail))
    }

    /// Cada motivo sale con SU clave: dos textos distintos pero intercambiados pasarían el test de arriba.
    @Test func note_eachNewReasonMapsToItsOwnKey() {
        #expect(L10n.Storage.ReverseAbort.note(for: .preMountRefused)
            == L10n.Storage.ReverseAbort.preMountRefused(AppConstants.supportEmail))
        #expect(L10n.Storage.ReverseAbort.note(for: .preMountStalled)
            == L10n.Storage.ReverseAbort.preMountStalled)
        #expect(L10n.Storage.ReverseAbort.note(for: .preMountOtherDevice)
            == L10n.Storage.ReverseAbort.preMountOtherDevice)
    }

    /// Lo que la persona decide no deja nota, también antes del montaje: el filtro es el mismo de siempre y los dos
    /// motivos nuevos SÍ la dejan.
    @Test func abortNote_cancelledIsStillTheOnlySilentReason() {
        let all: [ReverseAbortReason] = [
            .cancelled, .icloudFull, .icloudUnavailable, .stalled,
            .claimRetryLater, .claimRefused, .otherDeviceReverting,
            .preMountRefused, .preMountStalled, .preMountOtherDevice,
        ]
        for reason in all where reason != .cancelled {
            #expect(ReverseUploadWaitingCopyLogic.abortNote(reason) == reason, "\(reason) deja nota")
        }
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.cancelled) == nil, "lo que decide la persona, no")
        #expect(ReverseUploadWaitingCopyLogic.abortNote(nil) == nil)
    }

    /// El cuerpo de la confirmación cambia con la fase, y el de antes del montaje NO puede prometer un
    /// relanzamiento: ahí no hay espejo montado que apagar. Sin esto, el diálogo diría que Yala pedirá cerrarla y
    /// volver a abrirla, y luego no lo pediría.
    @Test func cancelDialog_theBeforeMountBodyDoesNotPromiseARelaunch() throws {
        let waiting = L10n.Storage.Confirm.cancelReverseBody
        let beforeMount = L10n.Storage.Confirm.cancelReverseBeforeMountBody
        #expect(!beforeMount.isEmpty)
        #expect(!beforeMount.hasPrefix("storage.confirm."), "la key cruda")
        #expect(beforeMount != waiting, "son dos cuerpos, no uno reusado")

        // Y lo que el nombre del caso promete, que las tres líneas de arriba NO comprueban: que el cuerpo previo al
        // montaje no pida cerrar y volver a abrir Yala. Se mide sobre `es-419`, el locale de referencia del repo,
        // porque el texto que resuelve `L10n` depende del idioma del simulador.
        let reference = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Resources/es-419.lproj/Localizable.strings"),
            encoding: .utf8)
        func value(_ key: String) throws -> String {
            let line = try #require(reference.split(separator: "\n").first { $0.hasPrefix("\"\(key)\" = ") },
                                    "falta \(key) en es-419")
            return String(line)
        }
        #expect(try value("storage.confirm.cancelReverseBody").contains("volver a abrirla"),
                "control positivo: el cuerpo de la espera SÍ promete el relanzamiento")
        #expect(try !value("storage.confirm.cancelReverseBeforeMountBody").contains("volver a abrir"),
                "antes del montaje no hay espejo que apagar, así que no hay relanzamiento que pedir")
    }

    /// El `%@` de `preMountRefused` está en los 16 idiomas. **Lo comprueba este caso y no la paridad**, porque
    /// `StringsFileParser.extractPlaceholders` no captura un `%@` aislado (su docblock lo dice), así que
    /// `placeholders_matchAcrossLocales` compara `0 == 0` para esta clave. Un idioma que lo pierda publicaría la
    /// nota sin el correo de soporte, que es lo único accionable que tiene ese texto.
    @Test func preMountRefused_keepsItsPlaceholder_inEveryLocale() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let lprojs = try FileManager.default.contentsOfDirectory(atPath: resources.path)
            .filter { $0.hasSuffix(".lproj") }.sorted()
        #expect(lprojs.count == 16, "16 idiomas; si cambia, este conteo lo dice")
        for lproj in lprojs {
            let file = resources.appendingPathComponent(lproj).appendingPathComponent("Localizable.strings")
            let text = try String(contentsOf: file, encoding: .utf8)
            let line = try #require(
                text.split(separator: "\n").first { $0.hasPrefix("\"storage.reverseAbort.preMountRefused\" = ") },
                "\(lproj): falta la clave")
            #expect(line.contains("%@"), "\(lproj): sin el %@ la nota sale sin el correo de soporte")
        }
    }
}
