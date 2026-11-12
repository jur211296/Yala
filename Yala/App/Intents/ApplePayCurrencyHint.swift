//
//  ApplePayCurrencyHint.swift
//  Yala
//
//  La moneda con la que el borrador de un pago de Apple Pay va a quedar, escrita por la app para que la notificación
//  del atajo diga lo mismo sin abrir SwiftData (auditoría UX 2.2, lote 15, L15-8, opción C).
//
//  El atajo corre en segundo plano y no puede abrir el store (`Bugs/applepay-shortcut-ios27-warm-launch-datos-vacios`),
//  pero quien decide la moneda del borrador (`ApplePayDraftService`) mira la última cuenta usada y sus cuentas. Antes
//  la notificación caía a dólares cuando el importe llegaba sin símbolo, y con `$` ignoraba la cuenta: «Pago de US$ 25,90»
//  para un borrador que la Bandeja enseñaba en soles. La app escribe aquí, con la misma regla del borrador, la moneda de
//  la última cuenta usada y la que resolvería `$` y `kr`; el atajo la lee solo si sigue siendo esa cuenta.
//

import Foundation

nonisolated struct ApplePayCurrencyHint: Codable, Equatable {
    /// `shortcutID` de la última cuenta usada cuando se escribió (`nil` si no había). Si ya es otra, la pista no vale.
    let lastUsedAccountID: String?
    /// La moneda en que la Bandeja enseñará un pago que llega sin símbolo; `nil` = la moneda por defecto.
    let noSymbolCurrency: String?
    /// Lo mismo para un pago con `$` o `kr`, por símbolo; sin entrada = la moneda por defecto.
    let currencyBySymbol: [String: String]

    nonisolated static let storageKey = "applePayCurrencyHint"

    private nonisolated static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
    }

    nonisolated static func read(defaults: UserDefaults? = ApplePayCurrencyHint.appGroupDefaults) -> ApplePayCurrencyHint? {
        guard let defaults, let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode(ApplePayCurrencyHint.self, from: data)
        } catch {
            #if DEBUG
            print("ApplePayCurrencyHint: Error decoding: \(error)")
            #endif
            return nil
        }
    }

    nonisolated static func write(_ hint: ApplePayCurrencyHint?, defaults: UserDefaults? = ApplePayCurrencyHint.appGroupDefaults) {
        guard let defaults else { return }
        guard let hint else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(hint), forKey: storageKey)
        } catch {
            #if DEBUG
            print("ApplePayCurrencyHint: Error encoding: \(error)")
            #endif
        }
    }

    /// La moneda de la notificación. Un código o un símbolo inequívoco manda (es la del pago). Sin símbolo o con `$`/`kr`,
    /// la que enseñará la Bandeja según la pista, si la pista es de la última cuenta usada de ahora; sin pista que valga,
    /// lo de antes: la del símbolo, o la moneda por defecto, o dólares.
    nonisolated static func notificationCurrency(
        parsedCurrency: String?,
        ambiguousSymbol: String?,
        hint: ApplePayCurrencyHint?,
        lastUsedAccountID: String?,
        defaultCurrency: String?
    ) -> String {
        var valid: ApplePayCurrencyHint?
        if let hint, hint.lastUsedAccountID == lastUsedAccountID { valid = hint }
        if let symbol = ambiguousSymbol {
            if let valid { return valid.currencyBySymbol[symbol] ?? defaultCurrency ?? parsedCurrency ?? "USD" }
            return parsedCurrency ?? defaultCurrency ?? "USD"
        }
        if let parsedCurrency { return parsedCurrency }
        if let valid { return valid.noSymbolCurrency ?? defaultCurrency ?? "USD" }
        return defaultCurrency ?? "USD"
    }
}
