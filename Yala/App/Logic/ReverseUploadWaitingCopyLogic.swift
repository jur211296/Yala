//
//  ReverseUploadWaitingCopyLogic.swift
//  Yala
//
//  Qué dice «Dónde viven tus datos» mientras la vuelta a iCloud espera a que el mirror suba los datos, y qué dice
//  después si la espera terminó sin llegar (ticket `reverse-upload-has-no-ceiling-and-no-exit`). Hasta este ticket
//  esa espera era una barra al 95 % sin una palabra, con un «Retomar» que no cambiaba nada.
//
//  Pura: la vista solo traduce cada caso a su texto localizado.
//

import Foundation

nonisolated enum ReverseUploadWaitingCopyLogic {

    /// El mensaje de la espera, según lo que se sabe de por qué no drena.
    enum Message: Equatable {
        /// No se sabe de ningún problema: está subiendo.
        case uploading
        /// CloudKit dijo que iCloud no tiene espacio.
        case icloudFull
        /// CloudKit dijo que la cuenta de iCloud no sirve en este dispositivo.
        case icloudUnavailable
        /// No hay token de iCloud y CloudKit no dijo nada. El token mide iCloud DRIVE, así que el mensaje es
        /// CONDICIONAL: con Drive apagado CloudKit puede estar subiendo, y afirmar que no llega sería falso.
        case icloudMaybeOff
    }

    /// Lo que pinta la espera: el mensaje y, si ya se observó en este proceso, cuántas filas faltan.
    struct WaitingCopy: Equatable {
        let message: Message
        let pending: Int?
    }

    /// El caso de la espera. La cifra va con TODOS los mensajes: es lo que deja ver que la subida avanza aunque el
    /// mensaje hable de un problema, y esconderla empujaba a cancelar una subida que iba bien. Sin observación
    /// todavía —recién abierta la app, antes del primer sondeo— solo se sabe que está subiendo.
    static func waitingCopy(sample: ReverseUploadSample?) -> WaitingCopy {
        guard let sample else { return WaitingCopy(message: .uploading, pending: nil) }
        let message: Message
        switch sample.blocker {
        case .icloudFull:
            message = .icloudFull
        case .icloudUnusable:
            message = .icloudUnavailable
        case .icloudOff:
            message = .icloudMaybeOff
        case .unknown:
            message = .uploading
        }
        return WaitingCopy(message: message, pending: sample.pending)
    }

    /// El motivo que la pantalla explica tras una salida de la espera. `nil` = nada que explicar: no hubo salida, o
    /// la pidió la persona, que ya sabe por qué sigue en la nube.
    static func abortNote(_ reason: ReverseUploadAbortReason?) -> ReverseUploadAbortReason? {
        guard let reason, reason != .cancelled else { return nil }
        return reason
    }
}
