//
//  SuggestionsRewriterServiceTests.swift
//  YalaTests
//
//  Cubre validación + extracción de candidatas. La parte de re-prompt LLM se cubre
//  manualmente en device QA (requeriría mockear OpenAI client del singleton).
//

import Testing
import Foundation
@testable import Yala

@Suite(.serialized)
struct SuggestionsRewriterServiceTests {

    private func makeWhitelist(
        categories: [String] = [],
        subcategories: [String] = [],
        budgets: [String] = [],
        tags: [String] = [],
        merchants: [String] = []
    ) -> SuggestionsRewriterService.Whitelist {
        SuggestionsRewriterService.Whitelist(
            categories: categories,
            subcategories: subcategories,
            budgets: budgets,
            tags: tags,
            merchants: merchants
        )
    }

    private func makeSuggestion(_ text: String) -> ChatSuggestion {
        ChatSuggestion(text: text, icon: "chart.pie", type: .general)
    }

    // MARK: - Validation logic

    @MainActor @Test func isValid_referencingExistingCategory_passes() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Restaurantes", "Mercado"])
        let s = makeSuggestion("¿Cuánto gasté en Restaurantes este mes?")
        #expect(service.isValid(s, whitelist: wl, language: "es"))
    }

    @MainActor @Test func isValid_referencingMissingBudget_fails() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Mercado"], budgets: ["Comida"])
        // Entretenimiento NO está en el whitelist
        let s = makeSuggestion("¿Cuánto me queda del presupuesto Entretenimiento?")
        #expect(!service.isValid(s, whitelist: wl, language: "es"))
    }

    @MainActor @Test func isValid_phraseWithoutNamedEntities_passes() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Mercado"])
        // Pregunta genérica sin nombres propios — válida.
        let s = makeSuggestion("¿Cuál fue mi mayor gasto del mes?")
        #expect(service.isValid(s, whitelist: wl, language: "es"))
    }

    @MainActor @Test func isValid_substringMatch_passes() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(subcategories: ["Bus"])
        // "Bus" es un nombre real del user.
        let s = makeSuggestion("¿Comparado con el mes pasado, cuánto gasté en Bus?")
        #expect(service.isValid(s, whitelist: wl, language: "es"))
    }

    @MainActor @Test func isValid_emptyWhitelist_passesGenericPhrases() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist()
        let s = makeSuggestion("¿Cuánto gasté?")
        #expect(service.isValid(s, whitelist: wl, language: "es"))
    }

    @MainActor @Test func isValid_uppercaseWordCommonNotPenalized() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Comida"])
        // "Cuánto" al inicio (skip), "Mes" en medio (palabra común), no nombres propios.
        let s = makeSuggestion("¿Cuánto gasté este Mes en Comida?")
        #expect(service.isValid(s, whitelist: wl, language: "es"))
    }

    // MARK: - Alemán, polaco e inglés (ticket suggestions-rewriter-drops-german-and-polish-rewrites)

    // Antes del arreglo, toda palabra con mayúscula que no fuera la primera tenía que estar en una lista
    // española/inglesa o en el whitelist: en alemán ningún sustantivo pasaba («Monat», «Ausgaben»), en
    // polaco no casaban los nombres declinados («w Biedronce») y en inglés, los meses («October»).
    // Las mismas frases están en `gateway/test/ai.bench.test.ts`, contra la réplica del banco.

    private var germanWhitelist: SuggestionsRewriterService.Whitelist {
        makeWhitelist(
            categories: ["Lebensmittel", "Freizeit"],
            subcategories: ["Restaurant", "Tanken", "Supermarkt"],
            merchants: ["Rewe", "Lidl"]
        )
    }

    private var polishWhitelist: SuggestionsRewriterService.Whitelist {
        makeWhitelist(
            categories: ["Jedzenie", "Rozrywka"],
            subcategories: ["Restauracje", "Kino", "Apteka"],
            merchants: ["Biedronka", "Żabka", "Lidl"]
        )
    }

    private var englishWhitelist: SuggestionsRewriterService.Whitelist {
        makeWhitelist(categories: ["Food"], subcategories: ["Gas"], merchants: ["Costco"])
    }

    private var spanishWhitelist: SuggestionsRewriterService.Whitelist {
        makeWhitelist(categories: ["Comida"], subcategories: ["Restaurantes"], merchants: ["Tambo"])
    }

    @MainActor @Test(arguments: [
        "Wie viel habe ich diesen Monat bei Rewe ausgegeben?",
        "Wie hoch waren meine Ausgaben für Lebensmittel im Oktober?",
        "Wie viel ist noch im Budget für Freizeit übrig?",
        "Habe ich am Samstag mehr für Restaurants ausgegeben als im Vergleich zum Vormonat?",
        "An welchen Wochentagen gebe ich mehr für Supermärkte aus?"
    ])
    func isValid_germanRewriteWithRealNames_passes(_ text: String) {
        let service = SuggestionsRewriterService.shared
        #expect(service.isValid(makeSuggestion(text), whitelist: germanWhitelist, language: "de-DE"))
    }

    @MainActor @Test(arguments: [
        "Ile wydałem w Biedronce w tym miesiącu?",
        "Ile wydałem w Żabce w tym tygodniu?",
        "Ile wydałem w Aptece?",
        "Ile wydałem na Rozrywkę?",
        "Ile wydałem w Restauracjach w tym miesiącu?",
        "Ile wydałem w Lidlu?",
        "Ile zostało Ci w budżecie Jedzenie?",
        "Jak wydatki na Rozrywkę wypadają względem Twojego budżetu?"
    ])
    func isValid_polishRewriteWithDeclinedNames_passes(_ text: String) {
        let service = SuggestionsRewriterService.shared
        #expect(service.isValid(makeSuggestion(text), whitelist: polishWhitelist, language: "pl-PL"))
    }

    @MainActor @Test(arguments: [
        "How much did I spend at Costco in October?",
        "Did I spend more on Gas on Saturday than on Sunday?"
    ])
    func isValid_englishRewriteWithMonthsAndDays_passes(_ text: String) {
        let service = SuggestionsRewriterService.shared
        #expect(service.isValid(makeSuggestion(text), whitelist: englishWhitelist, language: "en-US"))
    }

    @MainActor @Test func isValid_inventedName_stillFails_inEveryLanguage() {
        let service = SuggestionsRewriterService.shared
        let cases: [(String, SuggestionsRewriterService.Whitelist, String)] = [
            ("Wie viel habe ich bei Aldi ausgegeben?", germanWhitelist, "de-DE"),
            ("Wie hoch waren meine Kosten für Strom?", germanWhitelist, "de"),
            ("Wie viel zahle ich im Monat für Spotify?", germanWhitelist, "de-DE"),
            ("Ile wydałem w Rossmannie?", polishWhitelist, "pl-PL"),
            ("Ile wydałem na Ubrania?", polishWhitelist, "pl-PL"),
            ("How much did I spend at Walmart in October?", englishWhitelist, "en-US"),
            ("How much did I spend on Insurance?", englishWhitelist, "en-US"),
            ("¿Cuánto gasté en Wong en octubre?", spanishWhitelist, "es-PE"),
            ("¿Cuánto gasté en Comisiones este mes?", spanishWhitelist, "es-PE")
        ]
        for (text, whitelist, language) in cases {
            #expect(!service.isValid(makeSuggestion(text), whitelist: whitelist, language: language), "\(text)")
        }
    }

    @MainActor @Test func isValid_wordListsBelongToTheirLanguage() {
        let service = SuggestionsRewriterService.shared
        // «Monat» es común en alemán, no en español.
        #expect(!service.isValid(makeSuggestion("¿Cuánto gasté este Monat?"), whitelist: spanishWhitelist, language: "es-PE"))
        // La declinación polaca no se aplica en alemán.
        #expect(!service.isValid(
            makeSuggestion("Wie viel habe ich in Biedronce ausgegeben?"),
            whitelist: makeWhitelist(merchants: ["Biedronka"]),
            language: "de-DE"
        ))
        #expect(SuggestionsRewriterService.commonWordSet(for: "de_DE").contains("monat"))
        #expect(SuggestionsRewriterService.commonWordSet(for: "en-GB").contains("i"))
        #expect(!SuggestionsRewriterService.commonWordSet(for: "es").contains("monat"))
    }

    @Test func polishInflection_altersTheStemButNotUnrelatedWords() {
        #expect(SuggestionsRewriterService.isPolishInflection("biedronce", of: "biedronka"))
        #expect(SuggestionsRewriterService.isPolishInflection("żabce", of: "żabka"))
        #expect(SuggestionsRewriterService.isPolishInflection("kinie", of: "kino"))
        #expect(SuggestionsRewriterService.isPolishInflection("restauracjach", of: "restauracje"))
        #expect(!SuggestionsRewriterService.isPolishInflection("biedronkowski", of: "biedronka"))
        #expect(!SuggestionsRewriterService.isPolishInflection("rossmannie", of: "lidl"))
        #expect(!SuggestionsRewriterService.isPolishInflection("domu", of: "dom"))
    }

    @MainActor @Test func process_germanSuggestionsWithRealNames_needNoRewrite() async throws {
        let service = SuggestionsRewriterService.shared
        let suggestions = [
            makeSuggestion("Wie viel habe ich diesen Monat bei Rewe ausgegeben?"),
            makeSuggestion("Wie viel ist noch im Budget für Freizeit übrig?"),
            makeSuggestion("Wie hoch waren meine Ausgaben für Tanken im Oktober?")
        ]
        // Sin inválidas no hay llamada al LLM: si alguna no pasara, `process` iría a la red.
        let result = try await service.process(suggestions: suggestions, whitelist: germanWhitelist, language: "de")
        #expect(result.map(\.text) == suggestions.map(\.text))
    }

    // MARK: - process() with valid input (no LLM call)

    @MainActor @Test func process_allValid_returnsAsIs() async throws {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Restaurantes", "Mercado"])
        let suggestions = [
            makeSuggestion("¿Cuánto gasté en Restaurantes?"),
            makeSuggestion("¿Mi gasto en Mercado este mes?"),
            makeSuggestion("¿Cuál fue mi mayor gasto?"),
            makeSuggestion("¿Tasa de ahorro este mes?")
        ]

        let result = try await service.process(
            suggestions: suggestions,
            whitelist: wl,
            language: "es"
        )

        #expect(result.count == suggestions.count)
        // Sin LLM call: result idéntico al input
        #expect(result.map(\.text) == suggestions.map(\.text))
    }

    // MARK: - Whitelist snippet

    @Test func whitelistSnippet_includesAllSections() {
        let wl = SuggestionsRewriterService.Whitelist(
            categories: ["Comida"],
            subcategories: ["Bus"],
            budgets: ["Mensual"],
            tags: ["Vacaciones"],
            merchants: ["Starbucks"]
        )
        let snippet = wl.toPromptSnippet()
        #expect(snippet.contains("Categorías: Comida"))
        #expect(snippet.contains("Subcategorías: Bus"))
        #expect(snippet.contains("Presupuestos: Mensual"))
        #expect(snippet.contains("Etiquetas: Vacaciones"))
        #expect(snippet.contains("Comercios frecuentes: Starbucks"))
    }
}
