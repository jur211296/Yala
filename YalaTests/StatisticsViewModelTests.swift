//
//  StatisticsViewModelTests.swift
//  YalaTests
//
//  Unit tests for StatisticsViewModel pure logic (metric selection, filter state, context building).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct StatisticsViewModelTests {

    // MARK: - Helpers

    @MainActor private func makeVM(
        metric: TrendMetric = .balance,
        period: DetailPeriod = .thisMonth
    ) -> StatisticsViewModel {
        let context = StatisticsContext(
            initialMetric: metric,
            period: period
        )
        return StatisticsViewModel(context: context)
    }

    // MARK: - Initialization

    @MainActor @Test func init_setsMetricFromContext() {
        let vm = makeVM(metric: .income)
        #expect(vm.selectedMetric == .income)
    }

    @MainActor @Test func init_defaultState() {
        let vm = makeVM()
        #expect(vm.selectedTab == .trends)
        #expect(vm.isAggregatedView == true)
        #expect(vm.trendPoints.isEmpty)
        #expect(vm.recentRecords.isEmpty)
        #expect(vm.totalIncome == 0)
        #expect(vm.totalExpense == 0)
        #expect(vm.currentBalance == 0)
    }

    @MainActor @Test func init_withAccountID_setsFilter() {
        let account = Account(
            name: "Test",
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
        let context = StatisticsContext(
            initialMetric: .balance,
            period: .thisMonth,
            accountID: account.persistentModelID
        )
        let vm = StatisticsViewModel(context: context)
        #expect(vm.selectedAccounts.contains(account.persistentModelID))
    }

    @MainActor @Test func init_withNeed_setsFilter() {
        let context = StatisticsContext(
            initialMetric: .expense,
            period: .thisMonth,
            need: .essential
        )
        let vm = StatisticsViewModel(context: context)
        #expect(vm.selectedNeeds.contains(.essential))
    }

    // MARK: - totalMetricValue

    @MainActor @Test func totalMetricValue_balance_returnsLastTrendPoint() {
        let vm = makeVM(metric: .balance)
        vm.trendPoints = [
            PanelViewModel.BarPoint(date: Date(), value: 100),
            PanelViewModel.BarPoint(date: Date(), value: 250),
        ]
        #expect(vm.totalMetricValue == 250)
    }

    @MainActor @Test func totalMetricValue_income_returnsTotalIncome() {
        let vm = makeVM(metric: .income)
        vm.totalIncome = 5000
        #expect(vm.totalMetricValue == 5000)
    }

    @MainActor @Test func totalMetricValue_expense_returnsTotalExpense() {
        let vm = makeVM(metric: .expense)
        vm.totalExpense = 3200
        #expect(vm.totalMetricValue == 3200)
    }

    @MainActor @Test func totalMetricValue_balance_emptyPoints_returnsZero() {
        let vm = makeVM(metric: .balance)
        vm.trendPoints = []
        #expect(vm.totalMetricValue == 0)
    }

    // MARK: - buildRecordsContext

    @MainActor @Test func buildRecordsContext_income() {
        let vm = makeVM(metric: .income)
        let ctx = vm.buildRecordsContext()
        #expect(ctx.transactionType == .income)
    }

    @MainActor @Test func buildRecordsContext_expense() {
        let vm = makeVM(metric: .expense)
        let ctx = vm.buildRecordsContext()
        #expect(ctx.transactionType == .expense)
    }

    @MainActor @Test func buildRecordsContext_balance_nilType() {
        let vm = makeVM(metric: .balance)
        let ctx = vm.buildRecordsContext()
        #expect(ctx.transactionType == nil)
    }

    // MARK: - hasExpenseOnlyFilters

    @MainActor @Test func hasExpenseOnlyFilters_falseWhenEmpty() {
        let vm = makeVM()
        // Reset all filters from SessionState
        vm.selectedCategories.removeAll()
        vm.selectedSubcategories.removeAll()
        vm.selectedNeeds.removeAll()
        #expect(vm.hasExpenseOnlyFilters == false)
    }

    @MainActor @Test func hasExpenseOnlyFilters_trueWithNeeds() {
        let vm = makeVM()
        vm.selectedNeeds = [.essential]
        #expect(vm.hasExpenseOnlyFilters == true)
    }

    // MARK: - clearFilters

    @MainActor @Test func clearFilters_resetsAll() {
        let vm = makeVM()
        vm.selectedNeeds = [.essential]
        vm.searchText = "test"
        vm.isExcludeMode = true

        vm.clearFilters()

        #expect(vm.selectedAccounts.isEmpty)
        #expect(vm.selectedCategories.isEmpty)
        #expect(vm.selectedSubcategories.isEmpty)
        #expect(vm.selectedTags.isEmpty)
        #expect(vm.selectedNeeds.isEmpty)
        #expect(vm.selectedTransactionNatures.isEmpty)
        #expect(vm.selectedCurrencies.isEmpty)
        #expect(vm.searchText == "")
        #expect(vm.isExcludeMode == false)
    }

    // MARK: - setMetricManually

    @MainActor @Test func setMetricManually_changesMetric() {
        let vm = makeVM(metric: .balance)
        vm.setMetricManually(.expense)
        #expect(vm.selectedMetric == .expense)
    }

    // MARK: - maxRecentRecords

    @MainActor @Test func maxRecentRecords_isTen() {
        let vm = makeVM()
        #expect(vm.maxRecentRecords == 10)
    }
}
