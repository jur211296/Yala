//
//  PulidoPrimerosPasosPaywallText.swift
//  Yala
//
//  Los textos nuevos del pulido de Primeros pasos y del paywall (observación del iPhone 14 del 25-nov-2026), en su
//  propia tabla (`PulidoPrimerosPasosPaywall.strings`), leídos con el idioma de la app como `PrimerosPasosPulidoText`.
//  Tabla propia para no cruzarse con otras ramas que editan `Localizable.strings`.
//

import Foundation

enum PulidoPrimerosPasosPaywallText {
    static let table = "PulidoPrimerosPasosPaywall"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "pulidoPPP.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// Paso 1: el título del selector al añadir otra moneda a la cuenta (antes, «Moneda principal» de Ajustes).
    static var otherCurrencyTitle: String { string("currency.otherTitle") }
    /// Final de Primeros pasos con algún paso para después: no dice «completos».
    static var doneForNowTitle: String { string("final.doneForNowTitle") }
    /// Paywall sin precios: no culpa a la conexión (con la lista vacía de la tienda no es eso).
    static var pricesUnavailable: String { string("paywall.pricesUnavailable") }
}

/// Qué título lleva el final de Primeros pasos.
enum PrimerosPasosFinalTitleLogic: Equatable {
    /// «¡Primeros pasos completos!»: los siete hechos.
    case complete
    /// «¡Listo por ahora!»: alguno quedó para después.
    case forNow

    static func title(laterCount: Int) -> PrimerosPasosFinalTitleLogic {
        laterCount > 0 ? .forNow : .complete
    }

    /// El texto, en el idioma de la app.
    var text: String {
        switch self {
        case .complete: L10n.PrimerosPasos23.Final.doneTitle
        case .forNow: PulidoPrimerosPasosPaywallText.doneForNowTitle
        }
    }
}

/// Qué título lleva el selector de moneda del paso 1.
enum FirstAccountCurrencyPickerTitleLogic {
    /// `nil`: el título de siempre («Moneda principal»). Solo la primera moneda es la principal; añadir otra o cambiar
    /// la segunda dice «Otra moneda».
    static func title(slotIndex: Int?) -> String? {
        if let slotIndex, slotIndex == 0 { return nil }
        return PulidoPrimerosPasosPaywallText.otherCurrencyTitle
    }
}
