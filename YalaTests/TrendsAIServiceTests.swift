//
//  TrendsAIServiceTests.swift
//  YalaTests
//
//  Lo puro del análisis con IA de Tendencias: payload (solo agregados, una
//  sección por gráfica presente) y parseo de la respuesta.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct TrendsAIServiceTests {

    private func input(
        comparisonLabel: String? = "Ago 26",
        previous: Double? = 1000,
        history: [TrendHistoryPoint] = [TrendHistoryPoint(start: Date(timeIntervalSince1970: 0), income: 2000, expense: 1500)],
        cashFlow: CashFlowSummary? = nil,
        weekday: [WeekdaySpending] = []
    ) -> TrendsAIInput {
        TrendsAIInput(
            metric: .expense,
            periodLabel: "Mes pasado",
            comparisonLabel: comparisonLabel,
            currentTotal: 1100,
            previousTotal: previous,
            history: history,
            historyUnit: .months,
            cashFlow: cashFlow,
            weekdaySpending: weekday,
            weekdayNames: [7: "sábado"],
            currencyCode: "PEN",
            currencyDisplay: "S/",
            locale: "es",
            country: "PE",
            filtersActive: false
        )
    }

    @Test func payload_carriesOneBlockPerVisibleChart() {
        let summary = CashFlowSummary(
            totalIncome: 1500, totalExpense: 1000, netFlow: 500, chartData: [], currencyCode: "PEN",
            incomeAmountsAreApproximate: false, expenseAmountsAreApproximate: false, amountsAreApproximate: false
        )
        let payload = TrendsAIService.buildPayload(input(
            cashFlow: summary,
            weekday: [WeekdaySpending(weekday: 7, total: 400, count: 4, dayOccurrences: 4)]
        ))
        let comparison = payload["comparison"] as? [String: Any]
        #expect(comparison?["variation_pct"] as? Int == 10)
        #expect(comparison?["previous_label"] as? String == "Ago 26")
        let flow = payload["cash_flow"] as? [String: Any]
        #expect(flow?["income_covers_expense_pct"] as? Int == 150)
        let days = payload["weekday_avg_expense"] as? [[String: Any]]
        #expect(days?.first?["day"] as? String == "sábado")
        #expect(days?.first?["avg"] as? Int == 100)
        #expect((payload["history_completed_periods"] as? [[String: Any]])?.count == 1)
        #expect(payload["history_unit"] as? String == "months")
    }

    @Test func payload_withoutComparisonOrData_omitsThoseBlocks() {
        let payload = TrendsAIService.buildPayload(input(comparisonLabel: nil, previous: nil, history: []))
        #expect(payload["comparison"] == nil)
        #expect(payload["cash_flow"] == nil)
        #expect(payload["weekday_avg_expense"] == nil)
        #expect(payload["history_completed_periods"] == nil)
    }

    @Test func cacheKey_changesWithTheData() {
        let a = TrendsAIService.cacheKey(payload: TrendsAIService.buildPayload(input(previous: 1000)), tone: .normal, focus: .balanced)
        let b = TrendsAIService.cacheKey(payload: TrendsAIService.buildPayload(input(previous: 900)), tone: .normal, focus: .balanced)
        let c = TrendsAIService.cacheKey(payload: TrendsAIService.buildPayload(input(previous: 1000)), tone: .normal, focus: .balanced)
        #expect(a != b)
        #expect(a == c)
    }

    @Test func parse_mapsChartsToSources_andCapsAtFour() throws {
        let json = """
        {"bullets":[
          {"chart":"trend","text":"Uno"},
          {"chart":"comparison","text":"Dos"},
          {"chart":"cashflow","text":"Tres"},
          {"chart":"weekday","text":"Cuatro"},
          {"chart":"trend","text":"Cinco"}
        ]}
        """
        let bullets = try TrendsAIService.parseResponse(json)
        #expect(bullets.map(\.text) == ["Uno", "Dos", "Tres", "Cuatro"])
        #expect(bullets.map(\.source) == [.trend, .comparison, .cashFlow, .weekday])
    }

    @Test func parse_dropsEmptyTexts_andUnknownChartsKeepTheirText() throws {
        let json = #"{"bullets":[{"chart":"trend","text":"  "},{"chart":"otra","text":"Vale"}]}"#
        let bullets = try TrendsAIService.parseResponse(json)
        #expect(bullets.count == 1)
        #expect(bullets[0].source == nil)
        #expect(bullets[0].text == "Vale")
    }

    @Test func parse_withoutBullets_fails() {
        #expect(throws: InsightsLLMError.self) { try TrendsAIService.parseResponse(#"{"bullets":[]}"#) }
        #expect(throws: InsightsLLMError.self) { try TrendsAIService.parseResponse(#"{"hero":"x"}"#) }
        #expect(throws: InsightsLLMError.self) { try TrendsAIService.parseResponse("no es json") }
    }
}

@MainActor
struct TrendsAIViewModelTests {

    private var anyInput: TrendsAIInput {
        TrendsAIInput(
            metric: .expense, periodLabel: "Mes", comparisonLabel: nil, currentTotal: 1, previousTotal: nil,
            history: [], historyUnit: nil, cashFlow: nil, weekdaySpending: [], weekdayNames: [:],
            currencyCode: "PEN", currencyDisplay: "S/", locale: "es", country: "PE", filtersActive: false
        )
    }

    @Test func freeUser_staysIdle() async {
        let vm = TrendsAIViewModel(isPro: { false }, hasConsent: { true }, isOnline: { true })
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .idle)
    }

    @Test func withoutConsent_staysIdle() async {
        let vm = TrendsAIViewModel(isPro: { true }, hasConsent: { false }, isOnline: { true })
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .idle)
    }

    @Test func offline_fallsBackToRuleBullets() async {
        // V2-06: sin red la card vuelve a los bullets de reglas con su aviso.
        let vm = TrendsAIViewModel(isPro: { true }, hasConsent: { true }, isOnline: { false })
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .failed)
        vm.reset()
        #expect(vm.phase == .idle)
    }

    @Test func loaded_thenRegenerateHitsTheRateLimit_keepsTheAnalysis() async {
        // Hallazgo de la review: un «Regenerar» antes de 5 s borraba un análisis bueno.
        var calls = 0
        let bullet = TrendsAIBullet(id: 0, source: .trend, text: "Uno")
        let vm = TrendsAIViewModel(
            request: { _, _ in
                calls += 1
                if calls == 1 { return [bullet] }
                throw InsightsLLMError.rateLimited
            },
            isPro: { true }, hasConsent: { true }, isOnline: { true }
        )
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .loaded([bullet]))
        await vm.generate(input: anyInput, regenerate: true)
        #expect(vm.phase == .loaded([bullet]))
    }

    @Test func otherErrors_fallBackToRuleBullets() async {
        let vm = TrendsAIViewModel(
            request: { _, _ in throw InsightsLLMError.parseFailed },
            isPro: { true }, hasConsent: { true }, isOnline: { true }
        )
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .failed)
    }

    @Test func aResetDuringTheRequest_dropsTheStaleAnswer() async {
        // Otro período/filtro mientras la petición vuela: la respuesta no se pinta.
        var vmRef: TrendsAIViewModel?
        let vm = TrendsAIViewModel(
            request: { _, _ in
                vmRef?.reset()
                return [TrendsAIBullet(id: 0, source: nil, text: "Viejo")]
            },
            isPro: { true }, hasConsent: { true }, isOnline: { true }
        )
        vmRef = vm
        await vm.generate(input: anyInput, regenerate: false)
        #expect(vm.phase == .idle)
    }
}

