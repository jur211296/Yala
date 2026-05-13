//
//  RecordsMotivationalLogic.swift
//  Yala
//
//  Pure-logic helper para el subtítulo motivacional del hero de Records.
//  Devuelve un enum con el caso correspondiente al conteo filtrado; la
//  localización vive en el callsite UI (RecordsTabView.localizedMotivational).
//  Mantener este helper sin dependencias de L10n garantiza tests deterministas
//  sin Bundle lookup ni singletons.
//

import Foundation

enum RecordsHeroSubtitle: Equatable {
    case one
    case many(Int)
}

enum RecordsMotivationalLogic {
    /// Decide el subtítulo motivacional según el conteo total de registros
    /// filtrados. Retorna `nil` cuando no hay registros (count <= 0): la vista
    /// cubre N=0 con el empty state, no con subtítulo.
    static func subtitle(forCount count: Int) -> RecordsHeroSubtitle? {
        guard count > 0 else { return nil }
        return count == 1 ? .one : .many(count)
    }
}
