//
//  OpeningBalanceErrorCopyLogic.swift
//  Yala
//
//  Lote 2.3 de Grupos (10-nov): lo que se le dice a la persona cuando no se puede guardar, editar o quitar un saldo
//  inicial. El servicio lanza `expenseHasAssociatedSettlements` también para un saldo inicial, y su texto general habla
//  de BORRAR un gasto (`groups.bridge.deleteExpenseBlocked`), falso al editar un saldo. Aquí se cambia solo ese caso; el
//  resto sigue con el texto de siempre.
//

import Foundation

enum OpeningBalanceErrorCopyLogic {

    static func message(for error: Error) -> String {
        if case GroupExpenseServiceError.expenseHasAssociatedSettlements = error {
            return L10n.Groups.OpeningBalance.errorLockedBySettlements
        }
        return GroupsUserFacingErrorLogic.message(for: error)
    }
}
