//
//  StorageFailureCopyLogic.swift
//  Yala
//
//  El texto de la tarjeta de fallo de Almacenamiento («No pudimos activar la nube…»). Vivía dentro de
//  `StorageSettingsView` y sale aquí para poder fijarlo con un test que compare TEXTOS: es el texto lo que la persona
//  lee, y dos motivos que acabaran en la misma frase no los distingue ningún enum.
//

import Foundation

enum StorageFailureCopyLogic {

    /// Qué dice la tarjeta de fallo.
    ///
    /// **La subida del snapshot manda antes que el canal iCloud** (ticket
    /// `snapshot-upload-has-no-ceiling-and-no-way-out`, decisión de Jürgen: texto por motivo). En la práctica no pueden
    /// coincidir —los dos terminan el intento en `failedRollback`, y «Reintentar» limpia los dos—, pero si coincidieran,
    /// el de la subida es el único escrito por ESTE fallo: el veredicto del canal solo se escribe al entrar al cutover,
    /// que va después.
    ///
    /// Cada motivo de la subida dice quién falló solo cuando fue ése: `accountUnavailable` nombra la cuenta y da el
    /// correo de soporte —en `/sync/push` es el 409 de una cuenta congelada porque otro dispositivo la está devolviendo a
    /// iCloud, o un 403 si la ruta llega a emitirlo—; `sessionExpired` pide volver a entrar, y solo sale con la sesión ya
    /// borrada, que es cuando «Migrar» de verdad lo pide; el fallo local habla del dispositivo; y el techo largo —72 h sin
    /// avanzar, con la causa que fuera— no acusa a nadie, ni siquiera a la red.
    ///
    /// **Los tres pasos sin cifra que baje —22 %, 35 %, 80 %— van después de la subida** (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`, decisión de Jürgen: texto por motivo también aquí). Tampoco
    /// pueden coincidir con ella: cada motivo solo lo escribe la salida de su techo, y «Reintentar» limpia los dos. Reusan
    /// las dos frases de la subida que siguen siendo verdad fuera de ella —la cuenta que no lo permitió, que da el correo, y
    /// el dispositivo que no pudo preparar los datos— y tienen tres propias, porque las de la subida hablan de «subir tus
    /// datos» y al 22 % todavía no se ha subido nada: la activación que lleva días sin avanzar, la sesión que caducó antes
    /// de terminar y otro dispositivo de la cuenta que tomó el relevo. Ninguna de esas tres da el correo.
    static func message(
        kind: CloudMigrationUIState.FailureKind,
        snapshotExit: SnapshotExitReason?,
        forwardStepExit: ForwardStepExitReason? = nil,
        cutoverBlocker: ICloudChannelVerdict?,
        supportEmail: String = AppConstants.supportEmail
    ) -> String {
        guard kind == .migration else { return L10n.Storage.Failed.reverse }
        if let snapshotExit {
            switch snapshotExit {
            case .stalled:            return L10n.Storage.Failed.snapshotStalled
            case .sessionExpired:     return L10n.Storage.Failed.snapshotSessionExpired
            case .accountUnavailable: return L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail)
            case .localFailure:       return L10n.Storage.Failed.snapshotLocalFailure
            }
        }
        if let forwardStepExit {
            switch forwardStepExit {
            case .stalled:                       return L10n.Storage.Failed.stepStalled
            case .sessionExpired:                return L10n.Storage.Failed.stepSessionExpired
            case .accountUnavailable, .refused:  return L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail)
            case .otherDevice:                   return L10n.Storage.Failed.stepOtherDevice
            case .localFailure:                  return L10n.Storage.Failed.snapshotLocalFailure
            }
        }
        // C-1: copy del fallo por MOTIVO. El veredicto del canal iCloud sobrevive en el journal a `failedRollback`
        // justo para esto: "no pudimos" sin decir por qué deja al usuario sin ninguna acción posible, y con
        // "iCloud lleno" la acción (liberar espacio) es concreta. Sin veredicto → el copy genérico de siempre.
        switch cutoverBlocker {
        case .quotaExceeded:
            return L10n.Storage.Failed.migrationICloudFull
        case .noAccountWithFootprint, .accountUnusable:
            return L10n.Storage.Failed.migrationICloudOff
        case .healthy, .noChannelNoFootprint:
            // El canal se veía sano y aun así el marcador no llegó: es el atasco sin causa conocida.
            return L10n.Storage.Failed.migrationICloudStalled
        case nil:
            return L10n.Storage.Failed.migration
        }
    }
}
