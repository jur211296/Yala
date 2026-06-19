//
//  CalendarOrderedWeekdaysTests.swift
//  YalaTests
//
//  Unit tests for Calendar.orderedWeekdays(firstWeekday:) helper.
//

import Foundation
import Testing

@testable import Yala

struct CalendarOrderedWeekdaysTests {

    @Test func firstWeekdaySunday_returns1to7() {
        let result = Calendar.orderedWeekdays(firstWeekday: 1)
        #expect(result == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func firstWeekdayMonday_returnsRotated() {
        let result = Calendar.orderedWeekdays(firstWeekday: 2)
        #expect(result == [2, 3, 4, 5, 6, 7, 1])
    }

    @Test func firstWeekdaySaturday_returnsRotated() {
        let result = Calendar.orderedWeekdays(firstWeekday: 7)
        #expect(result == [7, 1, 2, 3, 4, 5, 6])
    }

    @Test func clampLowerBound_treatsZeroAsSunday() {
        let result = Calendar.orderedWeekdays(firstWeekday: 0)
        #expect(result == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func clampUpperBound_treatsEightAsSaturday() {
        let result = Calendar.orderedWeekdays(firstWeekday: 8)
        #expect(result == [7, 1, 2, 3, 4, 5, 6])
    }

    @Test func anyValueInRange_alwaysReturns7UniqueValues() {
        for firstWeekday in 1...7 {
            let result = Calendar.orderedWeekdays(firstWeekday: firstWeekday)
            #expect(result.count == 7)
            #expect(Set(result) == Set([1, 2, 3, 4, 5, 6, 7]))
            #expect(result.first == firstWeekday)
        }
    }
}
