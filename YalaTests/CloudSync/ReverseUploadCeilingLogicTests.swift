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
    }

    /// La nota explica una salida que la persona no pidió. La que pidió no lleva nota. Las salidas del claim
    /// (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`) nunca las pide la persona: siempre llevan nota.
    @Test func abortNote_skipsNothingAndCancelled() {
        #expect(ReverseUploadWaitingCopyLogic.abortNote(nil) == nil)
        #expect(ReverseUploadWaitingCopyLogic.abortNote(.cancelled) == nil)
        for reason: ReverseAbortReason in [.icloudFull, .icloudUnavailable, .stalled,
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
        #expect(MetricsService.reverseUploadWaitingDetail(advancing: true, stalledSeconds: 99_999, blocker: "unknown")
            == "advancing|unknown")
    }

    /// Los bordes de los tramos son los dos techos: 15 min y 72 h. `stalled|gte_72h` solo sale en la observación que
    /// SALE por el techo largo, así que cuenta salidas, no teléfonos atascados; un `stalled|24h_72h` sostenido en
    /// muchos teléfonos es el que delata un mirror que no exporta para nadie.
    @Test func canaryDetail_stalledBuckets_edgesAreTheBudgets() {
        func detail(_ seconds: Double) -> String {
            MetricsService.reverseUploadWaitingDetail(advancing: false, stalledSeconds: seconds, blocker: "icloudOff")
        }
        #expect(detail(0) == "stalled|lt_15m|icloudOff")
        #expect(detail(899) == "stalled|lt_15m|icloudOff")
        #expect(detail(900) == "stalled|15m_1h|icloudOff")
        #expect(detail(3_599) == "stalled|15m_1h|icloudOff")
        #expect(detail(3_600) == "stalled|1h_24h|icloudOff")
        #expect(detail(86_399) == "stalled|1h_24h|icloudOff")
        #expect(detail(86_400) == "stalled|24h_72h|icloudOff")
        #expect(detail(259_199) == "stalled|24h_72h|icloudOff")
        #expect(detail(259_200) == "stalled|gte_72h|icloudOff")
    }
}
