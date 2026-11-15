//
//  ProTrialCancelPlaceTests.swift
//  YalaTests
//
//  Lote 10 de las mejoras necesarias 2.3, punto 1. «Así funciona la prueba» decía «Cancela en Ajustes» y quien lo
//  leía buscaba en los Ajustes de Yala. Ahora nombra los ajustes del dispositivo, que existen siempre (también en la
//  vista de Solo grupos, que no tiene la fila «Yala Pro»), con la misma fórmula que ya usa `usageMode.leave.pro`.
//

import Foundation
import Testing
@testable import Yala

@Suite("La prueba de Pro dice dónde se cancela, en los 16 idiomas")
struct ProTrialCancelPlaceTests {

    static let languages = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl",
                            "pt", "pt-BR", "pt-PT", "zh-Hans"]

    /// El texto que mandaba a «Ajustes» a secas, por idioma. Ninguno puede volver.
    static let oldTexts: [String: String] = [
        "de": "Kündige in den Einstellungen und es wird nichts berechnet.",
        "en": "Cancel in Settings and you’re not charged.",
        "en-GB": "Cancel in Settings and you’re not charged.",
        "es": "Cancela en Ajustes y no se cobra nada.",
        "es-419": "Cancela en Ajustes y no se cobra nada.",
        "es-AR": "Cancelá en Ajustes y no se cobra nada.",
        "es-ES": "Cancela en Ajustes y no se cobra nada.",
        "fr": "Annule dans les Réglages et rien n’est facturé.",
        "it": "Annulla in Impostazioni e non paghi niente.",
        "ja": "設定からキャンセルすれば、料金はかかりません。",
        "nl": "Zeg op in Instellingen en je betaalt niets.",
        "pl": "Anuluj w Ustawieniach, a nic nie zapłacisz.",
        "pt": "Cancele nos Ajustes e nada é cobrado.",
        "pt-BR": "Cancele nos Ajustes e nada é cobrado.",
        "pt-PT": "Cancela nas Definições e não é cobrado nada.",
        "zh-Hans": "在“设置”中取消,就不会扣费。",
    ]

    /// Cómo se dice «dispositivo» en cada idioma: la palabra que ya usa `usageMode.leave.pro`.
    static let deviceWord: [String: String] = [
        "de": "Geräts", "en": "device", "en-GB": "device", "es": "dispositivo", "es-419": "dispositivo",
        "es-AR": "dispositivo", "es-ES": "dispositivo", "fr": "appareil", "it": "dispositivo", "ja": "デバイス",
        "nl": "apparaat", "pl": "urządzenia", "pt": "dispositivo", "pt-BR": "dispositivo", "pt-PT": "dispositivo",
        "zh-Hans": "设备",
    ]

    static func string(_ key: String, lang: String) throws -> String {
        let path = try #require(Bundle.main.path(forResource: lang, ofType: "lproj"), "La app no trae \(lang).lproj")
        let bundle = try #require(Bundle(path: path))
        let value = bundle.localizedString(forKey: key, value: "∅", table: nil)
        try #require(value != "∅", "Falta \(key) en \(lang)")
        return value
    }

    @Test(arguments: languages)
    func trialCancelBody_namesTheDeviceSettings(lang: String) throws {
        let body = try Self.string("uxpro.trial.cancelBody", lang: lang)
        #expect(body != Self.oldTexts[lang], "\(lang) sigue mandando a «Ajustes» a secas: \(body)")
        let word = try #require(Self.deviceWord[lang])
        #expect(body.contains(word), "\(lang) no nombra el dispositivo: \(body)")
        // La misma palabra que ya usa el aviso de salir a Solo grupos con Pro: un solo nombre para el mismo sitio.
        #expect(try Self.string("usageMode.leave.pro", lang: lang).contains(word))
    }

    @Test func trialCancelBody_spanish() throws {
        #expect(try Self.string("uxpro.trial.cancelBody", lang: "es")
                == "Cancela en los ajustes de tu dispositivo y no se cobra nada.")
    }
}
