//
//  CategoryQuickPick23Tests.swift
//  YalaTests
//
//  Decisión 21 de la revisión 2.3 (9-nov-2026), C2 + C3: las tres categorías a un toque en un registro nuevo y el
//  buscador de la hoja que entiende «café», «uber» o «menú» en los 16 idiomas. Sin SwiftData.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("2.3 · decisión 21 · categorías a un toque y palabras del buscador")
struct CategoryQuickPick23Tests {

    // MARK: - C2 · Las tres

    @Test func sinRegistros_salenLasDeArranque_enSuOrden() {
        let picked = CategoryQuickPickLogic.pick(usedNewestFirst: [String](), starters: ["rest", "super", "taxi"])
        #expect(picked == ["rest", "super", "taxi"])
    }

    @Test func conHistorial_saleLaMasUsada_yAIgualdadLaMasReciente() {
        // Del más nuevo al más viejo: farmacia ×1 (la más reciente), bar ×3, cine ×1, gym ×2.
        let used = ["farmacia", "bar", "gym", "bar", "cine", "gym", "bar"]
        let picked = CategoryQuickPickLogic.pick(usedNewestFirst: used, starters: ["rest", "super", "taxi"])
        #expect(picked == ["bar", "gym", "farmacia"])
    }

    @Test func conUnaUsada_seCompletaConLasDeArranque_sinRepetir() {
        let picked = CategoryQuickPickLogic.pick(usedNewestFirst: ["super", "super"], starters: ["rest", "super", "taxi"])
        #expect(picked == ["super", "rest", "taxi"])
    }

    @Test func lasDeArranque_sonRestaurantesSupermercadosYTaxis() {
        #expect(CategoryQuickPickLogic.expenseStarterSeeds == ["restaurants", "supermarkets", "rideshare"])
    }

    @Test func unaCategoriaSembrada_seReconoce_enCualquierIdioma() {
        #expect(CategoryEverydayWords.seed(forName: "Restaurantes") == "restaurants")
        #expect(CategoryEverydayWords.seed(forName: "Restaurants") == "restaurants")
        #expect(CategoryEverydayWords.seed(forName: "taxis y apps") == "rideshare")
        #expect(CategoryEverydayWords.seed(forName: "Supermercados y tiendas") == "supermarkets")
        #expect(CategoryEverydayWords.seed(forName: "Mi categoría inventada") == nil)
    }

    // MARK: - C3 · Las palabras del buscador

    /// Las palabras de `seed` tal como están en el catálogo de `locale`, sin depender del idioma del simulador.
    private func words(_ seed: String, in locale: String) throws -> [String] {
        let path = try #require(Bundle.main.path(forResource: locale, ofType: "lproj"), "Falta \(locale).lproj")
        let bundle = try #require(Bundle(path: path))
        let missing = "__FALTA__"
        let value = bundle.localizedString(forKey: "subcategory.words.\(seed)", value: missing, table: nil)
        #expect(value != missing, "\(locale) no tiene las palabras de \(seed)")
        return CategoryEverydayWords.parse(value)
    }

    @Test func cafeUberYMenu_llevanASuCategoria() throws {
        let restaurants = try words("restaurants", in: "es-419")
        let rideshare = try words("rideshare", in: "es-419")
        let es = Locale(identifier: "es")
        #expect(CategorySearchLogic.matches(
            query: "café", name: "Restaurantes", groupName: "Alimentación", words: restaurants, locale: es))
        #expect(CategorySearchLogic.matches(
            query: "menu", name: "Restaurantes", groupName: "Alimentación", words: restaurants, locale: es))
        #expect(CategorySearchLogic.matches(
            query: "Uber", name: "Taxis y apps", groupName: "Transporte", words: rideshare, locale: es))
        // Sin la palabra, «café» no casa con el nombre ni con el grupo: es la palabra la que lo encuentra.
        #expect(!CategorySearchLogic.matches(query: "café", name: "Restaurantes", groupName: "Alimentación", locale: es))
    }

    @Test func unaSolaLetra_noBuscaEntreLasPalabras() {
        // Ni el nombre ni el grupo llevan «u»: si casara, sería por la palabra.
        #expect(!CategorySearchLogic.matches(query: "u", name: "Cine", groupName: "Ocio", words: ["uber"]))
        #expect(CategorySearchLogic.matches(query: "ub", name: "Cine", groupName: "Ocio", words: ["uber"]))
    }

    @Test func laHoja_filtraPorLasPalabras_yDejaLasDemas() {
        let groups: [(category: String, subcategories: [String])] = [
            (category: "Alimentación", subcategories: ["Restaurantes", "Delivery"]),
            (category: "Transporte", subcategories: ["Taxis y apps"]),
        ]
        let wordsByName = ["Restaurantes": ["café", "menú"], "Taxis y apps": ["uber"]]
        let result = CategorySearchLogic.filter(
            groups, query: "cafe", groupName: { $0 }, itemName: { $0 },
            itemWords: { wordsByName[$0] ?? [] }, locale: Locale(identifier: "es")
        )
        #expect(result.count == 1)
        #expect(result.first?.subcategories == ["Restaurantes"])
    }

    /// Los 16 idiomas: cada categoría con palabras las tiene, y no son la clave cruda ni una sola palabra.
    @Test func cadaIdioma_tieneLasPalabrasDeCadaCategoria() throws {
        for locale in SupportedLocale.allCases {
            for seed in CategoryEverydayWords.seeds {
                let list = try words(seed, in: locale.bundleResourceName)
                #expect(list.count >= 3, "\(locale.rawValue) · \(seed): \(list)")
                #expect(!list.contains { $0.contains("subcategory.") }, "\(locale.rawValue) · \(seed)")
            }
        }
    }

    /// El ejemplo de la decisión en cada idioma: buscar la palabra del café de ese idioma encuentra Restaurantes.
    @Test func elCafe_seEncuentraEnCadaIdioma() throws {
        let coffee: [String: String] = [
            "es-419": "café", "es-ES": "café", "es-AR": "café", "es": "café",
            "en": "coffee", "en-GB": "coffee", "pt-BR": "café", "pt-PT": "café", "pt": "café",
            "de": "kaffee", "fr": "café", "it": "caffè", "nl": "koffie", "pl": "kawa", "ja": "コーヒー", "zh-Hans": "咖啡",
        ]
        for locale in SupportedLocale.allCases {
            let query = try #require(coffee[locale.rawValue], "Falta el café de \(locale.rawValue)")
            let list = try words("restaurants", in: locale.bundleResourceName)
            #expect(
                CategorySearchLogic.matches(query: query, name: "—", groupName: "—", words: list),
                "\(locale.rawValue): «\(query)» no lleva a Restaurantes"
            )
        }
    }
}
