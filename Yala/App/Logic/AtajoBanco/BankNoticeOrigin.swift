//
//  BankNoticeOrigin.swift
//  Yala
//
//  Cómo dice la Bandeja de dónde llegó un borrador del atajo del banco: «Aviso de BCP», o «No entendimos este aviso»
//  mientras no tenga importe. El borrador es `.automation` con el banco en la evidencia (`BankNoticeDraftService`);
//  cualquier otro `.automation` (Yala web, el correo reenviado) sigue diciendo lo de siempre.
//

import Foundation

enum BankNoticeOrigin {

    /// La etiqueta de origen de un borrador del atajo del banco, o `nil` si el borrador no viene de un aviso.
    static func label(sourceType: DraftSourceType, evidence: String?, hasAmount: Bool) -> String? {
        guard sourceType == .automation, let bank = BankNoticeBank.fromEvidence(evidence) else { return nil }
        if !hasAmount { return localized("inbox.sourceBankNoticeNotUnderstood") }
        if bank == .other { return localized("inbox.sourceBankNoticeOther") }
        return String(format: localized("inbox.sourceBankNotice"), bank.brandName)
    }

    /// Mismo orden de búsqueda que `ls()` de `L10n`: idioma elegido en Yala → su idioma padre → el del sistema.
    static func localized(_ key: String) -> String {
        let resolution = LanguageManager.resolved
        let sentinel = "__YALA_MISSING__"
        let variant = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
        if variant != sentinel { return variant }
        if let parent = resolution.parentBundle {
            let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
            if parentValue != sentinel { return parentValue }
        }
        let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
        return mainValue == sentinel ? key : mainValue
    }
}
