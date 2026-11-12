//
//  L10n+RecordsMonthJump23.swift
//  Yala
//
//  Textos de la revisión 2.3, decisión 17 (9-nov): el separador de mes de Registros que lleva a otro mes. En su propio
//  fichero para no pisar `L10n.swift` con otros lotes de 2.3.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su fichero.
private func rmj23(_ key: String) -> String {
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
    enum RecordsMonthJump23 {
        /// Título del menú del separador de mes y pista de VoiceOver: «Ir a otro mes».
        static var goToAnotherMonth: String { rmj23("records23.month.goToAnotherMonth") }
    }
}
