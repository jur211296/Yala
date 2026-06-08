//
//  SplitCalculator.swift
//  Yala
//
//  Pure logic for split amount calculation.
//

import Foundation

enum SplitCalculator {

    /// Calculates the user's portion based on split parameters.
    /// - Parameters:
    ///   - totalAmount: The total amount to split (positive).
    ///   - splitType: The type of split.
    ///   - myValue: Context-dependent value (percentage, people count, shares, or exact amount).
    ///   - divisor: Total divisor (nil for exact type).
    /// - Returns: The calculated portion, or nil if inputs are invalid.
    static func calculate(
        totalAmount: Double,
        splitType: SplitType,
        myValue: Double,
        divisor: Double?
    ) -> Double? {
        guard totalAmount > 0, myValue > 0 else { return nil }

        switch splitType {
        case .percentage:
            guard myValue > 0, myValue <= 100 else { return nil }
            let result = totalAmount * myValue / 100
            return roundToTwoDecimals(result)

        case .equal:
            let people = myValue
            guard people >= 1 else { return nil }
            let result = totalAmount / people
            return roundToTwoDecimals(result)

        case .shares:
            guard let totalShares = divisor, totalShares > 0, myValue <= totalShares else { return nil }
            let result = totalAmount * myValue / totalShares
            return roundToTwoDecimals(result)

        case .exact:
            guard myValue <= totalAmount else { return nil }
            return roundToTwoDecimals(myValue)
        }
    }

    /// Rounds to 2 decimal places (round half away from zero).
    private static func roundToTwoDecimals(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
