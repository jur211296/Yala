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
//
// `.appLanguageStateIsolated`: ese App Group sobrevive al proceso y lo comparten el host de los
// unit tests y el de los XCUITest, así que un override que sobreviva arranca la app siguiente en
// otro idioma. Antes lo cubría un `defer` por test —7 tests, 7 `defer`— y funcionaba, pero es la
// misma disciplina que falló en `AppLanguageSyncTests` al llegar el test número 10; y el `defer`
// de `resolved_noOverride_returnsMainBundle` no restauraba: forzaba `nil`, borrando el override
// legítimo que tuviera el simulador. El trait captura, limpia y devuelve el valor real.
@Suite(.serialized, .appLanguageStateIsolated)
@MainActor
struct LocaleResolutionTests {

    // MARK: - LocaleResolution

    @Test func resolved_noOverride_returnsMainBundle() {
        let resolution = LanguageManager.resolved
        #expect(resolution.bundle === Bundle.main)
        #expect(resolution.parentBundle == nil)
    }

    @Test func resolved_overrideEs_bundleEsLproj() {
        LanguageManager.overrideLanguage = "es"
        let resolution = LanguageManager.resolved

        #expect(resolution.bundle !== Bundle.main, "Should resolve to es.lproj bundle")
        #expect(resolution.parentBundle == nil, "es has no parent in M3")
        #expect(resolution.locale.identifier == "es")
    }

    @Test func resolved_overridePt_bundlePtLproj() {
        LanguageManager.overrideLanguage = "pt"
        let resolution = LanguageManager.resolved

        #expect(resolution.bundle !== Bundle.main)
        #expect(resolution.locale.identifier == "pt")
    }

    @Test func resolved_unknownOverride_fallsBackToMain() {
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
        LanguageManager.overrideLanguage = "es"
        // L10n.Action.cancel debe resolver a "Cancelar" en es.
        let value = L10n.Action.cancel
        #expect(!value.isEmpty)
        #expect(value != "action.cancel", "Should not return raw key")
    }

    @Test func ls_withEnOverride_returnsLocalizedEnglishString() {
        LanguageManager.overrideLanguage = "en"
        let value = L10n.Action.cancel
        #expect(!value.isEmpty)
        #expect(value != "action.cancel")
    }

    @Test func appLocale_current_matchesResolvedLocale() {
        LanguageManager.overrideLanguage = "fr"
        #expect(AppLocale.current.identifier == LanguageManager.resolved.locale.identifier)
        #expect(AppLocale.current.identifier == "fr")
    }
}
