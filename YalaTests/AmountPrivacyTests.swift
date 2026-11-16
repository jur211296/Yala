//
//  AmountPrivacyTests.swift
//  YalaTests
//
//  «Ocultar montos» del Panel (card «Ojo para ocultar montos en el Panel», 2026-11-06): la máscara que sustituye la cifra
//  y la preferencia que la enciende. La parte visible la fija `PanelAmountsVisibilityUITests`.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized)
struct AmountPrivacyTests {

    // MARK: - La máscara

    @Test func masked_keepsTheSymbol_andReplacesTheFigure() {
        #expect(AmountPrivacy.masked("S/ 2,266.37") == "S/ •••••")
        #expect(AmountPrivacy.masked("S/ -1,234.56") == "S/ •••••")
        #expect(AmountPrivacy.masked("≈ PEN 1,234.56") == "≈ PEN •••••")
        #expect(AmountPrivacy.masked("US$ 80.00") == "US$ •••••")
    }

    /// Un eje o un promedio compacto («22K») no lleva símbolo: queda solo la máscara.
    @Test func masked_withoutSymbol_isOnlyTheMask() {
        #expect(AmountPrivacy.masked("22K") == AmountPrivacy.mask)
        #expect(AmountPrivacy.masked("-1,234") == AmountPrivacy.mask)
    }

    /// El ancho no puede delatar la magnitud: una cifra de un dígito y una de siete dan el mismo texto.
    @Test func masked_hasTheSameLength_whateverTheFigure() {
        #expect(AmountPrivacy.masked("S/ 5.00") == AmountPrivacy.masked("S/ 1,234,567.89"))
    }

    @Test func text_onlyMasks_whenHidden() {
        #expect(AmountPrivacy.text("S/ 10.00", hidden: false) == "S/ 10.00")
        #expect(AmountPrivacy.text("S/ 10.00", hidden: true) == "S/ •••••")
    }

    /// VoiceOver no lee viñetas: dice que el monto está oculto.
    @Test func spoken_saysTheAmountIsHidden() {
        #expect(AmountPrivacy.spoken("S/ 10.00", hidden: false) == "S/ 10.00")
        #expect(AmountPrivacy.spoken("S/ 10.00", hidden: true) == L10n.Panel.amountHidden)
        #expect(!L10n.Panel.amountHidden.contains("•"))
    }

    // MARK: - La preferencia

    private static func makeSuite() -> UserDefaults {
        testDefaults(suiteName: "AmountPrivacyTests.\(UUID().uuidString)")!
    }

    @Test func panelAmountsHidden_isOffByDefault() {
        let prefs = AppPreferences(defaults: Self.makeSuite())
        #expect(prefs.panelAmountsHidden == false)
    }

    /// Quien oculta los montos para usar la app en público espera encontrarlos ocultos al volver a abrirla.
    @Test func panelAmountsHidden_survivesARelaunch() {
        let defaults = Self.makeSuite()
        let prefs = AppPreferences(defaults: defaults)
        prefs.panelAmountsHidden = true

        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.panelAmountsHidden == true)
        #expect(defaults.bool(forKey: AppPreferences.Keys.panelAmountsHidden) == true)
    }

    /// Es la privacidad de este aparato, no de la cuenta: no viaja a otros dispositivos.
    @Test func panelAmountsHidden_isNotASyncedPreference() {
        let syncedKeys = Set(PrefSyncKey.allCases.map(\.rawValue))
        #expect(!syncedKeys.contains(AppPreferences.Keys.panelAmountsHidden))
    }
}
