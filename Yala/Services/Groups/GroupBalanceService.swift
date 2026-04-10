//
//  GroupBalanceService.swift
//  Yala
//
//  Pure calculations for group balances and debts.
//  Stateless enum — receives data as parameters (like SplitCalculator).
//

import Foundation

/// Per-member balance in a single currency.
struct MemberBalance: Equatable, Sendable {
    let memberID: String
    let displayName: String
    let totalPaid: Double
    let totalOwes: Double
    let netBalance: Double      // totalPaid - totalOwes (+le deben, -debe)
    let currencyCode: String
}

/// Global summary across all groups for the current user.
struct GroupGlobalSummary: Equatable, Sendable {
    let totalOwedToMe: [String: Double]     // por moneda
    let totalIOwe: [String: Double]         // por moneda
    let pendingSettlements: Int
}

enum GroupBalanceService {

    private static let epsilon: Double = 0.01

    // MARK: - Balances

    /// Calculate per-member balances for a group, per currency.
    /// Each member may appear multiple times (once per currency they participate in).
    static func calculateBalances(
        expenses: [SplitExpense],
        shares: [SplitShare],
        members: [SplitMember],
        settlements: [SplitSettlement]
    ) -> [MemberBalance] {
        let activeExpenses = expenses.filter { !$0.isSettled }
        let confirmedSettlements = settlements.filter { $0.isConfirmed }

        // Build member lookup: memberID → displayName
        let memberNames = Dictionary(
            members.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )

        // Build share lookup: expenseID → [SplitShare]
        let sharesByExpense = Dictionary(grouping: shares, by: \.expenseID)

        // Accumulate per (memberID, currencyCode)
        struct BalanceKey: Hashable {
            let memberID: String
            let currencyCode: String
        }

        var paid: [BalanceKey: Double] = [:]
        var owes: [BalanceKey: Double] = [:]

        for expense in activeExpenses {
            let payerKey = BalanceKey(memberID: expense.paidByMemberID, currencyCode: expense.currencyCode)
            paid[payerKey, default: 0] += expense.amount

            let expenseShares = sharesByExpense[expense.id] ?? []
            for share in expenseShares {
                let shareKey = BalanceKey(memberID: share.memberID, currencyCode: expense.currencyCode)
                owes[shareKey, default: 0] += share.amount
            }
        }

        // Apply confirmed settlements
        for settlement in confirmedSettlements {
            let fromKey = BalanceKey(memberID: settlement.fromMemberID, currencyCode: settlement.currencyCode)
            let toKey = BalanceKey(memberID: settlement.toMemberID, currencyCode: settlement.currencyCode)
            paid[fromKey, default: 0] += settlement.amount
            owes[toKey, default: 0] += settlement.amount
        }

        // Collect all (memberID, currency) pairs
        let allKeys = Set(paid.keys).union(owes.keys)

        var result: [MemberBalance] = []
        for key in allKeys {
            let totalPaid = roundToTwoDecimals(paid[key] ?? 0)
            let totalOwes = roundToTwoDecimals(owes[key] ?? 0)
            let net = roundToTwoDecimals(totalPaid - totalOwes)

            result.append(MemberBalance(
                memberID: key.memberID,
                displayName: memberNames[key.memberID] ?? key.memberID,
                totalPaid: totalPaid,
                totalOwes: totalOwes,
                netBalance: net,
                currencyCode: key.currencyCode
            ))
        }

        return result.sorted { ($0.memberID, $0.currencyCode) < ($1.memberID, $1.currencyCode) }
    }

    // MARK: - Debts

