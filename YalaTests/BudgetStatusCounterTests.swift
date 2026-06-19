//
//  BudgetStatusCounterTests.swift
//  YalaTests
//
//  Pure-logic tests para BudgetStatusCounter.{classify, counters}.
//  Sin SwiftData, sin UI.
//

import Foundation
import Testing

@testable import Yala

struct BudgetStatusCounterTests {

    // MARK: - classify

    @Test func classify_belowThreshold_returnsOnTrack() {
        #expect(BudgetStatusCounter.classify(spent: 79, limit: 100) == .onTrack)
    }

    @Test func classify_atLowerLimit_returnsAtLimit() {
        #expect(BudgetStatusCounter.classify(spent: 80, limit: 100) == .atLimit)
    }

    @Test func classify_nearUpperLimit_returnsAtLimit() {
        #expect(BudgetStatusCounter.classify(spent: 99, limit: 100) == .atLimit)
    }

    @Test func classify_atOrAboveLimit_returnsOverLimit() {
        #expect(BudgetStatusCounter.classify(spent: 100, limit: 100) == .overLimit)
        #expect(BudgetStatusCounter.classify(spent: 150, limit: 100) == .overLimit)
    }

    @Test func classify_zeroLimit_returnsOnTrackDefensive() {
        #expect(BudgetStatusCounter.classify(spent: 0,   limit: 0) == .onTrack)
        #expect(BudgetStatusCounter.classify(spent: 100, limit: 0) == .onTrack)
    }

    @Test func classify_negativeLimit_returnsOnTrackDefensive() {
        #expect(BudgetStatusCounter.classify(spent: 50, limit: -10) == .onTrack)
    }

    // MARK: - counters

    @Test func counters_emptyInput_returnsZero() {
        let result = BudgetStatusCounter.counters(for: [])
        #expect(result == BudgetCounters.zero)
    }

    @Test func counters_mixedItems_aggregatesCorrectly() {
        let items: [(spent: Double, limit: Double)] = [
            (50,  100),    // onTrack
            (80,  100),    // atLimit
            (90,  100),    // atLimit
            (100, 100),    // overLimit
            (200, 100),    // overLimit
            (0,   100),    // onTrack
        ]
        let result = BudgetStatusCounter.counters(for: items)
        #expect(result == BudgetCounters(onTrack: 2, atLimit: 2, overLimit: 2))
    }
}
