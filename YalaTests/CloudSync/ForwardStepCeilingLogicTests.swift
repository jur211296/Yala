//
//  ForwardStepCeilingLogicTests.swift
//  YalaTests / CloudSync
//
//  Lo PURO del techo de los tres pasos de la ida sin cifra que baje —claim (22 %), identidad (35 %) y `cutover(.pending)`
//  (80 %)— (ticket `forward-migration-steps-have-no-ceiling-and-no-exit`): qué texto ve la persona por cada motivo, el WIRE
//  de los motivos y del canario, en qué fases se ofrece «Cancelar», y el cableado de la pantalla. El recorrido del runner
//  vive en `MigrationRunnerTests` §15; las aristas, en `MigrationStateMachineTests`; el reparto del no del servidor, en
//  `MigrationWorkExecutorTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Activación de la nube: techo de los tres pasos · lógica pura")
@MainActor
struct ForwardStepCeilingLogicTests {

    private let supportEmail = "soporte@example.test"

    private func message(
        _ exit: ForwardStepExitReason?, snapshot: SnapshotExitReason? = nil, _ blocker: ICloudChannelVerdict? = nil
    ) -> String {
        StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: snapshot, forwardStepExit: exit, cutoverBlocker: blocker,
            supportEmail: supportEmail)
    }

    private static let allReasons: [ForwardStepExitReason] = [
        .stalled, .sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure,
    ]

    // MARK: - El texto de la tarjeta de fallo (decisión de Jürgen: texto POR MOTIVO)

    /// Cada motivo con su frase, comparando TEXTOS. Las dos que se reusan de la subida son exactamente las de la subida; las
    /// tres propias existen porque las de la subida hablan de subir los datos y al 22 % no se ha subido nada.
    @Test func eachForwardStepExitReason_hasTheDecidedText() {
        #expect(message(.stalled) == L10n.Storage.Failed.stepStalled)
        #expect(message(.sessionExpired) == L10n.Storage.Failed.stepSessionExpired)
        #expect(message(.otherDevice) == L10n.Storage.Failed.stepOtherDevice)
        #expect(message(.accountUnavailable) == L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail))
        #expect(message(.refused) == L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail),
                "el servidor dijo que no: es la frase de la cuenta, con su correo")
        #expect(message(.localFailure) == L10n.Storage.Failed.snapshotLocalFailure)
    }

    /// Las tres frases nuevas son distintas entre sí, de las de la subida que NO se reusan y del genérico. Y ninguna sale
    /// como clave cruda: comparar L10n con L10n no lo vería (lo cazó la review de la subida).
    @Test func theThreeNewTexts_areTheirOwn_andTranslated() {
        let new = [L10n.Storage.Failed.stepStalled, L10n.Storage.Failed.stepSessionExpired,
                   L10n.Storage.Failed.stepOtherDevice]
        #expect(Set(new).count == 3)
        for text in new {
            #expect(!text.hasPrefix("storage."), "clave sin traducir en el idioma de la corrida: \(text)")
            #expect(!text.isEmpty)
            #expect(text != L10n.Storage.Failed.snapshotStalled && text != L10n.Storage.Failed.snapshotSessionExpired,
                    "la de la subida dice «mientras subíamos tus datos», que al 22 % es falso")
            #expect(text != L10n.Storage.Failed.migration, "ninguno cae al genérico: esa fue la decisión")
        }
        #expect(Set(Self.allReasons.map { message($0) }).count == 5,
                "seis motivos, cinco frases: `refused` y `accountUnavailable` comparten la de la cuenta a propósito")
    }

    /// Solo lo que dijo el servidor sobre la cuenta da el correo de soporte. «Otro dispositivo tomó el relevo» no es un
    /// problema que resolver con soporte.
    @Test func onlyTheAccountAnswers_giveTheSupportEmail() {
        for exit in [ForwardStepExitReason.accountUnavailable, .refused] {
            #expect(message(exit).contains(supportEmail), "\(exit)")
        }
        for exit in [ForwardStepExitReason.stalled, .sessionExpired, .otherDevice, .localFailure] {
            #expect(!message(exit).contains(supportEmail), "\(exit)")
        }
    }

    /// El motivo de los tres pasos manda sobre el veredicto del canal iCloud (es el único escrito por ESTE fallo) y cede ante
    /// el de la subida, que va antes y conserva su comportamiento de #212.
    @Test func precedence_snapshotThenStepThenICloudVerdict() {
        #expect(message(.otherDevice, .quotaExceeded) == L10n.Storage.Failed.stepOtherDevice)
        #expect(message(.otherDevice, snapshot: .localFailure) == L10n.Storage.Failed.snapshotLocalFailure)
        #expect(message(nil, .quotaExceeded) == L10n.Storage.Failed.migrationICloudFull, "sin motivo, lo de siempre")
        #expect(message(nil) == L10n.Storage.Failed.migration)
        #expect(StorageFailureCopyLogic.message(kind: .reverse, snapshotExit: nil, forwardStepExit: .otherDevice,
                                                cutoverBlocker: nil) == L10n.Storage.Failed.reverse,
                "la vuelta no lee el motivo de la ida")
    }

    // MARK: - WIRE

    /// Los `rawValue` viajan en el journal, en la clave del reloj de causa y en el canario: letra a letra.
    @Test func rawValues_areWire() {
        #expect([ForwardStepPhase.claim, .identity, .cutoverPending].map(\.rawValue)
            == ["claim", "identity", "cutoverPending"])
        #expect([ForwardStepBlocker.sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure]
            .map(\.rawValue) == ["sessionExpired", "accountUnavailable", "refused", "otherDevice", "localFailure"])
        #expect(Self.allReasons.map(\.rawValue)
            == ["stalled", "sessionExpired", "accountUnavailable", "refused", "otherDevice", "localFailure"])
        for blocker in [ForwardStepBlocker.sessionExpired, .accountUnavailable, .refused, .otherDevice, .localFailure] {
            #expect(ForwardStepExitReason(blocker).rawValue == blocker.rawValue, "\(blocker)")
        }
    }

    /// Los tres pasos, y solo esos: la subida tiene su techo y el cutover confirmado no puede hacer rollback.
    @Test func forwardStepPhase_coversExactlyTheThreeSteps() {
        #expect(ForwardStepPhase(phase: .claimingMigration) == .claim)
        #expect(ForwardStepPhase(phase: .assigningIdentity) == .identity)
        #expect(ForwardStepPhase(phase: .cutover(.pending)) == .cutoverPending)
        for phase in MigrationStateMachineTests.allPhases
        where ![MigrationPhase.claimingMigration, .assigningIdentity, .cutover(.pending)].contains(phase) {
            #expect(ForwardStepPhase(phase: phase) == nil, "\(phase)")
        }
    }

    /// «Cancelar la activación» se ofrece en las cuatro fases en las que el teléfono sigue intacto y la fase puede
    /// quedarse parada, y en ninguna otra. En positivo: una fase nueva no lo gana por omisión. **El claim, solo con
    /// «Migrar»**: en un adopt salir es un callejón (hallazgo de la review), y ese claim conserva su espera de siempre.
    @Test func cancelScope_isTheSnapshotAndTheThreeSteps_andTheClaimOnlyWhenMigrating() {
        let offering: [MigrationPhase] = [.assigningIdentity, .uploadingSnapshot, .cutover(.pending)]
        for phase in MigrationStateMachineTests.allPhases {
            #expect(ForwardCancelScope.offersCancel(phase, claimIntent: .migrateOnly)
                    == (offering.contains(phase) || phase == .claimingMigration), "\(phase) · migrar")
            #expect(ForwardCancelScope.offersCancel(phase, claimIntent: .adoptIfExisting) == offering.contains(phase),
                    "\(phase) · adopt")
        }
    }

    /// El detalle del canario: el paso delante y los dos tramos detrás, con la forma de la subida.
    @Test func waitingCanaryDetail_hasTheStepAndBothClocks() {
        #expect(MetricsService.forwardStepWaitingDetail(
            step: "claim", stalledSeconds: 10, causeStalledSeconds: 0, blocker: nil) == "claim|lt_15m|-|waiting")
        #expect(MetricsService.forwardStepWaitingDetail(
            step: "cutoverPending", stalledSeconds: 259_200, causeStalledSeconds: 900, blocker: "otherDevice")
            == "cutoverPending|gte_72h|15m_1h|stop_otherDevice")
        #expect(MetricsCanary.cloudForwardStepWaiting.rawValue == "cloudForwardStepWaiting")
        #expect(MetricsCanary.cloudForwardStepAborted.rawValue == "cloudForwardStepAborted")
    }

    // MARK: - El cableado de la pantalla (source-scan)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Cuerpo de un `func`, de su llave de apertura a la de cierre, sin líneas de comentario.
    private static func body(of marker: String, in path: String) throws -> String {
        let src = try source(path)
        let start = try #require(src.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(src[start.upperBound...])
        guard let open = chars.firstIndex(of: "{") else { return "" }
        var depth = 0
        var end = open
        for i in open..<chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { end = i; break } }
        }
        return String(chars[open...end]).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// La tarjeta de fallo recibe el motivo de los tres pasos, y el controller lo lee del journal y lo vuelve a `nil` en las
    /// dos ramas sin fila legible. Sin la primera, la pantalla diría el genérico; sin la segunda, un motivo viejo.
    @Test func failureCard_readsTheStepReasonFromTheJournal() throws {
        let failure = try Self.body(of: "private func failureMessage(",
                                    in: "Yala/App/Views/Settings/StorageSettingsView.swift")
        #expect(failure.contains("forwardStepExit: controller.forwardStepExitReason"))
        let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"
        #expect(try Self.source(controller).contains(
            "forwardStepExitReason = state.forwardStepExitReasonRaw.flatMap(ForwardStepExitReason.init(rawValue:))"))
        let snapshot = try Self.body(of: "private func readJournalSnapshot()", in: controller)
        #expect(snapshot.components(separatedBy: "forwardStepExitReason = nil").count - 1 == 2)
        // La intención del claim, del journal y con el mismo default que el runner: sin ella, el botón saldría en el claim
        // de un adopt.
        #expect(snapshot.contains(
            "journaledClaimIntent = state.forwardClaimIntentRaw.flatMap(ForwardClaimIntent.init(rawValue:)) ?? .adoptIfExisting"))
        #expect(snapshot.components(separatedBy: "journaledClaimIntent = .adoptIfExisting").count - 1 == 2)
    }
}
