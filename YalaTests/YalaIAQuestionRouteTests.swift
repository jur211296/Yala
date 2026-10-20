//
//  YalaIAQuestionRouteTests.swift
//  YalaTests
//
//  Revisión de Yala IA del 2026-10-20 (`docs/ai/revision-ia-2-2.md`):
//  - la ruta sin modelo (`ChatIntentClassifierService.preRoute`) solo da «pregunta» donde el banco de `chat.intent`
//    (115 frases de 12 idiomas, `gateway/bench/cases/chat.intent.json`) dice pregunta, y se ahorra el clasificador en
//    la mayoría de las preguntas;
//  - el trato del chat sale del idioma base y es-AR va de vos (ticket `chat-register-misses-regional-variants`);
//  - un contexto que no se puede preparar no llega al modelo como `{}` (ticket `chat-context-encoding-failure-is-silent`).
//

import Foundation
import Testing

@testable import Yala

@Suite("Yala IA · ruta sin modelo, trato y contexto que no se prepara")
@MainActor
struct YalaIAQuestionRouteTests {

    private struct IntentCase: Decodable {
        let id: String
        let text: String
        let expect: String
        let accept: [String]?
    }

    private struct IntentBench: Decodable { let cases: [IntentCase] }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test func preRoute_neverContradictsTheIntentBench_andSkipsTheClassifierForMostQuestions() throws {
        let url = Self.repoRoot.appendingPathComponent("gateway/bench/cases/chat.intent.json")
        let bench = try JSONDecoder().decode(IntentBench.self, from: Data(contentsOf: url))
        #expect(bench.cases.count >= 100, "el banco de chat.intent no se leyó entero")

        var routedAsks = 0
        for c in bench.cases {
            guard let routed = ChatIntentClassifierService.preRoute(c.text) else { continue }
            let accepted = c.accept ?? [c.expect]
            #expect(accepted.contains(routed.rawValue), "\(c.id) «\(c.text)» se rutea a \(routed.rawValue)")
            if routed == .ask { routedAsks += 1 }
        }
        let asks = bench.cases.filter { $0.expect == "ask" }.count
        // Medido el 2026-10-20: 43 de 48 (fuera: «compárame…», una con cifra y tres en japonés o chino sin signo de pregunta). El suelo deja margen y caza un patrón roto que no rutee nada.
        #expect(routedAsks * 10 >= asks * 7, "solo \(routedAsks) de \(asks) preguntas se ahorran el clasificador")
    }

    @Test(arguments: [
        ("¿Y el mes pasado?", ChatIntent.ask),
        ("¿Cuál es la capital de Francia?", .ask),
        ("cuánto llevo gastado este mes", .ask),
        ("Am I over budget on anything?", .ask),
        ("Quais assinaturas eu pago todo mês?", .ask),
        ("今月の食費はいくら？", .ask),
        ("Puedo gastar 500 soles en unas zapatillas este mes", .ask),  // con cifra y sin signos (medido en el simulador)
        ("me alcanza para un viaje de 3000", .ask),
        ("Can I afford a 200 dollar dinner this week", .ask),
    ])
    func preRoute_questions(_ text: String, _ expected: ChatIntent) {
        #expect(ChatIntentClassifierService.preRoute(text) == expected)
    }

    @Test(arguments: [
        "¿Gasté 500 soles en zapatillas?",          // una cifra sin «puedo gastar»: lo decide el clasificador
        "¿me anotas el café de hoy?",              // verbo de apuntar
        "anota el taxi",
        "que caro estuvo el almuerzo",             // «que» sin signo: puede ser retórica
        "gasté demasiado en restaurantes",
        "log coffee",
        "",
    ])
    func preRoute_leavesTheRestToTheClassifier(_ text: String) {
        #expect(ChatIntentClassifierService.preRoute(text) == nil)
    }

    @Test(arguments: [
        ("es-419", "tuteo (tú)"),
        ("es-PE", "tuteo (tú)"),
        ("es-ES", "tuteo (tú)"),
        ("es_ES", "tuteo (tú)"),
        ("es-AR", "voseo (vos)"),
        ("pt-BR", "você"),
        ("pt-PT", "você"),
        ("de-DE", "du"),
        ("en-GB", "informal you"),
    ])
    func chatRegister_followsTheBaseLanguage_andVoseoInArgentina(_ language: String, _ expected: String) {
        #expect(AIPromptLanguage.chatRegister(for: language) == expected)
    }

    @Test func contextThatCannotBeEncoded_throws_insteadOfSendingAnEmptyObject() throws {
        var context = FullFinancialContextBuilder().buildFromArrays(
            transactions: [], budgets: [], accounts: [], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: MockCurrencyConverter(),
            language: "es-419", country: "PE", includeAnomalies: false
        )
        // Un sano se prepara.
        _ = try ChatAssistantService.shared.makeAskQuery(
            context: context, turns: [], question: "¿Cuánto gasté?", language: "es-419", country: "PE",
            currencyCode: "PEN", currencyDisplay: "S/")
        context.fxRates = [FullFinancialContext.FxRateEntry(currency: "USD", rateToMainCurrency: .nan, isApproximate: false)]
        #expect(throws: (any Error).self) {
            _ = try ChatAssistantService.shared.makeAskQuery(
                context: context, turns: [], question: "¿Cuánto gasté?", language: "es-419", country: "PE",
                currencyCode: "PEN", currencyDisplay: "S/")
        }
    }

    /// Lo que el modelo lee sobre los datos nuevos: si una regla se pierde, el dato está y nadie lo usa.
    @Test func systemPrompt_namesTheNewSections() throws {
        let context = FullFinancialContextBuilder().buildFromArrays(
            transactions: [], budgets: [], accounts: [], tags: [], scheduledPayments: [],
            currencyCode: "PEN", currencyDisplay: "S/", converter: MockCurrencyConverter(),
            language: "es-419", country: "PE", includeAnomalies: false
        )
        let query = try ChatAssistantService.shared.makeAskQuery(
            context: context, turns: [], question: "¿Cuánto gasté?", language: "es-AR", country: "AR",
            currencyCode: "PEN", currencyDisplay: "S/")
        let body = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(query)) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: Any]])
        let system = try #require(messages.first?["content"] as? String)
        for needle in [
            "monthly_history", "monthly_history_summary", "income_categories", "recurring.active", "fx_rates",
            "month_outlook.all_budgets_remaining", "period_months", "balance_in_main_currency", "Trato: voseo (vos).",
        ] {
            #expect(system.contains(needle), "el prompt no nombra \(needle)")
        }
        // Y el JSON trae las secciones.
        for key in ["\"monthly_history\"", "\"income_categories\"", "\"fx_rates\"", "\"month_outlook\"", "\"period_months\""] {
            #expect(system.contains(key), "el contexto no trae \(key)")
        }
    }
}
