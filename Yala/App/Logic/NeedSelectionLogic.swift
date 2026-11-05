//
//  NeedSelectionLogic.swift
//  Yala
//
//  Lo que el Panel enseña con un filtro de necesidades, que es un CONJUNTO.
//
//  `SessionState.selectedNeeds` admite varias (Registros › Filtros inserta sin vaciar), y el cálculo del Panel ya las
//  usaba todas. El chip y el widget de necesidades, en cambio, leían `selectedNeeds.first`: con «Esencial» y
//  «Opcional» filtradas enseñaban una sola, y cuál no era estable (`Set.first`). Card
//  `tablero-con-dos-necesidades-filtradas-desde-regi-2y7e`; regla en `session-filters.md`.
//

import Foundation

enum NeedSelectionLogic {

    /// El orden en que se pintan: el de las leyendas del widget, no el del conjunto.
    static func ordered(_ selected: Set<SubcategoryNeed>) -> [SubcategoryNeed] {
        SubcategoryNeed.allCases.filter { selected.contains($0) }
    }

    /// Sin filtro, todas cuentan; con filtro, solo las elegidas.
    static func includes(_ need: SubcategoryNeed, in selected: Set<SubcategoryNeed>) -> Bool {
        selected.isEmpty || selected.contains(need)
    }

    /// Lo que suma un punto de la gráfica con ese filtro: el total sin filtro, la suma de las elegidas con él.
    static func amount(of point: NeedTrendPoint, for selected: Set<SubcategoryNeed>) -> Double {
        guard !selected.isEmpty else { return point.total }
        return selected.reduce(0) { $0 + point.amount(for: $1) }
    }

    /// Lo del período anterior que se compara con ese filtro. `nil` si no hay dato de ninguna elegida.
    static func previousAmount(
        total: Double?, byNeed: [SubcategoryNeed: Double], for selected: Set<SubcategoryNeed>
    ) -> Double? {
        guard !selected.isEmpty else { return total }
        let known = selected.compactMap { byNeed[$0] }
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    /// Tocar una necesidad en el widget o en su leyenda es «ver solo ésta»; si ya se veía solo ésa, quita el filtro.
    static func toggled(_ need: SubcategoryNeed, in selected: Set<SubcategoryNeed>) -> Set<SubcategoryNeed> {
        selected == [need] ? [] : [need]
    }
}
