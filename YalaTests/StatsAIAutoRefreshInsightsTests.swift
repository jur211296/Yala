//
//  StatsAIAutoRefreshInsightsTests.swift
//  YalaTests
//
//  El «Resumen con IA» de Resumen y Distribución se genera solo (encargo `estadisticas-ia-automatica`). Por la pasada
//  real de la pantalla (`StatisticsRecalculation.run`, que restaura lo guardado) y la decisión del contenedor
//  (`InsightsViewModel.autoRefreshIfNeeded`), con la llamada al servicio sustituida y almacenes aislados.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Estadísticas · el resumen con IA sale solo", .serialized)
struct StatsAIAutoRefreshInsightsTests {

    private let calendar = Calendar.current

    private func conTodoElTiempo(_ cuerpo: () async throws -> Void) async rethrows {
        let anterior = SessionState.shared.selectedPeriod
        SessionState.shared.selectedPeriod = .allTime
        defer { SessionState.shared.selectedPeriod = anterior }
        try await cuerpo()
    }

    private func dia10(mesesAtras: Int) -> Date {
        let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let mes = calendar.date(byAdding: .month, value: -mesesAtras, to: inicioMes) ?? inicioMes
        return calendar.date(byAdding: DateComponents(day: 9, hour: 12), to: mes) ?? mes
    }

    private struct Fixture {
        let account: Account
        let categories: [YalaCategory]
        var transactions: [TransactionItem]
    }

    /// `gastos` gastos de 100 en «Todo el tiempo».
    private func fixture(_ context: ModelContext, gastos: Int) -> Fixture {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        context.insert(account)
        context.insert(food)
        var fixture = Fixture(account: account, categories: [food], transactions: [])
        for _ in 0..<gastos { fixture.transactions.append(tx(-100, food, account, context)) }
        return fixture
    }

