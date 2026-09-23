//
//  SnapshotUploadCeilingLogicTests.swift
//  YalaTests / CloudSync
//
//  Lo PURO del techo de la subida del snapshot de la ida (ticket `snapshot-upload-has-no-ceiling-and-no-way-out`): qué
//  texto ve la persona por cada motivo, el WIRE de los motivos y del canario, el reloj por causa que comparte con la
//  vuelta a iCloud, y el cableado de la pantalla. El recorrido del runner vive en `MigrationRunnerTests` §14; las
//  aristas, en `MigrationStateMachineTests`; el reparto de motivos del uploader, en `MigrationSnapshotUploaderTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Activación de la nube: techo de la subida · lógica pura")
@MainActor
struct SnapshotUploadCeilingLogicTests {

    private let supportEmail = "soporte@example.test"

    private func message(_ exit: SnapshotExitReason?, _ blocker: ICloudChannelVerdict? = nil) -> String {
        StorageFailureCopyLogic.message(
            kind: .migration, snapshotExit: exit, cutoverBlocker: blocker, supportEmail: supportEmail)
    }

    // MARK: - El texto de la tarjeta de fallo (decisión de Jürgen: texto POR MOTIVO)

    /// Cada motivo tiene su frase, y se compara el TEXTO: es lo que la persona lee. Si dos motivos acabaran en la
    /// misma frase, ningún enum lo diría.
    @Test func eachSnapshotExitReason_hasItsOwnText() {
        #expect(message(.stalled) == L10n.Storage.Failed.snapshotStalled)
        #expect(message(.sessionExpired) == L10n.Storage.Failed.snapshotSessionExpired)
        #expect(message(.accountUnavailable) == L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail))
        #expect(message(.localFailure) == L10n.Storage.Failed.snapshotLocalFailure)
        let texts = [SnapshotExitReason.stalled, .sessionExpired, .accountUnavailable, .localFailure].map { message($0) }
        #expect(Set(texts).count == 4, "cuatro motivos, cuatro frases")
        #expect(!texts.contains(L10n.Storage.Failed.migration), "ninguno cae al genérico: esa fue la decisión")
        // Comparar L10n con L10n no ve una clave que falte: los dos lados devolverían la clave cruda. Esto sí (lo cazó
        // la review). Y va para los nueve textos nuevos, los del diálogo incluidos.
        let all = texts + [L10n.Storage.Progress.cancelMigration, L10n.Storage.Confirm.cancelMigrationTitle,
                           L10n.Storage.Confirm.cancelMigrationBody, L10n.Storage.Confirm.cancelMigrationConfirm,
                           L10n.Storage.Confirm.cancelMigrationKeep]
        for text in all {
            #expect(!text.hasPrefix("storage."), "clave sin traducir en el idioma de la corrida: \(text)")
            #expect(!text.isEmpty)
        }
    }

    /// Solo el 403 da el correo de soporte: reintentar no despierta una cuenta suspendida. En los demás, mandar a
    /// soporte sería mandar a alguien por nada.
    @Test func onlyTheAccountRefusal_givesTheSupportEmail() {
        #expect(message(.accountUnavailable).contains(supportEmail))
        for exit in [SnapshotExitReason.stalled, .sessionExpired, .localFailure] {
            #expect(!message(exit).contains(supportEmail), "\(exit)")
        }
    }

    /// El motivo de la subida manda sobre el veredicto del canal iCloud: es el único escrito por ESTE fallo.
    @Test func theSnapshotReason_winsOverTheICloudVerdict() {
        #expect(message(.localFailure, .quotaExceeded) == L10n.Storage.Failed.snapshotLocalFailure)
    }

