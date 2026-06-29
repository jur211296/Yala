//
//  TwoPersonSplitOptions+Text.swift
//  Yala
//
//  Textos localizados de las 4 opciones rápidas (capa de presentación, separada del
//  helper pure-logic para mantenerlo testeable sin bundle). Compartidos por la sheet
//  GroupTwoPersonSplitView y el chip-resumen de GroupExpenseFormView.
//

import Foundation

extension TwoPersonSplitOptions.Choice {

    /// Acción en lenguaje natural ("Pagaste · partes iguales", "Pagó María · es todo tuyo").
    func actionTitle(otherName: String) -> String {
        switch self {
        case .iPaidEqual: return L10n.Groups.Expense.TwoPerson.actionIPaidEqual
        case .iPaidOwedFull: return L10n.Groups.Expense.TwoPerson.actionIPaidOwedFull(otherName)
        case .theyPaidEqual: return L10n.Groups.Expense.TwoPerson.actionTheyPaidEqual(otherName)
        case .theyPaidOwedFull: return L10n.Groups.Expense.TwoPerson.actionTheyPaidOwedFull(otherName)
        }
    }

    /// Saldo resultante con el monto ya formateado ("María te debe S/ 25" / "Le debes S/ 25 a María").
    func debtText(otherName: String, amountStr: String) -> String {
        switch debtDirection {
        case .theyOweMe: return L10n.Groups.Expense.TwoPerson.theyOweAmount(otherName, amountStr)
        case .iOwe: return L10n.Groups.Expense.TwoPerson.youOweAmount(otherName, amountStr)
        }
    }
}