    private func tx(_ amount: Double, _ category: YalaCategory, _ account: Account, _ context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(
            date: dia10(mesesAtras: 1), amount: amount, currencyCode: "PEN", note: "",
            category: category, account: account, tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "PEN"
        context.insert(tx)
        return tx
    }

    private func inputs(_ f: Fixture) -> StatisticsRecalculation.Inputs {
        StatisticsRecalculation.Inputs(
            transactions: f.transactions, accounts: [f.account], categories: f.categories, tags: [], budgets: [],
            scheduledPayments: [], period: .allTime, customRange: nil, comparisonMode: .month, currencyCode: "PEN",
            dataVersion: SessionState.shared.dataVersion, includeGroupTransactionsInStats: true
        )
    }

    private final class Calls {
        var count = 0
        var shownDuringRequest: LLMInsightResponse?
        var loadingDuringRequest: Bool?
    }

    private static func response(_ hero: String) -> LLMInsightResponse {
        LLMInsightResponse(heroText: hero, cards: [], funFact: nil)
    }

    /// Una pantalla de Estadísticas con sus almacenes propios (`defaults` compartido entre dos «aperturas»).
    @MainActor private struct Pantalla {
        let pass = StatisticsRecalculation()
        let records = RecordsViewModel()
        let trends = StatisticsViewModel(context: StatisticsContext(initialMetric: .balance, period: .allTime))
        let insights = InsightsViewModel()

        init(
            defaults: UserDefaults,
            isPro: Bool = true,
            hasConsent: Bool = true,
            calls: Calls,
            answer: String = "Nuevo",
            fails: Bool = false
        ) {
            insights.aiResultStore = InsightsAIResultStore(defaults: defaults, storageKey: "insightsAI.savedResults")
            insights.autoRefreshStore = StatsAIAutoRefreshStore(defaults: defaults)
            insights.isProProvider = { isPro }
            insights.hasConsentProvider = { hasConsent }
            insights.isOnlineProvider = { true }
            let vm = insights
            insights.aiRequest = { _, _, _, _, _ in
                calls.count += 1
                calls.shownDuringRequest = vm.aiInsights
                calls.loadingDuringRequest = vm.isLoadingAI
                if fails { throw InsightsLLMError.parseFailed }
                return StatsAIAutoRefreshInsightsTests.response(answer)
            }
        }

        func run(_ inputs: StatisticsRecalculation.Inputs, _ context: ModelContext) {
            pass.run(inputs, records: records, trends: trends, insights: insights, context: context)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test("Pro con la IA aceptada: al abrir sale solo; al volver con los mismos datos, lo guardado y sin llamar")
    func opensGenerated_thenSavedWithoutCalling() async throws {
        let context = try makeTestContext()
        let f = fixture(context, gastos: 6)
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let primera = Pantalla(defaults: defaults, calls: calls)
            primera.run(inputs(f), context)
            #expect(primera.insights.isAwaitingAutoDecision, "Sin nada guardado: «Analizando…», no el botón.")
            await primera.insights.autoRefreshIfNeeded()
            #expect(calls.count == 1)
            #expect(primera.insights.aiInsights == Self.response("Nuevo"))
            #expect(primera.insights.aiActivated)

            let segunda = Pantalla(defaults: defaults, calls: calls)
            segunda.run(inputs(f), context)
            #expect(segunda.insights.aiInsights == Self.response("Nuevo"), "Lo guardado sale en la pasada, sin esperar.")
            await segunda.insights.autoRefreshIfNeeded(now: .now.addingTimeInterval(30 * 3600))
            #expect(calls.count == 1, "Mismas cifras: no se vuelve a pedir, ni pasadas 24 h.")
        }
    }

    @Test("Sin Pro o sin consentimiento: ninguna llamada y el botón de siempre")
    func gating_noCalls() async throws {
        let context = try makeTestContext()
        let f = fixture(context, gastos: 6)
        let calls = Calls()
        try await conTodoElTiempo {
            for (isPro, hasConsent) in [(false, true), (true, false)] {
                let pantalla = Pantalla(defaults: isolatedDefaults(), isPro: isPro, hasConsent: hasConsent, calls: calls)
                pantalla.run(inputs(f), context)
                #expect(!pantalla.insights.isAwaitingAutoDecision)
                await pantalla.insights.autoRefreshIfNeeded()
                #expect(!pantalla.insights.aiActivated)
            }
            #expect(calls.count == 0)
        }
    }

    @Test("Con menos de 5 registros no se genera solo")
    func fewTransactions_noCall() async throws {
        let context = try makeTestContext()
        let f = fixture(context, gastos: 4)
        let calls = Calls()
        try await conTodoElTiempo {
            let pantalla = Pantalla(defaults: isolatedDefaults(), calls: calls)
            pantalla.run(inputs(f), context)
            #expect(!pantalla.insights.isAwaitingAutoDecision)
            await pantalla.insights.autoRefreshIfNeeded()
            #expect(calls.count == 0)
        }
    }

    @Test("Un cambio relevante regenera por detrás, con lo guardado a la vista mientras llega")
    func relevantChange_showsSavedWhileRegenerating() async throws {
        let context = try makeTestContext()
        var f = fixture(context, gastos: 6)
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let primera = Pantalla(defaults: defaults, calls: calls, answer: "Viejo")
            primera.run(inputs(f), context)
            await primera.insights.autoRefreshIfNeeded()

            // Tres registros nuevos: cambio relevante.
            for _ in 0..<3 { f.transactions.append(tx(-100, f.categories[0], f.account, context)) }
            SessionState.shared.dataVersion += 1
            let segunda = Pantalla(defaults: defaults, calls: calls, answer: "Nuevo")
            segunda.run(inputs(f), context)
            #expect(segunda.insights.aiInsights == Self.response("Viejo"), "La ranura enseña lo último guardado.")
            await segunda.insights.autoRefreshIfNeeded(now: .now.addingTimeInterval(11 * 60))
            #expect(calls.count == 2)
            #expect(calls.shownDuringRequest == Self.response("Viejo"))
            #expect(calls.loadingDuringRequest == false, "Por detrás: sin «Analizando…» encima del texto.")
            #expect(segunda.insights.aiInsights == Self.response("Nuevo"))
        }
    }

    @Test("Un fallo automático es silencioso: sin aviso de error y vuelve el botón")
    func failure_isSilent() async throws {
        let context = try makeTestContext()
        let f = fixture(context, gastos: 6)
        let calls = Calls()
        try await conTodoElTiempo {
            let pantalla = Pantalla(defaults: isolatedDefaults(), calls: calls, fails: true)
            pantalla.run(inputs(f), context)
            await pantalla.insights.autoRefreshIfNeeded()
            #expect(calls.count == 1)
            #expect(pantalla.insights.aiError == nil)
            #expect(!pantalla.insights.aiActivated)
            #expect(!pantalla.insights.isLoadingAI)
            #expect(!pantalla.insights.isAwaitingAutoDecision)
        }
    }

    @Test("Techo diario: con 4 automáticas hoy, ni una más")
    func dailyCap() async throws {
        let context = try makeTestContext()
        let f = fixture(context, gastos: 6)
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            // Mediodía de hoy, fijo: el registro y la decisión caen el mismo día a cualquier hora que corra el test.
            let noon = try #require(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now))
            let store = StatsAIAutoRefreshStore(defaults: defaults)
            for i in 0..<StatsAIAutoRefreshLogic.dailyCap {
                store.recordGeneration(page: .summary, slot: "otra-\(i)", automatic: true, now: noon.addingTimeInterval(-60))
            }
            let pantalla = Pantalla(defaults: defaults, calls: calls)
            pantalla.run(inputs(f), context)
            await pantalla.insights.autoRefreshIfNeeded(now: noon)
            #expect(calls.count == 0)
            #expect(!pantalla.insights.isAwaitingAutoDecision, "Sin generación: vuelve el botón.")
        }
    }
}
