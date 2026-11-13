//
//  L10n+VoiceOverSelectores.swift
//  Yala
//
//  Nombres que VoiceOver lee en selectores que no tienen un rótulo visible propio (card «VoiceOver: cinco
//  selectores sin nombre», 2.3). En su propio fichero, como los de cada lote, para no pisar `L10n.swift`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func a11ySel(_ key: String) -> String {
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
    enum VoiceOverSelectores {
        /// «Modo del filtro»: el segmentado «Mostrar solo / Ocultar» de los filtros de Registros.
        static var filterMode: String { a11ySel("a11y.selectores.filterMode") }
        /// «Color personalizado»: el selector de color libre, al lado de los colores fijos.
        static var customColor: String { a11ySel("a11y.selectores.customColor") }
    }
}
