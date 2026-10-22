//
//  AIInsightFailureTests.swift
//  YalaTests
//
//  Si el análisis de IA de Resumen, Distribución o Tendencias falla, la tarjeta dice qué pasó en el idioma de la app, y
//  el cupo agotado del gateway se llama cupo agotado. Ticket `ai-insights-error-card-shows-raw-english-errors`.
//
//  Hasta el 2026-10-09 `InsightsViewModel` guardaba `error.localizedDescription` y la tarjeta enseñaba «Network error:
//  The request timed out.», «Rate limited — try again shortly» o «Failed to parse AI response» en inglés, y un 429
//  `yala_quota_daily` salía como «Network error: …».
//

import Foundation
import OpenAI
import Testing
@testable import Yala

@MainActor
struct AIInsightFailureTests {

    /// El sobre EXACTO de `gateway/src/errors.ts`, decodificado como lo decodifica el SDK.
    private static func gatewayError(_ type: String) throws -> Error {
        let json = #"{"error":{"message":"x","type":"\#(type)","param":null,"code":"\#(type)"}}"#
        return try JSONDecoder().decode(APIErrorResponse.self, from: Data(json.utf8))
    }

    // MARK: - Cada caso de InsightsLLMError

    @Test("cada caso de InsightsLLMError tiene su motivo", arguments: [
        (InsightsLLMError.noAPIKey, AIInsightFailure.generic),
        (.notProUser, .proRequired),
        (.noAIConsent, .generic),
        (.offline, .offline),
        (.rateLimited, .tooManyRequests),
        (.parseFailed, .generic),
        (.networkError(URLError(.timedOut)), .timeout),
        (.networkError(URLError(.notConnectedToInternet)), .offline),
        (.networkError(URLError(.badServerResponse)), .generic),
    ])
    func llmErrorCase(error: InsightsLLMError, expected: AIInsightFailure) {
        #expect(AIInsightFailureLogic.failure(for: error, isConnected: true) == expected)
    }

    @Test("la tarjeta nunca dice el localizedDescription del error", arguments: [
        InsightsLLMError.noAPIKey, .notProUser, .noAIConsent, .offline, .rateLimited, .parseFailed,
        .networkError(URLError(.timedOut)), .networkError(URLError(.badServerResponse)),
    ])
    func cardNeverShowsTheRawDescription(error: InsightsLLMError) {
        let failure = AIInsightFailureLogic.failure(for: error, isConnected: true)
        let card = AIInsightCardComponents.message(for: failure)
        #expect(card != error.localizedDescription)
        #expect(!card.hasPrefix("Network error"))
        #expect(!card.contains("Rate limited"))
        #expect(!card.contains("Failed to parse"))
    }

    // MARK: - Cada tipo del gateway

    @Test("los tipos del gateway, igual que en el chat", arguments: [
        ("yala_quota_daily", AIInsightFailure.dailyLimit),
        ("yala_quota_burst", .tooManyRequests),
        ("yala_pro_required", .proRequired),
        ("yala_attest_required", .generic),
    ])
    func gatewayType(type: String, expected: AIInsightFailure) throws {
        let wrapped = InsightsLLMError.networkError(try Self.gatewayError(type))
        #expect(AIInsightFailureLogic.failure(for: wrapped, isConnected: true) == expected)
        // Sin envolver (Tendencias deja pasar lo que no es InsightsLLMError).
        #expect(AIInsightFailureLogic.failure(for: try Self.gatewayError(type), isConnected: true) == expected)
    }

    @Test("el cupo diario agotado gana a «sin conexión»: lo dijo el servidor")
    func dailyQuotaWinsOverOffline() throws {
        let wrapped = InsightsLLMError.networkError(try Self.gatewayError("yala_quota_daily"))
        #expect(AIInsightFailureLogic.failure(for: wrapped, isConnected: false) == .dailyLimit)
    }

    @Test("un error desconocido sin red es «sin conexión»; con red, el genérico")
    func unknownError() {
        let error = InsightsLLMError.networkError(NSError(domain: "x", code: 1))
        #expect(AIInsightFailureLogic.failure(for: error, isConnected: false) == .offline)
        #expect(AIInsightFailureLogic.failure(for: error, isConnected: true) == .generic)
    }

    // MARK: - El texto de cada motivo, localizado

    /// La clave que pinta cada motivo. Si cambias el copy de un motivo, cambia esta tabla a propósito.
    private static let keys: [(AIInsightFailure, String)] = [
        (.offline, "insights.aiError.offline"),
        (.timeout, "chat.errorTimeout"),
        (.dailyLimit, "insights.aiError.dailyLimit"),
        (.tooManyRequests, "insights.aiError.tooManyRequests"),
        (.proRequired, "insights.aiError.proRequired"),
        (.generic, "chat.errorGeneric"),
    ]

