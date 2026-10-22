//
//  InsightsResponseLanguageTests.swift
//  YalaTests
//
//  Los comentarios de IA de Insights, del flujo de caja y de las desviaciones salen en el idioma de la APP
//  (`AppLocale`, vía `AIPromptLanguage.current`), no en el de la región de formato del iPhone (`Locale.current`).
//
//  Tickets `insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language` y
//  `ai-comments-ignore-the-app-language`. Hasta el 2026-10-07 los prompts del flujo de caja y de las desviaciones
//  no decían en qué idioma contestar, y Insights mandaba `Locale.current.language`.
//
//  El override de idioma se elige DISTINTO del idioma de `Locale.current` del host, para que el caso discrimine:
//  con el código viejo, el payload y los prompts dicen el de la región y estos casos salen rojos.
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized, .appLanguageStateIsolated)
struct InsightsResponseLanguageTests {

    /// Un idioma de la app que NO es el de la región del host: «de», o «ja» si el host ya está en alemán.
    private static var appLanguageUnlikeRegion: String {
        Locale.current.language.languageCode?.identifier == "de" ? "ja" : "de"
    }

    private static func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Lanza `body` con el transporte de prueba y devuelve los mensajes (sistema y usuario) de la única petición. Los
    /// servicios se llaman con `try?` a propósito, como en `ProxyTaskHeaderTests`: la respuesta de prueba es un JSON
    /// vacío que su parser rechaza, y lo que se mira es la PETICIÓN.
    private func sentMessages(_ body: () async -> Void) async throws -> (system: String, user: String) {
        CapturingURLProtocol.reset()
        ProxyClientFactory.testTransport = ("test-token", Self.stubSession())
        defer { ProxyClientFactory.testTransport = nil }
        await body()
        let sent = CapturingURLProtocol.snapshot()
        #expect(sent.count == 1, "salieron \(sent.count) peticiones")
        let data = try #require(sent.first?.body)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(json["messages"] as? [[String: Any]])
        func text(_ role: String) throws -> String {
            let message = try #require(messages.first { $0["role"] as? String == role }, "falta el mensaje \(role)")
            if let s = message["content"] as? String { return s }
            let parts = try #require(message["content"] as? [[String: Any]])
            return parts.compactMap { $0["text"] as? String }.joined()
        }
        return (try text("system"), try text("user"))
    }

    private static func emptyInsightData() -> InsightData {
        InsightData(
            periodSummary: PeriodSummary(
                totalExpense: 1000, totalIncome: 1500, netBalance: 500, transactionCount: 10,
                expenseVariation: nil, incomeVariation: nil, balanceVariation: nil,
                dailyAverageCount: 1, dailyAverageExpense: 33, dailyAverageVariation: nil,
                previousPeriodLabel: "vs Sep 26",
                incomeAmountsAreApproximate: false, expenseAmountsAreApproximate: false, amountsAreApproximate: false
            ),
            quickStats: QuickStats(dailyAverage: 33, topCategories: [], topSubcategories: [], highestExpense: nil, highestAvgWeekday: nil, subscriptionsTotal: 0),
            commitments: Commitments(pendingPaymentsCount: 0, pendingPaymentsAmount: 0, activeSubscriptionsCount: 0, activeSubscriptionsMonthly: 0, activeRecurringCount: 0, activeRecurringMonthly: 0, budgetsAtRisk: []),
            weekdaySpending: [],
            needDistribution: NeedDistribution(essential: 0, priority: 0, optional: 0, total: 0),
            yearOverYear: nil,
            ruleBasedInsights: []
        )
    }

    // MARK: - Insights: el payload

    @Test("Insights manda el idioma de la app, no el de la región del iPhone")
    func insightsPayload_carriesTheAppLanguage() throws {
        let appLanguage = Self.appLanguageUnlikeRegion
        LanguageManager.overrideLanguage = appLanguage
        let regionLanguage = Locale.current.language.languageCode?.identifier
        try #require(regionLanguage != appLanguage, "el caso no discrimina: la región ya está en \(appLanguage)")

        let payload = InsightsViewModel().buildAggregatedData(Self.emptyInsightData(), currencyCode: "PEN", comparisonMode: .month)

        #expect(payload["locale"] as? String == AppLocale.identifier)
        #expect(payload["locale"] as? String == appLanguage)
        // La región sigue viajando, pero solo como pista de tono.
        #expect(payload["country"] as? String == (Locale.current.region?.identifier ?? ""))
    }

    @Test("el prompt de Insights pide el idioma del payload, con su trato")
    func insightsPrompt_asksForThePayloadLanguage() async throws {
        let (system, _) = try await sentMessages {
            _ = try? await InsightsLLMService().generateInsights(aggregatedData: ["locale": "de", "currency": "EUR"], cacheKey: "test-\(UUID().uuidString)")
        }
        #expect(system.contains(InsightsLLMService.languageInstruction("de")))
        #expect(system.contains("- Trato: du, como un amigo que sabe de finanzas"))
        #expect(!system.contains("Tutea al usuario (\"tú\")"))
    }

    @Test("la caché de Insights distingue el idioma")
    func insightsCacheKey_includesTheLanguage() {
        let service = InsightsLLMService()
        let german = service.cacheKey(period: "thisMonth", filterHash: 1, txnCount: 2, language: "de")
        let english = service.cacheKey(period: "thisMonth", filterHash: 1, txnCount: 2, language: "en")
        #expect(german != english)
        LanguageManager.overrideLanguage = "ja"
        #expect(service.cacheKey(period: "thisMonth", filterHash: 1, txnCount: 2) == service.cacheKey(period: "thisMonth", filterHash: 1, txnCount: 2, language: "ja"))
    }

