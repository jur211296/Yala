//
//  L10n+UXAudit22Lote08Decididas.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 08 (widgets, iPad, teclado, botones flotantes y accesos del icono), implementado el
//  2026-10-20. En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l08d(_ key: String) -> String {
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
    enum UXL08D {

        // MARK: - Accesos rápidos del icono (L15-15)

        /// Los mismos títulos que los atajos de Siri y de Atajos, que ya existen en los 16 idiomas.
        static var quickActionNewRecord: String { l08d("shortcut.quickExpense.shortTitle") }
        static var quickActionVoice: String { l08d("shortcut.voiceEntry.shortTitle") }
        static var quickActionImage: String { l08d("shortcut.imageEntry.shortTitle") }

        // MARK: - La ventana que espera (L15-11)

        static var busySigningOutElsewhere: String { l08d("window.busy.signingOutElsewhere") }
        static var busySigningOut: String { l08d("window.busy.signingOut") }
        static var busyWiping: String { l08d("window.busy.wiping") }
        static var busyStarting: String { l08d("window.busy.starting") }

        // MARK: - Teclado y borrado (L15-13)

        /// El motivo de «Eliminar» apagado en un registro de grupo.
        static var deleteFromGroup: String { l08d("records.l15.deleteFromGroup") }
        /// El mensaje de la confirmación de borrado cuando el borrado se puede deshacer.
        static var undoSeconds: String { l08d("records.l15.undoSeconds") }
    }
}
