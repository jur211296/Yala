//
//  AntExpensesAIViewModelTests.swift
//  YalaTests
//
//  Gastos hormiga Pro con IA por la pasada real de Estadísticas (`StatisticsRecalculation.run`) y la decisión del
//  contenedor (`InsightsViewModel.autoRefreshAntAIIfNeeded`), con la llamada sustituida y almacenes aislados. Free no
//  llama nunca; Pro con la IA aceptada, sí; en la nube el envío lleva el detalle (Jürgen, 2026-11-06).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Gastos hormiga · la versión Pro con IA en la pantalla", .serialized)
struct AntExpensesAIViewModelTests {

    private let calendar = Calendar.current

    private func conTodoElTiempo(_ cuerpo: () async throws -> Void) async rethrows {
        let anterior = SessionState.shared.selectedPeriod
        SessionState.shared.selectedPeriod = .allTime
        defer { SessionState.shared.selectedPeriod = anterior }
        try await cuerpo()
    }

    private func dia(_ d: Int) -> Date {
        let inicioMes = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
        let mes = calendar.date(byAdding: .month, value: -1, to: inicioMes) ?? inicioMes
        return calendar.date(byAdding: DateComponents(day: d - 1, hour: 12), to: mes) ?? mes
    }

    private struct Fixture {
        let account: Account
        let categories: [YalaCategory]
        var transactions: [TransactionItem] = []
    }

    /// Dos grafías de la misma cafetería (2 + 2), un taxi hormiga (3) y gastos grandes.
    private func fixture(_ context: ModelContext) -> Fixture {
        let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        context.insert(account)
        context.insert(food)
        var f = Fixture(account: account, categories: [food])
        let rows: [(Double, String, Int)] = [
            (-9, "Starbucks", 1), (-9, "Starbucks", 2), (-11, "STARBUCKS COFFEE", 3), (-11, "STARBUCKS COFFEE", 4),
            (-12, "Taxi", 5), (-12, "Taxi", 6), (-12, "Taxi", 7),
            (-2200, "Alquiler", 8), (-400, "Súper", 9), (-150, "Zapatillas", 10), (-90, "Cena", 11), (-80, "Farmacia", 12),
        ]
        for (amount, note, d) in rows {
            let tx = TransactionItem(
                date: dia(d), amount: amount, currencyCode: "PEN", note: note,
                category: food, account: account, tags: [], amountInPreferredCurrency: amount)
            tx.preferredCurrencyCode = "PEN"
            context.insert(tx)
            f.transactions.append(tx)
        }
        return f
    }

    private func inputs(_ f: Fixture) -> StatisticsRecalculation.Inputs {
        StatisticsRecalculation.Inputs(
            transactions: f.transactions, accounts: [f.account], categories: f.categories, tags: [], budgets: [],
            scheduledPayments: [], period: .allTime, customRange: nil, comparisonMode: .month, currencyCode: "PEN",
            dataVersion: SessionState.shared.dataVersion, includeGroupTransactionsInStats: true
        )
    }

    private final class Calls {
        var payloads: [[String: Any]] = []
    }

    @MainActor private struct Pantalla {
        let pass = StatisticsRecalculation()
        let records = RecordsViewModel()
        let trends = StatisticsViewModel(context: StatisticsContext(initialMetric: .balance, period: .allTime))
        let insights = InsightsViewModel()

        init(
            defaults: UserDefaults, isPro: Bool = true, hasConsent: Bool = true, currentText: Bool = true,
            isCloud: Bool = false, calls: Calls
        ) {
            insights.aiResultStore = InsightsAIResultStore(defaults: defaults, storageKey: "insightsAI.savedResults")
            insights.autoRefreshStore = StatsAIAutoRefreshStore(defaults: defaults)
            insights.isProProvider = { isPro }
            insights.hasConsentProvider = { hasConsent }
            insights.hasCurrentConsentProvider = { hasConsent && currentText }
            insights.isOnlineProvider = { true }
            insights.isCloudProvider = { isCloud }
            insights.antAIRequest = { payload in
                calls.payloads.append(payload)
                return AntExpensesUITestReply.reply(for: payload)
            }
        }

        func run(_ inputs: StatisticsRecalculation.Inputs, _ context: ModelContext) {
            pass.run(inputs, records: records, trends: trends, insights: insights, context: context)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        testDefaults(suiteName: "test.\(UUID().uuidString)")!
    }

    @Test("Pro con la IA aceptada: sale solo, y al volver con los mismos datos sale lo guardado sin llamar")
    func pro_generatesThenRestores() async throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let defaults = isolatedDefaults()
        let calls = Calls()
        try await conTodoElTiempo {
            let primera = Pantalla(defaults: defaults, calls: calls)
            primera.run(inputs(f), context)
            #expect(primera.insights.antAI == nil)
            await primera.insights.autoRefreshAntAIIfNeeded()
            #expect(calls.payloads.count == 1)
            let insight = try #require(primera.insights.antAI)
            #expect(insight.mergedGroups.map(\.count) == [4])
            #expect(insight.tip == AntExpensesUITestReply.tip)

            let segunda = Pantalla(defaults: defaults, calls: calls)
            segunda.run(inputs(f), context)
            #expect(segunda.insights.antAI == insight, "Lo guardado sale en la pasada, sin esperar.")
            await segunda.insights.autoRefreshAntAIIfNeeded(now: .now.addingTimeInterval(30 * 3600))
            #expect(calls.payloads.count == 1, "Mismas cifras: no se vuelve a pedir.")
        }
    }

