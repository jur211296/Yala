//
//  PreviousPeriodHelper.swift
//  Neto
//
//  Helper for calculating previous period intervals and formatting comparison text.
//

import Foundation

// MARK: - Comparison Mode

/// Mode for comparing current period with a previous one
enum ComparisonMode: String, CaseIterable, Identifiable {
    case month  // Compare with immediate previous period (month ago, week ago, etc.)
    case year   // Compare with same period from previous year

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .month: return L10n.Comparison.month
        case .year: return L10n.Comparison.year
        }
    }

    var shortName: String {
        switch self {
        case .month: return L10n.Comparison.monthShort
        case .year: return L10n.Comparison.yearShort
        }
    }
}

// MARK: - Previous Period Helper

enum PreviousPeriodHelper {

    /// Determines if the comparison mode selector should be visible for a given period
    /// - Parameter period: The current detail period
    /// - Returns: True if selector should be shown (both M and A are valid options)
    static func isSelectorVisible(for period: DetailPeriod) -> Bool {
        switch period {
        case .thisYear, .lastYear, .allTime:
            return false  // Only year comparison makes sense
        default:
            return true   // Both month and year comparison are valid
        }
    }

    /// Gets the default comparison mode for a period
    /// - Parameter period: The current detail period
    /// - Returns: The default comparison mode
    static func defaultMode(for period: DetailPeriod) -> ComparisonMode {
        switch period {
        case .thisYear, .lastYear, .allTime:
            return .year
        default:
            return .month
        }
    }

    /// Calculates the previous period interval based on comparison mode
    /// - Parameters:
    ///   - period: The current detail period
    ///   - mode: The comparison mode (month or year)
    ///   - customRange: Optional custom date range for .custom period
    /// - Returns: The date interval for the previous period
    static func previousInterval(
        for period: DetailPeriod,
        mode: ComparisonMode,
        customRange: DateInterval? = nil
    ) -> DateInterval {
        let calendar = Calendar.current
        let currentInterval = period.dateInterval(customRange: customRange)

        switch mode {
        case .month:
            return previousPeriodInterval(currentInterval: currentInterval, period: period, calendar: calendar)
        case .year:
            return sameIntervalPreviousYear(currentInterval: currentInterval, calendar: calendar)
        }
    }

