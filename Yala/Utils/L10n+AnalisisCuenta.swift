//
//  L10n+AnalisisCuenta.swift
//  Yala
//
//  La ficha de una cuenta rediseñada con las gráficas de los widgets del Panel (2026-11-16, ticket
//  `analisis-por-cuenta`). Las gráficas traen sus propios títulos (los del Panel); aquí va solo lo que la ficha añade.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func analisisCuentaString(_ key: String) -> String {
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
    enum AnalisisCuenta {
        /// Título de la lista con los gastos más grandes de la cuenta en el período.
        static var largestTitle: String { analisisCuentaString("analisisCuenta.largestTitle") }
    }
}