    @Test("Free o sin consentimiento: ninguna llamada y nada de IA en la tarjeta")
    func freeOrNoConsent_noCalls() async throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let calls = Calls()
        await conTodoElTiempo {
            for (isPro, hasConsent) in [(false, true), (true, false)] {
                let pantalla = Pantalla(defaults: isolatedDefaults(), isPro: isPro, hasConsent: hasConsent, calls: calls)
                pantalla.run(inputs(f), context)
                await pantalla.insights.autoRefreshAntAIIfNeeded()
                await pantalla.insights.triggerAntAI()
                #expect(pantalla.insights.antAI == nil)
                // La tarjeta gratis sigue ahí.
                #expect(pantalla.insights.insightData?.quickStats.antExpenses?.groups.map(\.label) == ["Taxi"])
            }
            #expect(calls.payloads.isEmpty)
        }
    }

    @Test("Permiso aceptado con el texto anterior: la IA de hormigas no sale sola ni a mano hasta aceptar el nuevo")
    func oldConsentText_waitsForTheNewOne() async throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let calls = Calls()
        await conTodoElTiempo {
            let pantalla = Pantalla(defaults: isolatedDefaults(), currentText: false, calls: calls)
            pantalla.run(inputs(f), context)
            await pantalla.insights.autoRefreshAntAIIfNeeded()
            await pantalla.insights.triggerAntAI()
            #expect(calls.payloads.isEmpty)
            #expect(pantalla.insights.antAI == nil)
            // El resumen de siempre sigue con el permiso de antes.
            #expect(pantalla.insights.canGenerateAIAutomatically)
        }
    }

    @Test("La marca de versión: vale con el texto vigente y no con el anterior")
    func consentRevision_readsTheVersion() {
        let defaults = isolatedDefaults()
        defaults.set(true, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        #expect(!AIConsentRevision.hasCurrentInsightsConsent(defaults), "Aceptado antes de la marca: versión 0.")
        defaults.set(AIConsentRevision.insights - 1, forKey: AppPreferences.Keys.aiInsightsConsentVersion)
        #expect(!AIConsentRevision.hasCurrentInsightsConsent(defaults))
        defaults.set(AIConsentRevision.insights, forKey: AppPreferences.Keys.aiInsightsConsentVersion)
        #expect(AIConsentRevision.hasCurrentInsightsConsent(defaults))
        defaults.set(false, forKey: AppPreferences.Keys.aiInsightsConsentAccepted)
        #expect(!AIConsentRevision.hasCurrentInsightsConsent(defaults), "Retirado en Ajustes: no vale aunque tenga versión.")
    }

    @Test("En la nube el envío lleva el detalle; en privado, no")
    func cloudSendsDetail_privateDoesNot() async throws {
        let context = try makeTestContext()
        let f = fixture(context)
        let calls = Calls()
        try await conTodoElTiempo {
            for isCloud in [false, true] {
                let pantalla = Pantalla(defaults: isolatedDefaults(), isCloud: isCloud, calls: calls)
                pantalla.run(inputs(f), context)
                await pantalla.insights.autoRefreshAntAIIfNeeded()
            }
            #expect(calls.payloads.count == 2)
            let privado = try #require(calls.payloads.first), nube = try #require(calls.payloads.last)
            #expect(privado["detail_level"] == nil)
            #expect(nube["detail_level"] as? String == "full")
            let grupos = try #require(nube["groups"] as? [[String: Any]])
            #expect(grupos.allSatisfy { $0["purchases"] != nil })
        }
    }

    @Test("Una respuesta guardada para OTRAS cifras no se enseña: los ids son posicionales")
    func staleSavedResponse_isNotShown() async throws {
        let context = try makeTestContext()
        var f = fixture(context)
        let defaults = isolatedDefaults()
        let calls = Calls()
        await conTodoElTiempo {
            let primera = Pantalla(defaults: defaults, calls: calls)
            primera.run(inputs(f), context)
            await primera.insights.autoRefreshAntAIIfNeeded()
            #expect(primera.insights.antAI != nil)

            // Otra compra pequeña cambia los grupos y sus ids.
            let extra = TransactionItem(
                date: dia(13), amount: -7, currencyCode: "PEN", note: "Pan", category: f.categories[0],
                account: f.account, tags: [], amountInPreferredCurrency: -7)
            extra.preferredCurrencyCode = "PEN"
            context.insert(extra)
            f.transactions.append(extra)
            let segunda = Pantalla(defaults: defaults, calls: calls)
            segunda.run(inputs(f), context)
            #expect(segunda.insights.antAI == nil)
        }
    }
}
