//
//  AntExpensesAILogicTests.swift
//  YalaTests
//
//  Gastos hormiga con IA, solo Pro (ticket `insights-ant-expenses-ai-version-for-pro`): qué se envía en privado y en
//  la nube (decisiones 1A y «la nube lee todo lo que haga falta» de Jürgen, 2026-11-06), cómo se valida lo que la IA
//  contesta y que la tarjeta gratis no cambia.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Gastos hormiga · versión Pro con IA", .serialized)
struct AntExpensesAILogicTests {

    private let calendar = Calendar.current
    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: d, hour: 12)) ?? Date()
    }

    private func tx(_ amount: Double, _ note: String?, day d: Int = 10) -> TransactionItem {
        TransactionItem(
            date: day(d), amount: amount, currencyCode: "PEN", note: note,
            category: comida, account: cuenta,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    /// Un mes con dos grafías de la misma cafetería (2 + 2: ninguna llega a 3 sola), un taxi que sí es hormiga y
    /// gastos grandes que suben la mediana.
    private var mes: [TransactionItem] {
        [tx(-9, "Starbucks", day: 1), tx(-9, "Starbucks", day: 2),
         tx(-11, "STARBUCKS COFFEE", day: 3), tx(-11, "STARBUCKS COFFEE", day: 4),
         tx(-12, "Taxi", day: 5), tx(-12, "Taxi", day: 6), tx(-12, "Taxi", day: 7),
         tx(-2200, "Alquiler"), tx(-400, "Súper"), tx(-150, "Zapatillas"), tx(-90, "Cena"), tx(-80, "Farmacia")]
    }

    private func summary(_ txs: [TransactionItem]? = nil) throws -> AntExpensesSummary {
        try #require(AntExpensesCalculator.calculate(transactions: txs ?? mes, amountOf: { $0.amount }, dayCount: 30))
    }

    private func payload(_ s: AntExpensesSummary, detailed: Bool) -> [String: Any] {
        AntExpensesAILogic.payload(
            summary: s, currencyCode: "PEN", currencyDisplay: "S/", language: "es", periodLabel: "Abril",
            previousLabel: "vs marzo", detailed: detailed)
    }

    private func id(of label: String, in s: AntExpensesSummary) throws -> String {
        try #require(AntExpensesAILogic.orderedCandidates(s).first { $0.group.label == label }?.id)
    }

    // MARK: - La tarjeta gratis no cambia

    @Test("La tarjeta gratis sigue igual: solo Taxi; las dos grafías no llegan a 3 por separado")
    func freeCardUnchanged() throws {
        let s = try summary()
        #expect(s.groups.map(\.label) == ["Taxi"])
        #expect(s.count == 3 && s.total == 36)
        // Los candidatos para la IA incluyen las grafías sueltas.
        #expect(Set(s.candidates.map(\.label)).isSuperset(of: ["Starbucks", "STARBUCKS COFFEE", "Taxi"]))
    }

    // MARK: - Lo que se envía

    @Test("En privado (1A): nombre, veces y total; ni fechas, ni compras sueltas, ni grafías")
    func privatePayload_isMinimal() throws {
        let s = try summary()
        let p = payload(s, detailed: false)
        let groups = try #require(p["groups"] as? [[String: Any]])
        #expect(!groups.isEmpty)
        for group in groups {
            #expect(Set(group.keys) == ["id", "name", "count", "total"], "\(group.keys)")
        }
        #expect(p["detail_level"] == nil)
        #expect(p["previous_only_groups"] == nil)
        let json = String(data: try JSONSerialization.data(withJSONObject: p), encoding: .utf8) ?? ""
        #expect(!json.contains("2026-04"), "Ninguna fecha en privado.")
    }

    @Test("En la nube: además grafías, subcategoría, cada compra con su fecha y lo del período anterior que hoy no está")
    func cloudPayload_isDetailed() throws {
        var s = try summary()
        s.previousCandidates = AntExpensesCalculator.smallGroups(
            transactions: [tx(-10, "Rappi"), tx(-10, "Rappi"), tx(-12, "Taxi")],
            amountOf: { $0.amount }, threshold: s.threshold)
        let p = payload(s, detailed: true)
        #expect(p["detail_level"] as? String == "full")
        let groups = try #require(p["groups"] as? [[String: Any]])
        let taxi = try #require(groups.first { $0["name"] as? String == "Taxi" })
        let purchases = try #require(taxi["purchases"] as? [[String: Any]])
        #expect(purchases.count == 3)
        #expect(purchases.first?["date"] as? String == "2026-04-07", "De la más reciente a la más antigua.")
        #expect(taxi["category"] as? String == "Comida")
        #expect(taxi["previous_count"] as? Int == 1)
        let previousOnly = try #require(p["previous_only_groups"] as? [[String: Any]])
        #expect(previousOnly.map { $0["name"] as? String } == ["Rappi"])
    }

    @Test("Un grupo con dos grafías las manda todas en la nube")
    func cloudPayload_sendsEverySpelling() throws {
        // «Café» y «café » caen en la misma clave por la regla fija: el grupo tiene dos grafías.
        let s = try summary([tx(-8, "Café"), tx(-8, "café "), tx(-8, "Café"),
                             tx(-500, "A"), tx(-400, "B"), tx(-300, "C"), tx(-200, "D")])
        let groups = try #require(payload(s, detailed: true)["groups"] as? [[String: Any]])
        let cafe = try #require(groups.first { $0["name"] as? String == "Café" })
        let spellings = try #require(cafe["spellings"] as? [[String: Any]])
        #expect(spellings.count == 2)
    }

    // MARK: - Validación de la respuesta

    @Test("Une las dos grafías: cifras sumadas en Swift, la grafía más usada como nombre y el total con la unión")
    func merge_sumsInSwift() throws {
        let s = try summary()
        let a = try id(of: "Starbucks", in: s), b = try id(of: "STARBUCKS COFFEE", in: s)
        let insight = AntExpensesAILogic.insight(
            from: AntAIResponse(merges: [.init(ids: [a, b])], tip: "  Un **consejo**.  "), summary: s)
        let merged = try #require(insight.mergedGroups.first)
        #expect(merged.count == 4 && merged.total == 40)
        #expect(merged.label == "STARBUCKS COFFEE", "A igualdad de veces gana la que más suma.")
        #expect(merged.otherLabels == ["Starbucks"])
        #expect(insight.combinedCount == 7 && insight.combinedTotal == 76)
        #expect(insight.tip == "Un **consejo**.")
    }

    @Test("Lo que no cuadra se descarta: ids inventados, repetidos, en dos uniones o que no llegan a hormiga")
    func merge_rejectsWhatDoesNotFit() throws {
        let s = try summary()
        let a = try id(of: "Starbucks", in: s), b = try id(of: "STARBUCKS COFFEE", in: s), t = try id(of: "Taxi", in: s)
        let alquiler = try id(of: "Starbucks", in: s) // reusado para el caso del id en dos uniones
        let response = AntAIResponse(
            merges: [
                .init(ids: ["g999", a]),          // inventado → queda uno → fuera
                .init(ids: [a, a]),               // repetido → queda uno → fuera
                .init(ids: [a, b]),               // vale
                .init(ids: [alquiler, t]),        // `a` ya usado → queda uno → fuera
            ],
            tip: "   ")
        let insight = AntExpensesAILogic.insight(from: response, summary: s)
        #expect(insight.mergedGroups.count == 1)
        #expect(insight.tip == nil, "Un consejo vacío no se enseña.")

        // Dos grupos de 1 compra: 2 < 3, no es hormiga.
        let pocos = try summary([tx(-5, "Kiosco"), tx(-5, "KIOSCO LIMA"), tx(-12, "Taxi"), tx(-12, "Taxi"),
                                 tx(-12, "Taxi"), tx(-300, "A"), tx(-200, "B"), tx(-100, "C"), tx(-90, "D")])
        let k1 = try id(of: "Kiosco", in: pocos), k2 = try id(of: "KIOSCO LIMA", in: pocos)
        let sinHormiga = AntExpensesAILogic.insight(from: AntAIResponse(merges: [.init(ids: [k1, k2])], tip: nil), summary: pocos)
        #expect(sinHormiga.isEmpty)
    }

    @Test("Sin uniones no hay «total con la unión»: el de la tarjeta ya es ese")
    func noMerges_noCombinedTotal() throws {
        let insight = AntExpensesAILogic.insight(from: AntAIResponse(merges: [], tip: "Hola"), summary: try summary())
        #expect(insight.combinedTotal == nil && insight.combinedCount == nil)
        #expect(insight.tip == "Hola")
    }

    @Test("Un consejo largo se corta con «…»")
    func longTip_isCut() {
        let tip = AntExpensesAILogic.cleanTip(String(repeating: "a", count: 400))
        #expect(tip?.count == AntExpensesAILogic.tipMaxLength)
        #expect(tip?.hasSuffix("…") == true)
    }

    @Test("La respuesta sin `merges` decodifica como «no juntó nada»")
    func decoding_isTolerant() throws {
        let r = try JSONDecoder().decode(AntAIResponse.self, from: Data(#"{"tip":"x"}"#.utf8))
        #expect(r.merges.isEmpty && r.tip == "x")
    }

    @Test("La respuesta del seam de UI junta un nombre con los que empiezan por él (Starbucks)")
    func uiTestReply_mergesByPrefix() throws {
        let s = try summary()
        let reply = AntExpensesUITestReply.reply(for: payload(s, detailed: false))
        let insight = AntExpensesAILogic.insight(from: reply, summary: s)
        #expect(insight.mergedGroups.map(\.count) == [4])
    }

    @Test("El prompt pide solo ids del JSON y el idioma de la app")
    func prompt_rules() {
        let prompt = AntExpensesAIService.systemPrompt(currencyCode: "PEN", language: "en")
        #expect(prompt.contains("Usa SOLO los ids del JSON"))
        #expect(prompt.contains(InsightsLLMService.languageInstruction("en")))
        #expect(prompt.contains("detail_level"))
    }
}
