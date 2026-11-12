//
//  GroupSubcategoryMatchLogic.swift
//  Yala
//
//  Grupos B · card 10u2: la categoría de un gasto de grupo viaja por NOMBRE (`SplitExpense.subcategoryName`; el servidor
//  de Grupos no se toca), y cada aparato la casa con una subcategoría suya. Con dos homónimas —«Otros» de gasto y «Otros»
//  de ingreso— el formulario y el puente podían quedarse con distinta: el formulario decidía venta y el puente veía un
//  gasto sin cuenta, o al revés. Esta es la ÚNICA regla, y la usan el puente (`GroupTransactionBridge.matchSubcategory`),
//  «Partir» (`GroupSplitLinesService`) y el formulario (`GroupExpenseViewModel`).
//
//  El orden: el nombre exacto sin mayúsculas antes que el «contiene» de reserva; entre las que casan igual, la de usuario
//  antes que la de sistema, la visible antes que la oculta (la que el selector ofrece: si no, elegir «Otros» de ingreso
//  con un «Otros» de gasto oculto cambiaba la elección por una que el selector ni enseña), la de GASTO antes que la de
//  ingreso (es el tipo por defecto del formulario, y en el aparato de otro miembro una de ingreso no clasifica su parte) y,
//  a igualdad, el menor `shortcutID`, que es el mismo en todos los aparatos de la persona. Sin ese último criterio, el
//  orden del fetch decidía.
//
//  Lógica pura: sin SwiftData.
//

import Foundation

nonisolated enum GroupSubcategoryMatchLogic {

    struct Candidate: Equatable, Sendable {
        let name: String
        let isSystem: Bool
        /// Oculta ella o su categoría: el selector no la ofrece.
        var isHidden: Bool = false
        let isIncome: Bool
        /// Desempate estable entre aparatos: el `shortcutID` en texto.
        let key: String
    }

    /// El índice de la subcategoría que casa con `name`, o `nil`.
    static func bestIndex(for name: String?, in candidates: [Candidate]) -> Int? {
        guard let name, !name.isEmpty else { return nil }
        let lowered = name.lowercased()
        let exact = candidates.indices.filter { candidates[$0].name.lowercased() == lowered }
        if let best = preferred(exact, in: candidates) { return best }
        let partial = candidates.indices.filter { candidates[$0].name.localizedCaseInsensitiveContains(name) }
        return preferred(partial, in: candidates)
    }

    private static func preferred(_ indices: [Int], in candidates: [Candidate]) -> Int? {
        indices.min { lhs, rhs in
            let a = candidates[lhs], b = candidates[rhs]
            if a.isSystem != b.isSystem { return !a.isSystem }
            if a.isHidden != b.isHidden { return !a.isHidden }
            if a.isIncome != b.isIncome { return !a.isIncome }
            return a.key < b.key
        }
    }
}
