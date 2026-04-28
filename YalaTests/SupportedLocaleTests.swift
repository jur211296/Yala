//
//  SupportedLocaleTests.swift
//  YalaTests
//
//  Tests para SupportedLocale enum: bestMatch, parent chain, props.
//

import Foundation
import Testing

@testable import Yala

struct SupportedLocaleTests {

    // MARK: - bestMatch

    @Test func bestMatch_devicePreferredEs_returnsEs() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["es"], region: "ES")
        #expect(result == .es)
    }

    @Test func bestMatch_devicePreferredEn_returnsEn() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["en"], region: "US")
        #expect(result == .en)
    }

    @Test func bestMatch_devicePreferredJa_returnsEn_whenJaNotSupportedYet() {
        // ja aún no existe (M14). Fallback a en.
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["ja"], region: "JP")
        #expect(result == .en)
    }

    @Test func bestMatch_devicePreferredRu_returnsEn() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["ru"], region: "RU")
        #expect(result == .en)
    }

    @Test func bestMatch_compoundCodeWithoutVariant_fallsBackToBaseLanguage() {
        // es-MX → no hay variante específica todavía → fallback a es base
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["es-MX"], region: "MX")
        #expect(result == .es)
    }

    @Test func bestMatch_emptyPreferred_returnsEn() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: [], region: nil)
        #expect(result == .en)
    }

    @Test func bestMatch_multiplePreferred_picksFirstMatching() {
        // Primer match exacto gana
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["zh-Hans", "es", "en"], region: nil)
        #expect(result == .es)
    }

    // MARK: - parent

    @Test func parentChain_allCurrentlyNil() {
        for locale in SupportedLocale.allCases {
            #expect(locale.parent == nil, "Locale \(locale.code) should have nil parent in M1")
        }
    }

    // MARK: - properties

    @Test func code_matchesRawValue() {
        for locale in SupportedLocale.allCases {
            #expect(locale.code == locale.rawValue)
        }
    }

    @Test func bundleResourceName_matchesCode() {
        for locale in SupportedLocale.allCases {
            #expect(locale.bundleResourceName == locale.code)
        }
    }

    @Test func nativeName_isNotEmpty() {
        for locale in SupportedLocale.allCases {
            #expect(!locale.nativeName.isEmpty)
        }
    }

    @Test func flag_isSingleEmoji() {
        for locale in SupportedLocale.allCases {
            #expect(!locale.flag.isEmpty, "Locale \(locale.code) missing flag")
        }
    }

    @Test func flag_pt_currentlyBrazilian() {
        // Legacy: el `pt` actual usa bandera 🇧🇷. Cambiará al splitear pt-BR/pt-PT en M7.
        #expect(SupportedLocale.pt.flag == "🇧🇷")
    }

    // MARK: - from(_:)

    @Test func from_exactMatch_returnsLocale() {
        #expect(SupportedLocale.from("es") == .es)
        #expect(SupportedLocale.from("en") == .en)
        #expect(SupportedLocale.from("pt") == .pt)
    }

    @Test func from_compoundIdentifier_returnsBaseLocale() {
        #expect(SupportedLocale.from("es-MX") == .es)
        #expect(SupportedLocale.from("pt-BR") == .pt)
        #expect(SupportedLocale.from("en-GB") == .en)
    }

    @Test func from_unknownCode_returnsNil() {
        #expect(SupportedLocale.from("ja") == nil)
        #expect(SupportedLocale.from("ru") == nil)
        #expect(SupportedLocale.from("zh-Hans") == nil)
    }

    // MARK: - allCases / selectableCases

    @Test func allCases_currentlySixLocales() {
        // En M1 solo existen los 6 idiomas históricos.
        #expect(SupportedLocale.allCases.count == 6)
    }

    @Test func selectableCases_equalAllCases_inM1() {
        #expect(SupportedLocale.selectableCases.count == SupportedLocale.allCases.count)
    }
}
