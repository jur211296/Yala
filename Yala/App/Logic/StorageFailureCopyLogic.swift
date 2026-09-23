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
    /// avanzar, con la causa que fuera— no acusa a nadie, ni siquiera a la red. El techo corto con motivos turnándose
    /// (`mixedCauses`, ticket `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`) tampoco: no
    /// nombra motivo ni plazo, porque ninguno de los dos llegó solo y la salida llega a los 15 min, no a los días.
    ///
    /// **Los tres pasos sin cifra que baje —22 %, 35 %, 80 %— van después de la subida** (ticket
    /// `forward-migration-steps-have-no-ceiling-and-no-exit`, decisión de Jürgen: texto por motivo también aquí). Tampoco
    /// pueden coincidir con ella: cada motivo solo lo escribe la salida de su techo, y «Reintentar» limpia los dos. Reusan
    /// las dos frases de la subida que siguen siendo verdad fuera de ella —la cuenta que no lo permitió, que da el correo, y
    /// el dispositivo que no pudo preparar los datos— y tienen tres propias, porque las de la subida hablan de «subir tus
    /// datos» y al 22 % todavía no se ha subido nada: la activación que lleva días sin avanzar, la sesión que caducó antes
    /// de terminar y otro dispositivo de la cuenta que tomó el relevo. Ninguna de esas tres da el correo.
    ///
    /// **El claim de un ADOPT va primero, y con frases propias** (ticket `adopt-claim-stays-parked-with-no-ceiling`). Quien
    /// entraba en una cuenta que ya existe puede estar en un teléfono recién instalado, así que ninguna dice «tus datos
    /// están a salvo en tu dispositivo»: hablan de lo que tiene en la nube, que el claim no tocó. Cuando salen, también
    /// está puesto `forwardStepExit` —es la misma salida—, y por eso se miran antes. `.cancelled` no llega a esta tarjeta
    /// (cancelar va a `notStarted`), y si llegara cae a los motivos de siempre.
    ///
    /// **El EFECTO del adopt sale por la misma marca, con dos frases propias** (ticket
    /// `adopt-effect-retries-forever-with-no-ceiling`, textos de Jürgen del 2026-09-23): la base local que no se deja leer y
    /// la activación que lleva días sin poder terminar. Tampoco dicen «no cambiamos nada en la nube»: el reconcile puede
    /// haber subido algo de este teléfono antes de fallar. Y tampoco «tus datos siguen en este dispositivo», por la razón
    /// del claim: en un teléfono recién instalado sus datos están en la nube (lo cazó la review; Jürgen eligió «lo que
    /// tienes en este dispositivo sigue aquí», que es verdad en los dos teléfonos).
    static func message(
        kind: CloudMigrationUIState.FailureKind,
        snapshotExit: SnapshotExitReason?,
        forwardStepExit: ForwardStepExitReason? = nil,
        adoptClaimExit: AdoptClaimExit? = nil,
        cutoverBlocker: ICloudChannelVerdict?,
        supportEmail: String = AppConstants.supportEmail
    ) -> String {
        guard kind == .migration else { return L10n.Storage.Failed.reverse }
        switch adoptClaimExit {
        case .stalled:            return L10n.Storage.Failed.adoptStalled
        case .sessionExpired:     return L10n.Storage.Failed.adoptSessionExpired
        case .accountUnavailable: return L10n.Storage.Failed.adoptAccountUnavailable(supportEmail)
        case .effectStalled:      return L10n.Storage.Failed.adoptEffectStalled
        case .effectLocalFailure: return L10n.Storage.Failed.adoptEffectLocalFailure
        case .cancelled, nil:     break
        }
        if let snapshotExit {
            switch snapshotExit {
            case .stalled:            return L10n.Storage.Failed.snapshotStalled
            case .sessionExpired:     return L10n.Storage.Failed.snapshotSessionExpired
            case .accountUnavailable: return L10n.Storage.Failed.snapshotAccountUnavailable(supportEmail)
            case .localFailure:       return L10n.Storage.Failed.snapshotLocalFailure
            case .mixedCauses:        return L10n.Storage.Failed.snapshotMixedCauses
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
