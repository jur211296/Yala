//
//  ReverseUploadCeilingLogicTests.swift
//  YalaTests / CloudSync
//
//  Lógica PURA del techo de la espera de «Volver a iCloud» (ticket `reverse-upload-has-no-ceiling-and-no-exit`):
//  la causa que elige el presupuesto (`ReverseUploadBlockerLogic`), el copy de la espera y de la salida
//  (`ReverseUploadWaitingCopyLogic`) y el detalle del canario que separa «va lento» de «no avanza».
//

import CloudKit
import Foundation
import Testing

@testable import Yala

@Suite("Techo de reverseUpload · lógica pura")
struct ReverseUploadCeilingLogicTests {

    private static let errorAt = Date(timeIntervalSince1970: 1_700_000_000)

    /// Por defecto el error es VIGENTE (fecha de error y ningún éxito): los casos que miden la tabla de `CKError` no
    /// dependen de las fechas. Las fechas tienen sus propios casos abajo.
    private func decide(
        available: Bool = true, error: CKError.Code? = nil, notAuthenticated: Bool = false,
        errorAt: Date? = ReverseUploadCeilingLogicTests.errorAt, successAt: Date? = nil
    ) -> ReverseUploadBlocker {
        ReverseUploadBlockerLogic.decide(
            icloudAvailable: available, lastExportErrorCode: error,
            lastExportErrorAt: error == nil ? nil : errorAt, lastSuccessfulExportAt: successAt,
            mirrorReportedNotAuthenticated: notAuthenticated)
    }

    // MARK: - Causa

