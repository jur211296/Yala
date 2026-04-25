//
//  Calendar+Extensions.swift
//  Yala
//
//  Shared Calendar helpers for period calculations.
//

import Foundation

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }

    /// Returns weekday numbers (1=Sun..7=Sat) starting from `firstWeekday`.
    /// e.g. firstWeekday=2 (Monday) → [2,3,4,5,6,7,1].
    static func orderedWeekdays(firstWeekday: Int) -> [Int] {
        let clamped = max(1, min(7, firstWeekday))
        return (0..<7).map { offset in ((clamped - 1 + offset) % 7) + 1 }
    }
}
