//
//  GroupSplitCalculator.swift
//  Yala
//
//  Per-participant split calculation for group expenses.
//  Returns array of (memberID, amount) matching GroupExpenseService.createExpense(shares:) format.
//

import Foundation

enum GroupSplitCalculator {

    struct Participant {
        let memberID: String
        var value: Double // Meaning depends on splitType
    }

    /// Calculates each participant's share of the total amount.
    /// - Returns: Array of (memberID, amount) or nil if inputs are invalid.
    static func calculate(
        total: Double,
        splitType: SplitType,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        guard total > 0, !participants.isEmpty else { return nil }

        switch splitType {
        case .equal:
            return equalSplit(total: total, participants: participants)
        case .exact:
            return exactSplit(total: total, participants: participants)
        case .percentage:
            return percentageSplit(total: total, participants: participants)
        case .shares:
            return sharesSplit(total: total, participants: participants)
        }
    }

    // MARK: - Equal Split

    /// Divides total equally. Uses largest remainder method to distribute rounding cents.
    private static func equalSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let count = participants.count
        guard count > 0 else { return nil }

        let baseAmount = floor(total * 100 / Double(count)) / 100
        let totalDistributed = baseAmount * Double(count)
        var remainder = roundTwo(total - totalDistributed)

        return participants.enumerated().map { index, p in
            var amount = baseAmount
            if remainder >= 0.005 {
                amount += 0.01
                remainder -= 0.01
            }
            return (memberID: p.memberID, amount: roundTwo(amount))
        }
    }

    // MARK: - Exact Split

    /// Each participant.value is the exact amount they owe.
    /// Validates that sum of values equals total (within tolerance).
    private static func exactSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let sum = participants.reduce(0.0) { $0 + $1.value }
        guard abs(sum - total) < 0.02 else { return nil }
        guard participants.allSatisfy({ $0.value >= 0 }) else { return nil }

        return participants.map { (memberID: $0.memberID, amount: roundTwo($0.value)) }
    }

    // MARK: - Percentage Split

    /// Each participant.value is their percentage (0–100).
    /// Validates that percentages sum to 100 (within tolerance).
    private static func percentageSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let sumPct = participants.reduce(0.0) { $0 + $1.value }
        guard abs(sumPct - 100) < 0.1 else { return nil }
        guard participants.allSatisfy({ $0.value >= 0 }) else { return nil }

        var results = participants.map { p in
            (memberID: p.memberID, amount: roundTwo(total * p.value / 100))
        }

        adjustLastForRounding(&results, total: total)
        return results
    }

    // MARK: - Shares Split

    /// Each participant.value is their share count (integer-like).
    /// Calculates proportional amount based on share ratio.
    private static func sharesSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        guard participants.allSatisfy({ $0.value > 0 }) else { return nil }

        let totalShares = participants.reduce(0.0) { $0 + $1.value }
        guard totalShares > 0 else { return nil }

        var results = participants.map { p in
            (memberID: p.memberID, amount: roundTwo(total * p.value / totalShares))
        }

        adjustLastForRounding(&results, total: total)
        return results
    }

    // MARK: - Helpers

    /// Adjusts last participant's amount so distributed total matches expected total.
    private static func adjustLastForRounding(
        _ results: inout [(memberID: String, amount: Double)],
        total: Double
    ) {
        let distributed = results.reduce(0.0) { $0 + $1.amount }
        let diff = roundTwo(total - distributed)
        if abs(diff) > 0 && !results.isEmpty {
            let last = results.count - 1
            results[last].amount = roundTwo(results[last].amount + diff)
        }
    }

    private static func roundTwo(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
