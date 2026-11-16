//
//  RecordsQuickFiltersLogic.swift
//  Yala
//
//  Revisión 2.3, decisiones 15 y 16 (9-nov): chips rápidos sobre Registros (F2), hoja de Filtros con buscador de
//  categorías y resumen con lo elegido (F3), y la banda de filtros que se parte en líneas con «Quitar todo» (L1).
//  Aquí vive lo que se puede decidir sin vistas: qué nombre dice el resumen de Categorías, qué casa con una búsqueda,
//  qué dice cada chip rápido y cuántos filtros pinta la banda.
//

import Foundation

// MARK: - Resumen de Categorías (F3 · «Delivery +3»)

enum CategoryFilterSummaryLogic {
    /// Una categoría con sus subcategorías VISIBLES, en el orden en que se pintan.
    struct CategoryEntry<ID: Hashable> {
        let name: String
        let subcategories: [(id: ID, name: String)]
    }

    /// Lo elegido, nombrado como lo eligió la persona: si están todas las subcategorías visibles de una categoría, el
    /// nombre de la categoría («Alimentación»); si no, el de cada subcategoría elegida («Restaurantes»). En el orden de
    /// las categorías, que es estable: antes salía la primera subcategoría que devolvía un `filter` y «+N» por el resto,
    /// así que elegir Alimentación decía «Delivery +3».
    static func names<ID: Hashable>(selected: Set<ID>, categories: [CategoryEntry<ID>]) -> [String] {
        guard !selected.isEmpty else { return [] }
        var result: [String] = []
        for category in categories where !category.subcategories.isEmpty {
            let chosen = category.subcategories.filter { selected.contains($0.id) }
            if chosen.isEmpty { continue }
            if chosen.count == category.subcategories.count {
                result.append(category.name)
            } else {
                result.append(contentsOf: chosen.map(\.name))
            }
        }
        return result
    }

    /// «Alimentación», «Alimentación +2». `nil` sin nada elegido: quien pinta pone su texto de «Todas».
    static func text(names: [String]) -> String? {
        guard let first = names.first else { return nil }
        return names.count == 1 ? first : "\(first) +\(names.count - 1)"
    }
}

// MARK: - Buscador de categorías (F3 y chip «Categoría ▾»)

/// Reusa el plegado del buscador de Nuevo registro (`TransactionFormDecided02BLogic`): sin tildes ni mayúsculas.
extension CategorySearchLogic {
    static func normalized(_ text: String) -> String {
        folded(text)
    }

    /// Una búsqueda vacía no filtra nada (todo casa). Aquí cada fila se busca por su propio nombre.
    static func matches(_ name: String, query: String) -> Bool {
        let needle = folded(query)
        guard !needle.isEmpty else { return true }
        return folded(name).contains(needle)
    }
}

// MARK: - Qué dicen los chips rápidos (F2)

enum RecordsQuickChipLabel: Equatable {
    /// Nada elegido: el chip dice su nombre («Cuenta ▾»).
    case placeholder
    /// Un valor: su nombre («Cuenta Principal ▾»).
    case one(String)
    /// Varios: «2 cuentas ▾».
    case many(Int)

    /// Cuentas: lo que se ve marcado, una por tarjeta (las líneas de una tarjeta elegida no son otra cuenta).
    static func accounts(selectedNames: [String]) -> RecordsQuickChipLabel {
        switch selectedNames.count {
        case 0: return .placeholder
        case 1: return .one(selectedNames[0])
        default: return .many(selectedNames.count)
        }
    }

    /// Categorías: el mismo nombre que el resumen de la hoja.
    static func categories(names: [String]) -> RecordsQuickChipLabel {
        guard let text = CategoryFilterSummaryLogic.text(names: names) else { return .placeholder }
        return .one(text)
    }

    var isActive: Bool { self != .placeholder }
}

// MARK: - Varias a la vez en los chips rápidos (16-nov)

/// «Cuenta ▾» elige varias, como «Más filtros»: tocar una la añade o la quita. Trabaja sobre lo que se VE marcado (una
/// tarjeta, sin sus líneas); la sesión vuelve a meter las líneas de cada tarjeta al escribirlo.
enum RecordsQuickAccountSelectionLogic {
    static func toggled<ID: Hashable>(_ id: ID, in shown: Set<ID>) -> Set<ID> {
        var result = shown
        if result.contains(id) { result.remove(id) } else { result.insert(id) }
        return result
    }
}

