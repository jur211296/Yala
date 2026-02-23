//
//  ScheduledPaymentDateCalculator.swift
//  Yala
//
//  Shared date calculation for scheduled payments.
//  Fixes: BUG-25 (endDate), BUG-26 (weekly interval), BUG-27 (monthly interval),
//  BUG-28 (daily safety), BUG-29 (dedup VM/Widget).
//

import Foundation

enum ScheduledPaymentDateCalculator {

    struct PaymentParams {
        let isRecurring: Bool
        let recurrenceType: String
        let recurrenceInterval: Int
        let nextDueDate: Date
        let createdAt: Date
        let endDate: Date?
        let dayOfMonth: Int?
        let selectedWeekdays: String?
        let yearlyMonth: Int?
        let yearlyDay: Int?
    }

    // MARK: - Public API

    static func paymentDatesInMonth(
        params: PaymentParams, month: Date, calendar: Calendar = .current
    ) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var dates: [Date] = []

        // One-time payments
        if !params.isRecurring {
            let paymentDate = calendar.startOfDay(for: params.nextDueDate)
            if monthInterval.contains(paymentDate) {
                dates.append(paymentDate)
            }
            return applyPostFilters(dates: dates, params: params, calendar: calendar)
        }

        // Recurring payments
        guard let recurrenceType = RecurrenceType(rawValue: params.recurrenceType) else { return [] }
        let interval = max(1, params.recurrenceInterval)

        switch recurrenceType {
        case .daily:
            dates = dailyDates(params: params, interval: interval, monthInterval: monthInterval, calendar: calendar)

        case .weekly:
            dates = weeklyDates(params: params, interval: interval, monthInterval: monthInterval, calendar: calendar)

        case .monthly:
            dates = monthlyDates(params: params, interval: interval, month: month, monthInterval: monthInterval, calendar: calendar)

        case .yearly:
            dates = yearlyDates(params: params, interval: interval, month: month, monthInterval: monthInterval, calendar: calendar)
        }

        return applyPostFilters(dates: dates, params: params, calendar: calendar)
    }

    static func parseWeekdays(_ raw: String?) -> Set<Int> {
        guard let string = raw, !string.isEmpty else { return [] }
        return Set(string.split(separator: ",").compactMap { Int($0) })
    }

    // MARK: - Daily (BUG-28 fix: safety counter + guard let with break)

    private static func dailyDates(
        params: PaymentParams, interval: Int, monthInterval: DateInterval, calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var date = calendar.startOfDay(for: params.nextDueDate)

        // Go back to find first occurrence at or before month start
        var safety = 0
        while date > monthInterval.start && safety < 400 {
            guard let prev = calendar.date(byAdding: .day, value: -interval, to: date) else { break }
            date = prev
            safety += 1
        }

        // Iterate forward through the month
        while date < monthInterval.end {
            if date >= monthInterval.start {
                dates.append(date)
            }
            guard let next = calendar.date(byAdding: .day, value: interval, to: date) else { break }
            date = next
        }

        return dates
    }

    // MARK: - Weekly (BUG-26 fix: respect recurrenceInterval)

    private static func weeklyDates(
        params: PaymentParams, interval: Int, monthInterval: DateInterval, calendar: Calendar
    ) -> [Date] {
        let weekdays = parseWeekdays(params.selectedWeekdays)
        guard !weekdays.isEmpty else { return [] }

        let anchor = calendar.startOfDay(for: params.nextDueDate)
        guard let anchorWeekStart = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start else { return [] }

        var dates: [Date] = []
        var date = monthInterval.start

        while date < monthInterval.end {
            let weekday = calendar.component(.weekday, from: date)
            if weekdays.contains(weekday) {
                // BUG-26: Check week offset respects interval
                if interval == 1 {
                    dates.append(date)
                } else if let dateWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start {
                    let daysBetween = calendar.dateComponents([.day], from: anchorWeekStart, to: dateWeekStart).day ?? 0
                    let weekOffset = daysBetween / 7
                    if weekOffset % interval == 0 {
                        dates.append(date)
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }

        return dates
    }

    // MARK: - Monthly (BUG-27 fix: respect recurrenceInterval)

    private static func monthlyDates(
        params: PaymentParams, interval: Int, month: Date, monthInterval: DateInterval, calendar: Calendar
    ) -> [Date] {
        let dayOfMonth = params.dayOfMonth ?? calendar.component(.day, from: params.nextDueDate)
        let monthComponents = calendar.dateComponents([.year, .month], from: month)

        guard let year = monthComponents.year, let mon = monthComponents.month else { return [] }

        // BUG-27: Check month offset respects interval
        let anchorComponents = calendar.dateComponents([.year, .month], from: params.nextDueDate)
        guard let anchorYear = anchorComponents.year, let anchorMonth = anchorComponents.month else { return [] }

        let monthsBetween = (year - anchorYear) * 12 + (mon - anchorMonth)
        guard monthsBetween % interval == 0 else { return [] }

        let maxDay = calendar.range(of: .day, in: .month, for: month)?.count ?? 28
        guard var paymentDate = calendar.date(from: DateComponents(
            year: year,
            month: mon,
            day: min(dayOfMonth, maxDay)
        )) else { return [] }

        paymentDate = calendar.startOfDay(for: paymentDate)
        guard monthInterval.contains(paymentDate) else { return [] }

        return [paymentDate]
    }

    // MARK: - Yearly

    private static func yearlyDates(
        params: PaymentParams, interval: Int, month: Date, monthInterval: DateInterval, calendar: Calendar
    ) -> [Date] {
        let targetMonth = params.yearlyMonth ?? calendar.component(.month, from: params.nextDueDate)
        let targetDay = params.yearlyDay ?? calendar.component(.day, from: params.nextDueDate)
        let monthComponents = calendar.dateComponents([.year, .month], from: month)

        guard monthComponents.month == targetMonth, let year = monthComponents.year else { return [] }

        // Check year offset respects interval
        let anchorYear = calendar.component(.year, from: params.nextDueDate)
        let yearsBetween = year - anchorYear
        guard yearsBetween % interval == 0 else { return [] }

        guard let paymentDate = calendar.date(from: DateComponents(
            year: year,
            month: targetMonth,
            day: targetDay
        )) else { return [] }

        let startOfPayment = calendar.startOfDay(for: paymentDate)
        guard monthInterval.contains(startOfPayment) else { return [] }

        return [startOfPayment]
    }

    // MARK: - Post Filters (createdAt + endDate)

    private static func applyPostFilters(
        dates: [Date], params: PaymentParams, calendar: Calendar
    ) -> [Date] {
        let createdDay = calendar.startOfDay(for: params.createdAt)
        var filtered = dates.filter { $0 >= createdDay }

        // BUG-25: endDate is inclusive (payment on the last day counts)
        if let endDay = params.endDate.map({ calendar.startOfDay(for: $0) }) {
            filtered = filtered.filter { $0 <= endDay }
        }

        return filtered
    }
}

// MARK: - SwiftData Bridge

import SwiftData

extension ScheduledPayment {
    var dateCalculatorParams: ScheduledPaymentDateCalculator.PaymentParams {
        ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            nextDueDate: nextDueDate,
            createdAt: createdAt,
            endDate: endDate,
            dayOfMonth: dayOfMonth,
            selectedWeekdays: selectedWeekdays,
            yearlyMonth: yearlyMonth,
            yearlyDay: yearlyDay
        )
    }
}