    private static var lprojBundles: [(String, Bundle)] {
        let resources = Bundle.main.paths(forResourcesOfType: "lproj", inDirectory: nil)
        return resources.compactMap { path in
            let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".lproj", with: "")
            guard name != "Base", let bundle = Bundle(path: path) else { return nil }
            return (name, bundle)
        }
    }

    @Test("cada motivo tiene su texto en los 16 idiomas, y el cupo agotado habla del cupo")
    func everyFailureIsLocalizedEverywhere() throws {
        let bundles = Self.lprojBundles
        try #require(bundles.count >= 16, "solo \(bundles.count) .lproj en el bundle")
        for (failure, key) in Self.keys {
            var values: Set<String> = []
            for (locale, bundle) in bundles {
                let value = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
                #expect(value != "__MISSING__" && value != key, "\(key) falta en \(locale)")
                #expect(!value.contains("NEEDS_TRANSLATION"), "\(key) sin traducir en \(locale)")
                values.insert(value)
            }
            // Lo que pinta la tarjeta es el valor de ESA clave en algún idioma: el de la app.
            #expect(values.contains(AIInsightCardComponents.message(for: failure)), "\(failure) no pinta \(key)")
        }
        // Los seis motivos dicen cosas distintas.
        let messages = Set(Self.keys.map { AIInsightCardComponents.message(for: $0.0) })
        #expect(messages.count == Self.keys.count)
        // En español, el cupo agotado se llama cupo.
        let es = try #require(bundles.first { $0.0 == "es-419" }?.1)
        #expect(es.localizedString(forKey: "insights.aiError.dailyLimit", value: nil, table: nil).contains("cupo"))
    }

    // MARK: - Tendencias

    @Test("Tendencias: cada fallo guarda su motivo", arguments: [
        ("yala_quota_daily", AIInsightFailure.dailyLimit),
        ("yala_quota_burst", .tooManyRequests),
        ("yala_pro_required", .proRequired),
    ])
    func trendsKeepsTheGatewayReason(type: String, expected: AIInsightFailure) async throws {
        let error = InsightsLLMError.networkError(try Self.gatewayError(type))
        let vm = TrendsAIViewModel(
            request: { _, _ in throw error },
            isPro: { true }, hasConsent: { true }, isOnline: { true }
        )
        await vm.generate(input: TrendsAIViewModelFixtures.anyInput, regenerate: false)
        #expect(vm.phase == .failed(expected))
    }

    @Test("Tendencias sin red dice «sin conexión», no el genérico")
    func trendsOffline() async {
        let vm = TrendsAIViewModel(isPro: { true }, hasConsent: { true }, isOnline: { false })
        await vm.generate(input: TrendsAIViewModelFixtures.anyInput, regenerate: false)
        #expect(vm.phase == .failed(.offline))
    }

    // MARK: - Ningún camino pinta localizedDescription (source-scan)

    /// Quita comentarios de línea para que documentar el invariante no lo rompa.
    private static func codeOnly(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                if let range = line.range(of: "//") { return line[..<range.lowerBound] }
                return line
            }
            .joined(separator: "\n")
    }

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("ni los ViewModels ni la tarjeta leen localizedDescription", arguments: [
        "Yala/App/ViewModels/InsightsViewModel.swift",
        "Yala/App/ViewModels/TrendsAIViewModel.swift",
        "Yala/App/Views/Shared/AIInsightCardComponents.swift",
        "Yala/App/Logic/AIInsightFailureLogic.swift",
    ])
    func noLocalizedDescription(file: String) throws {
        #expect(!Self.codeOnly(try Self.source(file)).contains("localizedDescription"), "\(file)")
    }

    @Test("Insights clasifica el error con el mismo clasificador")
    func insightsViewModelClassifiesTheError() throws {
        let code = Self.codeOnly(try Self.source("Yala/App/ViewModels/InsightsViewModel.swift"))
        #expect(code.contains("aiError = AIInsightFailureLogic.failure(for: error, isConnected: NetworkMonitor.shared.isConnected)"))
        #expect(code.contains("private(set) var aiError: AIInsightFailure?"))
    }
}

enum TrendsAIViewModelFixtures {
    static var anyInput: TrendsAIInput {
        TrendsAIInput(
            metric: .expense, periodLabel: "Mes", comparisonLabel: nil, currentTotal: 1, previousTotal: nil,
            history: [], historyUnit: nil, cashFlow: nil, weekdaySpending: [], weekdayNames: [:],
            currencyCode: "PEN", currencyDisplay: "S/", locale: "es", country: "PE", filtersActive: false
        )
    }
}
