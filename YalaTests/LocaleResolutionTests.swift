//
//  LocaleResolutionTests.swift
//  YalaTests
//
//  Tests para LocaleResolution + ls() fallback chain manual.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct LocaleResolutionTests {

    private func cleanOverride() {
        LanguageManager.overrideLanguage = nil
    }

    // MARK: - LocaleResolution

    @Test func resolved_noOverride_returnsMainBundle() {
        cleanOverride()
        defer { cleanOverride() }

        let resolution = LanguageManager.resolved
        #expect(resolution.bundle === Bundle.main)
        #expect(resolution.parentBundle == nil)
    }

    @Test func resolved_overrideEs_bundleEsLproj() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "es"
        let resolution = LanguageManager.resolved

        #expect(resolution.bundle !== Bundle.main, "Should resolve to es.lproj bundle")
        #expect(resolution.parentBundle == nil, "es has no parent in M3")
        #expect(resolution.locale.identifier == "es")
    }

    @Test func resolved_overridePt_bundlePtLproj() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "pt"
        let resolution = LanguageManager.resolved

        #expect(resolution.bundle !== Bundle.main)
        #expect(resolution.locale.identifier == "pt")
    }

    @Test func resolved_unknownOverride_fallsBackToMain() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        // "xx" no es un SupportedLocale válido → resolved cae a Bundle.main.
        UserDefaults(suiteName: "group.com.jurgenschmidt.yala")?
            .set("xx", forKey: LanguageManager.overrideKey)

        let resolution = LanguageManager.resolved
        #expect(resolution.bundle === Bundle.main)

        // Cleanup directo (evita post de notification)
        UserDefaults(suiteName: "group.com.jurgenschmidt.yala")?
            .removeObject(forKey: LanguageManager.overrideKey)
    }

    // MARK: - ls() fallback (verificación con keys reales del bundle)

    @Test func ls_withEsOverride_returnsLocalizedSpanishString() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "es"
        // L10n.Action.cancel debe resolver a "Cancelar" en es.
        let value = L10n.Action.cancel
        #expect(!value.isEmpty)
        #expect(value != "action.cancel", "Should not return raw key")
    }

    @Test func ls_withEnOverride_returnsLocalizedEnglishString() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "en"
        let value = L10n.Action.cancel
        #expect(!value.isEmpty)
        #expect(value != "action.cancel")
    }

    @Test func appLocale_current_matchesResolvedLocale() {
        let original = LanguageManager.overrideLanguage
        defer { LanguageManager.overrideLanguage = original }

        LanguageManager.overrideLanguage = "fr"
        #expect(AppLocale.current.identifier == LanguageManager.resolved.locale.identifier)
        #expect(AppLocale.current.identifier == "fr")
    }
}
