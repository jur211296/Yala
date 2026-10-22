//
//  ReverseClaimRejectionLogicTests.swift
//  YalaTests / CloudSync
//
//  Lo puro de la salida del claim de «Volver a iCloud» (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`):
//  qué motivo del servidor es pasajero, qué texto ve la persona y qué detalle viaja en el canario. El recorrido del
//  runner vive en `MigrationRunnerTests`; la arista, en `MigrationStateMachineTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Vuelta a iCloud: rechazo del claim · lógica pura")
@MainActor
struct ReverseClaimRejectionLogicTests {

    // MARK: - Pasajero o permanente

    /// Solo `migration_in_progress` se arregla esperando (el lease de la ida caduca a los 60 min sin latido). Los
    /// motivos medidos en el cuerpo vivo del RPC y cualquier otro —también uno que este build no conoce— son
    /// permanentes: quedarse esperando por un motivo desconocido es el 15 % eterno de este ticket con otro nombre.
    @Test func forClaimRejection_onlyMigrationInProgressIsRetryLater() {
        #expect(ReverseAbortReason.forClaimRejection(serverReason: "migration_in_progress") == .claimRetryLater)
        for reason in ["not_complete", "no_profile", "unknown", "some_future_reason", "", "MIGRATION_IN_PROGRESS"] {
            #expect(ReverseAbortReason.forClaimRejection(serverReason: reason) == .claimRefused, "«\(reason)»")
        }
    }

    // MARK: - El texto

    /// Cada salida del claim tiene su texto, distinto de los demás y resuelto (no la key cruda). El permanente da el
    /// correo de soporte: reintentar no lo cambia. No se afirma el texto exacto: depende del idioma del simulador, y
    /// su presencia en los 16 idiomas la fija `LocalizationParityTests`.
    @Test func note_eachClaimExitHasItsOwnResolvedText_refusedCarriesTheSupportEmail() {
        let retryLater = L10n.Storage.ReverseAbort.note(for: .claimRetryLater)
        let refused = L10n.Storage.ReverseAbort.note(for: .claimRefused)
        let otherDevice = L10n.Storage.ReverseAbort.note(for: .otherDeviceReverting)
        let uploadNotes: [ReverseAbortReason] = [.icloudFull, .icloudUnavailable, .stalled]

        for text in [retryLater, refused, otherDevice] {
            #expect(!text.isEmpty)
            #expect(!text.hasPrefix("storage.reverseAbort."), "la key cruda: falta en el idioma del simulador")
        }
        #expect(Set([retryLater, refused, otherDevice]).count == 3)
        for reason in uploadNotes {
            #expect(![retryLater, refused, otherDevice].contains(L10n.Storage.ReverseAbort.note(for: reason)),
                    "una salida del claim no puede decir lo mismo que una de la espera (\(reason))")
        }
        #expect(refused.contains(AppConstants.supportEmail))
        #expect(!refused.contains("%@"), "el placeholder se rellena")
        #expect(!retryLater.contains(AppConstants.supportEmail), "el pasajero se arregla esperando")
    }

    /// Cada motivo sale con SU clave. Las notas de la espera no cambiaron al mudarse de la vista a `L10n`, y las del claim
    /// no se cruzan entre sí: dos textos distintos pero intercambiados pasarían el test de arriba.
    @Test func note_eachReasonMapsToItsOwnKey() {
        #expect(L10n.Storage.ReverseAbort.note(for: .icloudFull) == L10n.Storage.ReverseAbort.icloudFull)
        #expect(L10n.Storage.ReverseAbort.note(for: .icloudUnavailable) == L10n.Storage.ReverseAbort.icloudUnavailable)
        #expect(L10n.Storage.ReverseAbort.note(for: .stalled) == L10n.Storage.ReverseAbort.stalled)
        #expect(L10n.Storage.ReverseAbort.note(for: .claimRetryLater) == L10n.Storage.ReverseAbort.claimRetryLater)
        #expect(L10n.Storage.ReverseAbort.note(for: .claimRefused)
            == L10n.Storage.ReverseAbort.claimRefused(AppConstants.supportEmail))
        #expect(L10n.Storage.ReverseAbort.note(for: .otherDeviceReverting)
            == L10n.Storage.ReverseAbort.otherDeviceReverting)
    }

    // MARK: - Qué vuelta al origen repone los pendientes

    /// Solo las vueltas al origen ANTES de que el servidor conceda la reserva: desde la confirmación y desde
    /// `reverseClaimLeader`. Después de concederla la vuelta empezó, y cualquier otra fase no es de la vuelta.
    @Test func restoresOnReturn_onlyBeforeTheClaimIsGranted() {
        for from: MigrationPhase in [.reverseConfirm(.done), .reverseConfirm(.notStarted), .reverseClaimLeader] {
            for to: MigrationPhase in [.done, .notStarted] {
                #expect(ReverseOriginPendingEffects.restoresOnReturn(from: from, to: to), "\(from) → \(to)")
            }
            for to: MigrationPhase in [.reverseDrainAll, .reverseFailedRollback, .reverseClaimLeader, .icloudActive] {
                #expect(!ReverseOriginPendingEffects.restoresOnReturn(from: from, to: to), "\(from) → \(to)")
            }
        }
        for from: MigrationPhase in [.reverseDrainAll, .reverseVerify, .reverseFreezeBackend, .reverseUpload,
                                     .reverseFailedRollback, .done, .notStarted, .claimingMigration] {
            for to: MigrationPhase in [.done, .notStarted] {
                #expect(!ReverseOriginPendingEffects.restoresOnReturn(from: from, to: to), "\(from) → \(to)")
            }
        }
    }

    // MARK: - El canario

    /// El gateway rechaza el LOTE entero de eventos si un detalle viene vacío o pasa de 128 caracteres, y el motivo
    /// llega de la red: lo que no tenga forma de código viaja como `other`.
    @Test func canaryDetail_passesCodes_andBoundsEverythingElse() {
        for code in ["not_complete", "migration_in_progress", "no_profile", "other_leader", "unknown"] {
            #expect(MetricsService.reverseClaimRejectedDetail(serverReason: code) == code)
        }
        for odd in ["", String(repeating: "a", count: 65), "Not Complete", "no-profile", "motivo raro", "ñ"] {
            #expect(MetricsService.reverseClaimRejectedDetail(serverReason: odd) == "other", "«\(odd)»")
        }
        #expect(MetricsService.reverseClaimRejectedDetail(serverReason: String(repeating: "a", count: 64))
            == String(repeating: "a", count: 64))
    }
}