    /// Calculates the immediate previous period (M mode)
    private static func previousPeriodInterval(
        currentInterval: DateInterval,
        period: DetailPeriod,
        calendar: Calendar
    ) -> DateInterval {
        switch period {
        case .thisWeek, .last7Days:
            // Go back 7 days
            let duration = currentInterval.duration
            let previousStart = currentInterval.start.addingTimeInterval(-duration)
            let previousEnd = calendar.date(byAdding: .second, value: -1, to: currentInterval.start) ?? currentInterval.start
            return DateInterval(start: previousStart, end: previousEnd)

        case .thisMonth:
            // Previous month
            let startOfPreviousMonth = calendar.date(byAdding: .month, value: -1, to: currentInterval.start)!
            return DateInterval(start: startOfPreviousMonth, end: currentInterval.start)

        case .lastMonth:
            // Two months ago
            let startOfTwoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: currentInterval.end)!
            let endOfTwoMonthsAgo = calendar.date(byAdding: .month, value: -1, to: currentInterval.end)!
            return DateInterval(start: startOfTwoMonthsAgo, end: endOfTwoMonthsAgo)

        case .last30Days:
            // Previous 30 days
            let duration = currentInterval.duration
            let previousStart = currentInterval.start.addingTimeInterval(-duration)
            let previousEnd = calendar.date(byAdding: .second, value: -1, to: currentInterval.start) ?? currentInterval.start
            return DateInterval(start: previousStart, end: previousEnd)

        case .thisYear, .lastYear:
            // For year periods, M mode doesn't make sense - fall back to year comparison
            return sameIntervalPreviousYear(currentInterval: currentInterval, calendar: calendar)

        case .allTime:
            // No previous period for all time
            return currentInterval

        case .custom:
            // Move back by the same duration
            let duration = currentInterval.duration
            let previousStart = currentInterval.start.addingTimeInterval(-duration)
            let previousEnd = calendar.date(byAdding: .second, value: -1, to: currentInterval.start) ?? currentInterval.start
            return DateInterval(start: previousStart, end: previousEnd)
        }
    }

    /// Calculates the same interval but from the previous year (A mode)
    private static func sameIntervalPreviousYear(
        currentInterval: DateInterval,
        calendar: Calendar
    ) -> DateInterval {
        let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentInterval.start)!
        let previousYearEnd = calendar.date(byAdding: .year, value: -1, to: currentInterval.end)!
        return DateInterval(start: previousYearStart, end: previousYearEnd)
    }

    /// Formats the comparison period text for display (e.g., "vs Dic 25", "vs 2025")
    /// - Parameters:
    ///   - previousInterval: The previous period interval
    ///   - period: The current detail period
    ///   - mode: The comparison mode
    /// - Returns: Formatted string like "vs Dic 25"
    static func formatComparisonText(
        previousInterval: DateInterval,
        period: DetailPeriod,
        mode: ComparisonMode
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        switch period {
        case .thisYear, .lastYear:
            // "vs 2025"
            formatter.dateFormat = "yyyy"
            return "vs \(formatter.string(from: previousInterval.start))"

        case .thisMonth, .lastMonth:
            if mode == .year {
                // "vs Ene 25"
                formatter.dateFormat = "MMM yy"
                return "vs \(formatter.string(from: previousInterval.start).capitalized.replacingOccurrences(of: ".", with: ""))"
            } else {
                // "vs Dic 25"
                formatter.dateFormat = "MMM yy"
                return "vs \(formatter.string(from: previousInterval.start).capitalized.replacingOccurrences(of: ".", with: ""))"
            }

        case .thisWeek, .last7Days:
            if mode == .year {
                // "vs 5 - 11 ene 25"
                formatter.dateFormat = "d"
                let startDay = formatter.string(from: previousInterval.start)
                formatter.dateFormat = "d MMM yy"
                let endDate = formatter.string(from: previousInterval.end).replacingOccurrences(of: ".", with: "")
                return "vs \(startDay) - \(endDate)"
            } else {
                // "vs 29 dic - 4 ene"
                formatter.dateFormat = "d MMM"
                let startDate = formatter.string(from: previousInterval.start).replacingOccurrences(of: ".", with: "")
                let endDate = formatter.string(from: previousInterval.end).replacingOccurrences(of: ".", with: "")
                return "vs \(startDate) - \(endDate)"
            }

        case .last30Days:
            if mode == .year {
                // "vs 17 dic 24 - 15 ene 25"
                formatter.dateFormat = "d MMM yy"
                let startDate = formatter.string(from: previousInterval.start).replacingOccurrences(of: ".", with: "")
                let endDate = formatter.string(from: previousInterval.end).replacingOccurrences(of: ".", with: "")
                return "vs \(startDate) - \(endDate)"
            } else {
                // "vs 17 dic - 15 ene"
                formatter.dateFormat = "d MMM"
                let startDate = formatter.string(from: previousInterval.start).replacingOccurrences(of: ".", with: "")
                let endDate = formatter.string(from: previousInterval.end).replacingOccurrences(of: ".", with: "")
                return "vs \(startDate) - \(endDate)"
            }

        case .custom:
            // Always show full range with year
            formatter.dateFormat = "d MMM yy"
            let startDate = formatter.string(from: previousInterval.start).replacingOccurrences(of: ".", with: "")
            let endDate = formatter.string(from: previousInterval.end).replacingOccurrences(of: ".", with: "")
            return "vs \(startDate) - \(endDate)"

        case .allTime:
            return ""
        }
    }

    /// Calculates the percentage variation between current and previous amounts
    /// - Parameters:
    ///   - currentAmount: The current period amount
    ///   - previousAmount: The previous period amount
    /// - Returns: The percentage variation (positive or negative), or nil if previous is zero
    /// - Note: Uses abs(previousAmount) to correctly handle negative balances
    static func calculateVariation(currentAmount: Double, previousAmount: Double) -> Double? {
        guard previousAmount != 0 else { return nil }
        return ((currentAmount - previousAmount) / abs(previousAmount)) * 100
    }

    /// Formats the variation percentage for display
    /// - Parameter variation: The variation percentage
    /// - Returns: Formatted string with sign and 1 decimal max (e.g., "+12.5%", "-3.2%")
    static func formatVariation(_ variation: Double?) -> String {
        guard let variation = variation else { return "N/A" }
        return formatVariationValue(variation)
    }

    /// Formats a non-nil variation percentage for display
    /// - Parameter variation: The variation percentage (non-optional)
    /// - Returns: Formatted string with sign and 1 decimal max (e.g., "+12.5%", "-3.2%")
    static func formatVariationValue(_ variation: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0

        let sign = variation >= 0 ? "+" : ""
        let formatted = formatter.string(from: NSNumber(value: variation)) ?? "0"
        return "\(sign)\(formatted)%"
    }
}
