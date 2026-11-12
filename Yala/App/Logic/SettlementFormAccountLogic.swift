//
//  SettlementFormAccountLogic.swift
//  Yala
//
//  Cuándo el formulario de pago de un grupo pregunta «¿De qué cuenta sale?».
//

import Foundation

enum SettlementFormAccountLogic {
    /// Solo quien PAGA elige de qué cuenta sale el dinero: el puente usa esa cuenta únicamente
    /// en ese caso (`GroupTransactionBridge.bridgeSettlement`, Caso C). A quien cobra le llega
    /// su propio borrador en la Bandeja, y un pago entre otros dos no toca sus cuentas, así que
    /// la pregunta les decía algo falso y lo elegido se ignoraba.
    ///
    /// Sin identidad resuelta (`nil`) se pregunta, como antes: el puente resuelve la identidad
    /// por su cuenta, y si sí paga, quitarle la fila le cambiaría el resultado.
    static func asksForAccount(currentUserMemberID: String?, payerMemberID: String) -> Bool {
        guard let currentUserMemberID else { return true }
        return currentUserMemberID == payerMemberID
    }
}