    /// Solo la palabra de CloudKit acorta la espera. Es la MISMA tabla de `CKError` que la ida, y el test la recorre
    /// entera para que una tabla propia que divergiera saliera aquí.
    @Test func blocker_cloudKitWord_isDefinitive() {
        #expect(decide(error: .quotaExceeded) == .icloudFull)
        for code: CKError.Code in [.notAuthenticated, .managedAccountRestricted, .userDeletedZone] {
            #expect(decide(error: code) == .icloudUnusable, "\(code) = cuenta inutilizable")
        }
        #expect(decide(notAuthenticated: true) == .icloudUnusable,
                "el notAuthenticated del mirror no llega a lastExportError: se lee por su bandera")
        #expect(ReverseUploadBlocker.icloudFull.stallCause == .definitive)
        #expect(ReverseUploadBlocker.icloudUnusable.stallCause == .definitive)
    }

    /// EL pin fail-open: sin token de iCloud (que mide iCloud DRIVE) y sin error, la causa es `icloudOff` —la
    /// pantalla lo dice— pero el presupuesto es el LARGO. Si alguien la pasara a `.definitive`, a quien tiene Drive
    /// apagado y CloudKit sano se le cancelaría la vuelta a los 15 min.
    @Test func blocker_noTokenAlone_isICloudOff_withTheLongBudget() {
        #expect(decide(available: false) == .icloudOff)
        #expect(ReverseUploadBlocker.icloudOff.stallCause == .unknown)
    }

    /// Errores retriables no son la palabra de CloudKit: `unknown` con token, `icloudOff` sin él.
    @Test func blocker_retriableErrors_areNotDefinitive() {
        for code: CKError.Code in [.networkUnavailable, .networkFailure, .zoneBusy, .serviceUnavailable,
                                   .requestRateLimited] {
            #expect(decide(error: code) == .unknown, "\(code) con token")
            #expect(decide(available: false, error: code) == .icloudOff, "\(code) sin token")
        }
        #expect(decide() == .unknown)
        #expect(ReverseUploadBlocker.unknown.stallCause == .unknown)
    }

    /// Cuando CloudKit habló, manda sobre el token: el copy de «lleno» es más útil que el de «sin iCloud».
    @Test func blocker_cloudKitWord_winsOverMissingToken() {
        #expect(decide(available: false, error: .quotaExceeded) == .icloudFull)
        #expect(decide(available: false, notAuthenticated: true) == .icloudUnusable)
    }

    /// EL pin del latch: `lastExportError` no se limpia con un éxito, así que un «iCloud lleno» ya resuelto seguía
    /// acortando la espera a 15 min y diciendo en pantalla que no hay espacio a quien lo acababa de liberar. Solo
    /// manda un error POSTERIOR al último éxito; uno sin fecha no manda (la ambigüedad nunca acorta).
    @Test func blocker_errorOlderThanTheLastSuccess_isNotCloudKitsWord() {
        let errorAt = Self.errorAt
        #expect(decide(error: .quotaExceeded, successAt: errorAt.addingTimeInterval(1)) == .unknown,
                "un export con éxito DESPUÉS del error: el error ya no es vigente")
        #expect(decide(error: .quotaExceeded, successAt: errorAt.addingTimeInterval(-1)) == .icloudFull,
                "el éxito es ANTERIOR: el error sigue vigente")
        #expect(decide(error: .quotaExceeded, successAt: errorAt) == .unknown,
                "a la misma hora no se puede decir que siga: no acorta")
        #expect(decide(error: .quotaExceeded, errorAt: nil) == .unknown, "sin fecha de error no acorta")
        #expect(decide(available: false, error: .quotaExceeded, successAt: errorAt.addingTimeInterval(1)) == .icloudOff,
                "un error viejo no tapa lo que sí se sabe: sin token")
        #expect(decide(error: .userDeletedZone, successAt: errorAt.addingTimeInterval(1)) == .unknown)
    }

    /// `icloudOff` no afirma que iCloud faltara: con Drive apagado CloudKit puede estar sano, y la nota sobrevive al
    /// relanzamiento. Solo la palabra de CloudKit da `icloudUnavailable`.
    @Test func blocker_abortReason_mapsEveryCause() {
        #expect(ReverseUploadBlocker.icloudFull.abortReason == .icloudFull)
        #expect(ReverseUploadBlocker.icloudUnusable.abortReason == .icloudUnavailable)
        #expect(ReverseUploadBlocker.icloudOff.abortReason == .stalled)
        #expect(ReverseUploadBlocker.unknown.abortReason == .stalled)
        #expect(ReverseUploadBlocker.localFailure.abortReason == .localFailure)
    }

    /// La muestra ilegible es una avería de este teléfono, y esperar no la arregla (ticket
    /// `reverse-upload-unreadable-sample-waits-the-long-ceiling`): techo CORTO, el mismo número que la avería local de la
    /// ida. Y `ReverseUploadBlockerLogic` no la produce nunca: solo ve el canal iCloud, y la elige el runner.
    @Test func blocker_localFailure_isDefinitive_withTheForwardShortCeiling() {
        #expect(ReverseUploadBlocker.localFailure.stallCause == .definitive)
        let policy = MigrationPolicy.default
        #expect(policy.reverseUploadDefinitiveBudgetSeconds == policy.snapshotCauseBudgetSeconds,
                "el corto de la vuelta es el de la ida: si uno se mueve, esta avería deja de esperar lo mismo en los dos")
        #expect(policy.reverseUploadDefinitiveCeilingReached(stalledSeconds: 900, cause: .definitive))
        #expect(!policy.reverseUploadDefinitiveCeilingReached(stalledSeconds: 899, cause: .definitive))
        for available in [true, false] {
            for notAuthenticated in [true, false] {
                for error: CKError.Code? in [nil, .quotaExceeded, .networkFailure] {
                    #expect(decide(available: available, error: error, notAuthenticated: notAuthenticated) != .localFailure)
                }
            }
        }
    }

    // MARK: - Copy de la espera

    @Test func waitingCopy_withoutObservation_saysUploadingWithoutANumber() {
        #expect(ReverseUploadWaitingCopyLogic.waitingCopy(sample: nil)
            == .init(message: .uploading, pending: nil))
    }

    /// El mensaje sigue a la causa, y la cifra va con TODOS: es lo que deja ver que la subida avanza aunque el mensaje
    /// hable de un problema. Sin token de iCloud el mensaje es el CONDICIONAL, no el que afirma que no llega.
    @Test func waitingCopy_followsTheBlocker_andAlwaysCarriesTheCount() {
        func copy(_ blocker: ReverseUploadBlocker) -> ReverseUploadWaitingCopyLogic.WaitingCopy {
            ReverseUploadWaitingCopyLogic.waitingCopy(sample: ReverseUploadSample(pending: 42, blocker: blocker))
        }
        #expect(copy(.unknown) == .init(message: .uploading, pending: 42))
        #expect(copy(.icloudFull) == .init(message: .icloudFull, pending: 42))
        #expect(copy(.icloudUnusable) == .init(message: .icloudUnavailable, pending: 42))
        #expect(copy(.icloudOff) == .init(message: .icloudMaybeOff, pending: 42))
        #expect(copy(.localFailure) == .init(message: .localFailure, pending: 42))
    }

    /// La espera que EMPIEZA con la muestra ilegible tiene motivo y no cifra: la pantalla dice el motivo, no «subiendo».
    @Test func waitingCopy_sampleWithoutCount_saysItsReason_withoutANumber() {
        #expect(ReverseUploadWaitingCopyLogic.waitingCopy(sample: ReverseUploadSample(pending: nil, blocker: .localFailure))
            == .init(message: .localFailure, pending: nil))
    }

    /// El último eslabón: la vista traduce cada mensaje a su texto (`StorageSettingsView.reverseUploadMessage`). Ningún test
    /// pasa por esa función —es `private` y la pantalla no se monta en la simulación—, así que se fija su cuerpo ENTERO,
    /// caso a caso y en orden: un `contains` suelto no cazaría `.localFailure` devolviendo el texto de «subiendo» ni dos
    /// casos intercambiados (`.claude/rules/testing.md`, regla del source-scan).
    @Test func viewMapping_eachMessageGoesToItsOwnText() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent("Yala/App/Views/Settings/StorageSettingsView.swift"),
                              encoding: .utf8)
        let marker = "private func reverseUploadMessage(_ message: ReverseUploadWaitingCopyLogic.Message) -> String {"
        let start = try #require(text.range(of: marker), "la firma de reverseUploadMessage cambió")
        let chars = Array(text[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        let body = String(chars[0..<min(i, chars.count)])
            .split(separator: "\n")
            .map { line -> String in
                var code = String(line)
                if let comment = code.range(of: "//") { code = String(code[..<comment.lowerBound]) }
                return code.trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
        #expect(body == [
            "switch message {",
            "case .uploading:",
            "return L10n.Storage.Progress.reverseUploading",
            "case .icloudFull:",
            "return L10n.Storage.Progress.reverseICloudFull",
            "case .icloudUnavailable:",
            "return L10n.Storage.Progress.reverseICloudUnavailable",
            "case .icloudMaybeOff:",
            "return L10n.Storage.Progress.reverseICloudMaybeOff",
            "case .localFailure:",
            "return L10n.Storage.Progress.reverseLocalFailure",
            "}",
        ], "cada mensaje con su texto; la avería local nunca con el de «subiendo»")
    }

    /// El texto de la espera y el de la salida de la avería local: resueltos, propios, y sin las dos afirmaciones que no son
    /// verdad aquí. La espera no dice «subiendo» —no se sabe si sube— y la salida no culpa a iCloud ni a la conexión, que
    /// es lo que dice `stalled`. Se mide sobre `es-419`, el locale de referencia, porque `L10n` resuelve en el idioma del
    /// simulador; y en `L10n`, que cada motivo salga con su clave.
    @Test func localFailureCopy_ownTexts_neitherUploadingNorBlamingICloud() throws {
        let waiting = L10n.Storage.Progress.reverseLocalFailure
        let note = L10n.Storage.ReverseAbort.note(for: .localFailure)
        for text in [waiting, note] {
            #expect(!text.isEmpty)
            #expect(!text.hasPrefix("storage."), "la key cruda: falta en el idioma del simulador")
        }
        #expect(waiting != L10n.Storage.Progress.reverseUploading)
        #expect(note == L10n.Storage.ReverseAbort.localFailure, "el motivo sale con SU clave")
        #expect(note != L10n.Storage.ReverseAbort.note(for: .stalled))
        #expect(!note.contains(AppConstants.supportEmail), "como la ida: volver a intentarlo sí puede funcionar")

        let reference = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Yala/Resources/es-419.lproj/Localizable.strings"),
            encoding: .utf8)
        func es(_ key: String) throws -> String {
            let line = try #require(reference.split(separator: "\n").first { $0.hasPrefix("\"\(key)\" = ") },
                                    "falta \(key) en es-419")
            return String(line)
        }
        let esWaiting = try es("storage.progress.reverseLocalFailure")
        let esNote = try es("storage.reverseAbort.localFailure")
        #expect(try es("storage.progress.reverseUploading").contains("Subiendo"),
                "control positivo: el texto de la subida SÍ dice «subiendo»")
        #expect(!esWaiting.localizedCaseInsensitiveContains("subiendo"), "no dice «subiendo»: \(esWaiting)")
        #expect(esWaiting.contains("este dispositivo") || esWaiting.contains("Este dispositivo"),
                "nombra al teléfono como la ida: \(esWaiting)")
        #expect(esNote.contains("este dispositivo no pudo preparar tus datos"), "calco de la ida: \(esNote)")
        #expect(!esNote.contains("conexión") && !esNote.contains("iCloud no recibió"),
                "no culpa a iCloud ni a la red: \(esNote)")
    }

    /// La nota explica una salida que la persona no pidió. La que pidió no lleva nota. Las salidas del claim
    /// (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`) nunca las pide la persona: siempre llevan nota.
    @Test func abortNote_skipsNothingAndCancelled() {
        #expect(ReverseUploadWaitingCopyLogic.abortNote(nil) == nil)
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.cancelled) == nil)
        for reason: ReverseAbortReason in [.icloudFull, .icloudUnavailable, .stalled, .localFailure,
                                           .claimRetryLater, .claimRefused, .otherDeviceReverting] {
            #expect(ReverseUploadWaitingCopyLogic.abortNote(reason) == reason)
        }
    }

    // MARK: - Salida a medias

    /// La salida sigue a medias mientras su último efecto esté pendiente, con o sin el primero. Nada que no sea esa
    /// salida cuenta: con cualquier otro pendiente el runner no drena y la pantalla no habla de reactivar la nube.
    @Test func reverseExitPending_onlyTheExitsLastEffect() {
        #expect(ReverseExitPending.isPending([.rearmMirrorOff, .reverseRollback]))
        #expect(ReverseExitPending.isPending([.reverseRollback]))
        #expect(!ReverseExitPending.isPending([]))
        #expect(!ReverseExitPending.isPending([.runLeaderReconcileFromFrozenCloudKit]))
        #expect(!ReverseExitPending.isPending([.adoptBackendAccount]))
    }

    // MARK: - Canario

    @Test func canaryDetail_advancingCarriesOnlyTheCause() {
        #expect(MetricsService.reverseUploadWaitingDetail(
            advancing: true, stalledSeconds: 99_999, causeStalledSeconds: 99_999, blocker: "icloudFull")
            == "advancing|icloudFull")
    }

    /// Los bordes de los tramos son los dos techos: 15 min y 72 h. `stalled|gte_72h|…` solo sale en la observación que
    /// SALE por el techo largo, así que cuenta salidas, no teléfonos atascados; un `stalled|24h_72h|…` sostenido en
    /// muchos teléfonos es el que delata un mirror que no exporta para nadie. Sin motivo definitivo, el tramo de causa es
    /// `-`: ahí no corre ningún reloj de causa.
    @Test func canaryDetail_stalledBuckets_edgesAreTheBudgets() {
        func detail(_ seconds: Double) -> String {
            MetricsService.reverseUploadWaitingDetail(
                advancing: false, stalledSeconds: seconds, causeStalledSeconds: nil, blocker: "icloudOff")
        }
        #expect(detail(0) == "stalled|lt_15m|-|icloudOff")
        #expect(detail(899) == "stalled|lt_15m|-|icloudOff")
        #expect(detail(900) == "stalled|15m_1h|-|icloudOff")
        #expect(detail(3_599) == "stalled|15m_1h|-|icloudOff")
        #expect(detail(3_600) == "stalled|1h_24h|-|icloudOff")
        #expect(detail(86_399) == "stalled|1h_24h|-|icloudOff")
        #expect(detail(86_400) == "stalled|24h_72h|-|icloudOff")
        #expect(detail(259_199) == "stalled|24h_72h|-|icloudOff")
        #expect(detail(259_200) == "stalled|gte_72h|-|icloudOff")
    }

    /// EL caso del ticket en la flota: horas de espera y un motivo definitivo recién visto. Con un solo tramo se leía
    /// como horas con la cuenta inutilizable; con dos, el de causa dice que el motivo lleva segundos. Y el tramo de causa
    /// tiene sus propios bordes en el techo corto.
    @Test func canaryDetail_causeBucket_separatesAFreshCauseFromTheLongWait() {
        func detail(_ stalled: Double, _ cause: Double) -> String {
            MetricsService.reverseUploadWaitingDetail(
                advancing: false, stalledSeconds: stalled, causeStalledSeconds: cause, blocker: "icloudUnusable")
        }
        #expect(detail(10_800, 12) == "stalled|1h_24h|lt_15m|icloudUnusable")
        #expect(detail(10_800, 899) == "stalled|1h_24h|lt_15m|icloudUnusable")
        #expect(detail(10_800, 900) == "stalled|1h_24h|15m_1h|icloudUnusable")
        // El peor caso cabe de sobra en los 128 caracteres que admite el gateway.
        #expect(detail(259_200, 259_200).count <= 128)
    }

    // MARK: - Detalle de la salida (lente de telemetría de `reverse-upload-ceiling-charges-a-wait-to-whoever-stops-it-last`)

    /// `stalled` en el journal cubre dos salidas; en la flota se separan. Antes de las 72 h, un `stalled` solo puede
    /// venir del corto con motivos turnándose: `mixedCauses`. Desde las 72 h, `stalled`. El resto de motivos, tal cual.
    @Test func exitDetail_splitsTheTwoStalledExits_andKeepsTheRest() {
        let policy = MigrationPolicy.default
        func detail(_ reason: ReverseAbortReason, _ stalled: Double) -> String {
            MigrationRunner.reverseUploadExitDetail(reason: reason, progressStalledSeconds: stalled, policy: policy)
        }
        #expect(detail(.stalled, 900) == "mixedCauses")
        #expect(detail(.stalled, 259_199) == "mixedCauses")
        #expect(detail(.stalled, 259_200) == "stalled")
        #expect(detail(.icloudFull, 900) == "icloudFull")
        #expect(detail(.localFailure, 900) == "localFailure", "la avería local no se confunde con los motivos turnándose")
        #expect(detail(.icloudUnavailable, 259_200) == "icloudUnavailable")
        #expect(detail(.cancelled, 10) == "cancelled")
    }
}
