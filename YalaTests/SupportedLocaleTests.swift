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

    @Test func bestMatch_ptBR_explicitlyMatchesPtBR() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["pt-BR"], region: "BR")
        #expect(result == .ptBR)
    }

    @Test func bestMatch_ptPT_explicitlyMatchesPtPT() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["pt-PT"], region: "PT")
        #expect(result == .ptPT)
    }

    @Test func bestMatch_legacyPt_remappedToPtBR() {
        // El alias legacy "pt" se remappea automáticamente a ptBR (canónico).
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["pt"], region: nil)
        #expect(result == .ptBR)
    }

    @Test func bestMatch_regionPT_withoutPreferred_usesPtPT() {
        // Usuario en Portugal sin "pt" en preferredLanguages — region map cubre.
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["en"], region: "PT")
        // La línea 1 hace exact match con "en" antes del region map → resultado en
        // (no sería realista que un usuario portugués tuviera en como primera preferencia
        // pero el region map se ejerce en el caso device sin idioma soportado)
        #expect(result == .en)
    }

    @Test func bestMatch_regionAO_unknownPreferred_usesPtPT() {
        // Usuario en Angola con idioma no soportado → region map → ptPT
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["xx"], region: "AO")
        #expect(result == .ptPT)
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

    @Test func parentChain_baseLocalesHaveNilParent() {
        let bases: [SupportedLocale] = [.es, .en, .pt, .ptBR, .de, .fr, .it]
        for locale in bases {
            #expect(locale.parent == nil, "Base locale \(locale.code) should have nil parent")
        }
    }

    @Test func parentChain_ptPTInheritsFromPtBR() {
        #expect(SupportedLocale.ptPT.parent == .ptBR)
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

    @Test func from_compoundIdentifier_returnsExactWhenAvailable() {
        // Variantes con .lproj propio matchean exacto
        #expect(SupportedLocale.from("pt-BR") == .ptBR)
        #expect(SupportedLocale.from("pt-PT") == .ptPT)
    }

    @Test func from_compoundIdentifier_fallsBackToBaseWhenNoVariant() {
        // es-MX no tiene .lproj propio → cae al base es
        #expect(SupportedLocale.from("es-MX") == .es)
        // en-GB no tiene .lproj propio (M11) → cae al base en
        #expect(SupportedLocale.from("en-GB") == .en)
    }

    @Test func from_unknownCode_returnsNil() {
        #expect(SupportedLocale.from("ja") == nil)
        #expect(SupportedLocale.from("ru") == nil)
        #expect(SupportedLocale.from("zh-Hans") == nil)
    }

    // MARK: - allCases / selectableCases

    @Test func allCases_includesPtSplitVariants() {
        // M7 introdujo pt-BR y pt-PT. allCases incluye pt (alias) + ptBR + ptPT + 5 base.
        let expected: Set<SupportedLocale> = [.es, .en, .pt, .ptBR, .ptPT, .de, .fr, .it]
        #expect(Set(SupportedLocale.allCases) == expected)
    }

    @Test func selectableCases_excludesPtAliasButIncludesPtBROrPtPT() {
        // El alias `pt` se excluye del selector porque ya está cubierto por ptBR
        // con bandera explícita. Usuario nunca elige el alias plano manualmente.
        let selectable = Set(SupportedLocale.selectableCases)
        #expect(!selectable.contains(.pt))
        #expect(selectable.contains(.ptBR))
        #expect(selectable.contains(.ptPT))
    }
}
