//
//  DevSeedScheduledPayments.swift
//  Yala
//
//  Creates 8 scheduled payments for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedScheduledPayments {

    struct Result {
        let payments: [ScheduledPayment]
    }

    @MainActor
    static func create(
        account: Account,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) -> Result {
        let calendar = Calendar.current
        let today = Date.now

        func nextOccurrence(dayOfMonth day: Int) -> Date {
            // Always return THIS month's date if it hasn't passed,
            // otherwise next month — ensures current month has active payments
            var comps = calendar.dateComponents([.year, .month], from: today)
            comps.day = min(day, 28) // Safe for all months
            if let date = calendar.date(from: comps), date >= calendar.startOfDay(for: today) {
                return date
            }
            // Already passed this month → next month
            let currentMonth = comps.month ?? 1
            if currentMonth >= 12 {
                comps.month = 1
                comps.year = (comps.year ?? 2026) + 1
            } else {
                comps.month = currentMonth + 1
            }
            return calendar.date(from: comps) ?? today
        }

        // Days spread across month so most are still upcoming from any seed date
        let definitions: [(name: String, amount: Double, subKey: String, day: Int, category: String)] = [
            // Subscriptions
            ("Netflix", 45, L10n.Subcategory.streaming, 20, "subscription"),
            ("Spotify", 18, L10n.Subcategory.streaming, 18, "subscription"),
            (L10n.DevSeed.spGym, 150, L10n.Subcategory.fitness, 3, "subscription"),
            ("iCloud+", 10, L10n.Subcategory.utilitySubs, 22, "subscription"),
            // Recurring
            (L10n.DevSeed.spRent, 2200, L10n.Subcategory.rent, 5, "recurring"),
            (L10n.DevSeed.spPhone, 60, L10n.Subcategory.phone, 15, "recurring"),
            (L10n.DevSeed.spInternet, 90, L10n.Subcategory.utilities, 25, "recurring"),
            (L10n.DevSeed.spInsurance, 180, L10n.Subcategory.insurance, 28, "recurring"),
        ]

        var payments: [ScheduledPayment] = []
        for def in definitions {
            let sub = subcategoryLookup[def.subKey]
            let payment = ScheduledPayment(
                name: def.name,
                amount: def.amount,
                currencyCode: "PEN",
                transactionType: TransactionType.expense.rawValue,
                account: account,
                subcategory: sub,
                isRecurring: true,
                recurrenceType: "monthly",
                recurrenceInterval: 1,
                nextDueDate: nextOccurrence(dayOfMonth: def.day),
                dayOfMonth: def.day,
                paymentCategory: def.category,
                notifyOnDueDate: true,
                notifyDaysBefore: 3
            )
            context.insert(payment)
            payments.append(payment)
        }

        return Result(payments: payments)
    }
}
#endif
