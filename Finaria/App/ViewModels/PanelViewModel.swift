import Foundation
import SwiftData
import SwiftUI

@Observable
final class PanelViewModel {

    // MARK: - State

    var selectedAccountID: PersistentIdentifier?
    var leadingColumnIndex: Int? = 0

    // Period Filter State
    var panelPeriodType: PanelPeriodType = .thisMonth
    var customPeriodStart: Date?
    var customPeriodEnd: Date?

    // Draft state for custom period sheet
    var isPresentingCustomPeriodSheet = false
    var customPeriodStartDraft = Date()
    var customPeriodEndDraft = Date()
    var customPeriodErrorMessage: String?

    // MARK: - Dependencies / Configuration

    // We keep these as simple properties or computed ones based on what the View passes
    // or we can load them if we want to move AppStorage here (requires a wrapper or passing values).
    // For simplicity in MVVM with SwiftUI, we can keep AppStorage in View and sync,
    // OR use a PersistenceController.
    // However, to strictly follow the plan: "Move state variables... Move logic".

    // Let's handle the logic that doesn't depend on View-specific property wrappers like @Query directly,
    // or accept the data in methods.

    // MARK: - Computed Logic

    /// Returns active accounts sorted by the user's custom order.
    func orderedActiveAccounts(from accounts: [Account], sortOrderNames: [String]) -> [Account] {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let indexByName = Dictionary(
            uniqueKeysWithValues: sortOrderNames.enumerated().map { ($1, $0) })

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    /// Calculates the total balance in the default currency.
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        // Optimized: Calculate all balances in one pass
        let balances = AccountBalanceCalculator.batchCalculateBalances(
            accounts: eligibleAccounts,
            transactions: transactions
        )

        let totalDecimal: Decimal = eligibleAccounts.reduce(0) { partial, account in
            let currentBalance = balances[account.persistentModelID] ?? 0

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalance,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return partial + converted
        }

        return (totalDecimal as NSDecimalNumber).doubleValue
    }

    /// Calculates the displayed balance (either total or selected account).
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        if let selectedID = selectedAccountID,
            let account = accounts.first(where: { $0.persistentModelID == selectedID }),
            !account.isArchived,
            !account.excludeFromStatistics
        {
            let currentBalanceDecimal = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalanceDecimal,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return (converted as NSDecimalNumber).doubleValue
        }

        return totalBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    // MARK: - Helpers

    func ensureAccountsSortOrderConsistency(
        accounts: [Account],
        currentOrderRaw: String
    ) -> String {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeNames = activeAccounts.map { $0.name }

        if activeNames.isEmpty {
            return ""
        }

        let currentOrder = currentOrderRaw.split(separator: "|").map(String.init)
        var newOrder = currentOrder.filter { activeNames.contains($0) }

        for name in activeNames where !newOrder.contains(name) {
            newOrder.append(name)
        }

        return newOrder.joined(separator: "|")
    }

    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode
    ) -> Decimal {
        if source == target {
            return amount
        }

        // Tasas de ejemplo (mismas que en PanelView original)
        let usdToPen = Decimal(string: "3.54") ?? Decimal(3.54)
        let eurToPen = Decimal(string: "3.89") ?? Decimal(3.89)

        func penToUsd(_ pen: Decimal) -> Decimal {
            guard usdToPen != 0 else { return pen }
            return pen / usdToPen
        }

        func penToEur(_ pen: Decimal) -> Decimal {
            guard eurToPen != 0 else { return pen }
            return pen / eurToPen
        }

        let amountInPen: Decimal
        switch source {
        case .pen:
            amountInPen = amount
        case .usd:
            amountInPen = amount * usdToPen
        case .eur:
            amountInPen = amount * eurToPen
        }

        switch target {
        case .pen:
            return amountInPen
        case .usd:
            return penToUsd(amountInPen)
        case .eur:
            return penToEur(amountInPen)
        }
    }

    // MARK: - Filter Logic

    var panelPeriodFilter: PanelPeriodFilter {
        PanelPeriodFilter(
            type: panelPeriodType,
            customStartDate: customPeriodStart,
            customEndDate: customPeriodEnd
        )
    }

    var panelDateInterval: DateInterval {
        panelPeriodFilter.dateInterval()
    }

    func prepareCustomPeriodDraft() {
        customPeriodErrorMessage = nil
        if let start = customPeriodStart, let end = customPeriodEnd, start <= end {
            customPeriodStartDraft = start
            customPeriodEndDraft = end
        } else {
            let interval = panelDateInterval
            customPeriodStartDraft = interval.start
            customPeriodEndDraft = interval.end
        }
    }

    func applyCustomPeriod() -> Bool {
        guard customPeriodStartDraft <= customPeriodEndDraft else {
            customPeriodErrorMessage = "La fecha de inicio debe ser anterior a la fecha de fin."
            return false
        }

        customPeriodStart = customPeriodStartDraft
        customPeriodEnd = customPeriodEndDraft
        panelPeriodType = .custom
        isPresentingCustomPeriodSheet = false
        return true
    }
}
