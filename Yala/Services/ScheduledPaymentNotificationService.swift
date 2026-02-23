//
//  ScheduledPaymentNotificationService.swift
//  Yala
//
//  Service for sending personalized notifications for scheduled payments.
//  Handles: due today, upcoming (X days before), and overdue payments.
//

import Foundation
import SwiftData
import UserNotifications

/// Service for checking scheduled payments and sending personalized notifications
@MainActor
final class ScheduledPaymentNotificationService {
    static let shared = ScheduledPaymentNotificationService()

    private var modelContext: ModelContext?
    private let tracker = ScheduledPaymentNotificationTracker.shared

    /// Maximum overdue notifications per session to avoid spam
    private let maxOverdueNotifications = 5

    private init() {}

    func setContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Public Methods

    /// Check and notify payments that are due TODAY (using DateCalculator for all occurrences)
    func checkAndNotifyDuePayments() async {
        guard let context = modelContext else { return }
        guard await NotificationService.shared.isAuthorized() else { return }

        let payments = fetchActivePayments(context: context)
        let today = Date()

        for payment in payments {
            guard payment.notifyOnDueDate else { continue }

            // Use DateCalculator to get all occurrences this month (not just nextDueDate)
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today
            )

            for date in dates {
                guard Calendar.current.isDateInToday(date) else { continue }
                guard !payment.isDateSkipped(date) else { continue }

                // Avoid duplicate notification
                guard !tracker.hasNotifiedForDate(
                    paymentID: payment.id,
                    date: today,
                    type: .dueDate
                ) else { continue }

                await sendPaymentNotification(payment: payment, type: .dueToday)
                tracker.markNotified(paymentID: payment.id, date: today, type: .dueDate)
                payment.lastNotifiedDate = today
            }
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error saving context: \(error)")
            #endif
        }
    }

    /// Check and notify payments that are due in X days (based on notifyDaysBefore)
    /// Uses DateCalculator for all occurrences within a 7-day window
    func checkAndNotifyUpcomingPayments() async {
        guard let context = modelContext else { return }
        guard await NotificationService.shared.isAuthorized() else { return }

        let payments = fetchActivePayments(context: context)
        let today = Date()
        let calendar = Calendar.current

        for payment in payments {
            guard payment.notifyDaysBefore > 0 else { continue }

            // Use DateCalculator for all occurrences this month
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today
            )

            // Only consider dates within 7-day window to avoid spam
            let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today) ?? today
            for date in dates where date <= sevenDaysFromNow {
                let daysUntilDue = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                guard daysUntilDue == payment.notifyDaysBefore else { continue }
                guard !payment.isDateSkipped(date) else { continue }

                // Avoid duplicate notification
                guard !tracker.hasNotifiedForDate(
                    paymentID: payment.id,
                    date: today,
                    type: .daysBefore
                ) else { continue }

                await sendPaymentNotification(payment: payment, type: .dueSoon(days: daysUntilDue))
                tracker.markNotified(paymentID: payment.id, date: today, type: .daysBefore)
            }
        }
    }

    /// Check and notify OVERDUE payments (user didn't open app for days)
    func checkAndNotifyOverduePayments() async {
        guard let context = modelContext else { return }
        guard await NotificationService.shared.isAuthorized() else { return }

        let payments = fetchActivePayments(context: context)
        let today = Date()
        let calendar = Calendar.current
        var notificationCount = 0

        for payment in payments {
            guard notificationCount < maxOverdueNotifications else { break }
            guard payment.notifyOnDueDate else { continue }

            // Overdue = nextDueDate < today
            guard calendar.compare(payment.nextDueDate, to: today, toGranularity: .day) == .orderedAscending else {
                continue
            }

            // Skip if this date has been skipped by user
            guard !payment.isDateSkipped(payment.nextDueDate) else { continue }

            // Avoid duplicate overdue notification
            guard !tracker.hasNotifiedForDate(
                paymentID: payment.id,
                date: payment.nextDueDate,
                type: .overdue
            ) else { continue }

            await sendPaymentNotification(payment: payment, type: .overdue)
            tracker.markNotified(paymentID: payment.id, date: payment.nextDueDate, type: .overdue)
            notificationCount += 1
        }
    }

    // MARK: - Private

    private enum PaymentNotificationType {
        case dueToday
        case dueSoon(days: Int)
        case overdue
    }

    private func sendPaymentNotification(payment: ScheduledPayment, type: PaymentNotificationType) async {
        let currencySymbol = CurrencyUtils.symbol(for: payment.currencyCode)
        let formattedAmount = "\(currencySymbol)\(payment.amount.formatted(.number.precision(.fractionLength(0...2))))"
        let isIncome = payment.transactionType == "income"

        let message: String
        switch type {
        case .dueToday:
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.dueTodayIncome(formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.dueToday(payment.name, formattedAmount)
        case .dueSoon(let days):
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.dueSoonIncome(days, formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.dueSoon(days, payment.name, formattedAmount)
        case .overdue:
            message = isIncome
                ? L10n.Notifications.ScheduledPayment.overdueIncome(formattedAmount, payment.name)
                : L10n.Notifications.ScheduledPayment.overdue(payment.name, formattedAmount)
        }

        await NotificationService.shared.sendNotification(
            title: payment.name,
            body: message,
            deepLink: "scheduledPayments"
        )
    }

    private func fetchActivePayments(context: ModelContext) -> [ScheduledPayment] {
        let descriptor = FetchDescriptor<ScheduledPayment>(
            predicate: #Predicate { $0.isActive }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching payments: \(error)")
            #endif
            return []
        }
    }
}
