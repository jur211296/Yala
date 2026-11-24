//
//  RecordsQuickCategoryDetentLogic.swift
//  Yala
//
//  A qué altura va la hoja de «Categoría ▾» de Registros (Jürgen, 23-nov, pruebas de 2.3 en el iPhone). Tocar una
//  categoría saca sus subcategorías DEBAJO de la rejilla, y a media altura quedaban fuera de la vista: no se notaba que
//  habían aparecido. Ahora la hoja abre a media altura solo si no hay nada elegido; con algo elegido, abre grande; y
//  al elegir una categoría sube a grande y se desplaza hasta sus subcategorías, para que se vean enteras.
//
//  SwiftUI no mueve una hoja ya presentada al cambiar su `selection` (medido, `swiftui-ds.md`): la sube
//  `growsSheetToLarge`, por la hoja de UIKit. Esto solo decide CUÁNDO.
//

import SwiftUI

enum RecordsQuickCategoryDetentLogic {
    private typealias Selection = RecordsQuickCategorySelectionLogic

    /// Hay alguna categoría elegida (entera o a medias) entre las que se ofrecen.
    static func hasChosenCategory<C: Hashable, S: Hashable>(
        _ entries: [RecordsQuickCategorySelectionLogic.Entry<C, S>],
        in expanded: Set<S>
    ) -> Bool {
        entries.contains { Selection.isChosen($0, in: expanded) }
    }

    /// Al abrir: media altura sin nada elegido; grande si ya había una categoría elegida, para ver sus subcategorías.
    static func initialDetent<C: Hashable, S: Hashable>(
        _ entries: [RecordsQuickCategorySelectionLogic.Entry<C, S>],
        expanded: Set<S>
    ) -> PresentationDetent {
        hasChosenCategory(entries, in: expanded) ? .large : .medium
    }

    /// La categoría que el toque acaba de elegir (antes no lo estaba), o `nil`. Sus subcategorías salen debajo: la hoja
    /// sube y se desplaza hasta ellas. Quitar una categoría, o tocar una subcategoría, no da ninguna.
    static func newlyChosen<C: Hashable, S: Hashable>(
        _ entries: [RecordsQuickCategorySelectionLogic.Entry<C, S>],
        before: Set<S>,
        after: Set<S>
    ) -> C? {
        entries.first { !Selection.isChosen($0, in: before) && Selection.isChosen($0, in: after) }?.id
    }

    /// El toque eligió una categoría nueva: la hoja sube a grande.
    static func growsToLarge<C: Hashable, S: Hashable>(
        _ entries: [RecordsQuickCategorySelectionLogic.Entry<C, S>],
        before: Set<S>,
        after: Set<S>
    ) -> Bool {
        newlyChosen(entries, before: before, after: after) != nil
    }
}
