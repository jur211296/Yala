//
//  CashFlowSmallBinner.swift
//  Yala
//
//  Re-bins CashFlowCalculator's daily chartData into adaptive buckets
//  (day/week/month/quarter/year) used by CashFlowWidget.small (PP2-06c).
//
//  Pure — no SwiftUI, no services. Safe to unit-test.
//

import Foundation

enum CashFlowSmallBucket: Equatable {
    case day
    case week
    case month
    case quarter
    case year
}

struct CashFlowSmallBinner {
    /// Returns chart data re-binned to the granularity that fits `.small` (max ~12 bars).
    ///
    /// Rules:
    /// - duration ≤ 45 days → bucket is daily (≤7d) or weekly (>7d); weekly buckets align to
    ///   `firstWeekday` and are clipped by `interval.end`.
    /// - duration > 45 days → bucket is monthly (≤7m), quarterly (8-20m), or yearly (≥21m).
    static func bin(
        chartData: [CashFlowData],
        interval: DateInterval,
        firstWeekday: Int
    ) -> (bins: [CashFlowData], bucket: CashFlowSmallBucket) {
        guard interval.duration > 0, !chartData.isEmpty else {
            return ([], .day)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = max(1, min(7, firstWeekday))
        calendar.timeZone = TimeZone.current

        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 0
        let months = calendar.dateComponents([.month], from: interval.start, to: interval.end).month ?? 0

        let bucket: CashFlowSmallBucket
        if days <= 45 {
            bucket = days <= 7 ? .day : .week
        } else {
            if months <= 7 {
                bucket = .month
            } else if months <= 20 {
                bucket = .quarter
            } else {
                bucket = .year
            }
        }

        let bins = aggregate(
            chartData: chartData,
            bucket: bucket,
            interval: interval,
            calendar: calendar
        )
        return (bins, bucket)
    }

    // MARK: - Aggregation

    private static func aggregate(
        chartData: [CashFlowData],
        bucket: CashFlowSmallBucket,
        interval: DateInterval,
        calendar: Calendar
    ) -> [CashFlowData] {
        let keyed = chartData.map { point -> (key: Date, point: CashFlowData) in
            let natural = naturalBucketStart(for: point.date, bucket: bucket, calendar: calendar)
            let key = max(natural, calendar.startOfDay(for: interval.start))
            return (key, point)
        }

        var buckets: [Date: (income: Double, expense: Double, net: Double)] = [:]
        for (key, point) in keyed {
            var current = buckets[key] ?? (0, 0, 0)
            current.income += point.income
            current.expense += point.expense
            current.net += point.net
            buckets[key] = current
        }

        // Enumerate every bucket start inside interval so empty buckets render as zeros.
        let boundaries = enumerateBucketStarts(bucket: bucket, interval: interval, calendar: calendar)

        return boundaries.map { start in
            let totals = buckets[start] ?? (0, 0, 0)
            return CashFlowData(
                date: start,
                income: totals.income,
                expense: totals.expense,
                net: totals.net
            )
        }
    }

    /// Natural start of the bucket that contains `date` (no clamping).
    /// For weekly buckets the alignment depends on `calendar.firstWeekday`.
    private static func naturalBucketStart(
        for date: Date,
        bucket: CashFlowSmallBucket,
        calendar: Calendar
    ) -> Date {
        switch bucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
                ?? calendar.startOfDay(for: date)
        case .quarter:
            let comps = calendar.dateComponents([.year, .month], from: date)
            let month0 = (comps.month ?? 1) - 1
            let quarterStartMonth = (month0 / 3) * 3 + 1
            var start = comps
            start.month = quarterStartMonth
            start.day = 1
            return calendar.date(from: start) ?? calendar.startOfDay(for: date)
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: date))
                ?? calendar.startOfDay(for: date)
        }
    }

    /// All bucket start dates covering `interval`. The first bucket is clamped to
    /// `interval.start`; subsequent buckets use natural boundaries aligned to the grid.
    private static func enumerateBucketStarts(
        bucket: CashFlowSmallBucket,
        interval: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        let intervalStart = calendar.startOfDay(for: interval.start)
        let firstNatural = naturalBucketStart(for: interval.start, bucket: bucket, calendar: calendar)
        var result: [Date] = []
        var cursor = firstNatural
        while cursor < interval.end {
            let effective = max(cursor, intervalStart)
            result.append(effective)
            cursor = nextBucketStart(after: cursor, bucket: bucket, calendar: calendar)
        }
        if result.isEmpty { result = [intervalStart] }
        return result
    }

    private static func nextBucketStart(
        after date: Date,
        bucket: CashFlowSmallBucket,
        calendar: Calendar
    ) -> Date {
        switch bucket {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: date) ?? date
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarter:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .year:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
    }
}
