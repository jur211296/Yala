//
//  WidgetSelectionFallback.swift
//  Yala
//
//  UX 2.2 · L15-2 (opción C, Jürgen 2026-10-18). Un widget de presupuestos o de pagos configurado a mano decía «Sin
//  presupuestos» cuando lo elegido ya se había borrado, aunque hubiera otros: era el único caso en el que el widget
//  mentía con datos delante. Ahora, si de lo elegido no queda nada, vuelve solo a lo automático (los más usados, los
//  próximos).
//
//  Membership: Yala (para los tests) + YalaWidgetsExtension (vía exception set en el pbxproj, como
//  `WidgetAmountSplitter`). Sin dependencias de la app ni de WidgetKit.
//

import Foundation

nonisolated enum WidgetSelectionFallback {

    /// Lo que enseña un widget con selección manual.
    /// - Parameters:
    ///   - selectedIDs: lo elegido a mano, en el orden elegido. Vacío = modo automático.
    ///   - available: todo lo que hay hoy, en cualquier orden.
    ///   - automatic: lo que el widget enseña en automático, ya ordenado.
    ///   - id: la identidad de cada elemento.
    ///   - limit: cuántos caben en ese tamaño.
    /// - Returns: lo elegido que sigue existiendo, en su orden; si no queda nada (o no se eligió nada), lo automático.
    static func resolve<Item>(
        selectedIDs: [String],
        available: [Item],
        automatic: [Item],
        id: (Item) -> String,
        limit: Int
    ) -> [Item] {
        let chosen = selectedIDs.compactMap { selected in available.first { id($0) == selected } }
        let shown = chosen.isEmpty ? automatic : chosen
        return Array(shown.prefix(max(0, limit)))
    }
}
