//
//  CategoryQuickPickLogic.swift
//  Yala
//
//  Decisión 21 de la revisión 2.3 (Jürgen, 9-nov-2026), opción C2 + C3: al abrir un registro nuevo, las categorías
//  frecuentes están a un toque, y el buscador de la hoja entiende las palabras con que la gente nombra lo que compró.
//  Sin SwiftUI ni SwiftData, para fijarlo con tests.
//

import Foundation

// MARK: - C2 · Las tres categorías más usadas

/// La fila del formulario: las tres categorías que la persona más usa y, mientras no haya tantas, las de arranque.
enum CategoryQuickPickLogic {

    /// Cuántas caben en la fila, además de «Más…».
    static let limit = 3

    /// Las de arranque para quien empieza (decisión 21): Restaurantes, Supermercados y Taxis y apps. Solo en un gasto:
    /// para un ingreso la decisión no eligió ninguna, y la fila enseña solo lo que la persona ya usó.
    static let expenseStarterSeeds = ["restaurants", "supermarkets", "rideshare"]

    /// `usedNewestFirst`: la categoría de cada registro reciente, del más nuevo al más viejo, con repeticiones. Sale
    /// primero la más usada; a igualdad, la usada más recientemente. Si no llegan a `limit`, se completan con
    /// `starters` en su orden, sin repetir.
    static func pick<ID: Hashable>(usedNewestFirst: [ID], starters: [ID], limit: Int = limit) -> [ID] {
        var counts: [ID: Int] = [:]
        var firstSeen: [ID: Int] = [:]
        for (index, id) in usedNewestFirst.enumerated() {
            counts[id, default: 0] += 1
            if firstSeen[id] == nil { firstSeen[id] = index }
        }
        let mostUsed = counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs, default: 0]
            let rhsCount = counts[rhs, default: 0]
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return firstSeen[lhs, default: .max] < firstSeen[rhs, default: .max]
        }
        var result = Array(mostUsed.prefix(limit))
        for starter in starters where result.count < limit && !result.contains(starter) {
            result.append(starter)
        }
        return result
    }
}

// MARK: - C3 · Las palabras del día a día

/// Las palabras que llevan a cada categoría sembrada en el buscador de la hoja: «café» a Restaurantes, «uber» a Taxis y
/// apps, «menú» a Restaurantes. Viven en el catálogo de textos (`subcategory.words.<semilla>`), separadas por comas, en
/// los 16 idiomas: cada idioma nombra lo suyo (la bodega en Perú, el chino en Argentina, el súper en España).
///
/// Una categoría sembrada se reconoce por su nombre en CUALQUIER idioma (`L10n.allLocalizedValues`): se guardó con el
/// nombre del idioma en que se sembró, y la persona pudo cambiar de idioma después. Las que la persona creó no tienen
/// palabras: el buscador sigue mirando su nombre y el de su grupo.
enum CategoryEverydayWords {

    /// Las categorías sembradas que tienen palabras (sufijo de `subcategory.<semilla>`).
    static let seeds: [String] = [
        "restaurants", "delivery", "supermarkets", "rideshare", "publicTransport", "fuel", "parking", "pharmacy",
        "health", "clothing", "tech", "gifts", "beauty", "rent", "utilities", "phone", "streaming", "bars", "shows",
        "travel", "fitness", "education", "petFood", "salary",
    ]

    /// Nombre plegado (sin tildes ni mayúsculas) → semilla, con los nombres de los 16 idiomas. Se arma una vez.
    private static let seedByFoldedName: [String: String] = {
        var map: [String: String] = [:]
        for seed in Set(seeds + CategoryQuickPickLogic.expenseStarterSeeds) {
            for name in L10n.allLocalizedValues(forKey: "subcategory.\(seed)") {
                map[CategorySearchLogic.folded(name)] = seed
            }
        }
        return map
    }()

    /// La semilla de una categoría por su nombre guardado, o `nil` si la creó la persona (o la renombró).
    static func seed(forName name: String) -> String? {
        seedByFoldedName[CategorySearchLogic.folded(name)]
    }

    /// Las palabras de una categoría en el idioma de la app; vacío si no es de las sembradas con palabras.
    static func words(forName name: String) -> [String] {
        guard let seed = seed(forName: name), seeds.contains(seed) else { return [] }
        return parse(L10n.Subcategory.everydayWords(seed))
    }

    /// «café, menú, almuerzo» → ["café", "menú", "almuerzo"]. Sin huecos.
    static func parse(_ list: String) -> [String] {
        list.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
