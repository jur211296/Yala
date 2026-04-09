//
//  TrendProcessingHelper.swift
//  Yala
//
//  Helper for processing trend data points and domains.
//

import Foundation

struct BarPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date && lhs.value == rhs.value
    }
}

struct TrendProcessingHelper {

    /// Calculates a moving average for a series of data points.
    /// The last `window` points are preserved without smoothing to ensure
    /// recent data reflects actual values, not averaged approximations.
    /// - Parameters:
    ///   - data: The raw data points.
    ///   - window: The window size for the moving average (also used as no-smooth zone at end).
    /// - Returns: A new array of points with smoothed values (except last `window` points).
    static func movingAverage(for data: [BarPoint], window: Int) -> [BarPoint] {
        guard !data.isEmpty else { return [] }
        var result: [BarPoint] = []
        let sorted = data.sorted { $0.date < $1.date }

        // Don't smooth the last `window` points (e.g., last 14 days)
        let noSmoothStart = sorted.count - window

        for i in 0..<sorted.count {
            if i >= noSmoothStart {
                // Preserve original value for recent data
                result.append(BarPoint(date: sorted[i].date, value: sorted[i].value))
            } else {
                // Apply moving average to historical data
                let start = max(0, i - window + 1)
                let chunk = sorted[start...i]
                let sum = chunk.map(\.value).reduce(0, +)
                let avg = sum / Double(chunk.count)
                result.append(BarPoint(date: sorted[i].date, value: avg))
            }
        }
        return result
    }

    /// Calculates the Y-axis domain for the trend chart.
    /// - Parameters:
    ///   - points: The processed trend points.
    ///   - isExpense: Whether the trend is for expenses (affects domain logic).
    /// - Returns: A standard ClosedRange<Double> for the Y-axis.
    static func calculateYDomain(
        for points: [BarPoint],
        isExpense: Bool
    ) -> ClosedRange<Double> {
        let values = points.map(\.value)
        let maxVal = values.max() ?? 0
        let minVal = values.min() ?? 0
        let topBuffer = max(abs(maxVal) * 0.05, 100)

        if isExpense {
            let safeMax = max(0, abs(maxVal))
            return 0...(safeMax + topBuffer)
        } else {
            let safeMin = min(minVal, 0)
            let safeMax = max(maxVal, 0)
            let bottomBuffer = (safeMin < 0) ? abs(safeMin) * 0.05 : 0

            let lowerBound = safeMin - bottomBuffer
            let upperBound = max(lowerBound, safeMax + topBuffer)
            return lowerBound...upperBound
        }
    }
}
