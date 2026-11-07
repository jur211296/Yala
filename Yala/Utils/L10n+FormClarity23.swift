//
//  L10n+FormClarity23.swift
//  Yala
//
//  Textos de «Mejoras necesarias 2.3 · Formulario: monedas claras y salida manual disponible» (M1 y T1). En su propio
//  fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones. V3 reusa `L10n.Voice.enterManually`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func fc23(_ key: String) -> String {
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
    enum FormClarity {

        // MARK: - M1 · El cambio de moneda del importe, con palabras

        /// «Ahora en dólares (USD), la moneda de Ahorros USD».
        static func currencyNotice(currencyName: String, code: String, account: String) -> String {
            String(format: fc23("formClarity.currencyNotice"), currencyName, code, account)
        }

        /// «Ahora en XYZ, la moneda de Mi cuenta», para una divisa que la app no nombra.
        static func currencyNoticeCodeOnly(code: String, account: String) -> String {
            String(format: fc23("formClarity.currencyNotice.codeOnly"), code, account)
        }

        // MARK: - T1 · Cada importe de la transferencia dice su cuenta

        /// «Sale de Cuenta Principal».
        static func transferSourceCaption(_ account: String) -> String {
            String(format: fc23("formClarity.transfer.sourceCaption"), account)
        }

        /// «Llega a Ahorros USD».
        static func transferDestinationCaption(_ account: String) -> String {
            String(format: fc23("formClarity.transfer.destinationCaption"), account)
        }

        /// VoiceOver: «Importe que sale de Cuenta Principal, en soles (PEN)».
        static func transferSourceAmountA11y(account: String, currency: String) -> String {
            String(format: fc23("formClarity.transfer.sourceAmountA11y"), account, currency)
        }

        /// VoiceOver: «Importe que llega a Ahorros USD, en dólares (USD)».
        static func transferDestinationAmountA11y(account: String, currency: String) -> String {
            String(format: fc23("formClarity.transfer.destinationAmountA11y"), account, currency)
        }

        /// «dólares (USD)», o el código si la app no nombra la divisa. Para las etiquetas de VoiceOver.
        static func currencyPhrase(_ code: String) -> String {
            let upper = code.uppercased()
            guard let currency = CurrencyCode(rawValue: upper) else { return upper }
            return "\(currency.shortPluralName) (\(upper))"
        }
    }
}
