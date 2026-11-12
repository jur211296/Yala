//
//  L10n+UXAudit22Lote16.swift
//  Yala
//
//  Textos de la implementación de la auditoría UX 2.2, lote 16 (Ajustes: perfil y preferencias). Van en su propio
//  fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l16(_ key: String) -> String {
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
    enum UXL16 {

        // MARK: - Lo elegido, relleno (L16-9)

        static var inUse: String { l16("settings.l16.inUse") }

        // MARK: - Confirmar el cambio de moneda principal (L16-3)

        static func currencyChangeTitle(_ currencyName: String) -> String {
            String(format: l16("settings.l16.currencyChange.title"), currencyName)
        }
        static var currencyChangeToday: String { l16("settings.l16.currencyChange.today") }
        static func currencyChangeIn(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.in"), code)
        }
        static func currencyChangeTotals(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.totals"), code)
        }
        static var currencyChangeRates: String { l16("settings.l16.currencyChange.rates") }
        static var currencyChangeRecordsKeep: String { l16("settings.l16.currencyChange.recordsKeep") }
        static func currencyChangeCanReturn(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.canReturn"), code)
        }
        static func currencyChangeConfirm(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.confirm"), code)
        }

        // MARK: - Si el cambio de moneda falla (bug del lote 16)

        static func currencyChangeFailedTitle(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.failedTitle"), code)
        }
        static func currencyChangeFailedMessage(_ code: String) -> String {
            String(format: l16("settings.l16.currencyChange.failedMessage"), code)
        }
    }
}
