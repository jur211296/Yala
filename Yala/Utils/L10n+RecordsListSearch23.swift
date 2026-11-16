//
//  L10n+RecordsListSearch23.swift
//  Yala
//
//  Textos de «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1). En su propio fichero, como los de cada
//  lote, para no pisar `L10n.swift` con otras sesiones. El vacío sin resultados reusa `YalaEmptyState.noResults()`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func rls23(_ key: String) -> String {
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
    enum RecordsListSearch {
        /// Marcador del campo que asoma arriba de la lista de Registros.
        static var placeholder: String { rls23("records.listSearch.placeholder") }
        /// La X del campo: lo vacía y lo vuelve a esconder (VoiceOver).
        static var clear: String { rls23("records.listSearch.clear") }
    }
}