    /// Calculate debts (who owes whom). Optionally simplified.
    static func calculateDebts(
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement],
        simplifyDebts: Bool
    ) -> [Debt] {
        let raw = rawDebts(expenses: expenses, shares: shares, settlements: settlements)

        if simplifyDebts {
            return DebtSimplificationService.simplify(debts: raw)
        }

        // Consolidate raw debts: merge same (from, to, currency) pairs
        return consolidateDebts(raw)
    }

    /// Build raw debts from expenses + shares, minus confirmed settlements.
    private static func rawDebts(
        expenses: [SplitExpense],
        shares: [SplitShare],
        settlements: [SplitSettlement]
    ) -> [Debt] {
        let activeExpenses = expenses.filter { !$0.isSettled }
        let sharesByExpense = Dictionary(grouping: shares, by: \.expenseID)

        var debts: [Debt] = []

        for expense in activeExpenses {
            let expenseShares = sharesByExpense[expense.id] ?? []
            for share in expenseShares {
                // Skip if member paid for themselves
                guard share.memberID != expense.paidByMemberID else { continue }
                guard share.amount > epsilon else { continue }

                debts.append(Debt(
                    fromMemberID: share.memberID,
                    toMemberID: expense.paidByMemberID,
                    amount: share.amount,
                    currencyCode: expense.currencyCode
                ))
            }
        }

        // Subtract confirmed settlements as reverse debts
        let confirmedSettlements = settlements.filter { $0.isConfirmed }
        for settlement in confirmedSettlements {
            guard settlement.amount > epsilon else { continue }
            debts.append(Debt(
                fromMemberID: settlement.toMemberID,
                toMemberID: settlement.fromMemberID,
                amount: settlement.amount,
                currencyCode: settlement.currencyCode
            ))
        }

        return debts
    }

    /// Consolidate debts: merge same (from, to, currency) pairs and net bidirectional.
    /// Uses canonical pair key (min, max) to correctly handle debts in both directions.
    private static func consolidateDebts(_ debts: [Debt]) -> [Debt] {
        struct PairKey: Hashable {
            let memberA: String  // always min(from, to)
            let memberB: String  // always max(from, to)
            let currency: String
        }

        // Positive = A owes B, negative = B owes A
        var netAmounts: [PairKey: Double] = [:]

        for debt in debts {
            let isForward = debt.fromMemberID <= debt.toMemberID
            let key = PairKey(
                memberA: min(debt.fromMemberID, debt.toMemberID),
                memberB: max(debt.fromMemberID, debt.toMemberID),
                currency: debt.currencyCode
            )
            if isForward {
                netAmounts[key, default: 0] += debt.amount
            } else {
                netAmounts[key, default: 0] -= debt.amount
            }
        }

        var result: [Debt] = []
        for (key, amount) in netAmounts {
            guard abs(amount) > epsilon else { continue }
            if amount > 0 {
                result.append(Debt(
                    fromMemberID: key.memberA,
                    toMemberID: key.memberB,
                    amount: roundToTwoDecimals(amount),
                    currencyCode: key.currency
                ))
            } else {
                result.append(Debt(
                    fromMemberID: key.memberB,
                    toMemberID: key.memberA,
                    amount: roundToTwoDecimals(abs(amount)),
                    currencyCode: key.currency
                ))
            }
        }

        return result
    }

    // MARK: - Global Summary

    /// Global summary across all groups for the current user.
    /// - Parameter currentUserMemberIDs: Set of member IDs that represent the current user across groups.
    static func globalSummary(
        allExpenses: [SplitExpense],
        allShares: [SplitShare],
        allSettlements: [SplitSettlement],
        currentUserMemberIDs: Set<String>
    ) -> GroupGlobalSummary {
        let debts = rawDebts(expenses: allExpenses, shares: allShares, settlements: allSettlements)
        let simplified = DebtSimplificationService.simplify(debts: debts)

        var owedToMe: [String: Double] = [:]
        var iOwe: [String: Double] = [:]

        for debt in simplified {
            if currentUserMemberIDs.contains(debt.toMemberID) {
                owedToMe[debt.currencyCode, default: 0] += debt.amount
            }
            if currentUserMemberIDs.contains(debt.fromMemberID) {
                iOwe[debt.currencyCode, default: 0] += debt.amount
            }
        }

        // Round
        owedToMe = owedToMe.mapValues { roundToTwoDecimals($0) }
        iOwe = iOwe.mapValues { roundToTwoDecimals($0) }

        let pendingCount = allSettlements.filter { !$0.isConfirmed }.count

        return GroupGlobalSummary(
            totalOwedToMe: owedToMe,
            totalIOwe: iOwe,
            pendingSettlements: pendingCount
        )
    }

    // MARK: - Consolidated Balances (single currency)

    /// Consolidate multi-currency balances into a single target currency.
    /// Groups balances by member and converts each via the provided converter.
    static func consolidatedBalances(
        from balances: [MemberBalance],
        targetCurrency: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [MemberBalance] {
        let grouped = Dictionary(grouping: balances, by: \.memberID)

        return grouped.compactMap { memberID, memberBalances -> MemberBalance? in
            guard let first = memberBalances.first else { return nil }

            var totalPaid: Double = 0
            var totalOwes: Double = 0

            for balance in memberBalances {
                if balance.currencyCode == targetCurrency {
                    totalPaid += balance.totalPaid
                    totalOwes += balance.totalOwes
                } else {
                    let convertedPaid = converter.convertWithLatestRate(
                        Decimal(balance.totalPaid), from: balance.currencyCode, to: targetCurrency
                    )
                    let convertedOwes = converter.convertWithLatestRate(
                        Decimal(balance.totalOwes), from: balance.currencyCode, to: targetCurrency
                    )
                    totalPaid += NSDecimalNumber(decimal: convertedPaid).doubleValue
                    totalOwes += NSDecimalNumber(decimal: convertedOwes).doubleValue
                }
            }

            let net = roundToTwoDecimals(totalPaid - totalOwes)
            return MemberBalance(
                memberID: memberID,
                displayName: first.displayName,
                totalPaid: roundToTwoDecimals(totalPaid),
                totalOwes: roundToTwoDecimals(totalOwes),
                netBalance: net,
                currencyCode: targetCurrency
            )
        }.sorted { $0.memberID < $1.memberID }
    }

    /// Consolidate multi-currency debts into a single target currency.
    static func consolidatedDebts(
        from debts: [Debt],
        targetCurrency: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [Debt] {
        // Convert each debt to target currency, then re-consolidate
        let converted = debts.map { debt -> Debt in
            if debt.currencyCode == targetCurrency { return debt }
            let convertedAmount = converter.convertWithLatestRate(
                Decimal(debt.amount), from: debt.currencyCode, to: targetCurrency
            )
            return Debt(
                fromMemberID: debt.fromMemberID,
                toMemberID: debt.toMemberID,
                amount: NSDecimalNumber(decimal: convertedAmount).doubleValue,
                currencyCode: targetCurrency
            )
        }
        return consolidateDebts(converted)
    }

    // MARK: - Helpers

    private static func roundToTwoDecimals(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
