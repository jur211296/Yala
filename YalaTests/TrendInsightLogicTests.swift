//
//  TrendInsightLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para TrendInsightLogic.finding(metric:currentTotal:previousTotal:).
//  Sin SwiftData, sin UI, sin singletons. Cubre los 3 ramos (ONSET / STABILITY /
//  VARIATION) + edge cases (zero previous, negative balance, threshold exacto).
//

import Foundation
import Testing

@testable import Yala

struct TrendInsightLogicTests {

    @Test func finding_nilPrevious_returnsOnset() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 100, previousTotal: nil
        )
        #expect(result == .onset)
    }

    @Test func finding_zeroPrevious_returnsStable() {
        // Edge case: división por cero — sin variation calculable, defaults a stable.
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 100, previousTotal: 0
        )
        #expect(result == .stable(metric: .expense))
    }

    @Test func finding_variationUnder5Percent_returnsStable() {
        // 102 vs 100 → 2% < 5% threshold → stable.
        let result = TrendInsightLogic.finding(
            metric: .income, currentTotal: 102, previousTotal: 100
        )
        #expect(result == .stable(metric: .income))
    }

    @Test func finding_variationUp10Percent_returnsVariationUp() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 110, previousTotal: 100
        )
        #expect(result == .variationUp(percent: 10, metric: .expense))
    }

    @Test func finding_variationDown15Percent_returnsVariationDown() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 85, previousTotal: 100
        )
        #expect(result == .variationDown(percent: 15, metric: .expense))
    }

    @Test func finding_negativePrevious_handlesCorrectly() {
        // Balance negativo que mejora: -200 → -100. (-100 - (-200)) / 200 = +0.5 → +50%.
        let result = TrendInsightLogic.finding(
            metric: .balance, currentTotal: -100, previousTotal: -200
        )
        #expect(result == .variationUp(percent: 50, metric: .balance))
    }

    @Test func finding_exactly5Percent_returnsVariationUp() {
        // Threshold exacto: |variation| == 0.05 NO < 0.05 → entra a variation, no stable.
        let result = TrendInsightLogic.finding(
            metric: .income, currentTotal: 105, previousTotal: 100
        )
        #expect(result == .variationUp(percent: 5, metric: .income))
    }
}
