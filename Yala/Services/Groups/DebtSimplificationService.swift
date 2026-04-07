//
//  DebtSimplificationService.swift
//  Yala
//
//  Minimum cash flow algorithm for debt simplification.
//  Reduces the number of transfers needed to settle debts in a group.
//

import Foundation

/// A debt between two members in a specific currency.
struct Debt: Equatable, Sendable, Identifiable {
    var id: String { "\(fromMemberID)-\(toMemberID)-\(currencyCode)" }
    let fromMemberID: String
    let toMemberID: String
    let amount: Double
    let currencyCode: String
}

enum DebtSimplificationService {

    private static let epsilon: Double = 0.001

    /// Simplifies debts using the minimum cash flow algorithm.
    /// Groups debts by currency and simplifies each group independently.
    /// - Parameter debts: Raw debts (one per expense-share pair).
    /// - Returns: Simplified debts (minimum transfers).
    static func simplify(debts: [Debt]) -> [Debt] {
        guard !debts.isEmpty else { return [] }

        let grouped = Dictionary(grouping: debts, by: \.currencyCode)
        var result: [Debt] = []

        for (currencyCode, currencyDebts) in grouped {
            result.append(contentsOf: simplifyForCurrency(currencyDebts, currencyCode: currencyCode))
        }

        return result
    }

    /// Greedy minimum cash flow O(n^2) for a single currency.
    private static func simplifyForCurrency(_ debts: [Debt], currencyCode: String) -> [Debt] {
        // 1. Calculate net balance per member
        var netBalance: [String: Double] = [:]

        for debt in debts {
            netBalance[debt.fromMemberID, default: 0] -= debt.amount
            netBalance[debt.toMemberID, default: 0] += debt.amount
        }

        // Remove near-zero balances
        netBalance = netBalance.filter { abs($0.value) > epsilon }

        var result: [Debt] = []

        // 2. Iteratively settle: match max creditor with max debtor
        while true {
            guard let maxCreditor = netBalance.max(by: { $0.value < $1.value }),
                  maxCreditor.value > epsilon,
                  let maxDebtor = netBalance.min(by: { $0.value < $1.value }),
                  maxDebtor.value < -epsilon else {
                break
            }

            let transferAmount = min(maxCreditor.value, abs(maxDebtor.value))
            let rounded = roundToTwoDecimals(transferAmount)

            if rounded > 0 {
                result.append(Debt(
                    fromMemberID: maxDebtor.key,
                    toMemberID: maxCreditor.key,
                    amount: rounded,
                    currencyCode: currencyCode
                ))
            }

            netBalance[maxDebtor.key, default: 0] += transferAmount
            netBalance[maxCreditor.key, default: 0] -= transferAmount

            // Clean up near-zero balances
            if abs(netBalance[maxDebtor.key] ?? 0) <= epsilon {
                netBalance.removeValue(forKey: maxDebtor.key)
            }
            if abs(netBalance[maxCreditor.key] ?? 0) <= epsilon {
                netBalance.removeValue(forKey: maxCreditor.key)
            }
        }

        return result
    }

    /// Rounds to 2 decimal places using banker's rounding.
    private static func roundToTwoDecimals(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
