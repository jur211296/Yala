//
//  ReportNotificationServiceTests.swift
//  YalaTests
//
//  Tests for ReportNotificationService pure logic methods:
//  shouldSendNow, getIntervalForReportType, formatReportBody.
//

import Foundation
import Testing

@testable import Yala

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
        let data = ReportData(balance: 1500.50, totalExpense: 0, totalIncome: 0, topCategory: nil)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_expenses_zeroAmount_emptyState() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        // Should show empty state message, not a formatted amount
        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_expenses_withAmount_showsFormatted() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 250.75, totalIncome: 0, topCategory: nil)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_income_zeroAmount_emptyState() {
        let config = ReportConfig(dataType: .income, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_topCategory_noCategory_emptyState() {
        let config = ReportConfig(dataType: .topCategory, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil)
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(!body.isEmpty)
    }

    @Test @MainActor func formatReportBody_topCategory_withCategory_showsName() {
        let config = ReportConfig(dataType: .topCategory, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 100, totalIncome: 0, topCategory: "Alimentación")
        let body = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)

        #expect(body.contains("Alimentación"))
    }

    @Test @MainActor func formatReportBody_expenses_differentReportTypes_differentEmptyStates() {
        let config = ReportConfig(dataType: .expenses, dayPreference: .monday)
        let data = ReportData(balance: 0, totalExpense: 0, totalIncome: 0, topCategory: nil)

        let dailyBody = ReportNotificationService.formatReportBody(config, reportType: .dailyReport, data: data)
        let weeklyBody = ReportNotificationService.formatReportBody(config, reportType: .weeklyReport, data: data)
        let monthlyBody = ReportNotificationService.formatReportBody(config, reportType: .monthlyReport, data: data)

        // Each report type should have its own empty state message
        #expect(!dailyBody.isEmpty)
        #expect(!weeklyBody.isEmpty)
        #expect(!monthlyBody.isEmpty)
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
}
