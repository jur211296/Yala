//
//  BaseLanguageCodeTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 5 · B3: una localización regional («es-419», «pt-BR») comparada con una lista de idiomas
//  base caía al inglés (imágenes de ejemplo de «Prueba el registro con foto», enlace de privacidad).
//

import Testing

@testable import Yala

@Suite("LanguageManager.baseLanguageCode")
struct BaseLanguageCodeTests {

    @Test(arguments: [
        ("es", "es"), ("es-419", "es"), ("es-AR", "es"), ("es-ES", "es"),
        ("pt", "pt"), ("pt-BR", "pt"), ("pt-PT", "pt"),
        ("en", "en"), ("en-GB", "en"),
        ("de", "de"), ("fr", "fr"), ("it", "it"), ("nl", "nl"), ("pl", "pl"), ("ja", "ja"), ("zh-Hans", "zh"),
    ])
    func regionalVariantResolvesToItsBaseLanguage(_ c: (localization: String, base: String)) {
        #expect(LanguageManager.baseLanguageCode(of: c.localization) == c.base)
    }

    /// Las 16 localizaciones de Yala que tienen imágenes de ejemplo propias (es, pt, en, de, fr, it) ya no caen al
    /// inglés por ser una variante: la lista de `PanelView.loadExampleImages` es de idiomas base.
    @Test func everySpanishAndPortugueseVariantFindsItsExampleImages() {
        let withImages: Set<String> = ["de", "en", "es", "fr", "it", "pt"]
        for localization in ["es-419", "es-AR", "es-ES", "pt-BR", "pt-PT", "en-GB"] {
            #expect(withImages.contains(LanguageManager.baseLanguageCode(of: localization)))
        }
    }
}
