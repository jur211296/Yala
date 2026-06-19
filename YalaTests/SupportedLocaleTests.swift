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

    @Test func bestMatch_devicePreferredEs_regionES_canonicalizesAndMaps() {
        // Step 1 (exact "es") canonicaliza alias → es-419, pero "es" es exact match.
        // canonicalize convierte el alias .es → .es419 antes de retornar.
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["es"], region: "ES")
        #expect(result == .es419)
    }

    @Test func bestMatch_devicePreferredEs_noRegion_returnsEs419() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["es"], region: nil)
        #expect(result == .es419)
    }

    @Test func bestMatch_devicePreferredEn_returnsEn() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["en"], region: "US")
        #expect(result == .en)
    }

    @Test func bestMatch_devicePreferredJa_returnsJa() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["ja"], region: "JP")
        #expect(result == .ja)
    }

    @Test func bestMatch_devicePreferredRu_returnsEn() {
        // ru no soportado → fallback a en
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["ru"], region: "RU")
        #expect(result == .en)
    }

    @Test func bestMatch_compoundCodeWithoutVariant_fallsBackToCanonicalBase() {
        // es-MX no tiene .lproj propio + region MX no en map → fallback a es base → canonicaliza a es-419
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["es-MX"], region: "MX")
        #expect(result == .es419)
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

    @Test func bestMatch_regionAO_unknownPreferred_usesPtPT() {
        // Usuario en Angola con idioma no soportado → region map → ptPT
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["xx"], region: "AO")
        #expect(result == .ptPT)
    }

    @Test func bestMatch_regionGB_unknownPreferred_usesEnGB() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["xx"], region: "GB")
        #expect(result == .enGB)
    }

    @Test func bestMatch_regionAR_unknownPreferred_usesEsAR() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["xx"], region: "AR")
        #expect(result == .esAR)
    }

    @Test func bestMatch_emptyPreferred_returnsEn() {
        let result = SupportedLocale.bestMatch(forPreferredLanguages: [], region: nil)
        #expect(result == .en)
    }

    @Test func bestMatch_multiplePreferred_picksFirstExactMatch() {
        // Primer match exacto gana — zh-Hans existe.
        let result = SupportedLocale.bestMatch(forPreferredLanguages: ["zh-Hans", "es", "en"], region: nil)
        #expect(result == .zhHans)
    }

    // MARK: - parent chain

    @Test func parentChain_baseLocalesHaveNilParent() {
        let bases: [SupportedLocale] = [.es, .es419, .en, .pt, .ptBR, .de, .fr, .it, .nl, .pl, .ja, .zhHans]
        for locale in bases {
            #expect(locale.parent == nil, "Base locale \(locale.code) should have nil parent")
        }
    }

    @Test func parentChain_variantsInheritFromCanonicalBase() {
        #expect(SupportedLocale.ptPT.parent == .ptBR)
        #expect(SupportedLocale.esES.parent == .es419)
        #expect(SupportedLocale.esAR.parent == .es419)
        #expect(SupportedLocale.enGB.parent == .en)
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

    @Test func flag_ptAlias_isBrazilian() {
        // El alias catch-all `pt` muestra bandera BR (mercado mayoritario).
        #expect(SupportedLocale.pt.flag == "🇧🇷")
    }

    @Test func flag_esAlias_isLatamGlobe() {
        // El alias catch-all `es` muestra globo LatAm (no peninsular).
        #expect(SupportedLocale.es.flag == "🌎")
    }

    // MARK: - from(_:)

    @Test func from_exactMatch_returnsLocale() {
        #expect(SupportedLocale.from("es") == .es)
        #expect(SupportedLocale.from("en") == .en)
        #expect(SupportedLocale.from("pt") == .pt)
        #expect(SupportedLocale.from("ja") == .ja)
        #expect(SupportedLocale.from("zh-Hans") == .zhHans)
    }

    @Test func from_compoundIdentifier_returnsExactWhenAvailable() {
        // Variantes con .lproj propio matchean exacto
        #expect(SupportedLocale.from("pt-BR") == .ptBR)
        #expect(SupportedLocale.from("pt-PT") == .ptPT)
        #expect(SupportedLocale.from("es-419") == .es419)
        #expect(SupportedLocale.from("es-ES") == .esES)
        #expect(SupportedLocale.from("es-AR") == .esAR)
        #expect(SupportedLocale.from("en-GB") == .enGB)
    }

    @Test func from_compoundIdentifier_fallsBackToBaseWhenNoVariant() {
        // es-MX no tiene .lproj propio → cae al base es
        #expect(SupportedLocale.from("es-MX") == .es)
        // pt-AO no tiene .lproj propio → cae al base pt
        #expect(SupportedLocale.from("pt-AO") == .pt)
    }

    @Test func from_unknownCode_returnsNil() {
        #expect(SupportedLocale.from("ru") == nil)
        #expect(SupportedLocale.from("zh-Hant") == nil)
        #expect(SupportedLocale.from("ko") == nil)
    }

    // MARK: - allCases / selectableCases

    @Test func allCases_includesAllFinalLocales() {
        let expected: Set<SupportedLocale> = [
            .es, .es419, .esES, .esAR,
            .en, .enGB,
            .pt, .ptBR, .ptPT,
            .de, .fr, .it,
            .nl, .pl, .ja, .zhHans
        ]
        #expect(Set(SupportedLocale.allCases) == expected)
        #expect(SupportedLocale.allCases.count == 16)
    }

    @Test func selectableCases_excludesAliasesButIncludesCanonicalsAndVariants() {
        // Aliases catch-all (`es`, `pt`) se excluyen — están cubiertos por las variantes
        // canónicas con bandera explícita.
        let selectable = Set(SupportedLocale.selectableCases)
        #expect(!selectable.contains(.es))
        #expect(!selectable.contains(.pt))
        #expect(selectable.contains(.es419))
        #expect(selectable.contains(.esES))
        #expect(selectable.contains(.esAR))
        #expect(selectable.contains(.ptBR))
        #expect(selectable.contains(.ptPT))
        #expect(selectable.contains(.enGB))
    }
}
