//
//  L10n+PendientesJurgen22.swift
//  Yala
//
//  Textos de la sesión «Pendientes de Jürgen 2.2» (2026-10-23): el idioma híbrido (L16-5) y la fila de Face ID en
//  «Permisos de Yala» (L16-14). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func pj22(_ key: String) -> String {
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
    enum PJ22 {

        // MARK: - L16-5 · Idioma de la app (opción B, híbrido)

        /// Pie de «Idioma de la app» cuando la fila lleva a los Ajustes del iPhone (más de un idioma en el iPhone).
        static var appLanguageInIOSFooter: String { pj22("pj22.language.inIOSFooter") }

        // MARK: - L16-14 · Face ID en «Permisos de Yala» (opción A)

        static var permissionFaceID: String { pj22("pj22.permissions.faceID") }
        static var permissionFaceIDDetail: String { pj22("pj22.permissions.faceIDDetail") }
        static var permissionFaceIDSeeHow: String { pj22("pj22.permissions.faceIDSeeHow") }
    }
}
