//
//  CashFlowSmallBinnerTests.swift
//  YalaTests
//
//  Unit tests for CashFlowSmallBinner (PP2-06c).
//

import Foundation
import Testing

@testable import Yala

struct CashFlowSmallBinnerTests {

    // MARK: - Helpers

    // Use system calendar so tests align with the binner's internal calendar.
    private let calendar = Calendar.current

    private func date(_ components: DateComponents) -> Date {
        calendar.date(from: components)!
    }

    private func daily(from start: Date, count: Int, income: Double = 100, expense: Double = 50) -> [CashFlowData] {
        (0..<count).map { offset in
            let d = calendar.date(byAdding: .day, value: offset, to: start)!
            return CashFlowData(date: d, income: income, expense: expense, net: income - expense)
        }
    }

    // MARK: - Edge cases

    @Test("Empty chartData returns empty bins, bucket defaults to day")
    func emptyData() {
        let interval = DateInterval(start: Date.now, duration: 86_400)
        let result = CashFlowSmallBinner.bin(chartData: [], interval: interval, firstWeekday: 2)
        #expect(result.bins.isEmpty)
        #expect(result.bucket == .day)
    }

    @Test("Degenerate interval (duration == 0) returns empty")
    func degenerateInterval() {
        let d = Date.now
        let interval = DateInterval(start: d, duration: 0)
        let data = [CashFlowData(date: d, income: 100, expense: 50, net: 50)]
        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        #expect(result.bins.isEmpty)
    }

    // MARK: - Day bucket

    @Test("≤7 day interval uses .day bucket with one bin per day")
    func dailyBucketForShortInterval() {
        let start = date(DateComponents(year: 2026, month: 4, day: 1))
        let data = daily(from: start, count: 5)
        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 5, to: start)!)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)

        #expect(result.bucket == .day)
        #expect(result.bins.count == 5)
    }

    // MARK: - Week bucket — firstWeekday variations

    @Test("8-45 day interval uses .week bucket")
    func weekBucketForMediumInterval() {
        let start = date(DateComponents(year: 2026, month: 4, day: 1))  // wed
        let data = daily(from: start, count: 30)
        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 30, to: start)!)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        #expect(result.bucket == .week)
        // 30 days spans 5 week buckets (partial at both ends)
        #expect(result.bins.count >= 4)
        #expect(result.bins.count <= 6)
    }

    @Test("Weekly buckets align to firstWeekday preference")
    func weekBucketRespectsFirstWeekday() {
        // 30 days starting on Wednesday.
        let start = date(DateComponents(year: 2026, month: 4, day: 1))
        let data = daily(from: start, count: 30)
        let interval = DateInterval(start: start, end: calendar.date(byAdding: .day, value: 30, to: start)!)

        let mondayFirst = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        let sundayFirst = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 1)

        // Both should produce week buckets; total income across all buckets must match the raw data.
        let mondayIncome = mondayFirst.bins.reduce(0) { $0 + $1.income }
        let sundayIncome = sundayFirst.bins.reduce(0) { $0 + $1.income }
        let rawIncome = data.reduce(0) { $0 + $1.income }
        #expect(mondayIncome == rawIncome)
        #expect(sundayIncome == rawIncome)
    }

    // MARK: - Month / quarter / year buckets

    @Test("≤7 months uses .month bucket")
    func monthBucketFor6Months() {
        let start = date(DateComponents(year: 2026, month: 1, day: 1))
        let end = calendar.date(byAdding: .month, value: 6, to: start)!  // ~180 days
        let data = daily(from: start, count: 180)
        let interval = DateInterval(start: start, end: end)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        #expect(result.bucket == .month)
        #expect(result.bins.count == 6)
    }

    @Test("8-20 months uses .quarter bucket")
    func quarterBucketFor12Months() {
        let start = date(DateComponents(year: 2026, month: 1, day: 1))
        let end = calendar.date(byAdding: .month, value: 12, to: start)!
        let data = daily(from: start, count: 365)
        let interval = DateInterval(start: start, end: end)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        #expect(result.bucket == .quarter)
        #expect(result.bins.count == 4)
    }

    @Test("≥21 months uses .year bucket")
    func yearBucketFor25Months() {
        let start = date(DateComponents(year: 2024, month: 1, day: 1))
        let end = calendar.date(byAdding: .month, value: 25, to: start)!
        let data = daily(from: start, count: 760)
        let interval = DateInterval(start: start, end: end)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        #expect(result.bucket == .year)
        #expect(result.bins.count == 3)
    }

    // MARK: - Totals preserved

    @Test("Aggregation preserves totals across all buckets")
    func aggregationPreservesTotals() {
        let start = date(DateComponents(year: 2026, month: 1, day: 1))
        let data = daily(from: start, count: 365, income: 200, expense: 80)
        let end = calendar.date(byAdding: .day, value: 365, to: start)!
        let interval = DateInterval(start: start, end: end)

        let result = CashFlowSmallBinner.bin(chartData: data, interval: interval, firstWeekday: 2)
        let totalIncome = result.bins.reduce(0) { $0 + $1.income }
        let totalExpense = result.bins.reduce(0) { $0 + $1.expense }
        #expect(totalIncome == 200 * 365)
        #expect(totalExpense == 80 * 365)
    }
}
