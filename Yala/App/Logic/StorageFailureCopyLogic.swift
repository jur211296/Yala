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
    static func message(
        kind: CloudMigrationUIState.FailureKind,
        snapshotExit: SnapshotExitReason?,
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
