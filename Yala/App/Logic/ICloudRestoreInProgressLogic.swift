//
//  ICloudRestoreInProgressLogic.swift
//  Yala
//
//  ¿Está ESTE proceso bajando el corpus del propio dueño AHORA MISMO?
//
//  Existe por un caso concreto: quien cambia de móvil o reinstala entra por «Restaurar desde iCloud»
//  y, mientras sus datos bajan, toca «atrás» y entra por la card de su cuenta. Ahí
//  `CrossAccountEntryGuardLogic` ve filas locales sin claim que las reclame —el claim vive en
//  `UserDefaults` y muere con la reinstalación, que es justo la mitad del escenario— y le bloquea la
//  entrada a su propia cuenta diciéndole que los datos son de otra.
//
//  LA SEÑAL ES ACOTADA A PROPÓSITO, y el porqué es lo que hay que entender antes de tocarla: un «hay
//  un import en curso» genérico se enciende también cuando el mirror de CloudKit re-importa por su
//  cuenta en cualquier arranque, y con ella encendida el guard dejaría adoptar sobre el corpus de otro
//  humano — exactamente la puerta que el guard existe para cerrar. Los DOS términos son necesarios:
//
//   1. **esta SESIÓN pidió restaurar** (`restoreRequestedThisSession`) — un acto explícito del usuario
//      en ESTE proceso. Vive en memoria y no en `UserDefaults` a propósito: si el proceso muere, la
//      señal se apaga y el guard vuelve a bloquear, que es el sesgo correcto (fail-closed).
//   2. **y ese import NO ha terminado** — con el import asentado las filas ya no son «las que estoy
//      bajando», son corpus preexistente como cualquier otro.
//
//  Residual DECLARADO: quien espera a que el restore termine del todo y solo DESPUÉS toca «atrás»
//  sigue viendo la pantalla de bloqueo. La señal está apagada y así tiene que ser — para él la salida
//  es el copy de la pieza 2 (`welcome.cloud.blockedRestoreHint`), no un veredicto distinto.
//

import Foundation

nonisolated enum ICloudRestoreInProgressLogic {

    /// - Parameters:
    ///   - restoreRequestedThisSession: el usuario abrió el restore de iCloud en ESTE proceso y la
    ///     búsqueda llegó a arrancar (iCloud disponible y sin wipe reciente — los dos estados en que
    ///     `WelcomeRestoreView` NO importa nada).
    ///   - hasCompletedFirstImport: CloudKit cerró al menos un `importEvent`
    ///     (`iCloudSyncService.hasCompletedFirstImport`).
    ///   - isImportQuiescent: pasó la ventana de quietud desde el último import
    ///     (`iCloudSyncService.isImportQuiescent`).
    ///
    /// - Returns: `true` SOLO si el corpus local de este device lo está trayendo el propio dueño
    ///   ahora. Ante cualquier duda, `false` — y `false` significa «el guard decide como siempre».
    static func isRestoringNow(
        restoreRequestedThisSession: Bool,
        hasCompletedFirstImport: Bool,
        isImportQuiescent: Bool
    ) -> Bool {
        guard restoreRequestedThisSession else { return false }
        // `hasCompletedFirstImport` solo NO basta y la asimetría es la misma que documenta
        // `waitForImportQuiescence`: la quiescencia es `true` ANTES del primer import, así que
        // preguntar solo por ella daría «ya terminó» cuando no ha empezado.
        return !(hasCompletedFirstImport && isImportQuiescent)
    }
}
