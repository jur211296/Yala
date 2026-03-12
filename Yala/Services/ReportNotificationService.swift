//
//  ReportNotificationService.swift
//  Yala
//
//  Service for sending report notifications with real calculated data.
//  Uses existing calculators: BalanceHelper, TopSpendingCategoriesCalculator.
//

import Foundation
import SwiftData

/// Data calculated for a report notification
struct ReportData {
    let balance: Double
    let totalExpense: Double
    let totalIncome: Double
    let topCategory: String?
}

/// Service for sending report notifications with real financial data
@MainActor
final class ReportNotificationService {
    static let shared = ReportNotificationService()

    private init() {}

    /// Guard flag to prevent concurrent sendDueReports calls (race between bootstrap and becameActive)
    private var isSendingReports = false

    // MARK: - Public Methods

    /// Sends report notifications that are due based on their configuration
    func sendDueReports(context: ModelContext) async {
        guard !isSendingReports else { return }
        isSendingReports = true
        defer { isSendingReports = false }
        guard await NotificationService.shared.isAuthorized() else { return }

        let reports = fetchActiveReportNotifications(context: context)
        var sentCount = 0

        for report in reports {
            guard Self.shouldSendNow(report) else { continue }

            let data = calculateReportData(config: report.reportConfig, type: report.notificationType, context: context)

            await NotificationService.shared.sendNotification(
                title: report.localizedName,
                body: Self.formatReportBody(report.reportConfig, reportType: report.notificationType, data: data),
                deepLink: "statistics"
            )

            // Mark as notified to prevent duplicate sends
            report.lastNotifiedDate = Date()
            sentCount += 1
        }

        // Save changes if any notifications were sent
        if sentCount > 0 {
            do {
                try context.save()
                #if DEBUG
                print("ReportNotificationService: Sent \(sentCount) report notifications")
                #endif
            } catch {
                #if DEBUG
                print("ReportNotificationService: Error saving lastNotifiedDate: \(error)")
                #endif
            }
        }
    }

    // MARK: - Timing Check

    /// Determines if the report should be sent now based on configuration
    /// Checks: 1) Not already notified today, 2) Within 30min window of scheduled time, 3) Correct day/weekday
    static func shouldSendNow(_ report: NotificationItem) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let config = report.reportConfig

        // 1. Already notified today? Skip to avoid spam
        if let lastNotified = report.lastNotifiedDate,
           calendar.isDateInToday(lastNotified) {
            return false
        }

        // 2. Has the scheduled time passed today?
        // We accept any time after the scheduled time on the same day
        // (lastNotifiedDate check above prevents duplicates)
        guard let scheduledToday = calendar.date(
            bySettingHour: report.hour,
            minute: report.minute,
            second: 0,
            of: now
        ) else { return false }

        // Only send if we're past the scheduled time (same day)
        guard now >= scheduledToday else { return false }