    // MARK: - Flujo de caja y desviaciones: la petición que sale de verdad

    @Test("el comentario del flujo de caja pide el idioma de la app y escribe los meses en él")
    func cashFlowRequest_usesTheAppLanguage() async throws {
        let appLanguage = Self.appLanguageUnlikeRegion
        LanguageManager.overrideLanguage = appLanguage
        try #require(Locale.current.language.languageCode?.identifier != appLanguage, "el caso no discrimina")

        // Octubre de 2026, el mes en curso: «okt. 2026» en alemán, «2026年10月» en japonés.
        let october = try #require(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 10, day: 15)))
        let month = CashFlowMonth(
            monthKey: "2026-10", date: october, isPast: false, isCurrent: true,
            incomeLines: [], expenseLines: [], otherExpenses: nil, otherIncome: nil,
            totalIncome: 3000, totalExpense: 3500, netFlow: -500, accumulatedBalance: 900
        )
        let projection = CashFlowProjection(months: [month], startingBalance: 1400, totalProjectedIncome: 3000, totalProjectedExpense: 3500, totalProjectedNet: -500)

        let (system, user) = try await sentMessages {
            _ = try? await InsightsLLMService().generateCashFlowInsight(projection: projection, currencyCode: "EUR")
        }

        #expect(system.contains(InsightsLLMService.languageInstruction(AppLocale.identifier)))
        #expect(system.contains("IDIOMA: Responde SIEMPRE en \(AIPromptLanguage.label(for: appLanguage)),"))
        let monthName = october.formatted(Date.FormatStyle.dateTime.month(.abbreviated).year().locale(Locale(identifier: appLanguage))).lowercased()
        let regionMonthName = october.formatted(.dateTime.month(.abbreviated).year()).lowercased()
        try #require(monthName != regionMonthName, "el nombre del mes no distingue los dos idiomas")
        #expect(user.contains(monthName), "el payload no lleva «\(monthName)»: \(user)")
    }

    @Test("el comentario de las desviaciones pide el idioma de la app")
    func deviationRequest_usesTheAppLanguage() async throws {
        let appLanguage = Self.appLanguageUnlikeRegion
        LanguageManager.overrideLanguage = appLanguage
        try #require(Locale.current.language.languageCode?.identifier != appLanguage, "el caso no discrimina")

        let (system, _) = try await sentMessages {
            _ = try? await InsightsLLMService().generateDeviationInsight(deviations: [(name: "Comida", planned: 100, actual: 150, excess: 50)], currencyCode: "EUR")
        }

        #expect(system.contains("IDIOMA: Responde SIEMPRE en \(AIPromptLanguage.label(for: appLanguage)),"))
        #expect(system.contains(InsightsLLMService.languageInstruction(AppLocale.identifier)))
    }

    // MARK: - Los prompts, puros

    @Test("flujo y desviaciones: la línea de idioma y el trato de cada idioma", arguments: [
        ("es-AR", "tuteo (tú)"),
        ("pt-BR", "você"),
        ("de", "du"),
        ("fr", "tu"),
        ("ja", "informal you"),
        ("zh-Hans", "informal you"),
    ])
    func prompts_carryTheLanguageAndItsRegister(language: String, register: String) {
        for prompt in [
            InsightsLLMService.cashFlowSystemPrompt(currencyCode: "EUR", language: language),
            InsightsLLMService.deviationSystemPrompt(currencyCode: "EUR", language: language),
        ] {
            #expect(prompt.contains(InsightsLLMService.languageInstruction(language)))
            #expect(prompt.contains("- Trato: \(register). Lidera con el dato"))
            #expect(!prompt.contains("Tutea (\"tú\")"))
            // Lo que el gateway usa para deducir la tarea en versiones sin cabecera, intacto.
            #expect(prompt.contains("sobre la proyección de flujo de caja del usuario.") || prompt.contains("sobre las subcategorías donde el usuario gastó más de lo planeado."))
        }
    }

    @Test("la línea de idioma cita el idioma y pide traducir el vocabulario de las reglas")
    func languageInstruction_namesTheLanguageAndTheLeakingWords() {
        let line = InsightsLLMService.languageInstruction("pl")
        #expect(line.hasPrefix("IDIOMA: Responde SIEMPRE en polaco (pl),"))
        #expect(line.contains("ni copies palabras de estas instrucciones: gasto, ingreso, presupuesto y plan"))
        #expect(line.hasSuffix("con la palabra propia de ese idioma."))
    }

    @Test("el idioma con nombre y código; uno sin nombre, con su código")
    func label() {
        #expect(AIPromptLanguage.label(for: "it") == "italiano (it)")
        #expect(AIPromptLanguage.label(for: "es-PE") == "español (es-PE)")
        #expect(AIPromptLanguage.label(for: "zh-Hans") == "chino (zh-Hans)")
        #expect(AIPromptLanguage.label(for: "ko") == "ko")
        // Los diez idiomas de la app tienen nombre.
        for locale in SupportedLocale.allCases {
            #expect(AIPromptLanguage.spanishName(forBaseLanguage: AIPromptLanguage.baseCode(of: locale.code)) != nil, "\(locale.code) sin nombre")
        }
    }

    @Test("el idioma base de un BCP-47")
    func baseCode() {
        #expect(AIPromptLanguage.baseCode(of: "es-419") == "es")
        #expect(AIPromptLanguage.baseCode(of: "zh-Hans") == "zh")
        #expect(AIPromptLanguage.baseCode(of: "pt-PT") == "pt")
        #expect(AIPromptLanguage.baseCode(of: "en") == "en")
    }
}