    /// Sin motivo de la subida, la tarjeta sigue diciendo lo de siempre: este ticket no cambia los fallos del cutover.
    @Test func withoutASnapshotReason_theCutoverCopyIsUnchanged() {
        #expect(message(nil) == L10n.Storage.Failed.migration)
        #expect(message(nil, .quotaExceeded) == L10n.Storage.Failed.migrationICloudFull)
        #expect(message(nil, .noAccountWithFootprint) == L10n.Storage.Failed.migrationICloudOff)
        #expect(message(nil, .accountUnusable) == L10n.Storage.Failed.migrationICloudOff)
        #expect(message(nil, .healthy) == L10n.Storage.Failed.migrationICloudStalled)
        #expect(StorageFailureCopyLogic.message(kind: .reverse, snapshotExit: .localFailure, cutoverBlocker: nil)
            == L10n.Storage.Failed.reverse, "la vuelta no lee el motivo de la ida")
    }

    // MARK: - WIRE

    /// Los `rawValue` viajan en el journal (motivo), en la clave del reloj de causa y en el canario: renombrar uno
    /// deja una fila vieja sin texto y parte la serie. Se afirman letra a letra.
    @Test func rawValues_areWire() {
        #expect([SnapshotStallBlocker.sessionExpired, .accountUnavailable, .localFailure].map(\.rawValue)
            == ["sessionExpired", "accountUnavailable", "localFailure"])
        #expect([SnapshotExitReason.stalled, .sessionExpired, .accountUnavailable, .localFailure].map(\.rawValue)
            == ["stalled", "sessionExpired", "accountUnavailable", "localFailure"])
        #expect(SnapshotExitReason(.localFailure) == .localFailure)
        #expect(SnapshotExitReason(.sessionExpired) == .sessionExpired)
        #expect(SnapshotExitReason(.accountUnavailable) == .accountUnavailable)
    }

    /// El detalle del canario: los dos tramos, `-` sin motivo, `stop_` o `waiting`. Mismos bordes que la vuelta.
    @Test func waitingCanaryDetail_hasBothClocks() {
        #expect(MetricsService.snapshotUploadWaitingDetail(stalledSeconds: 10, causeStalledSeconds: 0, blocker: nil)
            == "lt_15m|-|waiting")
        #expect(MetricsService.snapshotUploadWaitingDetail(
            stalledSeconds: 10_800, causeStalledSeconds: 12, blocker: "localFailure")
            == "1h_24h|lt_15m|stop_localFailure")
        #expect(MetricsService.snapshotUploadWaitingDetail(
            stalledSeconds: 259_200, causeStalledSeconds: 900, blocker: "accountUnavailable")
            == "gte_72h|15m_1h|stop_accountUnavailable")
    }

    // MARK: - El reloj por causa (compartido con la vuelta a iCloud)

    @Test func causeClock_theThreeRules() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Primera observación con motivo: empieza de cero.
        #expect(CauseStallClock.observe(sealedRaw: nil, sealedOpenSince: nil, sealedAccrued: nil,
                                        blockerRaw: "a", observedAt: t0)
            == .init(stalled: 0, raw: "a", accruedFrom: t0, accrued: 0))
        // Misma causa: suma el tramo abierto a lo acumulado.
        #expect(CauseStallClock.observe(sealedRaw: "a", sealedOpenSince: t0, sealedAccrued: 100,
                                        blockerRaw: "a", observedAt: t0.addingTimeInterval(50))
            == .init(stalled: 150, raw: "a", accruedFrom: t0, accrued: 100))
        // Sin motivo: PAUSA — cierra el tramo, conserva la causa.
        #expect(CauseStallClock.observe(sealedRaw: "a", sealedOpenSince: t0, sealedAccrued: 100,
                                        blockerRaw: nil, observedAt: t0.addingTimeInterval(50))
            == .init(stalled: 0, raw: "a", accruedFrom: nil, accrued: 150))
        // Causa distinta: empieza de cero.
        #expect(CauseStallClock.observe(sealedRaw: "a", sealedOpenSince: t0, sealedAccrued: 100,
                                        blockerRaw: "b", observedAt: t0.addingTimeInterval(50))
            == .init(stalled: 0, raw: "b", accruedFrom: t0.addingTimeInterval(50), accrued: 0))
        // Un sello en el FUTURO re-abre el tramo ahora, sin tramo negativo.
        #expect(CauseStallClock.observe(sealedRaw: "a", sealedOpenSince: t0.addingTimeInterval(3_600),
                                        sealedAccrued: 100, blockerRaw: "a", observedAt: t0)
            == .init(stalled: 100, raw: "a", accruedFrom: t0, accrued: 100))
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

    /// La tarjeta de progreso ofrece el botón solo con la fase que lo admite, y el «sí» cancela de verdad. Sin el
    /// `if`, el botón saldría en toda la ida; sin la llamada, el diálogo prometería algo que no hace.
    @Test func progressCard_offersCancel_onlyWhereTheControllerSays() throws {
        let view = "Yala/App/Views/Settings/StorageSettingsView.swift"
        let card = try Self.body(of: "private func progressCard(", in: view)
        #expect(card.contains("if controller.canCancelMigration {\n                cancelMigrationButton(controller)"))
        let button = try Self.body(of: "private func cancelMigrationButton(", in: view)
        #expect(button.contains("Task { await controller.cancelMigration() }"))
        #expect(button.contains("isDisabled: controller.isWorking"),
                "con una pasada en vuelo el botón no se toca: la cancelación es de la subida APARCADA")
        let failure = try Self.body(of: "private func failureMessage(", in: view)
        #expect(failure.contains("snapshotExit: controller.snapshotExitReason"))
    }

    /// El controller ofrece la salida donde dice `ForwardCancelScope` —la subida y, desde
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`, los tres pasos sin cifra que baje—, y lee el motivo del journal.
    @Test func controller_readsThePhaseAndTheReasonFromTheJournal() throws {
        let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"
        let src = try Self.source(controller)
        #expect(src.contains("ForwardCancelScope.offersCancel(journaledPhase, claimIntent: journaledClaimIntent)"))
        #expect(src.contains(
            "snapshotExitReason = state.snapshotExitReasonRaw.flatMap(SnapshotExitReason.init(rawValue:))"))
        let cancel = try Self.body(of: "func cancelMigration() async", in: controller)
        #expect(cancel.contains("await runner.cancelMigration()"))
        // El «sí» se apunta ANTES de esperar a la pasada en vuelo: después llegaría tarde (hallazgo de la review).
        let statements = cancel.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "{" }
        #expect(statements.first == "runner.requestMigrationCancel()")
        // Y cierra la sesión que abrió el intento, solo si la subida se canceló de verdad.
        let guardLine = "if journaledPhase == .notStarted, let attempt = migrationAttempt {"
        let closeLine = "_ = await closeSessionIfOpened(attempt.sessionOpenedByThisAttempt)"
        let guardIndex = try #require(statements.firstIndex(of: guardLine))
        #expect(statements.firstIndex(of: closeLine).map { $0 > guardIndex } == true)
        // El motivo se vuelve a `nil` en las dos ramas sin fila legible, no solo se lee en la buena.
        let snapshot = try Self.body(of: "private func readJournalSnapshot()", in: controller)
        #expect(snapshot.components(separatedBy: "snapshotExitReason = nil").count - 1 == 2)
    }
}
