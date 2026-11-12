//
//  GroupsUserFacingErrorLogic.swift
//  Yala
//
//  Qué texto ve la persona cuando falla una acción de Grupos o de sus borradores en la Bandeja.
//

import Foundation

enum GroupsUserFacingErrorLogic {
    /// Los errores de Yala que ya hablan con la persona (`GroupExpenseServiceError`, `DraftServiceError`)
    /// dicen su texto; cualquier otro —un fallo de SwiftData, `GroupTransactionBridgeError`— se queda en
    /// el mensaje genérico. Hasta el lote 13 estas pantallas enseñaban `localizedDescription` tal cual, y
    /// eso llegaba a la alerta como texto de desarrollo en inglés («GroupExpenseService: Save failed…»).
    static func message(for error: Error) -> String {
        switch error {
        case let known as GroupExpenseServiceError:
            return known.errorDescription ?? L10n.Groups.Errors.actionFailed
        case let known as DraftServiceError:
            return known.errorDescription ?? L10n.Groups.Errors.actionFailed
        default:
            return L10n.Groups.Errors.actionFailed
        }
    }
}
