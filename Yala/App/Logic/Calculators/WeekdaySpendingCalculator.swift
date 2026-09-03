//
//  WeekdaySpendingCalculator.swift
//  Yala
//
//  Groups expenses by weekday (1=Sunday through 7=Saturday) and returns totals.
//

import Foundation

struct WeekdaySpending: Identifiable, Equatable {
    let weekday: Int        // 1=Sunday ... 7=Saturday (Calendar weekday)
    let total: Double
    let count: Int          // Number of transactions
    let dayOccurrences: Int // How many times this weekday appears in the period

    var id: Int { weekday }

    /// Average spending per calendar day (e.g., per Monday), not per transaction
    var average: Double { dayOccurrences > 0 ? total / Double(dayOccurrences) : 0 }

    /// Localized short weekday name (Mon, Tue, etc.) — used by VoiceOver.
    var shortName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "" }
        return symbols[weekday - 1]
    }

    /// Two-letter axis label capitalised (Lu, Ma, Mi, Ju, Vi, Sá, Do) — disambiguates
    /// martes/miércoles that collapse to "M" with the system's one-letter symbols.
    var axisLabel: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "" }
        return String(symbols[weekday - 1].prefix(2)).capitalized
    }

    /// Full weekday name capitalised (Lunes, Martes, ...) — used by the `.small`
    /// "priciest day" KPI.
    var weekdayLongName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1, weekday <= 7 else { return "" }
        return symbols[weekday - 1].capitalized
    }
}

struct WeekdaySpendingCalculator {

    /// Groups expense transactions by weekday and returns totals in preferred currency.
    /// Average is computed per calendar day occurrence (e.g., per Monday in the period).
    static func calculate(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [WeekdaySpending] {
        let calendar = Calendar.current
        var totals: [Int: Double] = [:]
        var counts: [Int: Int] = [:]

        for tx in transactions {
            guard !adjustment.isSuppressed(tx) else { continue }
            guard let category = tx.category, !category.isIncome else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }

            let weekday = calendar.component(.weekday, from: tx.date)

            // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto).
            let amount: Double
            if tx.preferredCurrencyCode == currencyCode {
                amount = abs(adjustment.amountInPreferredCurrency(tx))
            } else {
                let converted = converter.convert(
                    Decimal(abs(adjustment.amount(tx))),
                    from: tx.currencyCode,
                    to: currencyCode,
                    on: tx.date
                )
                amount = NSDecimalNumber(decimal: converted).doubleValue
            }

            totals[weekday, default: 0] += amount
            counts[weekday, default: 0] += 1
        }

        // Count how many times each weekday occurs in the interval
        let occurrences = Self.weekdayOccurrences(in: interval)

        return (1...7).map { day in
            WeekdaySpending(
                weekday: day,
                total: totals[day, default: 0],
                count: counts[day, default: 0],
                dayOccurrences: occurrences[day, default: 0]
            )
        }
    }

    /// Counts how many times each weekday (1=Sun..7=Sat) appears in a date interval.
    static func weekdayOccurrences(in interval: DateInterval) -> [Int: Int] {
        let calendar = Calendar.current
        var occurrences: [Int: Int] = [:]
        // Contado con el helper: sobre un período CERRADO (`.lastMonth`, `.lastYear`, un rango
        // personalizado) el intervalo llega con `-1 s` y `dateComponents` a pelo devolvía un día menos.
        // Aquí no es un promedio, es peor: `totalDays` decide `fullWeeks` y `remainder`, así que el
        // ÚLTIMO día del período no sumaba su día de la semana. En enero (31 días contados como 30) el
        // sábado recibía 4 ocurrencias en vez de 5 y su media salía inflada ~25 %, con lo que el KPI
        // «día más caro» podía señalar un día equivocado.
        let totalDays = DateIntervalDayCount.days(in: interval, calendar: calendar)
        let fullWeeks = totalDays / 7
        let remainder = totalDays % 7

        // Every weekday appears at least fullWeeks times
        for day in 1...7 {
            occurrences[day] = fullWeeks
        }

        // Add partial week
        var current = interval.start
        for _ in 0..<remainder {
            let weekday = calendar.component(.weekday, from: current)
            occurrences[weekday, default: 0] += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return occurrences
    }
}
