//
//  SettingsReturnOpening.swift
//  Yala
//
//  UX 2.2 · L16-5 (opción B): tras cambiar el idioma con el selector de Yala, el Panel recién montado reabre Ajustes en
//  Personalización. Esto decide CUÁNDO pedir esa hoja y qué hacer si no llega a montarse.
//
//  **Por qué no basta con pedirla al aparecer** (card `tablero-tras-cambiar-el-idioma-desde-personaliza-6d71`, medido
//  el 2026-10-24 en iOS 27.0). El cambio de idioma reconstruye la app (`.id(languageVersion)` en `ContentView`) con
//  Ajustes y el selector de idioma todavía en pantalla: cuando el Panel nuevo aparece, la ventana sigue con DOS hojas
//  presentadas que UIKit está cerrando. Pedir Ajustes en ese momento compite con ese cierre —UIKit avisa «Attempt to
//  dismiss … while a presentation or dismiss is in progress»— y unas veces la hoja nueva sale y otras se descarta en
//  silencio. Si se descarta, el `isPresentingSettings` del Panel se queda en `true` sin hoja y el botón de Ajustes ya
//  no abre nada (poner `true` a lo que ya es `true` no cambia nada) hasta cerrar la app.
//
//  **Lo que hace.** (1) Espera a que la ventana no tenga NADA presentado: es la condición viva, no un retraso fijo. (2)
//  Pide la hoja y comprueba con UIKit que algo se presentó. (3) Si no llegó, baja el flag —el botón vuelve a funcionar— y
//  lo intenta otra vez. Si la ventana no se libera, no la pide: es preferible no reabrir Ajustes a dejar el botón muerto.
//

import Foundation

enum SettingsReturnOpening {

    enum Outcome: Equatable {
        /// La hoja se pidió con la ventana libre y UIKit la presentó.
        case presented
        /// La ventana no se liberó a tiempo: no se pidió nada y el flag sigue en `false`.
        case slotNeverFreed
        /// Se pidió y no llegó a presentarse ninguna de las veces: el flag quedó en `false`.
        case neverTook
    }

    /// Cada cuánto se vuelve a preguntar a UIKit.
    static let pollInterval: Duration = .milliseconds(50)
    /// Cuánto se espera a que se cierren las hojas de antes del cambio. Medido: el cierre tarda ~0,3-0,5 s.
    static let slotWaitPolls = 60  // 3 s
    /// Cuánto se espera a que la hoja pedida aparezca en UIKit. `presentedViewController` se pone al EMPEZAR la
    /// transición, así que esto no espera a la animación entera.
    static let presentationWaitPolls = 30  // 1,5 s
    static let maxAttempts = 2

    /// - Parameters:
    ///   - isWindowPresenting: la pregunta a UIKit (`ModalPresentationProbe.isAnythingPresented(in:)` de esta ventana).
    ///   - open: pide la hoja (pone el destino y `isPresentingSettings = true`).
    ///   - release: baja `isPresentingSettings` cuando la hoja pedida no llegó.
    ///   - pause: la espera entre preguntas; los tests la sustituyen.
    @MainActor
    static func run(
        isWindowPresenting: () -> Bool,
        open: () -> Void,
        release: () -> Void,
        pause: () async -> Void
    ) async -> Outcome {
        for _ in 0..<maxAttempts {
            guard await waitUntil({ !isWindowPresenting() }, polls: slotWaitPolls, pause: pause) else {
                return .slotNeverFreed
            }
            open()
            if await waitUntil(isWindowPresenting, polls: presentationWaitPolls, pause: pause) {
                return .presented
            }
            release()
            // Una vuelta antes de volver a pedirla: el `false → true` en la misma vuelta SwiftUI lo funde en nada.
            await pause()
        }
        return .neverTook
    }

    @MainActor
    private static func waitUntil(_ condition: () -> Bool, polls: Int, pause: () async -> Void) async -> Bool {
        for _ in 0...polls {
            if condition() { return true }
            await pause()
        }
        return false
    }
}
