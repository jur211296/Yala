//
//  SettingsLote16CopyTests.swift
//  YalaTests
//
//  Auditoría UX 2.2, lote 16 (Ajustes: perfil y preferencias). Textos que decían algo falso:
//  - el pie de Ajustes enseñaba «Versión 1.0.0 (Build 1)» en cualquier versión;
//  - el pie de «Idioma de la app» pedía reiniciar, y el cambio se aplica al momento;
//  - los nombres de los iconos de perfil eran literales en español en los 16 idiomas.
//

import Foundation
import Testing

@testable import Yala

struct SettingsLote16CopyTests {

    // MARK: - Pie de versión

    @Test func versionAndBuild_readTheBundleValues() {
        let parts = AppVersionInfo.versionAndBuild(from: [
            "CFBundleShortVersionString": "2.2",
            "CFBundleVersion": "31",
        ])
        #expect(parts.version == "2.2")
        #expect(parts.build == "31")
    }

    @Test func versionAndBuild_missingOrBlankValues_fallBackToQuestionMark() {
        let missing = AppVersionInfo.versionAndBuild(from: nil)
        #expect(missing.version == "?")
        #expect(missing.build == "?")
        let blank = AppVersionInfo.versionAndBuild(from: ["CFBundleShortVersionString": " ", "CFBundleVersion": ""])
        #expect(blank.version == "?")
        #expect(blank.build == "?")
    }

    @Test func footer_showsTheRealVersion_notTheOldFixedText() {
        let footer = AppVersionInfo.footer(info: ["CFBundleShortVersionString": "2.2", "CFBundleVersion": "31"])
        #expect(footer.contains("2.2"), "El pie no enseña la versión del bundle: \(footer)")
        #expect(footer.contains("31"), "El pie no enseña el build del bundle: \(footer)")
        #expect(!footer.contains("1.0.0"), "El pie sigue con el texto fijo de 1.0.0: \(footer)")
    }

    @Test func footer_ofTheRunningApp_matchesItsOwnInfoPlist() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let version = try #require(info["CFBundleShortVersionString"] as? String)
        let build = try #require(info["CFBundleVersion"] as? String)
        let footer = AppVersionInfo.footer()
        #expect(footer.contains(version) && footer.contains(build), "Pie: \(footer) · bundle: \(version) (\(build))")
    }

    /// La clave es un formato con versión y build, en ese orden, en TODOS los idiomas. Sin los dos
    /// marcadores, `String(format:)` pintaría un número de menos (o el texto fijo de antes).
    @Test func versionFormat_hasBothPlaceholders_inEveryLocale() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            let value = strings["settings.versionInfo"] ?? ""
            #expect(value.contains("%1$@") && value.contains("%2$@"),
                    "\(locale.code): settings.versionInfo no es un formato de versión y build: «\(value)»")
            #expect(!value.contains("1.0.0"), "\(locale.code): settings.versionInfo sigue fijo: «\(value)»")
        }
    }

    // MARK: - Pie del idioma

    @Test func appLanguageFooter_noLongerAsksToRestart() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            #expect(strings["settings.appLanguageRestart"] == nil,
                    "\(locale.code): queda la clave vieja que pedía reiniciar la app")
            #expect(!(strings["settings.appLanguageAppliesNow"] ?? "").isEmpty,
                    "\(locale.code): falta el pie nuevo del idioma")
        }
    }

    // MARK: - Iconos de perfil

    private static let profileIconKeys = [
        "person", "smiley", "star", "heart", "bolt", "crown",
        "leaf", "flame", "moon", "sun", "cloud", "drop",
    ].map { "profile.icon.\($0)" }

    @Test func profileIconNames_existInEveryLocale() {
        for locale in SupportedLocale.allCases {
            let strings = StringsFileParser.parseStrings(forLocale: locale.code)
            let missing = Self.profileIconKeys.filter { (strings[$0] ?? "").isEmpty }
            #expect(missing.isEmpty, "\(locale.code): faltan nombres de iconos de perfil: \(missing)")
        }
    }

    /// El bug era que salían en español en todos los idiomas: en inglés, ninguno puede coincidir con el español
    /// salvo los que se escriben igual en los dos idiomas (no hay ninguno en esta lista).
    @Test func profileIconNames_inEnglish_areNotTheSpanishLiterals() {
        let es = StringsFileParser.parseStrings(forLocale: "es-419")
        let en = StringsFileParser.parseStrings(forLocale: "en")
        let same = Self.profileIconKeys.filter { es[$0] != nil && es[$0] == en[$0] }
        #expect(same.isEmpty, "Nombres de icono iguales en inglés y en español: \(same)")
    }
}
