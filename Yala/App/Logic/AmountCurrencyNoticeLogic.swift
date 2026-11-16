//
//  AmountCurrencyNoticeLogic.swift
//  Yala
//
//  Mejoras necesarias 2.3 · M1 (revisión por vistas 2.3 de Nuevo registro, problema 4): el importe escrito con la moneda
//  principal pasaba a dólares al elegir la cuenta, sin aviso. El número se queda y la moneda cambia: eso es lo de
//  siempre (L2-16, no se convierte nada); lo nuevo es que el formulario lo dice con palabras.
//

import Foundation

/// Lo que el formulario mira para decidir: la moneda del importe y el número escrito, antes y después de un cambio.
struct AmountCurrencySnapshot: Equatable {
    let currencyCode: String
    let amount: Double
}

/// El aviso «Ahora en dólares (USD), la moneda de Ahorros USD».
struct AmountCurrencyNotice: Equatable {
    let currencyCode: String
    let accountName: String
}

enum AmountCurrencyNoticeLogic {

    /// El aviso que deja un cambio, o el que había si el cambio no lo toca.
    ///
    /// - Sale cuando cambia la moneda y el número ya estaba escrito y sigue igual: la persona escribió una cifra
    ///   pensando en una moneda y ahora vale en otra.
    /// - No sale si el número cambió en la misma pasada (un favorito trae importe y cuenta a la vez) ni sin importe:
    ///   ahí no hay cifra que se reinterprete.
    /// - Un cambio que no es de moneda (escribir otro número, otra categoría) conserva el aviso que hubiera.
    /// - En una transferencia no hay aviso: cada importe dice ya su cuenta.
    static func notice(
        from old: AmountCurrencySnapshot,
        to new: AmountCurrencySnapshot,
        current: AmountCurrencyNotice?,
        accountName: String?,
        isTransfer: Bool
    ) -> AmountCurrencyNotice? {
        guard !isTransfer else { return nil }
        let oldCode = old.currencyCode.uppercased()
        let newCode = new.currencyCode.uppercased()
        guard oldCode != newCode else { return current }
        guard old.amount > 0, new.amount == old.amount, let accountName, !accountName.isEmpty else { return nil }
        return AmountCurrencyNotice(currencyCode: newCode, accountName: accountName)
    }

    /// Si el aviso se pinta ahora: solo mientras la moneda sea la que anunció y haya importe.
    static func isShown(_ notice: AmountCurrencyNotice?, currencyCode: String, amount: Double, isTransfer: Bool) -> Bool {
        guard let notice, !isTransfer, amount > 0 else { return false }
        return notice.currencyCode == currencyCode.uppercased()
    }

    /// «dólares (USD)»; si la app no conoce la divisa, solo su código.
    static func text(for notice: AmountCurrencyNotice) -> String {
        if let currency = CurrencyCode(rawValue: notice.currencyCode) {
            return L10n.FormClarity.currencyNotice(
                currencyName: currency.shortPluralName, code: notice.currencyCode, account: notice.accountName)
        }
        return L10n.FormClarity.currencyNoticeCodeOnly(code: notice.currencyCode, account: notice.accountName)
    }
}
