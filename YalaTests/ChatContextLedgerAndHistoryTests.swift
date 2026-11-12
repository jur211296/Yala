//
//  ChatContextLedgerAndHistoryTests.swift
//  YalaTests
//
//  Revisión de Yala IA del 2026-10-20 (`docs/ai/revision-ia-2-2.md`). Fija, por el camino de producción
//  (`FullFinancialContextBuilder.build(modelContext:)`, el que leía solo 13 meses):
//  - los saldos salen del libro entero, como en el Panel (card `tablero-yala-ia-calcula-los-saldos-solo-con-los-646z`):
//    con la semilla `realista` Yala IA decía S/ 37.631 y el Panel S/ 71.569;
//  - un gasto de hoy fechado a las 12:00 cuenta desde por la mañana (card `…qrv9`);
//  - `monthly_history` trae los 12 meses cerrados, del más reciente al más antiguo, con su gasto real, y su resumen
//    acierta el mes más caro (el banco midió que el modelo se saltaba diciembre leyendo las 12 filas).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

#if DEBUG

@Suite("Yala IA · contexto: saldos del libro entero, hoy entero y meses anteriores", .serialized)
@MainActor
struct ChatContextLedgerAndHistoryTests {

    private let calendar = Calendar.current

    private func context(
        _ modelContext: ModelContext,
        now: Date,
        converter: CurrencyConverting? = nil
    ) -> FullFinancialContext {
        FullFinancialContextBuilder().build(
            modelContext: modelContext,
            currencyCode: "PEN",
            currencyDisplay: "S/",
            converter: converter ?? MockCurrencyConverter(),
            language: "es-419",
            country: "PE",
            includeAnomalies: false,
            includeGroupsInTotal: true,
            includeGroupTransactionsInStats: true,
            now: now
        )
    }

    /// Un mediodía de un día 15: lejos de los bordes de mes y de día.
    private var midMonthNoon: Date {
        let start = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        let day15 = calendar.date(byAdding: .day, value: 14, to: start) ?? start
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day15) ?? day15
    }

    @Test func balances_countTheWholeLedger_notTheThirteenMonthWindow() throws {
        let ctx = try makeTestContext()
        let now = midMonthNoon
        let account = makeTestAccount(context: ctx, name: "Principal")
        let category = makeTestCategory(context: ctx, name: "Comida")
        let sub = makeTestSubcategory(context: ctx, name: "Mercado", category: category)
        // Saldo inicial de hace dos años: fuera de la ventana de 13 meses.
        let initial = makeTestTransaction(
            context: ctx, amount: 5000, date: calendar.date(byAdding: .year, value: -2, to: now) ?? now,
            account: account, category: category, subcategory: sub)
        initial.balanceAdjustmentType = "initial_balance"
        _ = makeTestTransaction(
            context: ctx, amount: -300, date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            account: account, category: category, subcategory: sub)
        try ctx.save()

        let result = context(ctx, now: now)

        #expect(result.balances.totalBalance == 4700, "el saldo inicial de hace dos años cuenta, como en el Panel")
        #expect(result.balances.accounts.first?.balance == 4700)
        // Las estadísticas siguen siendo de la ventana: el gasto de ayer sí, el saldo inicial no es un gasto.
        #expect(result.periods.currentMonth.expense == 300)
    }

    @Test func expenseDatedTodayAtNoon_countsFromTheMorning() throws {
        let ctx = try makeTestContext()
        let morning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: midMonthNoon) ?? midMonthNoon
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: morning) ?? morning
        let account = makeTestAccount(context: ctx, name: "Principal")
        let category = makeTestCategory(context: ctx, name: "Comida")
        let sub = makeTestSubcategory(context: ctx, name: "Mercado", category: category)
        _ = makeTestTransaction(context: ctx, amount: -45, date: noon, account: account, category: category, subcategory: sub)
        // Y uno de mañana, que no cuenta.
        _ = makeTestTransaction(
            context: ctx, amount: -999, date: calendar.date(byAdding: .day, value: 1, to: noon) ?? noon,
            account: account, category: category, subcategory: sub)
        try ctx.save()

        let result = context(ctx, now: morning)

        #expect(result.periods.today.expense == 45, "la foto de hoy (12:00) cuenta a las 08:00, como en el Panel")
        #expect(result.periods.currentMonth.expense == 45)
        #expect(result.balances.totalBalance == -45)
    }

    @Test func monthlyHistory_twelveClosedMonths_newestFirst_withEachMonthsExpense() throws {
        let ctx = try makeTestContext()
        let now = midMonthNoon
        let account = makeTestAccount(context: ctx, name: "Principal")
        let category = makeTestCategory(context: ctx, name: "Comida")
        let sub = makeTestSubcategory(context: ctx, name: "Mercado", category: category)
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        // Un gasto el día 10 de cada uno de los 14 meses anteriores: 100 + n en el mes de hace n meses. El de hace 5
        // meses es el más caro (900), para que el máximo no sea ni el primero ni el último de la lista.
        for back in 1...14 {
            let month = calendar.date(byAdding: .month, value: -back, to: monthStart) ?? monthStart
            let day10 = calendar.date(byAdding: .day, value: 9, to: month) ?? month
            let amount = back == 5 ? 900.0 : Double(100 + back)
            _ = makeTestTransaction(context: ctx, amount: -amount, date: day10, account: account, category: category, subcategory: sub)
        }
        try ctx.save()

        let history = context(ctx, now: now).monthlyHistory
        let keyFormatter = DateFormatter()
        keyFormatter.locale = Locale(identifier: "en_US_POSIX")
        keyFormatter.calendar = Calendar(identifier: .gregorian)
        keyFormatter.timeZone = calendar.timeZone
        keyFormatter.dateFormat = "yyyy-MM"

        #expect(history.count == 12)
        for (index, month) in history.enumerated() {
            let back = index + 1
            let expectedStart = calendar.date(byAdding: .month, value: -back, to: monthStart) ?? monthStart
            #expect(month.month == keyFormatter.string(from: expectedStart))
            #expect(month.expense == (back == 5 ? 900 : Double(100 + back)), "mes de hace \(back)")
            #expect(month.topExpenseSubcategories.first?.name == "Mercado")
            #expect(month.topExpenseSubcategories.first?.category == "Comida")
        }

        let summary = try #require(context(ctx, now: now).monthlyHistorySummary)
        let fifthBack = calendar.date(byAdding: .month, value: -5, to: monthStart) ?? monthStart
        #expect(summary.highestExpenseMonth == keyFormatter.string(from: fifthBack))
        #expect(summary.highestExpense == 900)
        // Los años de la historia más el mes en curso suman los 13 meses.
        #expect(summary.byYear.reduce(0) { $0 + $1.months } == 13)
    }

    @Test func foreignAccount_carriesItsBalanceInTheMainCurrency_andTheRate() throws {
        let ctx = try makeTestContext()
        let now = midMonthNoon
        let account = makeTestAccount(context: ctx, name: "Ahorros USD", currencyCode: "USD")
        let category = makeTestCategory(context: ctx, name: "Ingresos", isIncome: true)
        let sub = makeTestSubcategory(context: ctx, name: "Salario", category: category)
        _ = makeTestTransaction(
            context: ctx, amount: 100, date: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
            account: account, category: category, subcategory: sub, currencyCode: "USD")
        try ctx.save()

        let result = context(ctx, now: now, converter: MockCurrencyConverter(fixedRate: 3.5))

        let entry = try #require(result.balances.accounts.first)
        #expect(entry.balance == 100)
        #expect(entry.balanceInMainCurrency == 350)
        #expect(entry.balanceInMainCurrencyIsApproximate == false)
        #expect(result.fxRates == [FullFinancialContext.FxRateEntry(currency: "USD", rateToMainCurrency: 3.5, isApproximate: false)])
    }
}

