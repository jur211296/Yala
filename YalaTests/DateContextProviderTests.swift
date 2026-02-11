//
//  DateContextProviderTests.swift
//  YalaTests
//
//  Unit tests for DateContextProvider (semi-pure, uses injectable Date).
//

import Foundation
import Testing

@testable import Yala

struct DateContextProviderTests {

    @Test func containsToday() {
        let now = Date()
        let output = DateContextProvider.buildDateContext(now: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let todayStr = fmt.string(from: now)
        #expect(output.contains(todayStr))
    }

    @Test func containsYesterday() {
        let now = Date()
        let output = DateContextProvider.buildDateContext(now: now)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        let yesterdayStr = fmt.string(from: yesterday)
        #expect(output.contains(yesterdayStr))
    }

    @Test func containsWeekdayMappings() {
        let output = DateContextProvider.buildDateContext(now: Date())
        // Should have 7 weekday arrow mappings
        let arrowCount = output.components(separatedBy: "→").count - 1
        // At least 7 from weekday lookups + several from rules
        #expect(arrowCount >= 7)
    }

    @Test func containsLastWeekRange() {
        let output = DateContextProvider.buildDateContext(now: Date())
        #expect(output.contains(" a "))
    }

    @Test func containsCurrentYear() {
        let output = DateContextProvider.buildDateContext(now: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        #expect(output.contains(String(currentYear)))
    }
}
