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
    /// Varios (elegidos en «Más filtros»): «2 cuentas ▾».
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
