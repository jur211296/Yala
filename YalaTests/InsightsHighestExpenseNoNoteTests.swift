//
//  InsightsHighestExpenseNoNoteTests.swift
//  YalaTests
//
//  Lote 12.7 · card `tablero-observaciones-manda-a-la-ia-la-nota-libr-ve42` (ticket
//  `insights-cards-send-the-note-of-the-largest-expense`). Observaciones mandaba a la IA la NOTA libre del gasto
//  más alto, y su permiso promete agregados. Ahora viaja su subcategoría o categoría; la nota se sigue
//  enseñando en pantalla, que no sale del teléfono.
//
//  Discrimina: la nota («Regalo para Ana») no coincide con ninguna etiqueta, así que con el código viejo el
//  payload la lleva y el primer caso sale rojo.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Observaciones · el gasto más alto viaja sin su nota", .serialized)
struct InsightsHighestExpenseNoNoteTests {

    private let calendar = Calendar.current
    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let compras = YalaCategory(name: "Compras", colorHex: "#FF0000", isIncome: false)

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: d, hour: 12)) ?? Date()
    }

    private var abril: DateInterval {
        let start = calendar.startOfDay(for: day(1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private func highest(_ txs: [TransactionItem]) -> HighestExpenseInfo? {
        InsightsCalculator.calculate(
            transactions: txs, accounts: [cuenta], categories: [compras], budgets: [],
            scheduledPayments: [], period: .custom, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: abril, now: day(30)
        ).quickStats.highestExpense
    }

    private func tx(_ amount: Double, note: String?, category: YalaCategory?) -> TransactionItem {
        TransactionItem(
            date: day(10), amount: amount, currencyCode: "PEN", note: note,
            category: category, account: cuenta,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    @Test("El payload de la IA lleva la categoría, no la nota libre")
    func payload_carriesTheCategory_notTheNote() throws {
        let mayor = try #require(highest([tx(-300, note: "Regalo para Ana", category: compras), tx(-20, note: "Pan", category: compras)]))
        // La pantalla sigue enseñando la nota.
        #expect(mayor.note == "Regalo para Ana")
        #expect(mayor.categoryLabel == "Compras")

        let data = InsightData(
            periodSummary: PeriodSummary(
                totalExpense: 320, totalIncome: 0, netBalance: -320, transactionCount: 2,
                expenseVariation: nil, incomeVariation: nil, balanceVariation: nil,
                dailyAverageCount: 1, dailyAverageExpense: 10, dailyAverageVariation: nil,
                previousPeriodLabel: "vs mar",
                incomeAmountsAreApproximate: false, expenseAmountsAreApproximate: false, amountsAreApproximate: false
            ),
            quickStats: QuickStats(dailyAverage: 10, topCategories: [], topSubcategories: [], highestExpense: mayor,
                                   highestAvgWeekday: nil, subscriptionsTotal: 0),
            commitments: Commitments(pendingPaymentsCount: 0, pendingPaymentsAmount: 0, activeSubscriptionsCount: 0,
                                     activeSubscriptionsMonthly: 0, activeRecurringCount: 0, activeRecurringMonthly: 0,
                                     budgetsAtRisk: []),
            weekdaySpending: [],
            needDistribution: NeedDistribution(essential: 0, priority: 0, optional: 0, total: 0),
            yearOverYear: nil,
            ruleBasedInsights: []
        )
        let payload = InsightsViewModel().buildAggregatedData(data, currencyCode: "PEN", comparisonMode: .month)
        let highestPayload = try #require(payload["highest_expense"] as? [String: Any])
        #expect(highestPayload["description"] as? String == "Compras")
        #expect(highestPayload["amount"] as? Int == 300)
        // Ninguna parte del payload lleva la nota.
        let json = try JSONSerialization.data(withJSONObject: payload)
        #expect(!(String(data: json, encoding: .utf8) ?? "").contains("Regalo para Ana"))
    }

    @Test("Sin categoría: «sin categoría», tampoco la nota")
    func uncategorized_sendsTheUncategorizedLabel() throws {
        let mayor = try #require(highest([tx(-300, note: "Regalo para Ana", category: nil)]))
        #expect(mayor.categoryLabel == L10n.Report.uncategorized)
        #expect(mayor.note == "Regalo para Ana")
    }

    @Test("Sin nota, la pantalla enseña la categoría como antes")
    func noNote_screenShowsTheCategory() throws {
        let mayor = try #require(highest([tx(-300, note: nil, category: compras)]))
        #expect(mayor.note == "Compras")
        #expect(mayor.categoryLabel == "Compras")
    }
}
