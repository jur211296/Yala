//
//  AverageSegment.swift
//  Yala
//
//  Helper for computing average segments over grouped bar chart data.
//

import Foundation

struct AverageSegment {
    let startDate: Date
    let endDate: Date
    let average: Double
    let variation: Double?  // nil for the first segment

    /// Compute average segments by grouping data points into a higher-level period.
    /// - Parameters:
    ///   - data: Array of (date, amount) tuples from bar chart data
    ///   - barGrouping: The grouping of the bar chart (day/week/month)
    /// - Returns: Array of AverageSegment, one per higher-level group
    static func compute(
        from data: [(date: Date, amount: Double)],
        barGrouping: TrendGrouping
    ) -> [AverageSegment] {
        guard data.count >= 2 else { return [] }

        let calendar = Calendar.current
        let segmentUnit = segmentGrouping(for: barGrouping, dataCount: data.count)

        // If no valid segmentation possible, return empty
        guard let unit = segmentUnit else { return [] }

        let barUnit = barGrouping.calendarComponent

        // Group data by the segment unit
        var groups: [(key: Date, values: [(date: Date, amount: Double)])] = []
        var currentGroupStart: Date?
        var currentValues: [(date: Date, amount: Double)] = []

        for point in data {
            let groupStart = calendar.dateInterval(of: unit, for: point.date)?.start ?? point.date

            if groupStart != currentGroupStart {
                if let start = currentGroupStart, !currentValues.isEmpty {
                    groups.append((key: start, values: currentValues))
                }
                currentGroupStart = groupStart
                currentValues = [point]
            } else {
                currentValues.append(point)
            }
        }
        // Don't forget the last group
        if let start = currentGroupStart, !currentValues.isEmpty {
            groups.append((key: start, values: currentValues))
        }

        guard groups.count >= 2 else { return [] }

        // Build segments
        var segments: [AverageSegment] = []
        var previousAvg: Double?

        for group in groups {
            let avg = group.values.reduce(0) { $0 + $1.amount } / Double(group.values.count)

            // Start: beginning of the first bar's calendar unit
            let firstDate = group.values.first?.date ?? group.key
            let startDate = calendar.dateInterval(of: barUnit, for: firstDate)?.start ?? firstDate

            // End: end of the last bar's calendar unit
            let lastDate = group.values.last?.date ?? group.key
            let endDate = calendar.dateInterval(of: barUnit, for: lastDate)?.end ?? lastDate

            let variation: Double?
            if let prev = previousAvg, prev > 0 {
                variation = ((avg - prev) / prev) * 100
            } else {
                variation = nil
            }

            segments.append(AverageSegment(
                startDate: startDate,
                endDate: endDate,
                average: avg,
                variation: variation
            ))

            previousAvg = avg
        }

        return segments
    }

    /// Determine the higher-level grouping for segments.
    /// - day bars → week segments
    /// - week bars → month segments
    /// - month bars → quarter segments (if ≥6 months data), else nil (fallback to total)
    private static func segmentGrouping(
        for barGrouping: TrendGrouping,
        dataCount: Int
    ) -> Calendar.Component? {
        switch barGrouping {
        case .day:
            return .weekOfYear
        case .week:
            return .month
        case .month:
            return dataCount >= 6 ? .quarter : nil
        }
    }
}
