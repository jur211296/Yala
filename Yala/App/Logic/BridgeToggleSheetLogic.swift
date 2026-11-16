//
//  BridgeToggleSheetLogic.swift
//  Yala
//
//  Ticket `bridge-history-import-is-only-offered-when-something-was-already-bridged` (lote 2.3 de Grupos, 10-nov).
//  Qué hoja sale al cambiar «Reflejar en tus cuentas», en Ajustes de Grupos y en los de cada grupo.
//
//  Al ENCENDERLO, la hoja de activación ofrece «Importar todo el historial»: los gastos de grupo que ya existen. Hasta
//  este día salía solo si ya había movimientos reflejados, así que la primera vez —cuando más falta hace— no salía. Ahora
//  sale si hay gastos que importar. Al APAGARLO, la de desactivar sigue pidiendo movimientos reflejados: es lo que decide.
//

import Foundation

enum BridgeToggleSheetLogic {

    enum Sheet: Equatable {
        case activation
        case deactivation
    }

    static func sheet(turningOn: Bool, hasGroupExpenses: Bool, hasBridgedTransactions: Bool) -> Sheet? {
        if turningOn {
            return hasGroupExpenses ? .activation : nil
        }
        return hasBridgedTransactions ? .deactivation : nil
    }
}
