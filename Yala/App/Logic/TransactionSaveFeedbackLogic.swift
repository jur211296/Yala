//
//  TransactionSaveFeedbackLogic.swift
//  Yala
//
//  Qué ve la persona al guardar un registro. Desde el 2026-11-23 (decisión de Jürgen: «la pantalla de éxito aparece
//  siempre al guardar un registro nuevo, sin excepciones») un registro nuevo enseña siempre la pantalla completa.
//  Antes (UX 2.2 · L2-5, 14/21-oct) solo los tres primeros; desde el cuarto el formulario se cerraba con el aviso breve,
//  y en la 2.3 se leyó como «la pantalla de éxito ya no sale».
//  «Hacer recurrente» desde el «···» de Nuevo registro también enseña la pantalla completa (decisión de Jürgen del
//  2026-11-23); el aviso breve «Guardado · se repetirá cada mes» queda para una edición y para la oferta de la propia
//  pantalla de éxito, que ya se vio.
//

import Foundation

nonisolated enum TransactionSaveFeedbackLogic {

    enum Feedback: Equatable {
        /// La pantalla completa «¡Listo!» con el detalle.
        case fullScreen
        /// El formulario se cierra y sale «Cambios guardados».
        case editedNotice
        /// El formulario se cierra y sale «Guardado · se repetirá cada mes» (o semana, o año).
        case recurringNotice
    }

    /// - Parameter isEdit: se guardó una edición de un registro que ya existía.
    static func feedback(isEdit: Bool) -> Feedback {
        isEdit ? .editedNotice : .fullScreen
    }

    /// Lo que ve la persona tras «Hacer recurrente».
    /// - Parameters:
    ///   - isEdit: el registro ya existía antes de este guardado.
    ///   - successScreenShown: se pidió desde la oferta «Recurrente» de la pantalla de éxito, que ya está a la vista.
    static func recurringFeedback(isEdit: Bool, successScreenShown: Bool) -> Feedback {
        (isEdit || successScreenShown) ? .recurringNotice : .fullScreen
    }
}
