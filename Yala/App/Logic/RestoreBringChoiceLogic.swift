//
//  RestoreBringChoiceLogic.swift
//  Yala
//
//  Card «Recuperar desde iCloud: un solo "Continuar"» (recorrido del 13-nov, E01). Quien toca «Traer mis datos» en «Ya
//  tienes datos en tu iCloud» reabre Yala, espera la carga y llegaba a «¡Qué bien volver a verte!» con la misma pregunta
//  otra vez («Traer mis datos» / «Empezar desde cero») y una flecha atrás. Jürgen: un solo botón para seguir, sin volver a
//  preguntar.
//
//  La elección vive en disco porque entre las dos pantallas hay un relanzamiento: el origen de Restaurar que el Welcome
//  apunta (`welcomeRestoreOrigin`) es un `@State` y muere con el proceso.
//

import Foundation

/// La marca «ya eligió traer sus datos» entre la puerta de iCloud privado y Restaurar.
///
/// - La ENCIENDE la puerta al tocar «Traer mis datos» (`WelcomePrivateICloudGateView`), en el Welcome y en la activación de
///   Yala completo, que comparten la pantalla.
/// - La APAGA el Welcome al abrir Restaurar desde cualquier otra entrada («¡Hola de nuevo!», la puerta de Grupos): ahí la
///   persona todavía no eligió nada.
/// - La APAGAN el principal y la flecha atrás de Restaurar: no puede sobrevivir a la restauración que la usó.
///   «Empezar desde cero» no la toca, a propósito: lleva a la puerta, que la vuelve a escribir si se elige traer los datos,
///   y su cuerpo (`discardImportAndStartFresh`) está fijado entero por `ICloudRestoreSignalTests`.
enum RestoreBringChoiceStore {

    static let key = "welcome.restore.bringChosenAtGate"

    static func recordChosenAtGate(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    static func wasChosenAtGate(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Qué ofrece «¡Qué bien volver a verte!» (el estado `.found` de Restaurar).
enum RestoreFoundActionsLogic {

    struct Actions: Equatable {
        /// `true` = el botón principal dice «Continuar»; `false` = «Traer mis datos».
        let primaryIsContinue: Bool
        /// «Empezar desde cero» debajo del principal.
        let offersStartFresh: Bool
        /// La flecha atrás de la barra.
        let offersBack: Bool
    }

    /// Con la elección ya hecha en la puerta: un solo «Continuar», sin segunda pregunta ni flecha atrás. Sin ella (se llegó
    /// por «Restaurar desde iCloud»), la pregunta de siempre: es la primera vez que la persona la ve.
    static func actions(bringChosenAtGate: Bool) -> Actions {
        bringChosenAtGate
            ? Actions(primaryIsContinue: true, offersStartFresh: false, offersBack: false)
            : Actions(primaryIsContinue: false, offersStartFresh: true, offersBack: true)
    }
}
