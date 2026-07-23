//
//  ReportNotificationServiceTests.swift
//  YalaTests
//
//  Tests for ReportNotificationService pure logic methods:
//  shouldSendNow, getIntervalForReportType, formatReportBody.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// ≥1 `makeTestContext()` en la suite ⇒ `@Suite(.serialized)` (regla del repo, evita la
// acumulación de containers in-memory que crashea el proceso).
@Suite(.serialized)
struct ReportNotificationServiceTests {

    // MARK: - shouldSendNow — Already notified today

    @Test @MainActor func shouldSendNow_alreadyNotifiedToday_returnsFalse() {
        let report = makeDailyReport(hour: 0, minute: 0) // Midnight, so we're past it
        report.lastNotifiedDate = Date() // Notified today
        #expect(ReportNotificationService.shouldSendNow(report) == false)
    }

    // MARK: - shouldSendNow — Time check

    @Test @MainActor func shouldSendNow_beforeScheduledTime_returnsFalse() {
        let report = makeDailyReport(hour: 23, minute: 59)
        report.lastNotifiedDate = nil
        // Scheduled at 23:59 — unless we're past that, it should return false
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        // Only expect false if we're before 23:59
        if currentHour < 23 {
            #expect(ReportNotificationService.shouldSendNow(report) == false)
        }
    }

    @Test @MainActor func shouldSendNow_afterScheduledTime_daily_returnsTrue() {
        let report = makeDailyReport(hour: 0, minute: 0)
        report.lastNotifiedDate = nil
        // Scheduled at midnight, we're always past midnight during the day
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        if currentHour > 0 {
            #expect(ReportNotificationService.shouldSendNow(report) == true)
        }
    }

    // MARK: - shouldSendNow — Weekly

    @Test @MainActor func shouldSendNow_weekly_wrongDay_returnsFalse() {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())

        // Set the report to fire on a day that isn't today
        let config = ReportConfig(
            dataType: .expenses,
            dayPreference: today == 1 ? .monday : .sunday
        )
        let report = makeReport(type: .weeklyReport, hour: 0, minute: 0, config: config)
        report.lastNotifiedDate = nil

