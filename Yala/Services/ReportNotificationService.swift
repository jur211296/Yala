//
//  ReportNotificationService.swift
//  Yala
//
//  Service for sending report notifications with real calculated data.
//  Uses existing calculators: BalanceHelper, TrendDataProcessor, TopSpendingCategoriesCalculator.
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

    // MARK: - Public Methods

    /// Sends report notifications that are due based on their configuration
    func sendDueReports(context: ModelContext) async {
        guard await NotificationService.shared.isAuthorized() else { return }

        let reports = fetchActiveReportNotifications(context: context)

        for report in reports {
            guard shouldSendNow(report) else { continue }

            let data = calculateReportData(config: report.reportConfig, context: context)

            await NotificationService.shared.sendTestNotification(
                title: "Yala - \(report.name)",
                body: formatReportBody(report.reportConfig, data: data)
            )
        }
    }

    // MARK: - Timing Check

    /// Determines if the report should be sent now based on configuration
    private func shouldSendNow(_ report: NotificationItem) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let config = report.reportConfig

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

    private func calculateReportData(config: ReportConfig, context: ModelContext) -> ReportData {
        let interval = getIntervalForReportType(config)
        let transactions = fetchTransactions(in: interval, context: context)
        let accounts = fetchAccounts(context: context)
        let currencyCode = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"

        // Calculate balance using BalanceHelper
        let balance = BalanceHelper.totalBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            context: context
        )

        // Calculate income/expense using TrendDataProcessor
        let trendResult = TrendDataProcessor.processTrendData(
            transactions: transactions,
            accounts: accounts,
            metric: .expense,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: currencyCode,
            context: context
        )

        // Get top category using TopSpendingCategoriesCalculator
        let topCategories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: transactions,
            interval: interval,
            currencyCode: currencyCode,
            context: context
        )

        return ReportData(
            balance: balance,
            totalExpense: trendResult.totalExpense,
            totalIncome: trendResult.totalIncome,
            topCategory: topCategories.first?.category.name
        )
    }

    private func getIntervalForReportType(_ config: ReportConfig) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()

        switch config.dayPreference {
        case .sunday, .monday:
            // Weekly: last 7 days
            let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: weekStart, end: now)
        case .firstDay, .lastDay:
            // Monthly: current month
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            ) ?? now
            return DateInterval(start: monthStart, end: now)
        }
    }

    private func formatReportBody(_ config: ReportConfig, data: ReportData) -> String {
        let currencyCode = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"
        let symbol = CurrencyUtils.symbol(for: currencyCode)

        switch config.dataType {
        case .balance:
            return L10n.Notifications.reportBalance("\(symbol)\(data.balance.formatted())")
        case .expenses:
            return L10n.Notifications.reportExpenses("\(symbol)\(data.totalExpense.formatted())")
        case .income:
            return L10n.Notifications.reportIncome("\(symbol)\(data.totalIncome.formatted())")
        case .topCategory:
            return L10n.Notifications.reportTopCategory(data.topCategory ?? "—")
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
            predicate: #Predicate { !$0.isArchived }
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
