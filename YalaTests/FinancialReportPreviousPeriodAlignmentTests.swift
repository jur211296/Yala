//
//  FinancialReportPreviousPeriodAlignmentTests.swift
//  YalaTests
//
//  Regresión p20-15: el pivot Comparativa no debe comparar lun→hoy contra
//  la semana calendario anterior completa. Sin el recorte, 10+40 = 50.
//  `firstWeekday` en `.standard` (lo lee `userConfiguredCalendar`) → suite
//  serializada + restore.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct FinancialReportPreviousPeriodAlignmentTests {

    @MainActor
    @Test func calculateReport_thisWeek_month_previousIsWTD() throws {
        let defaults = UserDefaults.standard
        let previousWeekday = defaults.object(forKey: "firstWeekday")
        defaults.set(2, forKey: "firstWeekday")
        defer {
            if let previousWeekday {
                defaults.set(previousWeekday, forKey: "firstWeekday")
            } else {
                defaults.removeObject(forKey: "firstWeekday")
            }
        }

        let cal = userConfiguredCalendar()
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }
        let now = date(2026, 7, 8) // miércoles

        let account = Account(
            name: "Cash",
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "banknote",
            type: "cash"
        )
        let food = YalaCategory(name: "Food", colorHex: "#000000", isIncome: false)

        func expense(amount: Double, on day: Date) -> TransactionItem {
            let tx = TransactionItem(
                date: day,
                amount: -amount,
                currencyCode: "PEN",
                note: "",
                category: food,
                account: account,
                amountInPreferredCurrency: -amount
            )
            tx.preferredCurrencyCode = "PEN"
            return tx
        }

        let transactions = [
            expense(amount: 10, on: date(2026, 7, 8)),
            expense(amount: 10, on: date(2026, 6, 29)),
            expense(amount: 40, on: date(2026, 7, 2)),
        ]

        let session = SessionState.shared
        let savedAccounts = session.selectedAccountIDs
        let savedCategories = session.selectedCategoryIDs
        let savedSubcategories = session.selectedSubcategoryIDs
        let savedNeeds = session.selectedNeeds
        let savedNatures = session.selectedTransactionNatures
        let savedTags = session.selectedTags
        let savedCurrencies = session.selectedCurrencies
        let savedAmount = session.amountCondition
        let savedSearch = session.searchText
        let savedExclude = session.isExcludeMode
        defer {
            session.selectedAccountIDs = savedAccounts
            session.selectedCategoryIDs = savedCategories
            session.selectedSubcategoryIDs = savedSubcategories
            session.selectedNeeds = savedNeeds
            session.selectedTransactionNatures = savedNatures
            session.selectedTags = savedTags
            session.selectedCurrencies = savedCurrencies
            session.amountCondition = savedAmount
            session.searchText = savedSearch
            session.isExcludeMode = savedExclude
        }

        let vm = FinancialReportViewModel()
        vm.clearFilters()
        vm.calculateReport(
            transactions: transactions,
            accounts: [account],
            preferredCurrency: "PEN",
            now: now,
            period: .thisWeek,
            comparisonMode: .month,
            expensesOnly: false
        )

        let previousNet = try #require(vm.netFlowPrevious)
        #expect(abs(previousNet) == 10)
        #expect(abs(previousNet) != 50)

        let expenseRoot = try #require(vm.rootNodes.first { !$0.isIncome })
        #expect(abs(expenseRoot.previousAmount ?? 0) == 10)
    }
}
