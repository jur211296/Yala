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

    /// Single entry point: checks all scheduled payment notifications (overdue, due today, upcoming).
    /// Fetches payments, paid status, and notification config once to avoid redundant queries.
    func checkAllPaymentNotifications() async {
        guard let context = modelContext else { return }
        guard await NotificationService.shared.isAuthorized() else { return }
        guard isWithinNotificationWindow(context: context) else { return }

        let payments = fetchActivePayments(context: context)
        guard !payments.isEmpty else { return }

        let today = Date.now
        let paidStatus = ScheduledPaymentPaidStatusHelper.loadPaidStatus(for: payments, month: today, context: context)

        await notifyOverduePayments(payments: payments, paidStatus: paidStatus, today: today)
        await notifyDuePayments(payments: payments, paidStatus: paidStatus, today: today)
        await notifyUpcomingPayments(payments: payments, paidStatus: paidStatus, today: today)

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error saving context: \(error)")
            #endif
        }
    }

    // MARK: - Notification Checks

    /// Notify payments that are due TODAY (using DateCalculator for all occurrences)
    private func notifyDuePayments(payments: [ScheduledPayment], paidStatus: [String: Int], today: Date) async {
        for payment in payments {
            guard payment.notifyOnDueDate else { continue }

            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today
            )

            for date in dates {
                guard Calendar.current.isDateInToday(date) else { continue }
                guard !payment.isDateSkipped(date) else { continue }
                guard !isPaid(payment, paidStatus: paidStatus) else { continue }

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
    }

    /// Notify payments that are due in X days (based on notifyDaysBefore)
    private func notifyUpcomingPayments(payments: [ScheduledPayment], paidStatus: [String: Int], today: Date) async {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: today)
        let sevenDaysFromNow = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        for payment in payments {
            guard payment.notifyDaysBefore > 0 else { continue }

            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: today
            )

            for date in dates where date <= sevenDaysFromNow {
                let startOfDueDate = calendar.startOfDay(for: date)
                let daysUntilDue = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0
                guard daysUntilDue == payment.notifyDaysBefore else { continue }
                guard !payment.isDateSkipped(date) else { continue }
                guard !isPaid(payment, paidStatus: paidStatus) else { continue }

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

    /// Notify OVERDUE payments (user didn't open app for days)
    private func notifyOverduePayments(payments: [ScheduledPayment], paidStatus: [String: Int], today: Date) async {
        let calendar = Calendar.current
        var notificationCount = 0

        for payment in payments {
            guard notificationCount < maxOverdueNotifications else { break }
            guard payment.notifyOnDueDate else { continue }

            guard calendar.compare(payment.nextDueDate, to: today, toGranularity: .day) == .orderedAscending else {
                continue
            }

            guard !payment.isDateSkipped(payment.nextDueDate) else { continue }
            guard !isPaid(payment, paidStatus: paidStatus) else { continue }

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

    private func isPaid(_ payment: ScheduledPayment, paidStatus: [String: Int]) -> Bool {
        (paidStatus[payment.id.uuidString] ?? 0) > 0
    }

    // MARK: - Notification Window

    /// Check if current time is past the user's configured notification hour for scheduled payments
    private func isWithinNotificationWindow(context: ModelContext) -> Bool {
        let calendar = Calendar.current
        let now = Date.now

        let typeRaw = "scheduledPayments"
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.typeRaw == typeRaw && $0.isActive }
        )

        let item: NotificationItem?
        do {
            item = try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching notification config: \(error)")
            #endif
            return true
        }

        guard let config = item else {
            return true
        }

        guard let scheduledToday = calendar.date(
            bySettingHour: config.hour,
            minute: config.minute,
            second: 0,
            of: now
        ) else { return true }

        return now >= scheduledToday
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

    // MARK: - Credit Card Payment Notifications

    /// Check accounts with credit card payment reminders and notify if today is payment day
    func checkAndNotifyCreditCardPayments() async {
        guard let context = modelContext else { return }
        guard await NotificationService.shared.isAuthorized() else { return }

        let accounts = fetchCreditCardAccounts(context: context)
        let today = Date.now
        let dayOfMonth = Calendar.current.component(.day, from: today)

        for account in accounts {
            guard account.creditCardPaymentDay == dayOfMonth else { continue }

            let trackerKey = "creditCardNotif_\(account.name)_\(ScheduledPaymentNotificationTracker.dateKeyString(from: today))"
            guard !UserDefaults.standard.bool(forKey: trackerKey) else { continue }

            let message = L10n.Account.CreditCard.paymentNotification(account.name)
            await NotificationService.shared.sendNotification(
                title: account.name,
                body: message,
                deepLink: "accounts"
            )

            UserDefaults.standard.set(true, forKey: trackerKey)
        }
    }

    private func fetchCreditCardAccounts(context: ModelContext) -> [Account] {
        let creditCardType = AccountType.creditCard.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                $0.type == creditCardType && $0.creditCardPaymentReminder == true
            }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentNotificationService: Error fetching credit card accounts: \(error)")
            #endif
            return []
        }
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
