//
//  TransactionSaveFeedbackLogic.swift
//  Yala
//
//  Qué ve la persona al guardar un registro (UX 2.2 · L2-5, decidido por Jürgen el 14-oct y cerrado el 21-oct).
//

import Foundation

nonisolated enum TransactionSaveFeedbackLogic {

    enum Feedback: Equatable {
        /// La pantalla completa «¡Listo!» con el detalle.
        case fullScreen
        /// El formulario se cierra y sale «Gasto guardado · S/ 12.00» con «Editar» y «Deshacer».
        case savedNotice
        /// El formulario se cierra y sale «Cambios guardados».
        case editedNotice
    }

    /// Registros con pantalla completa: los tres primeros.
    static let fullScreenRecords = 3

    /// - Parameters:
    ///   - isEdit: se guardó una edición de un registro que ya existía.
    ///   - savedCountAfterSave: `transactionsSavedCount` contando el que se acaba de guardar.
    static func feedback(isEdit: Bool, savedCountAfterSave: Int) -> Feedback {
        if isEdit { return .editedNotice }
        return savedCountAfterSave <= fullScreenRecords ? .fullScreen : .savedNotice
    }
}
