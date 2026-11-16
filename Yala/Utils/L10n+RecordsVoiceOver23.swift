//
//  L10n+RecordsVoiceOver23.swift
//  Yala
//
//  Textos del lote de Registros 2.3 (decisiones 61 y 78 de la discusión del 9-nov): la pista de VoiceOver de las
//  etiquetas de la fila, que decía «Tag» en inglés en todos los idiomas, y los estados de carga y de error de la lista.
//  En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func rvo23(_ key: String) -> String {
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
    enum RecordsVoiceOver23 {
        /// Pista de VoiceOver de cada etiqueta de la fila: dice qué es lo que acaba de leer.
        static var tagHint: String { rvo23("records.row.tagHint") }
        /// La lista aún no ha cargado y tarda: lo dice en vez de quedarse en blanco.
        static var loading: String { rvo23("records.list.loading") }
        /// Leer los movimientos falló: no es «Sin registros».
        static var loadErrorTitle: String { rvo23("records.list.loadErrorTitle") }
        static var loadErrorMessage: String { rvo23("records.list.loadErrorMessage") }
    }
}
