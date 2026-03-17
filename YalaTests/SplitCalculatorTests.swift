//
//  SplitCalculatorTests.swift
//  YalaTests
//
//  Unit tests for SplitCalculator pure logic.
//

import Foundation
import Testing

@testable import Yala

struct SplitCalculatorTests {

    // MARK: - Percentage

    @Test func percentage_80percentOf125_returns100() {
        let result = SplitCalculator.calculate(
            totalAmount: 125,
            splitType: .percentage,
            myValue: 80,
            divisor: nil
        )

        #expect(result == 100)
    }

    @Test func percentage_50percentOf200_returns100() {
        let result = SplitCalculator.calculate(
            totalAmount: 200,
            splitType: .percentage,
            myValue: 50,
            divisor: nil
        )

        #expect(result == 100)
    }

    @Test func percentage_100percent_returnsFullAmount() {
        let result = SplitCalculator.calculate(
            totalAmount: 250,
            splitType: .percentage,
            myValue: 100,
            divisor: nil
        )

        #expect(result == 250)
    }

    @Test func percentage_0percent_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 100,
            splitType: .percentage,
            myValue: 0,
            divisor: nil
        )

        #expect(result == nil)
    }

    @Test func percentage_over100percent_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 100,
            splitType: .percentage,
            myValue: 150,
            divisor: nil
        )

        #expect(result == nil)
    }

    // MARK: - Equal

    @Test func equal_3people120total_returns40each() {
        let result = SplitCalculator.calculate(
            totalAmount: 120,
            splitType: .equal,
            myValue: 3,
            divisor: nil
        )

        #expect(result == 40)
    }

    @Test func equal_1person_returnsFullAmount() {
        let result = SplitCalculator.calculate(
            totalAmount: 200,
            splitType: .equal,
            myValue: 1,
            divisor: nil
        )

        #expect(result == 200)
    }

    @Test func equal_0people_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 120,
            splitType: .equal,
            myValue: 0,
            divisor: nil
        )

        #expect(result == nil)
    }

    // MARK: - Shares

    @Test func shares_2of5shares500total_returns200() {
        let result = SplitCalculator.calculate(
            totalAmount: 500,
            splitType: .shares,
            myValue: 2,
            divisor: 5
        )

        #expect(result == 200)
    }

    @Test func shares_totalSharesZero_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 500,
            splitType: .shares,
            myValue: 2,
            divisor: 0
        )

        #expect(result == nil)
    }

    @Test func shares_mySharesGreaterThanTotal_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 500,
            splitType: .shares,
            myValue: 6,
            divisor: 5
        )

        #expect(result == nil)
    }

    // MARK: - Exact

    @Test func exact_60from100total_returns60() {
        let result = SplitCalculator.calculate(
            totalAmount: 100,
            splitType: .exact,
            myValue: 60,
            divisor: nil
        )

        #expect(result == 60)
    }

    @Test func exact_amountGreaterThanTotal_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: 100,
            splitType: .exact,
            myValue: 150,
            divisor: nil
        )

        #expect(result == nil)
    }

    // MARK: - Negative total

    @Test func negativeTotalAmount_returnsNil() {
        let result = SplitCalculator.calculate(
            totalAmount: -100,
            splitType: .percentage,
            myValue: 50,
            divisor: nil
        )

        #expect(result == nil)
    }
}
