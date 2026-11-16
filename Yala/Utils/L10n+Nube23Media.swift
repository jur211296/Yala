//
//  L10n+Nube23Media.swift
//  Yala
//
//  Textos del encargo «Nube 2.3: los cinco bugs de prioridad media» (2026-11-16). En su propio fichero, como los de cada
//  lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func n23m(_ key: String) -> String {
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
    enum Nube23Media {
        /// Card «Modo iCloud: la salida se llama "Cerrar sesión"» (decisión de Jürgen del 13-nov). La nota de la hoja nombra el
        /// botón de la bienvenida que hay HOY, leído del propio botón (`L10n.Showcase.enterWithICloud`): si el botón cambia de
        /// nombre, la nota cambia con él.
        static var signOutICloudConservation: String {
            String(format: n23m("nube23media.signOutICloud.conservation"), L10n.Showcase.enterWithICloud)
        }
        static var signOutICloudConservationWithGroups: String {
            String(format: n23m("nube23media.signOutICloud.conservationWithGroups"), L10n.Showcase.enterWithICloud)
        }

        /// Card «2.3 · Poder volver a la nube con la misma cuenta» (opción A, 16-nov): la hoja de volver a iCloud ya no dice
        /// «Hoy no se puede».
        static var revertCloudAgainDetail: String { n23m("nube23media.revert.cloudAgainDetail") }
    }
}
