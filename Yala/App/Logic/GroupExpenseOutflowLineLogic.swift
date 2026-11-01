//
//  GroupExpenseOutflowLineLogic.swift
//  Yala
//
//  La línea bajo los selectores de Nuevo gasto de Grupos (registro unificado, opción A, 2026-10-31): lo que de verdad
//  pasa en tus registros cuando pagas tú. «Salen S/ 240.00 de tu cuenta y te deben S/ 160.00»: el gasto entero sale de tu
//  cuenta y lo que pagaste por los demás vuelve como deuda. No dice «tu parte»: tu parte no es lo que sale de la cuenta
//  (review del PR #719).
//
//  Solo sale cuando se pide la cuenta (pagas tú y el puente está activo), hay participantes y el reparto cuadra: con el
//  reparto a medias, lo que te deben aún no existe. Y solo al CREAR: al editar, el puente no mueve el registro que ya
//  existe a otra cuenta (y si cambia la moneda lo devuelve a la Bandeja), así que la frase prometería algo que no pasa
//  (review adversarial del 2026-11-01).
//
//  Tu parte es la que se GUARDA (`GroupExpenseViewModel.calculatedShares`, redondeada al céntimo con el sobrante
//  repartido), no la de `effectiveAmountsByID`, que no redondea: con S/ 100 entre tres y tú primero, lo guardado es 33.34 y
//  el puente apunta 66.66 prestados; la cifra sin redondear decía 66.67.
//

import Foundation

enum GroupExpenseOutflowLineLogic {

    struct Line: Equatable {
        /// Lo que sale de tu cuenta: el gasto entero.
        let paidOut: Double
        /// Lo que te deben los demás. `nil` si nadie te debe nada (el gasto era solo tuyo).
        let owedToYou: Double?
    }

    /// - Parameters:
    ///   - accountRequired: el formulario pide tu cuenta (`GroupExpenseViewModel.isAccountRequired`).
    ///   - isEditing: se edita un gasto que ya existe.
    ///   - amount: el gasto entero.
    ///   - hasParticipants: hay alguien en el reparto.
    ///   - sharesBalanced: el reparto cuadra con el gasto.
    ///   - myShare: tu parte guardada. `nil` o 0 si no participas: entonces te deben todo.
    static func line(
        accountRequired: Bool,
        isEditing: Bool,
        amount: Double,
        hasParticipants: Bool,
        sharesBalanced: Bool,
        myShare: Double?
    ) -> Line? {
        guard accountRequired, !isEditing, amount > 0, hasParticipants, sharesBalanced else { return nil }
        let owed = amount - max(0, myShare ?? 0)
        return Line(paidOut: amount, owedToYou: owed >= 0.005 ? owed : nil)
    }

    /// Tu parte tal como se guarda: la de `shares` (`GroupExpenseViewModel.calculatedShares`). `nil` sin reparto o si no
    /// participas.
    static func myStoredShare(_ shares: [(memberID: String, amount: Double)]?, myMemberID: String?) -> Double? {
        guard let myMemberID else { return nil }
        return shares?.first { $0.memberID == myMemberID }?.amount
    }
}
