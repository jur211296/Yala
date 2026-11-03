//
//  GroupBridgeEditedAccountLogic.swift
//  Yala
//
//  Card 8933 (2026-11-02) · qué hace el puente con tu registro de un gasto de grupo que pagaste cuando EDITAS el gasto y
//  eliges otra cuenta. Hasta ese día la rama «preserve+update» del Caso A no tocaba nunca la cuenta: la pastilla del
//  formulario enseñaba la cuenta B y el dinero seguía saliendo de la A; y con otra moneda el registro se borraba y quedaba
//  un borrador en la Bandeja aunque la cuenta elegida ya fuera de esa moneda.
//
//  La regla sigue siendo «NUNCA pisar la cuenta» para todo lo que NO es tu edición: un cambio que baja de otro teléfono
//  (`isRemoteSync`) o un re-puente sin cuenta (`GroupsPendingBridgeResume`, la Bandeja) no saben qué cuenta quieres.
//  Solo la cuenta que eligió la persona en el formulario, de la moneda del gasto, mueve el registro.
//

import Foundation

nonisolated enum GroupBridgeEditedAccountLogic {

    enum Decision: Equatable {
        /// Misma moneda y misma cuenta (o nadie eligió otra): se actualizan importe y fecha, la cuenta se queda.
        case keep
        /// Misma moneda, otra cuenta elegida al editar: el registro pasa a esa cuenta.
        case move
        /// Moneda nueva y una cuenta elegida de esa moneda: el registro se rehace en la cuenta elegida.
        case recreateInChosenAccount
        /// Moneda nueva sin cuenta elegida de esa moneda (otro teléfono, re-puente): borrador en la Bandeja, como antes.
        case currencyDraft
    }

    static func decide(
        isRemoteSync: Bool,
        recordAccountID: UUID?,
        recordCurrency: String,
        chosenAccountID: UUID?,
        chosenAccountCurrency: String?,
        expenseCurrency: String
    ) -> Decision {
        let chosenFits = !isRemoteSync && chosenAccountID != nil && chosenAccountCurrency == expenseCurrency
        guard recordCurrency == expenseCurrency else {
            return chosenFits ? .recreateInChosenAccount : .currencyDraft
        }
        guard chosenFits, let chosenAccountID, chosenAccountID != recordAccountID else { return .keep }
        return .move
    }
}
