//
//  LocaleResolutionTests.swift
//  YalaTests
//
//  Tests para LocaleResolution + ls() fallback chain manual.
//

import Foundation
import Testing

@testable import Yala

// `.serialized`: los tests mutan el singleton `LanguageManager.overrideLanguage`
// (App Group compartido) → correrlos en paralelo se pisan entre sí.
@Suite(.serialized)
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
        // Escribir vía el setter (NO un suiteName hardcodeado): `resolved` lee de
        // `sharedDefaults` = `SharedContainerService.appGroupIdentifier`, que bajo el scheme
        // "Yala Dev" NO es "group.com.jurgenschmidt.yala" → el write hardcodeado iba a otro
        // grupo y el test leía un override filtrado de un test hermano (falso rojo).
        LanguageManager.overrideLanguage = "xx"

        let resolution = LanguageManager.resolved
        #expect(resolution.bundle === Bundle.main)
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