        #expect(ReportNotificationService.shouldSendNow(report) == false)
    }

    @Test @MainActor func shouldSendNow_weekly_correctDay_returnsTrue() {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let currentHour = calendar.component(.hour, from: Date())

        guard currentHour > 0 else { return } // Skip at exact midnight

        // Set preference to match today
        let dayPref: ReportDayPreference = today == 1 ? .sunday : (today == 2 ? .monday : .sunday)
        // This test only works reliably on Sunday or Monday
        guard today == 1 || today == 2 else { return }

        let config = ReportConfig(dataType: .expenses, dayPreference: dayPref)
        let report = makeReport(type: .weeklyReport, hour: 0, minute: 0, config: config)
        report.lastNotifiedDate = nil

        #expect(ReportNotificationService.shouldSendNow(report) == true)
    }

    // MARK: - shouldSendNow — Non-report type

    @Test @MainActor func shouldSendNow_nonReportType_returnsFalse() {
        let report = NotificationItem(
            name: "Test", text: "", hour: 0, minute: 0, type: .endOfDay
        )
        report.lastNotifiedDate = nil
        #expect(ReportNotificationService.shouldSendNow(report) == false)
    }

    // MARK: - shouldSendNow — Daily with weekday filter

    @Test @MainActor func shouldSendNow_daily_restrictedWeekdays_todayIncluded() {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let currentHour = calendar.component(.hour, from: Date())
        guard currentHour > 0 else { return }

        let report = makeDailyReport(hour: 0, minute: 0)
        report.lastNotifiedDate = nil
        report.selectedWeekdays = Set([today]) // Only today
        #expect(ReportNotificationService.shouldSendNow(report) == true)
    }

    @Test @MainActor func shouldSendNow_daily_restrictedWeekdays_todayExcluded() {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())
        let otherDay = today == 1 ? 2 : 1

        let report = makeDailyReport(hour: 0, minute: 0)
        report.lastNotifiedDate = nil
        report.selectedWeekdays = Set([otherDay]) // Not today
        #expect(ReportNotificationService.shouldSendNow(report) == false)
    }

    // MARK: - getIntervalForReportType

    @Test @MainActor func getIntervalForReportType_daily_startsAtStartOfToday() {
        let config = ReportConfig.default
        let interval = ReportNotificationService.getIntervalForReportType(config, type: .dailyReport)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        #expect(interval.start == todayStart)
        #expect(interval.end <= Date().addingTimeInterval(1))
    }

    @Test @MainActor func getIntervalForReportType_weekly_spans7Days() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let interval = ReportNotificationService.getIntervalForReportType(config, type: .weeklyReport)

        let duration = interval.end.timeIntervalSince(interval.start)
        // Should be approximately 7 days (± a few seconds)
        #expect(duration > 6 * 86400)
        #expect(duration < 8 * 86400)
    }

    @Test @MainActor func getIntervalForReportType_monthly_firstDay_previousMonth() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .firstDay)
        let interval = ReportNotificationService.getIntervalForReportType(config, type: .monthlyReport)

        let calendar = Calendar.current
        let currentMonthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        )!

        // Should end 1 second before current month start (reporting previous month,
        // sin incluir la medianoche del día 1 del mes actual — DateInterval es cerrado en ambos extremos)
        let expectedEnd = calendar.date(byAdding: .second, value: -1, to: currentMonthStart)!
        #expect(interval.end == expectedEnd)
        #expect(interval.start < currentMonthStart)
    }

    @Test @MainActor func getIntervalForReportType_monthly_lastDay_currentMonth() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .lastDay)
        let interval = ReportNotificationService.getIntervalForReportType(config, type: .monthlyReport)

        let calendar = Calendar.current
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: Date())
        )!

        #expect(interval.start == monthStart)
        #expect(interval.end <= Date().addingTimeInterval(1))
    }

    // MARK: - formatReportBody

    @Test @MainActor func formatReportBody_balance_containsAmount() {
        let config = ReportConfig(dataType: .balance, dayPreference: .monday)
        let data = ReportData(balance: 1500.50, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_expenses_noActivity_emptyState() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        // Sin actividad de gasto → copy vacío
        #expect(body == L10n.Notifications.emptyExpensesDaily)
    }

    @Test @MainActor func formatReportBody_expenses_netZeroButActivity_showsAmount() {
        // AC-c: gasto neto 0 PERO hubo actividad (reembolso que cancela) → NO empty.
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: true, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body != L10n.Notifications.emptyExpensesDaily)
    }

    @Test @MainActor func formatReportBody_expenses_withAmount_showsFormatted() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 250.75, totalIncome: 0, topCategory: nil, hasExpenseActivity: true, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body != L10n.Notifications.emptyExpensesDaily)
    }

    @Test @MainActor func formatReportBody_income_noActivity_emptyState() {
        let config = ReportConfig(dataType: .income, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body == L10n.Notifications.emptyIncome)
    }

    @Test @MainActor func formatReportBody_income_netZeroButActivity_showsAmount() {
        // AC-c simétrico: ingreso neto 0 con actividad → NO empty.
        let config = ReportConfig(dataType: .income, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: true)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body != L10n.Notifications.emptyIncome)
    }

    @Test @MainActor func formatReportBody_topCategory_noCategory_emptyState() {
        let config = ReportConfig(dataType: .topCategory, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_topCategory_withCategory_showsName() {
        let config = ReportConfig(dataType: .topCategory, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 100, totalIncome: 0, topCategory: "Alimentación", hasExpenseActivity: true, hasIncomeActivity: false)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body.contains("Alimentación"))
    }

    @Test @MainActor func formatReportBody_expenses_differentReportTypes_differentEmptyStates() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil, hasExpenseActivity: false, hasIncomeActivity: false)

        let dailyBody = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)
        let weeklyBody = ReportNotificationService.formatReportBody(config, reportType: .weeklyReport, data: data)
        let monthlyBody = ReportNotificationService.formatReportBody(config, reportType: .monthlyReport, data: data)

        // Each report type should have its own empty state message
        #expect(dailyBody == L10n.Notifications.emptyExpensesDaily)
        #expect(weeklyBody == L10n.Notifications.emptyExpensesWeekly)
        #expect(monthlyBody == L10n.Notifications.emptyExpensesMonthly)
    }

    // MARK: - accumulateReportTotals (clasificación + actividad — p20-14 Fase 2)

    @Test @MainActor func accumulate_classifiesByCategory_signed() {
        let account = makeAccount()
        let ids: Set<PersistentIdentifier> = [account.persistentModelID]
        let incomeCat = makeCategory(isIncome: true)
        let expenseCat = makeCategory(isIncome: false)
        let txs = [
            makeTransaction(amount: 500, account: account, category: incomeCat),
            makeTransaction(amount: -40, account: account, category: incomeCat),   // income refund
            makeTransaction(amount: -100, account: account, category: expenseCat),
            makeTransaction(amount: 30, account: account, category: expenseCat),   // expense refund
        ]

        let totals = ReportNotificationService.accumulateReportTotals(
            transactions: txs, eligibleAccountIDs: ids, currencyCode: "USD"
        )

        #expect(totals.totalIncome == 460)   // 500 - 40
        #expect(totals.totalExpense == 70)    // 100 - 30
        #expect(totals.hasIncomeActivity == true)
        #expect(totals.hasExpenseActivity == true)
    }

    @Test @MainActor func accumulate_netZeroExpense_stillHasActivity() {
        // AC-c: gasto −100 + reembolso +100 = neto 0 PERO hubo actividad de gasto.
        let account = makeAccount()
        let ids: Set<PersistentIdentifier> = [account.persistentModelID]
        let expenseCat = makeCategory(isIncome: false)
        let txs = [
            makeTransaction(amount: -100, account: account, category: expenseCat),
            makeTransaction(amount: 100, account: account, category: expenseCat),
        ]

        let totals = ReportNotificationService.accumulateReportTotals(
            transactions: txs, eligibleAccountIDs: ids, currencyCode: "USD"
        )

        #expect(totals.totalExpense == 0)
        #expect(totals.hasExpenseActivity == true)   // ← la clave del fix
        #expect(totals.hasIncomeActivity == false)
    }

    @Test @MainActor func accumulate_excludesBalanceAdjustmentsAndIneligibleAccounts() {
        let account = makeAccount()
        let other = makeAccount()
        let ids: Set<PersistentIdentifier> = [account.persistentModelID]
        let expenseCat = makeCategory(isIncome: false)
        let valid = makeTransaction(amount: -100, account: account, category: expenseCat)
        let adjustment = makeTransaction(amount: -50, account: account, category: expenseCat, balanceAdjustmentType: "manual")
        let ineligible = makeTransaction(amount: -200, account: other, category: expenseCat)
        let noAccount = makeTransaction(amount: -300, account: nil, category: expenseCat)

        let totals = ReportNotificationService.accumulateReportTotals(
            transactions: [valid, adjustment, ineligible, noAccount],
            eligibleAccountIDs: ids, currencyCode: "USD"
        )

        #expect(totals.totalExpense == 100)   // solo `valid`
        #expect(totals.hasExpenseActivity == true)
    }

    @Test @MainActor func accumulate_multiCurrency_convertsWithConverter() {
        let account = makeAccount()
        let ids: Set<PersistentIdentifier> = [account.persistentModelID]
        let expenseCat = makeCategory(isIncome: false)
        // EUR expense, reporting USD, rate 2.0 → −100 EUR = −200 USD
        let tx = makeTransaction(
            amount: -100, account: account, category: expenseCat,
            currencyCode: "EUR", preferredCurrencyCode: "EUR"
        )
        let converter = MockCurrencyConverter(fixedRate: 2.0)

        let totals = ReportNotificationService.accumulateReportTotals(
            transactions: [tx], eligibleAccountIDs: ids, currencyCode: "USD", converter: converter
        )

        // convert(−100, rate 2.0) = −200 ; expense -= (−200) = 200
        #expect(totals.totalExpense == 200)
        #expect(totals.hasExpenseActivity == true)
    }

    // MARK: - sendDueReports — marca de dedup SOLO con entrega confirmada
    // (ticket pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega, D3: superficie
    // hermana de ScheduledPaymentNotificationService — un fallo silencioso no debe suprimir
    // el reporte hasta el próximo período).

    @Test @MainActor func sendDueReports_sendFails_doesNotMarkNotified() async throws {
        let context = try makeTestContext()
        let report = makeDueDailyReport()
        context.insert(report)
        try context.save()

        let service = ReportNotificationService.makeForTesting()
        service.isAuthorizedOverride = { true }
        service.isQuiescentOverride = { true }
        service.sendOverride = { _, _, _ in false }   // iOS rechaza el request

        await service.sendDueReports(context: context)

        // Sin entrega ⇒ marca NO puesta: el próximo pass reintenta (no se suprime el reporte).
        #expect(report.lastNotifiedDate == nil)
    }

    @Test @MainActor func sendDueReports_sendSucceeds_marksNotified() async throws {
        let context = try makeTestContext()
        let report = makeDueDailyReport()
        context.insert(report)
        try context.save()

        let service = ReportNotificationService.makeForTesting()
        service.isAuthorizedOverride = { true }
        service.isQuiescentOverride = { true }
        service.sendOverride = { _, _, _ in true }

        await service.sendDueReports(context: context)

        #expect(report.lastNotifiedDate != nil)
    }

    @Test @MainActor func sendDueReports_notQuiescent_defersWithoutMarking() async throws {
        let context = try makeTestContext()
        let report = makeDueDailyReport()
        context.insert(report)
        try context.save()

        let service = ReportNotificationService.makeForTesting()
        service.isAuthorizedOverride = { true }
        service.isQuiescentOverride = { false }        // import en curso ⇒ diferir
        service.sendOverride = { _, _, _ in true }     // aunque "entregara", no debe llegar al envío

        await service.sendDueReports(context: context)

        // Gate de quiescencia load-bearing (evita el crash-loop del `save()` durante el restore):
        // sin quiescencia no se envía ni se marca. Si el guard se cae, enviaría (true) y marcaría.
        #expect(report.lastNotifiedDate == nil)
    }

    @Test @MainActor func sendDueReports_notAuthorized_defersWithoutMarking() async throws {
        let context = try makeTestContext()
        let report = makeDueDailyReport()
        context.insert(report)
        try context.save()

        let service = ReportNotificationService.makeForTesting()
        service.isAuthorizedOverride = { false }       // permisos denegados ⇒ no enviar ni marcar
        service.isQuiescentOverride = { true }
        service.sendOverride = { _, _, _ in true }

        await service.sendDueReports(context: context)

        #expect(report.lastNotifiedDate == nil)
    }

    /// Reporte diario activo, ventana siempre abierta (00:00, sin restricción de días),
    /// nunca notificado ⇒ `shouldSendNow == true` en cualquier momento del día (sin flakiness
    /// de medianoche: `now >= inicio-de-hoy` siempre se cumple).
    @MainActor
    private func makeDueDailyReport() -> NotificationItem {
        let report = makeReport(type: .dailyReport, hour: 0, minute: 0, config: .default)
        report.lastNotifiedDate = nil
        return report
    }

    // MARK: - Helpers

    @MainActor
    private func makeDailyReport(hour: Int, minute: Int) -> NotificationItem {
        makeReport(type: .dailyReport, hour: hour, minute: minute, config: .default)
    }

    @MainActor
    private func makeReport(
        type: NotificationType,
        hour: Int,
        minute: Int,
        config: ReportConfig
    ) -> NotificationItem {
        NotificationItem(
            name: "Test Report",
            text: "",
            hour: hour,
            minute: minute,
            type: type,
            reportConfig: config
        )
    }

    @MainActor
    private func makeAccount() -> Account {
        Account(
            name: "Test",
            currencyCode: "USD",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
    }

    @MainActor
    private func makeCategory(isIncome: Bool) -> YalaCategory {
        YalaCategory(name: isIncome ? "Salario" : "Comida", colorHex: "#000000", isIncome: isIncome)
    }

    @MainActor
    private func makeTransaction(
        amount: Double,
        account: Account?,
        category: YalaCategory?,
        currencyCode: String = "USD",
        preferredCurrencyCode: String = "USD",
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: amount,
            currencyCode: currencyCode,
            note: nil,
            category: category,
            account: account,
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: preferredCurrencyCode
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }
}