/// «Categoría ▾» elige como el primer presupuesto del onboarding: categorías enteras y, de cada una, las subcategorías
/// que no se quieran se quitan. Dentro de la hoja todo es un conjunto de subcategorías («expandido»); al escribirlo en
/// la sesión vuelve a la forma que filtra igual que la hoja de «Más filtros»:
/// - solo categorías enteras → `selectedCategories`, sin subcategorías;
/// - alguna a medias → `selectedSubcategories` con todas las elegidas, sin categorías.
/// Nunca las dos a la vez: el filtro de categoría y el de subcategoría se cumplen los DOS (`FilterService`), y «Comida
/// entera + Taxi» en dos listas no dejaría pasar nada.
enum RecordsQuickCategorySelectionLogic {
    /// Una categoría con sus subcategorías VISIBLES, en el orden de la hoja.
    struct Entry<C: Hashable, S: Hashable> {
        let id: C
        let subcategories: [S]
    }

    /// Lo elegido en la sesión, como conjunto de subcategorías.
    static func expanded<C: Hashable, S: Hashable>(
        selectedCategories: Set<C>, selectedSubcategories: Set<S>, entries: [Entry<C, S>]
    ) -> Set<S> {
        var result = selectedSubcategories
        for entry in entries where selectedCategories.contains(entry.id) {
            result.formUnion(entry.subcategories)
        }
        return result
    }

    /// La categoría está elegida (entera o a medias): su tarjeta sale marcada y sus subcategorías, debajo.
    static func isChosen<C: Hashable, S: Hashable>(_ entry: Entry<C, S>, in expanded: Set<S>) -> Bool {
        entry.subcategories.contains { expanded.contains($0) }
    }

    /// Tocar una tarjeta: elegida (entera o a medias) la quita entera; sin elegir, la añade entera. Como en el onboarding.
    static func togglingCategory<C: Hashable, S: Hashable>(_ entry: Entry<C, S>, in expanded: Set<S>) -> Set<S> {
        if isChosen(entry, in: expanded) {
            return expanded.subtracting(entry.subcategories)
        }
        return expanded.union(entry.subcategories)
    }

    /// Tocar una subcategoría la quita o la vuelve a poner.
    static func togglingSubcategory<S: Hashable>(_ id: S, in expanded: Set<S>) -> Set<S> {
        RecordsQuickAccountSelectionLogic.toggled(id, in: expanded)
    }

    /// Lo que se escribe en la sesión (ver arriba).
    static func committed<C: Hashable, S: Hashable>(
        _ expanded: Set<S>, entries: [Entry<C, S>]
    ) -> (categories: Set<C>, subcategories: Set<S>) {
        guard !expanded.isEmpty else { return ([], []) }
        let touched = entries.filter { isChosen($0, in: expanded) }
        let wholes = touched.allSatisfy { entry in entry.subcategories.allSatisfy { expanded.contains($0) } }
        let coveredByTouched = Set(touched.flatMap(\.subcategories))
        if wholes && expanded.isSubset(of: coveredByTouched) {
            return (Set(touched.map(\.id)), [])
        }
        return ([], expanded)
    }
}

// MARK: - La banda (L1)

enum FilterBandLogic {
    /// Cuántos filtros pinta la banda. En Registros, con los chips rápidos a la vista, lo INCLUIDO de cuenta y de
    /// categoría lo dicen los chips («los chips dicen lo elegido y la banda, lo de “Más filtros”»): la banda no lo repite.
    /// Lo OCULTO de esas dimensiones sí va en la banda: ningún chip rápido lo enseña.
    static func bandFilterCount(
        userFilterCount: Int,
        hidesQuickDimensions: Bool,
        hasIncludedAccounts: Bool,
        hasIncludedCategoriesOrSubcategories: Bool
    ) -> Int {
        guard hidesQuickDimensions else { return userFilterCount }
        let shownByChips = (hasIncludedAccounts ? 1 : 0) + (hasIncludedCategoriesOrSubcategories ? 1 : 0)
        return max(0, userFilterCount - shownByChips)
    }

    /// «Quitar todo» va siempre que la banda enseñe algo, también con un solo filtro: es la salida que no hay que
    /// buscar (L1). Antes la ✕ de «borrar todo» salía solo con dos o más.
    static func showsRemoveAll(bandFilterCount: Int) -> Bool {
        bandFilterCount > 0
    }
}