        // 3. Check day/weekday based on notification type
        switch report.notificationType {
        case .dailyReport:
            // Daily: check selected weekdays
            let weekday = calendar.component(.weekday, from: now)
            let selectedWeekdays = report.selectedWeekdays
            return selectedWeekdays.isEmpty || selectedWeekdays.contains(weekday)

        case .weeklyReport:
            // Weekly: check if it's the configured day (sunday=1 or monday=2)
            let weekday = calendar.component(.weekday, from: now)
            let targetWeekday = config.dayPreference == .sunday ? 1 : 2
            return weekday == targetWeekday

        case .monthlyReport:
            // Monthly: check if it's first or last day of month
            let day = calendar.component(.day, from: now)
            if config.dayPreference == .firstDay {
                return day == 1
            } else {
                // Last day of month
                let range = calendar.range(of: .day, in: .month, for: now)
                return day == range?.count
            }

        default:
            return false
        }
    }

    // MARK: - Data Calculation

    private func calculateReportData(config: ReportConfig, type: NotificationType, context: ModelContext) -> ReportData {
        let interval = Self.getIntervalForReportType(config, type: type)
        let transactions = fetchTransactions(in: interval, context: context)
        let accounts = fetchAccounts(context: context)
        let currencyCode = CurrencyDefaults.currentPreferred

        // Calculate balance using BalanceHelper
        let balance = BalanceHelper.totalBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode
        )

        // Calculate income/expense with proper currency conversion (R2, R4, R5)
        var totalIncome: Decimal = 0
        var totalExpense: Decimal = 0
        let eligibleAccountIDs = Set(accounts.map { $0.persistentModelID })

        for tx in transactions {
            // Exclude balance adjustments (same as TrendDataProcessor)
            guard tx.balanceAdjustmentType == nil else { continue }
            // Filter by eligible accounts (consistent with BalanceHelper)
            guard let account = tx.account,
                  eligibleAccountIDs.contains(account.persistentModelID) else { continue }

            let amount: Decimal
            // R2: Check currency and convert if needed (BalanceHelper pattern)
            if tx.preferredCurrencyCode == currencyCode {
                amount = Decimal(tx.amountInPreferredCurrency)
            } else {
                let sourceCurrency = CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode))
                    ?? (CurrencyCode(rawValue: currencyCode) ?? .usd)
                amount = CurrencyConverter.shared.convert(
                    Decimal(tx.amount),
                    from: sourceCurrency.rawValue,
                    to: currencyCode,
                    on: tx.date
                )
            }

            // R4: Same sign convention as TrendDataProcessor (income > 0, expense < 0)
            if amount > 0 {
                totalIncome += amount
            } else {
                totalExpense += abs(amount)
            }
        }

        // Get top category using TopSpendingCategoriesCalculator
        let topCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: transactions,
            interval: interval,
            currencyCode: currencyCode
        )

        return ReportData(
            balance: balance,
            totalExpense: NSDecimalNumber(decimal: totalExpense).doubleValue,
            totalIncome: NSDecimalNumber(decimal: totalIncome).doubleValue,
            topCategory: topCategories.first?.category.name
        )
    }

    static func getIntervalForReportType(_ config: ReportConfig, type: NotificationType) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()

        // Daily: today only
        if type == .dailyReport {
            let todayStart = calendar.startOfDay(for: now)
            // R1: If now == startOfDay (exact midnight), use previous full day
            if now <= todayStart {
                let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
                return DateInterval(start: yesterdayStart, end: todayStart)
            }
            return DateInterval(start: todayStart, end: now)
        }

        // Weekly/Monthly: use config.dayPreference
        switch config.dayPreference {
        case .sunday, .monday:
            // Weekly: last 7 days
            let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: weekStart, end: now)
        case .firstDay:
            // First day of month: report previous month
            let currentMonthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
            return DateInterval(start: previousMonthStart, end: currentMonthStart)
        case .lastDay:
            // Last day of month: report current month up to now
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            return DateInterval(start: monthStart, end: now)
        }
    }

    static func formatReportBody(_ config: ReportConfig, reportType: NotificationType, data: ReportData) -> String {
        let currencyCode = CurrencyDefaults.currentPreferred

        switch config.dataType {
        case .balance:
            return L10n.Notifications.reportBalance(YalaFormatter.currency(value: data.balance, currencyCode: currencyCode, forceFullPrecision: true))
        case .expenses:
            // Empty state check
            if data.totalExpense == 0 {
                switch reportType {
                case .dailyReport: return L10n.Notifications.emptyExpensesDaily
                case .weeklyReport: return L10n.Notifications.emptyExpensesWeekly
                case .monthlyReport: return L10n.Notifications.emptyExpensesMonthly
                default: return L10n.Notifications.emptyExpensesDaily
                }
            }
            return L10n.Notifications.reportExpenses(YalaFormatter.currency(value: data.totalExpense, currencyCode: currencyCode, forceFullPrecision: true))
        case .income:
            // Empty state check
            if data.totalIncome == 0 {
                return L10n.Notifications.emptyIncome
            }
            return L10n.Notifications.reportIncome(YalaFormatter.currency(value: data.totalIncome, currencyCode: currencyCode, forceFullPrecision: true))
        case .topCategory:
            guard let topCategory = data.topCategory else {
                return L10n.Notifications.emptyTopCategory
            }
            return L10n.Notifications.reportTopCategory(topCategory)
        }
    }

    // MARK: - Fetching

    private func fetchActiveReportNotifications(context: ModelContext) -> [NotificationItem] {
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate {
                $0.isActive && (
                    $0.typeRaw == "dailyReport" ||
                    $0.typeRaw == "weeklyReport" ||
                    $0.typeRaw == "monthlyReport"
                )
            }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching reports: \(error)")
            #endif
            return []
        }
    }

    private func fetchTransactions(in interval: DateInterval, context: ModelContext) -> [TransactionItem] {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= start && $0.date <= end }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching transactions: \(error)")
            #endif
            return []
        }
    }

    private func fetchAccounts(context: ModelContext) -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { !$0.excludeFromStatistics }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ReportNotificationService: Error fetching accounts: \(error)")
            #endif
            return []
        }
    }
}
