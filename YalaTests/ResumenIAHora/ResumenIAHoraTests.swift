//
//  ResumenIAHoraTests.swift
//  YalaTests
//
//  El resumen con IA de Estadísticas escrito con cifras viejas se marca «Escrito con tus datos de las HH:MM ·
//  Actualizar» (ticket `stats-ai-summary-shows-figures-from-before-the-latest-records`, opción B de Jürgen del
//  2026-11-17). Por la pasada real de la pantalla (`StatisticsRecalculation.run`) y la decisión del contenedor
//  (`InsightsViewModel.autoRefreshIfNeeded`), con la llamada al servicio sustituida y almacenes aislados.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Estadísticas · el resumen con IA dice a qué hora se escribió", .serialized)
struct ResumenIAHoraTests {

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
        let category: YalaCategory
        var transactions: [TransactionItem]
    }

    /// 20 gastos de 100: uno más mueve el total un 5 % y el recuento en 1, por debajo del umbral de regeneración
    /// automática (±3 registros o ±10 %).
    private func fixture(_ context: ModelContext, gastos: Int = 20) -> Fixture {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        context.insert(account)
        context.insert(food)
        var fixture = Fixture(account: account, category: food, transactions: [])
        for _ in 0..<gastos { fixture.transactions.append(tx(-100, fixture, context)) }
        return fixture
    }

    private func tx(_ amount: Double, _ f: Fixture, _ context: ModelContext) -> TransactionItem {
        let tx = TransactionItem(
            date: dia10(mesesAtras: 1), amount: amount, currencyCode: "PEN", note: "",
            category: f.category, account: f.account, tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "PEN"
        context.insert(tx)
        return tx
    }

    private func inputs(_ f: Fixture) -> StatisticsRecalculation.Inputs {
        StatisticsRecalculation.Inputs(
            transactions: f.transactions, accounts: [f.account], categories: [f.category], tags: [], budgets: [],
            scheduledPayments: [], period: .allTime, customRange: nil, comparisonMode: .month, currencyCode: "PEN",
            dataVersion: SessionState.shared.dataVersion, includeGroupTransactionsInStats: true
        )
    }

    private final class Calls {
        var count = 0
        var answer = "Viejo"
        var fails = false
    }

    private static func response(_ hero: String) -> LLMInsightResponse {
        LLMInsightResponse(heroText: hero, cards: [], funFact: nil)
    }

    @MainActor private struct Pantalla {
        let pass = StatisticsRecalculation()
        let records = RecordsViewModel()
        let trends = StatisticsViewModel(context: StatisticsContext(initialMetric: .balance, period: .allTime))
        let insights = InsightsViewModel()

        init(defaults: UserDefaults, calls: Calls) {
            insights.aiResultStore = InsightsAIResultStore(defaults: defaults, storageKey: "insightsAI.savedResults")
            insights.autoRefreshStore = StatsAIAutoRefreshStore(defaults: defaults)
            insights.isProProvider = { true }
            insights.hasConsentProvider = { true }
            insights.isOnlineProvider = { true }
            insights.aiRequest = { _, _, _, _, _ in
                calls.count += 1
                if calls.fails { throw InsightsLLMError.networkError(URLError(.timedOut)) }
                return ResumenIAHoraTests.response(calls.answer)
            }
        }

        func run(_ inputs: StatisticsRecalculation.Inputs, _ context: ModelContext) {
            pass.run(inputs, records: records, trends: trends, insights: insights, context: context)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        testDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    /// Abre Estadísticas, deja que el resumen se genere solo y añade un gasto de 100: por debajo del umbral, la ranura
    /// sigue enseñando el texto viejo. Devuelve la pantalla ya recalculada con el gasto nuevo.
    private func textoViejoTrasUnGasto(
        _ context: ModelContext, defaults: UserDefaults, calls: Calls
    ) async throws -> (Pantalla, Fixture) {
        var f = fixture(context)
        let primera = Pantalla(defaults: defaults, calls: calls)
        primera.run(inputs(f), context)
        await primera.insights.autoRefreshIfNeeded()
        #expect(calls.count == 1)
        #expect(primera.insights.aiWrittenWithOlderDataAt == nil, "Recién escrito con las cifras de ahora: sin marca.")

        f.transactions.append(tx(-100, f, context))
        SessionState.shared.dataVersion += 1
        let segunda = Pantalla(defaults: defaults, calls: calls)
        segunda.run(inputs(f), context)
        // Pasado el antirrebote, la decisión automática tampoco regenera: el cambio no es relevante.
        await segunda.insights.autoRefreshIfNeeded(now: .now.addingTimeInterval(11 * 60))
        #expect(calls.count == 1, "Un gasto bajo el umbral no regenera solo: el coste no cambia.")
        return (segunda, f)
    }

    // MARK: - Los cuatro casos del encargo

    @Test("Con los mismos datos no hay marca, tampoco al volver a abrir")
    func sameData_noMark() async throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let defaults = isolatedDefaults()
        let calls = Calls()
        await conTodoElTiempo {
            let primera = Pantalla(defaults: defaults, calls: calls)
            primera.run(inputs(f), context)
            await primera.insights.autoRefreshIfNeeded()
            #expect(primera.insights.aiInsights == Self.response("Viejo"))
            #expect(primera.insights.aiWrittenWithOlderDataAt == nil)

            let segunda = Pantalla(defaults: defaults, calls: calls)
            segunda.run(inputs(f), context)
            await segunda.insights.autoRefreshIfNeeded(now: .now.addingTimeInterval(30 * 3600))
            #expect(segunda.insights.aiInsights == Self.response("Viejo"))
            #expect(segunda.insights.aiWrittenWithOlderDataAt == nil, "Mismas cifras: sin marca, tenga la edad que tenga.")
            #expect(calls.count == 1)
        }
    }

    @Test("Un gasto nuevo bajo el umbral: el texto viejo se queda, marcado con la hora en que se escribió")
    func newExpenseUnderThreshold_marks() async throws {
        let context = try makeTestContext()
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let antes = Date.now
            let (pantalla, _) = try await textoViejoTrasUnGasto(context, defaults: defaults, calls: calls)
            #expect(pantalla.insights.aiInsights == Self.response("Viejo"))
            let marca = try #require(pantalla.insights.aiWrittenWithOlderDataAt, "Cifras distintas: la marca sale.")
            let guardado = try #require(
                pantalla.insights.currentAISlot().flatMap { pantalla.insights.autoRefreshStore.entry(page: .summary, slot: $0) }
            )
            #expect(marca == guardado.savedAt, "La hora es la de cuando se escribió el texto, no la de ahora.")
            #expect(marca >= antes.addingTimeInterval(-1))
        }
    }

    @Test("«Actualizar» regenera con los datos de ahora y quita la marca")
    func refresh_regeneratesAndClearsMark() async throws {
        let context = try makeTestContext()
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let (pantalla, _) = try await textoViejoTrasUnGasto(context, defaults: defaults, calls: calls)
            #expect(pantalla.insights.aiWrittenWithOlderDataAt != nil)

            calls.answer = "Nuevo"
            await pantalla.insights.refreshStaleAI()
            #expect(calls.count == 2)
            #expect(pantalla.insights.aiInsights == Self.response("Nuevo"))
            #expect(pantalla.insights.aiWrittenWithOlderDataAt == nil)
            #expect(!pantalla.insights.isLoadingAI)

            // Y cuenta para el techo: «Actualizar» no abre una puerta de llamadas sin límite.
            let slot = try #require(pantalla.insights.currentAISlot())
            #expect(pantalla.insights.autoRefreshStore.today(page: .summary, slot: slot).automaticCount == 2)
        }
    }

    @Test("Techo diario alcanzado: «Actualizar» no llama y lo dice; el texto y la marca se quedan")
    func refresh_dailyCapReached() async throws {
        let context = try makeTestContext()
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let (pantalla, _) = try await textoViejoTrasUnGasto(context, defaults: defaults, calls: calls)
            // Mediodía de hoy, fijo: el registro y la decisión caen el mismo día a cualquier hora que corra el test.
            let noon = try #require(calendar.date(bySettingHour: 12, minute: 0, second: 0, of: .now))
            let store = pantalla.insights.autoRefreshStore
            for i in 0..<StatsAIAutoRefreshLogic.dailyCap {
                store.recordGeneration(page: .summary, slot: "otra-\(i)", automatic: true, now: noon.addingTimeInterval(-60))
            }

            await pantalla.insights.refreshStaleAI(now: noon)
            #expect(calls.count == 1, "Con el techo gastado no se llama.")
            #expect(pantalla.insights.staleRefreshBlockedByDailyCap, "Y se dice, no falla en silencio.")
            #expect(pantalla.insights.aiInsights == Self.response("Viejo"))
            #expect(pantalla.insights.aiWrittenWithOlderDataAt != nil)
        }
    }

    // MARK: - Más

    @Test("Si «Actualizar» falla, el texto viejo se queda con su marca y el motivo a la vista")
    func refresh_failure_keepsMarkAndSaysWhy() async throws {
        let context = try makeTestContext()
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let (pantalla, _) = try await textoViejoTrasUnGasto(context, defaults: defaults, calls: calls)
            calls.fails = true
            await pantalla.insights.refreshStaleAI()
            #expect(calls.count == 2)
            #expect(pantalla.insights.aiInsights == Self.response("Viejo"))
            #expect(pantalla.insights.aiWrittenWithOlderDataAt != nil)
            #expect(pantalla.insights.aiError == .timeout)
            #expect(!pantalla.insights.isLoadingAI)
        }
    }

    @Test("La lógica: marca solo con cifras distintas y hora conocida")
    func logic_writtenWithOlderData() {
        let a = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [2000, 0])
        let b = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 21, totals: [2100, 0])
        let c = StatsAIAutoRefreshLogic.Snapshot(transactionCount: 20, totals: [2050, 0])
        let at = Date(timeIntervalSince1970: 1_000_000)
        #expect(StatsAIAutoRefreshLogic.writtenWithOlderData(shown: a, writtenAt: at, current: a) == nil)
        #expect(StatsAIAutoRefreshLogic.writtenWithOlderData(shown: a, writtenAt: at, current: b) == at)
        #expect(StatsAIAutoRefreshLogic.writtenWithOlderData(shown: a, writtenAt: at, current: c) == at, "Mismo recuento, otro total.")
        #expect(StatsAIAutoRefreshLogic.writtenWithOlderData(shown: nil, writtenAt: at, current: b) == nil)
        #expect(StatsAIAutoRefreshLogic.writtenWithOlderData(shown: a, writtenAt: nil, current: b) == nil)

        func today(_ automatic: Int) -> StatsAIAutoRefreshLogic.Today {
            StatsAIAutoRefreshLogic.Today(automaticCount: automatic, anyCount: automatic, lastForSlot: nil)
        }
        #expect(StatsAIAutoRefreshLogic.staleRefresh(today: today(StatsAIAutoRefreshLogic.dailyCap - 1)) == .allowed)
        #expect(StatsAIAutoRefreshLogic.staleRefresh(today: today(StatsAIAutoRefreshLogic.dailyCap)) == .dailyCapReached)
    }

    @Test("La hora sigue el ajuste de 12 o 24 horas de la persona")
    func time_followsHourCycle() throws {
        let date = try #require(calendar.date(bySettingHour: 18, minute: 5, second: 0, of: .now))
        let h24 = L10n.ResumenIAHora.time(date, language: Locale(identifier: "es"), region: Locale(identifier: "es_ES"))
        #expect(h24 == "18:05")
        let h12 = L10n.ResumenIAHora.time(date, language: Locale(identifier: "en"), region: Locale(identifier: "en_US"))
        #expect(h12.hasPrefix("6:05"), "12 h: \(h12)")
        #expect(h12.contains("PM"), "12 h: \(h12)")
    }

    @Test("Los textos de la marca están en los 16 idiomas, con la hora en su sitio")
    func strings_inEveryLocale() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/Resources")
        let locales = ["de", "en", "en-GB", "es", "es-419", "es-AR", "es-ES", "fr", "it", "ja", "nl", "pl", "pt",
                       "pt-BR", "pt-PT", "zh-Hans"]
        for locale in locales {
            let url = resources.appendingPathComponent("\(locale).lproj/Localizable.strings")
            let dict = try #require(NSDictionary(contentsOf: url) as? [String: String], "\(locale)")
            for key in ["insights.aiStale.writtenAt", "insights.aiStale.refresh", "insights.aiStale.refreshHint",
                        "insights.aiStale.dailyCap"] {
                let value = try #require(dict[key], "\(locale): falta \(key)")
                #expect(!value.isEmpty)
            }
            #expect(dict["insights.aiStale.writtenAt"]?.components(separatedBy: "%@").count == 2, "\(locale): un solo %@")
        }
    }
}
