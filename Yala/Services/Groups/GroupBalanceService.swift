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

/// Net balance del usuario actual en UN grupo, por moneda, para la banda del header del detalle.
/// A diferencia de `GroupGlobalSummary` (que mantiene ambos lados por separado), aquí se netea
/// por moneda (te-deben menos debes) para dar el vistazo rápido estilo Splitwise.
struct GroupHeaderBalance: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case theyOweMe   // todo el neto a favor
        case iOwe        // todo el neto en contra
        case mixed       // a favor en una moneda, en contra en otra
        case settled     // sin saldos pendientes
    }
    let state: State
    let owedToMe: [String: Double]   // neto > 0 por moneda (te deben)
    let iOwe: [String: Double]       // abs del neto < 0 por moneda (debes)
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
        // Defensa contra duplicados de CloudKit (race en merge resolution): dedup por id.
        let uniqueExpenses = Dictionary(grouping: expenses, by: \.id).values.compactMap(\.first)
        let activeExpenses = uniqueExpenses.filter { !$0.isSettled }
        let confirmedSettlements = settlements.filter { $0.isConfirmed }

        // Build member lookup: memberID → displayName. `resolvedDisplayName` (H1 review G5-D1): un
        // member anonimizado por eliminar-cuenta (`__deleted_user__`, status removed) sigue en los
        // balances si tenía saldo — sin el mapeo, la pestaña Balances mostraría el sentinel crudo.
        let memberNames = Dictionary(
            members.map { ($0.id.uuidString, $0.resolvedDisplayName) },
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
        // Defensa contra duplicados de CloudKit (race en merge resolution): dedup por id.
        let uniqueExpenses = Dictionary(grouping: expenses, by: \.id).values.compactMap(\.first)
        let activeExpenses = uniqueExpenses.filter { !$0.isSettled }
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

    /// Lo que un grupo aporta al resumen global: sus fuentes y sus dos opciones de cómo enseñar las deudas.
    struct GroupSummarySource {
        let expenses: [SplitExpense]
        let shares: [SplitShare]
        let settlements: [SplitSettlement]
        /// «Menos pagos entre ustedes» del grupo (`SplitGroup.simplifyDebts`).
        let simplifyDebts: Bool
        /// La divisa del grupo si tiene «una sola moneda» (`showDebtsInSingleCurrency`); `nil` si no.
        let singleCurrency: String?

        init(expenses: [SplitExpense], shares: [SplitShare], settlements: [SplitSettlement],
             simplifyDebts: Bool, singleCurrency: String?) {
            self.expenses = expenses
            self.shares = shares
            self.settlements = settlements
            self.simplifyDebts = simplifyDebts
            self.singleCurrency = singleCurrency
        }

        init(group: SplitGroup, expenses: [SplitExpense], shares: [SplitShare], settlements: [SplitSettlement]) {
            self.init(expenses: expenses, shares: shares, settlements: settlements,
                      simplifyDebts: group.simplifyDebts,
                      singleCurrency: group.showDebtsInSingleCurrency ? group.currencyCode : nil)
        }
    }

    /// Las deudas de UN grupo tal como las enseña: con su «Menos pagos» y, con «una sola moneda», consolidadas en la
    /// divisa del grupo si alguna está en otra. Es la cuenta de la tarjeta de la lista
    /// (`GroupsViewModel.computeCurrentUserDebts`) y la de Saldos (`GroupDetailViewModel.recalculate`).
    static func shownDebts(
        _ source: GroupSummarySource,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [Debt] {
        let debts = calculateDebts(
            expenses: source.expenses,
            shares: source.shares,
            settlements: source.settlements,
            simplifyDebts: source.simplifyDebts
        )
        guard let target = source.singleCurrency, debts.contains(where: { $0.currencyCode != target }) else {
            return debts
        }
        return consolidatedDebts(from: debts, targetCurrency: target, converter: converter)
    }

    /// Lo que debes y lo que te deben en todos los grupos, por divisa: la suma de lo que dice la tarjeta de cada grupo.
    ///
    /// Cada grupo se cuenta APARTE y con sus opciones (lote chico de 2.3, card de «Debes S/ 0.00» junto a «Le debes a
    /// Ana»). Antes se juntaban las deudas de todos los grupos y se simplificaban siempre: con «Menos pagos» apagado la
    /// cabecera neteaba lo que la tarjeta enseña por persona («Debes S/ 10» frente a «Le debes a Ana S/ 40 · Beto te debe
    /// S/ 30»), y la simplificación podía emparejar a un deudor de un grupo con un acreedor de otro.
    /// - Parameter currentUserMemberIDs: los ids de «yo» de cada grupo (en una zona migrada, dos filas del mismo humano).
    ///   La tarjeta resuelve UNO por grupo; con dos filas mías la cabecera puede sumar algo que la tarjeta no enseña. Eso
    ///   ya pasaba antes y es a propósito (`GroupsViewModel.recalculate`: quedarse con la canónica borraría la otra).
    static func globalSummary(
        groups: [GroupSummarySource],
        currentUserMemberIDs: Set<String>,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> GroupGlobalSummary {
        var owedToMe: [String: Double] = [:]
        var iOwe: [String: Double] = [:]

        for group in groups {
            for debt in shownDebts(group, converter: converter) {
                if currentUserMemberIDs.contains(debt.toMemberID) {
                    owedToMe[debt.currencyCode, default: 0] += debt.amount
                }
                if currentUserMemberIDs.contains(debt.fromMemberID) {
                    iOwe[debt.currencyCode, default: 0] += debt.amount
                }
            }
        }

        // Round
        owedToMe = owedToMe.mapValues { roundToTwoDecimals($0) }
        iOwe = iOwe.mapValues { roundToTwoDecimals($0) }

        let pendingCount = groups.reduce(0) { $0 + $1.settlements.filter { !$0.isConfirmed }.count }

        return GroupGlobalSummary(
            totalOwedToMe: owedToMe,
            totalIOwe: iOwe,
            pendingSettlements: pendingCount
        )
    }

    // MARK: - Header Balance (single group, current user)

    /// Netea las deudas del usuario actual en UN grupo, por moneda, para la banda del header.
    /// `debts` se asume ya consolidado/convertido por el caller (respeta `showDebtsInSingleCurrency`).
    /// Suma ambas direcciones (to==me suma, from==me resta), descarta monedas saldadas (≤ epsilon)
    /// y clasifica el estado resultante.
    static func computeGroupHeaderBalance(debts: [Debt], currentMemberID: String) -> GroupHeaderBalance {
        var net: [String: Double] = [:]
        for debt in debts {
            if debt.toMemberID == currentMemberID {
                net[debt.currencyCode, default: 0] += debt.amount
            }
            if debt.fromMemberID == currentMemberID {
                net[debt.currencyCode, default: 0] -= debt.amount
            }
        }

        var owedToMe: [String: Double] = [:]
        var iOwe: [String: Double] = [:]
        for (currency, raw) in net {
            let value = roundToTwoDecimals(raw)
            if value > epsilon {
                owedToMe[currency] = value
            } else if value < -epsilon {
                iOwe[currency] = -value
            }
        }

        let state: GroupHeaderBalance.State
        switch (owedToMe.isEmpty, iOwe.isEmpty) {
        case (true, true): state = .settled
        case (false, true): state = .theyOweMe
        case (true, false): state = .iOwe
        case (false, false): state = .mixed
        }

        return GroupHeaderBalance(state: state, owedToMe: owedToMe, iOwe: iOwe)
    }

    // MARK: - Consolidated Balances (single currency)

    /// Defensa en profundidad: `Decimal(Double.nan)` / `Decimal(.infinity)` provocan un trap
    /// fatal en runtime. Los montos ya se sanean en la ingestión remota
    /// (`CKRecordTranslator.sanitizeAmount`), pero esto protege también registros persistidos
    /// antes de ese fix y cualquier cálculo que pudiera producir un valor no-finito.
    private static func safeDecimal(_ value: Double) -> Decimal {
        Decimal(value.isFinite ? value : 0)
    }

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
                        safeDecimal(balance.totalPaid), from: balance.currencyCode, to: targetCurrency
                    )
                    let convertedOwes = converter.convertWithLatestRate(
                        safeDecimal(balance.totalOwes), from: balance.currencyCode, to: targetCurrency
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
                safeDecimal(debt.amount), from: debt.currencyCode, to: targetCurrency
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
