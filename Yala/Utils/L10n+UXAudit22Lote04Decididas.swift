//
//  L10n+UXAudit22Lote04Decididas.swift
//  Yala
//
//  Textos de las decisiones de Jürgen del lote decidido 2.2 · 04 (cuenta, cerrar sesión y modo solo grupos: L19-15,
//  L19-17, L19-18, L19-19, L20-6, L20-7, L20-9, L20-10), implementadas el 2026-10-19. En su propio fichero, como los de
//  cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l04(_ key: String) -> String {
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
    enum UXCS {

        // MARK: - L20-6 · sin cuenta de Yala, la salida dice lo que hace

        /// «Quitar mis datos de este iPhone»: la fila de la celda privada sin cuenta (`.privateSignOut`).
        static var removeDeviceDataRow: String { l04("uxcs.removeDeviceData.row") }
        /// «Siguen en tu iCloud»: solo con copia en iCloud.
        static var removeDeviceDataSubtitle: String { l04("uxcs.removeDeviceData.subtitle") }
        /// La hoja de alcance que abre esa fila, con el mismo verbo.
        static var removeDeviceDataSheetTitle: String { l04("uxcs.removeDeviceData.sheetTitle") }
        static var removeDeviceDataConfirm: String { l04("uxcs.removeDeviceData.confirm") }

        // MARK: - L20-7 · la espera del cierre se ve

        static var signOutUploadTitle: String { l04("uxcs.signOutUpload.title") }
        /// «Cambios por subir: %d».
        static func signOutUploadPending(_ count: Int) -> String {
            String(format: l04("uxcs.signOutUpload.pending"), count)
        }

        // MARK: - L19-19 · un grupo migrado, en una frase

        static var migratedRejoinSentence: String { l04("uxcs.migrated.rejoinSentence") }

        // MARK: - L20-10 · la alerta final de eliminar la cuenta, por celda

        /// Cuenta de grupos con sesión privada: lo del teléfono se queda.
        static var deleteAccountFinalGroupsOnly: String { l04("uxcs.deleteAccount.finalGroupsOnly") }
    }
}
