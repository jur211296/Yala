//
//  SmartAxisHelper.swift
//  YalaWidgets
//
//  Shared smart axis logic for bar charts (CashFlowWidget, NeedTrendWidget)
//  Replicates the dynamic axis spacing from TrendChartView
//
//  Note: This is a copy adapted for YalaWidgets target (can't import from Yala)
//

import Foundation
import SwiftUI

/// Helper for calculating smart axis dates and labels for charts
enum SmartAxisHelper {

    /// Maximum number of axis labels to show (to avoid crowding)
    static let maxAxisLabels = 5

    /// Minimum visible bars for a reasonable chart appearance
    /// When data has fewer points, we extend the domain to simulate this many slots
    static let minVisibleSlots = 5

    /// Calculate smart axis dates aligned with actual data grouping
    /// Use this for BAR charts where labels must match data points (no duplicates)
    /// - Parameters:
    ///   - actualDataDates: The actual dates from data points (already grouped)
    ///   - grouping: Calendar component used for grouping (.day, .weekOfYear, .month)
    ///   - maxLabels: Maximum labels to show (default 5)
    /// - Returns: Array of dates to use as axis marks (subset of actual data dates)
    static func calculateSmartAxisDates(
        forDataDates actualDataDates: [Date],
        grouping: Calendar.Component,
        maxLabels: Int = maxAxisLabels
    ) -> [Date] {
        guard !actualDataDates.isEmpty else { return [] }

        // Single point: return just that date
        if actualDataDates.count == 1 {
            return actualDataDates
        }

        // For month/week grouping: use actual data dates (not linear interpolation)
        // This prevents duplicate labels like "ene", "ene", "feb", "mar"
        if grouping == .month || grouping == .weekOfYear {
            let dataCount = actualDataDates.count

            if dataCount <= maxLabels {
                return actualDataDates  // Show all data points as labels
            }

            // More data than labels: select evenly spaced indices
            var indices: Set<Int> = [0, dataCount - 1]  // Always include first and last
            let step = Double(dataCount - 1) / Double(maxLabels - 1)
            for i in 1..<(maxLabels - 1) {
                indices.insert(Int(round(step * Double(i))))
            }
            return indices.sorted().map { actualDataDates[$0] }
        }

        // For day grouping: delegate to linear interpolation (existing behavior)
        guard let first = actualDataDates.first,
              let last = actualDataDates.last else { return [] }
        return calculateSmartAxisDates(from: first, to: last, maxLabels: maxLabels)
    }

    /// Calculate smart axis dates evenly distributed across the data range (LINEAR)
    /// Use this for LINE charts where smooth distribution is preferred
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
    ///   - forceGrouping: Optional grouping to force format (overrides span-based logic)
    /// - Returns: Formatted string for axis label
    static func formatAxisLabel(
        for date: Date,
        startDate: Date,
        endDate: Date,
        forceGrouping: Calendar.Component? = nil
    ) -> String {
        let calendar = Calendar.current
        let span = endDate.timeIntervalSince(startDate)
        let days = span / 86400

        let formatter = DateFormatter()
        formatter.locale = Locale.current  // Widget uses system locale

        // Check if data spans multiple years
        let firstYear = calendar.component(.year, from: startDate)
        let lastYear = calendar.component(.year, from: endDate)
        let multipleYears = firstYear != lastYear

        // If forceGrouping is specified, use that instead of span-based logic
        if let grouping = forceGrouping {
            switch grouping {
            case .month:
                // Always show month format for monthly grouping
                if multipleYears {
                    formatter.dateFormat = "MMM yy"  // "ene 25"
                } else {
                    formatter.dateFormat = "MMM"  // "ene"
                }
                return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
            case .weekOfYear:
                formatter.dateFormat = "d MMM"  // "15 dic"
                return formatter.string(from: date).lowercased().replacingOccurrences(of: ".", with: "")
            default:
                break  // Fall through to span-based logic for day
            }
        }

        // Single data point: show full date
        if startDate == endDate || days == 0 {
            if multipleYears || days > 60 {
                formatter.dateFormat = "d MMM yy"  // "15 ene 25"
            } else {
                formatter.dateFormat = "d MMM"  // "15 ene"
            }
        } else if days > 60 {
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

    // MARK: - Calendar Unit Centering

    /// Center a date within its calendar unit for axis alignment with BarMark(unit:)
    /// BarMark with `unit:` spans the entire calendar unit, so the bar's visual center
    /// is at the midpoint. Axis labels must also be centered to align properly.
    static func centerInCalendarUnit(_ date: Date, unit: Calendar.Component) -> Date {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: unit, for: date) else { return date }
        return interval.start.addingTimeInterval(interval.duration / 2)
    }

    /// Center an array of dates within their calendar units
    static func centerDatesInCalendarUnit(_ dates: [Date], unit: Calendar.Component) -> [Date] {
        dates.map { centerInCalendarUnit($0, unit: unit) }
    }

    // MARK: - Bar Chart Domain Helpers

    /// Calculate extended X domain for bar charts to prevent overly wide bars with few data points
    /// - Parameters:
    ///   - dataPoints: Number of actual data points
    ///   - firstDate: First date in data
    ///   - lastDate: Last date in data
    ///   - grouping: Calendar component used for grouping (.day or .month)
    /// - Returns: Extended domain range that ensures reasonable bar widths
    static func extendedXDomain(
        dataPoints: Int,
        firstDate: Date,
        lastDate: Date,
        grouping: Calendar.Component
    ) -> ClosedRange<Date> {
        let calendar = Calendar.current

        // Determine unit duration based on grouping
        let unitDays: Int = {
            switch grouping {
            case .month: return 30
            case .weekOfYear: return 7
            default: return 1  // day
            }
        }()

        // If we have enough data points, use minimal padding
        if dataPoints >= minVisibleSlots {
            // Standard asymmetric padding (less on left, more on right for Y-axis)
            let startPadding = unitDays / 2
            let endPadding = unitDays
            let paddedStart = calendar.date(byAdding: .day, value: -startPadding, to: firstDate) ?? firstDate
            let paddedEnd = calendar.date(byAdding: .day, value: endPadding, to: lastDate) ?? lastDate
            return paddedStart...paddedEnd
        }

        // Few data points: extend domain to simulate minVisibleSlots slots
        // This makes bars narrower and better looking
        let slotsToAdd = minVisibleSlots - dataPoints

        // Distribute extra slots: more on the right (where Y-axis is)
        let leftSlots = slotsToAdd / 3
        let rightSlots = slotsToAdd - leftSlots

        let paddedStart = calendar.date(byAdding: .day, value: -(leftSlots * unitDays + unitDays / 2), to: firstDate) ?? firstDate
        let paddedEnd = calendar.date(byAdding: .day, value: rightSlots * unitDays + unitDays, to: lastDate) ?? lastDate

        return paddedStart...paddedEnd
    }

    /// Determine the anchor point for axis labels based on position and data count
    /// - Parameters:
    ///   - date: The date being labeled
    ///   - allDates: All axis dates
    ///   - dataPointCount: Number of actual data points (not axis marks)
    /// - Returns: Anchor point for the label
    static func axisLabelAnchor(
        for date: Date,
        in allDates: [Date],
        dataPointCount: Int
    ) -> UnitPoint {
        // With few data points, center all labels for better alignment with bars
        if dataPointCount <= 2 {
            return .top
        }

        // Standard behavior for more data
        let isFirst = date == allDates.first
        let isLast = date == allDates.last

        if isLast {
            return .topTrailing
        } else if isFirst {
            return .topLeading
        } else {
            return .top
        }
    }
}
