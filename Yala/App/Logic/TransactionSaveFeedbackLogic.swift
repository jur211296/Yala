//
//  TransactionSaveFeedbackLogic.swift
//  Yala
//
//  Qué ve la persona al guardar un registro. Desde el 2026-11-23 (decisión de Jürgen: «la pantalla de éxito aparece
//  siempre al guardar un registro nuevo, sin excepciones») un registro nuevo enseña siempre la pantalla completa.
//  Antes (UX 2.2 · L2-5, 14/21-oct) solo los tres primeros; desde el cuarto el formulario se cerraba con el aviso breve,
//  y en la 2.3 se leyó como «la pantalla de éxito ya no sale». El aviso breve sigue para «Hacer recurrente».
//

import Foundation

nonisolated enum TransactionSaveFeedbackLogic {

    enum Feedback: Equatable {
        /// La pantalla completa «¡Listo!» con el detalle.
        case fullScreen
        /// El formulario se cierra y sale «Cambios guardados».
        case editedNotice
    }

    /// - Parameter isEdit: se guardó una edición de un registro que ya existía.
    static func feedback(isEdit: Bool) -> Feedback {
        isEdit ? .editedNotice : .fullScreen
    }
}
