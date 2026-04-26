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
        #expect(service.isValid(s, whitelist: wl))
    }

    @MainActor @Test func isValid_referencingMissingBudget_fails() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Mercado"], budgets: ["Comida"])
        // Entretenimiento NO está en el whitelist
        let s = makeSuggestion("¿Cuánto me queda del presupuesto Entretenimiento?")
        #expect(!service.isValid(s, whitelist: wl))
    }

    @MainActor @Test func isValid_phraseWithoutNamedEntities_passes() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Mercado"])
        // Pregunta genérica sin nombres propios — válida.
        let s = makeSuggestion("¿Cuál fue mi mayor gasto del mes?")
        #expect(service.isValid(s, whitelist: wl))
    }

    @MainActor @Test func isValid_substringMatch_passes() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(subcategories: ["Bus"])
        // "Bus" es un nombre real del user.
        let s = makeSuggestion("¿Comparado con el mes pasado, cuánto gasté en Bus?")
        #expect(service.isValid(s, whitelist: wl))
    }

    @MainActor @Test func isValid_emptyWhitelist_passesGenericPhrases() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist()
        let s = makeSuggestion("¿Cuánto gasté?")
        #expect(service.isValid(s, whitelist: wl))
    }

    @MainActor @Test func isValid_uppercaseWordCommonNotPenalized() {
        let service = SuggestionsRewriterService.shared
        let wl = makeWhitelist(categories: ["Comida"])
        // "Cuánto" al inicio (skip), "Mes" en medio (palabra común), no nombres propios.
        let s = makeSuggestion("¿Cuánto gasté este Mes en Comida?")
        #expect(service.isValid(s, whitelist: wl))
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
