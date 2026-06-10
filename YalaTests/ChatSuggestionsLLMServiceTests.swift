//
//  ChatSuggestionsLLMServiceTests.swift
//  YalaTests
//
//  Tests para `ChatSuggestionsLLMService.parseSuggestions(json:)` y cache helpers.
//  No mockean OpenAI — el método estático `parseSuggestions` valida sin red.
//

import Testing
import Foundation
@testable import Yala

@Suite(.serialized)
struct ChatSuggestionsLLMServiceTests {

    // MARK: - Parse

    @Test func parseValidJSON_returns10Items() throws {
        let json = """
        {
          "suggestions": [
            { "text": "¿Cuánto gasté en Restaurantes?", "icon": "chart.pie" },
            { "text": "¿Mi presupuesto de Mercado?", "icon": "chart.bar" },
            { "text": "¿Cuál es mi top categoría?", "icon": "chart.bar" },
            { "text": "¿Cómo voy vs el mes pasado?", "icon": "arrow.left.arrow.right" },
            { "text": "¿Qué día gasto más?", "icon": "calendar" },
            { "text": "¿Qué pagos vienen?", "icon": "creditcard" },
            { "text": "¿Top merchant del mes?", "icon": "storefront" },
            { "text": "¿Tasa de ahorro?", "icon": "percent" },
            { "text": "¿Total ingresos?", "icon": "banknote" },
            { "text": "¿Total gastos?", "icon": "cart" }
          ]
        }
        """

        let result = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        #expect(result.count == 10)
        #expect(result[0].text == "¿Cuánto gasté en Restaurantes?")
        #expect(result[0].icon == "chart.pie")
    }

    @Test func parseInvalidJSON_throws() {
        #expect(throws: ChatSuggestionsParseError.self) {
            _ = try ChatSuggestionsLLMService.parseSuggestions(json: "not json")
        }
    }

    @Test func parseMissingSuggestionsKey_throws() {
        let json = "{ \"items\": [] }"
        #expect(throws: ChatSuggestionsParseError.malformedJSON) {
            _ = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        }
    }

    @Test func parseEmptyArray_throws() {
        let json = "{ \"suggestions\": [] }"
        #expect(throws: ChatSuggestionsParseError.emptyArray) {
            _ = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        }
    }

    @Test func parseTooManyItems_truncatesTo10() throws {
        var items: [String] = []
        for i in 1...15 {
            items.append("{ \"text\": \"pregunta \(i)\", \"icon\": \"sparkles\" }")
        }
        let json = "{ \"suggestions\": [\(items.joined(separator: ","))] }"

        let result = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        #expect(result.count == 10)
    }

    @Test func parseItemTooLong_filteredOut() throws {
        let longText = String(repeating: "a", count: 100) // > 80 chars
        let json = """
        {
          "suggestions": [
            { "text": "uno", "icon": "sparkles" },
            { "text": "dos", "icon": "sparkles" },
            { "text": "\(longText)", "icon": "sparkles" },
            { "text": "tres", "icon": "sparkles" }
          ]
        }
        """

        let result = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        #expect(result.count == 3)
        #expect(!result.contains(where: { $0.text.count > 80 }))
    }

    @Test func parseItemMissingText_filteredOut() throws {
        let json = """
        {
          "suggestions": [
            { "text": "uno", "icon": "sparkles" },
            { "icon": "sparkles" },
            { "text": "dos", "icon": "sparkles" },
            { "text": "tres", "icon": "sparkles" }
          ]
        }
        """

        let result = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        #expect(result.count == 3)
    }

    @Test func parseUnknownIcon_fallsBackToSparkles() throws {
        let json = """
        {
          "suggestions": [
            { "text": "uno", "icon": "not.a.real.symbol" },
            { "text": "dos", "icon": "chart.pie" },
            { "text": "tres", "icon": "another.fake" }
          ]
        }
        """

        let result = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        #expect(result.count == 3)
        #expect(result[0].icon == "sparkles")
        #expect(result[1].icon == "chart.pie")
        #expect(result[2].icon == "sparkles")
    }

    @Test func parseFewerThanMinItems_throws() throws {
        let json = """
        {
          "suggestions": [
            { "text": "uno", "icon": "sparkles" },
            { "text": "dos", "icon": "sparkles" }
          ]
        }
        """
        #expect(throws: ChatSuggestionsParseError.tooFewItems) {
            _ = try ChatSuggestionsLLMService.parseSuggestions(json: json)
        }
    }

    // MARK: - Cache (suite aislada por test — nace vacía, sin limpieza manual)

    @Test func cacheHit_returnsCachedSuggestions() throws {
        let defaults = makeIsolatedDefaults()

        let suggestions = [
            ChatSuggestion(text: "uno", icon: "chart.pie", type: .general),
            ChatSuggestion(text: "dos", icon: "chart.bar", type: .general)
        ]
        ChatSuggestionsLLMService.setCached(suggestions, for: Date.now, defaults: defaults)

        let cached = ChatSuggestionsLLMService.cachedSuggestions(for: Date.now, defaults: defaults)
        #expect(cached?.count == 2)
        #expect(cached?[0].text == "uno")
    }

    @Test func cacheMissOrCorrupted_returnsNil() {
        let defaults = makeIsolatedDefaults()

        let result = ChatSuggestionsLLMService.cachedSuggestions(for: Date.now, defaults: defaults)
        #expect(result == nil)
    }

    @Test func cacheCorruptedData_returnsNil() {
        let defaults = makeIsolatedDefaults()

        // Sembrar data corrupta en el MISMO defaults aislado que lee el service
        let key = "chat_suggestions_" + DayKeyFormatter.string(from: Date.now)
        defaults.set(Data([0xFF, 0x00, 0xAA]), forKey: key)

        let result = ChatSuggestionsLLMService.cachedSuggestions(for: Date.now, defaults: defaults)
        #expect(result == nil)
    }
}