/// `month_outlook`: lo que queda del mes, ya sumado. Sin contexto de SwiftData.
@Suite("Yala IA · lo que queda del mes")
@MainActor
struct ChatContextMonthOutlookTests {

    private func budget(_ name: String, limit: Double, spent: Double, period: String = "monthly", currency: String = "PEN")
        -> FullFinancialContext.BudgetEntry {
        FullFinancialContext.BudgetEntry(
            name: name, category: nil, limit: limit, spent: spent, usagePercent: nil, daysLeft: 1, status: .onTrack,
            periodType: period, currency: currency)
    }

    private func pending(_ date: String, _ amount: Double, income: Bool = false) -> FullFinancialContext.RecurringPendingEntry {
        FullFinancialContext.RecurringPendingEntry(
            name: "x", amount: amount, dueDate: date, category: nil, subcategory: nil, type: "recurring", isIncome: income)
    }

    @Test func budgetsRemaining_sumsMonthlyBudgetsInTheMainCurrency_withoutNegatives() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        let monthEnd = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59)))
        let recurring = FullFinancialContext.RecurringSection(
            paidThisMonth: [],
            pendingNext30Days: [pending("2026-10-25", 90), pending("2026-10-31", 10), pending("2026-11-05", 2200), pending("2026-10-28", 500, income: true)],
            totals: FullFinancialContext.RecurringTotals(subscriptionsMonthly: 0, recurringMonthly: 0)
        )
        let outlook = FullFinancialContextBuilder.monthOutlook(
            budgets: [
                budget("A", limit: 1000, spent: 400),          // quedan 600
                budget("B", limit: 500, spent: 700),           // pasado: 0, no −200
                budget("C", limit: 300, spent: 0, period: "weekly"),
                budget("D", limit: 300, spent: 0, currency: "USD"),
            ],
            recurring: recurring,
            currencyCode: "PEN",
            now: now,
            monthEnd: monthEnd,
            calendar: calendar
        )
        #expect(outlook.budgetsRemaining == 600)
        #expect(outlook.daysLeft == 12, "del 20 al 31 contando hoy")
        #expect(outlook.pendingPaymentsUntilMonthEnd == 100, "el alquiler del 5 de noviembre no es de este mes")
        #expect(outlook.pendingIncomeUntilMonthEnd == 500)
    }
}

#endif
