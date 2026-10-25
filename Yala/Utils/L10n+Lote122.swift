//
//  L10n+Lote122.swift
//  Yala
//
//  Textos del lote 12.2 de la cola 2.2 (Nube, iCloud y migración desde 2.0.4): el aviso del Panel que propone activar la
//  nube en un segundo dispositivo (card vbf9). En su propio fichero, como los de cada lote, para no pisar `L10n.swift`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l122(_ key: String) -> String {
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
    /// Card vbf9: el aviso del Panel en el segundo dispositivo, tras activar la nube en otro del mismo iCloud.
    enum CloudAdoptOffer {
        static var title: String { l122("panel.cloudAdoptOffer.title") }
        static var body: String { l122("panel.cloudAdoptOffer.body") }
        static var button: String { l122("panel.cloudAdoptOffer.button") }
    }
}
