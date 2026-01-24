//
//  SmartAxisHelper.swift
//  Yala
//
//  Shared smart axis logic for bar charts (CashFlowWidget, NatureTrendWidget)
//  Replicates the dynamic axis spacing from TrendChartView
//

import Foundation
import SwiftUI

/// Helper for calculating smart axis dates and labels for charts
enum SmartAxisHelper {

    /// Maximum number of axis labels to show (to avoid crowding)
    static let maxAxisLabels = 5

    /// Calculate smart axis dates evenly distributed across the data range
    /// - Parameters:
    ///   - startDate: First date in data
    ///   - endDate: Last date in data
    ///   - maxLabels: Maximum labels to show (default 5)
    /// - Returns: Array of dates to use as axis marks
    static func calculateSmartAxisDates(
        from startDate: Date,
        to endDate: Date,
        maxLabels: Int = maxAxisLabels
    ) -> [Date] {
        // If same date, return just that date
        if startDate == endDate {
            return [startDate]
        }

        let calendar = Calendar.current
        let span = endDate.timeIntervalSince(startDate)

        // Always include first and last dates
        var dates: [Date] = [startDate]

        // Calculate how many middle labels we can fit
        let middleLabelsCount = maxLabels - 2  // minus first and last

        if middleLabelsCount > 0 && span > 86400 {  // More than 1 day
            // Calculate step based on data range
            let step = span / Double(maxLabels - 1)

            for i in 1..<(maxLabels - 1) {
                let middleDate = startDate.addingTimeInterval(step * Double(i))

                // Normalize to start of day for cleaner alignment
                let normalizedDate = calendar.startOfDay(for: middleDate)

                // Avoid duplicate if too close to first or last
                if normalizedDate > startDate && normalizedDate < endDate {
                    dates.append(normalizedDate)
                }
            }
        }

        dates.append(endDate)

        // Sort and remove duplicates
        return Array(Set(dates)).sorted()
    }

    /// Format axis label based on data span
    /// - Parameters:
    ///   - date: Date to format
    ///   - startDate: First date in data (for span calculation)
    ///   - endDate: Last date in data (for span calculation)
    /// - Returns: Formatted string for axis label
    static func formatAxisLabel(
        for date: Date,
        startDate: Date,
        endDate: Date
    ) -> String {
        let calendar = Calendar.current
        let span = endDate.timeIntervalSince(startDate)
        let days = span / 86400

        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        // Check if data spans multiple years
        let firstYear = calendar.component(.year, from: startDate)
        let lastYear = calendar.component(.year, from: endDate)
        let multipleYears = firstYear != lastYear

        if days > 60 {
            // Long period (> 2 months): Show month abbreviation
            if multipleYears {
                formatter.dateFormat = "MMM yy"  // "ene 25"
            } else {
                formatter.dateFormat = "MMM"  // "ene"
            }
        } else if days > 14 {
            // Medium period (2 weeks - 2 months): Show day + month
            formatter.dateFormat = "d MMM"  // "15 dic"
        } else {
            // Short period (< 2 weeks): Just day number
            formatter.dateFormat = "d"  // "15"
        }

        // Remove trailing periods from abbreviations (e.g., "ene." -> "ene")
        return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
    }
}
