//
//  GroupExpenseAmountResolver.swift
//  Yala
//
//  Pure-logic resolver para perspectiva personal del current user en un gasto compartido.
//

import Foundation

enum PersonalShareStatus: Equatable {
    /// Yo pagué (el grupo me debe `amount` = totalExpense - miParte).
    case youAreOwed(amount: Double)
    /// Otro pagó y yo participo (yo debo `amount` = miParte del split).
    case youOwe(amount: Double)
    /// No participo en este gasto.
    case notIncluded
    /// **No se sabe quién soy en este grupo** — la identidad local aún no resolvió.
    ///
    /// No es lo mismo que `notIncluded`, y confundirlos costó un bug de device: en el build 12 la
    /// pantalla afirmaba «No participaste» a alguien que sí participaba, porque el llamador pasaba
    /// `currentMemberID ?? ""` y el centinela vacío no casaba con nadie. La ignorancia entraba por
    /// la misma puerta que el conocimiento y salía convertida en una frase categórica.
    ///
    /// Quien pinte este caso NO debe afirmar nada sobre la participación: se calla. Es preferible
    /// una fila sin perspectiva personal a una que le diga a alguien que no participó en un gasto
    /// que sí comparte — y que además contradice a lo que ve el otro teléfono.
    case identityUnresolved
}

enum GroupExpenseAmountResolver {

    /// Resuelve la perspectiva personal del current user en un expense.
    ///
    /// - Parameters:
    ///   - expense: el gasto compartido.
    ///   - share: el share del current user. `nil` cuando no tiene parte asignada — para un
    ///     NO-pagador significa que no participa; para el pagador significa que prestó el total.
    ///   - currentMemberID: id del current member (uuidString).
    static func resolve(
        expense: SplitExpense,
        share: SplitShare?,
        currentMemberID: String?
    ) -> PersonalShareStatus {
        // Identidad sin resolver ⇒ no se afirma NADA. Antes los dos llamadores pasaban
        // `currentMemberID ?? ""`, y ese centinela vacío no casa con ningún `paidByMemberID`, así
        // que un no-saber se degradaba a «No participaste» — la frase que el device vio el
        // 2026-08-28 en un gasto que el otro teléfono mostraba mitad y mitad.
        guard let currentMemberID else { return .identityUnresolved }
        // El pagador SIEMPRE participa (modelo Splitwise), tenga o no `SplitShare` propio:
        // pagar algo cuya parte propia es 0 (otro lo devuelve todo) = prestar el total. Por eso
        // se evalúa el pagador ANTES del guard de `share`.
        if expense.paidByMemberID == currentMemberID {
            return .youAreOwed(amount: expense.amount - (share?.amount ?? 0))
        }
        // No-pagador sin share: no participa en el gasto.
        guard let share else { return .notIncluded }
        return .youOwe(amount: share.amount)
    }
}
