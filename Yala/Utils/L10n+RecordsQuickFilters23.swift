//
//  L10n+RecordsQuickFilters23.swift
//  Yala
//
//  Textos de la revisión 2.3, decisiones 15 y 16 (9-nov): chips rápidos de Registros, buscador de categorías de la hoja
//  de Filtros y la banda con «Quitar todo». En su propio fichero para no pisar `L10n.swift` con otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func rq23(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum RecordsQuickFilters23 {
        // MARK: - Chips rápidos (F2)

        /// Chip sin nada elegido: «Cuenta».
        static var account: String { rq23("records23.quick.account") }
        /// Chip sin nada elegido: «Categoría». También el título de la hoja que abre.
        static var category: String { rq23("records23.quick.category") }
        /// Chip sin período acotado: «Fecha».
        static var date: String { rq23("records23.quick.date") }
        /// El chip que abre la hoja completa: «Más filtros».
        static var more: String { rq23("records23.quick.more") }
        /// Varias cuentas elegidas en «Más filtros»: «2 cuentas». Siempre con 2 o más.
        static func accountsCount(_ count: Int) -> String { String(format: rq23("records23.quick.accountsCount"), count) }

        // MARK: - Buscador de categorías (F3)

        /// Texto de ayuda del buscador: «Busca una categoría».
        static var searchPrompt: String { rq23("records23.category.searchPrompt") }
        /// Sin resultados: «Ninguna categoría con «café»».
        static func noResults(_ query: String) -> String { String(format: rq23("records23.category.noResults"), query) }
        /// Debajo de una categoría en los resultados: elegirla es elegir todas sus subcategorías.
        static var wholeCategory: String { rq23("records23.category.wholeCategory") }
        /// VoiceOver del chevrón que despliega: «Ver subcategorías de Alimentación».
        static func expand(_ category: String) -> String { String(format: rq23("records23.category.expand"), category) }
        /// VoiceOver del chevrón que pliega: «Ocultar subcategorías de Alimentación».
        static func collapse(_ category: String) -> String { String(format: rq23("records23.category.collapse"), category) }

        // MARK: - Banda (L1)

        /// El botón de la banda que quita todos los filtros: «Quitar todo».
        static var removeAll: String { rq23("records23.band.removeAll") }
    }
}
