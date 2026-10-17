//
//  FinancialReportAllTimeComparisonTests.swift
//  YalaTests
//
//  Lote 18 de la auditoría UX 2.2: la Comparativa abre en «Todo el tiempo», que no tiene período anterior.
//  `PreviousPeriodHelper` devuelve para él el MISMO intervalo, así que la tabla se comparaba consigo misma:
//  cada fila enseñaba su propio importe como «anterior» y un «+0 %». Sin período anterior no hay comparación.
//  Toca `SessionState.shared` (filtros) → suite serializada + restore, molde de
//  `FinancialReportPreviousPeriodAlignmentTests`.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct FinancialReportAllTimeComparisonTests {

    private struct Fixture {
        let account: Account
        let transactions: [TransactionItem]
        let now: Date
    }

    private func makeFixture() -> Fixture {
        let cal = Calendar.current
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        let account = Account(name: "Cash", currencyCode: "PEN", colorHex: "#000000", iconName: "banknote", type: "cash")
        let food = YalaCategory(name: "Food", colorHex: "#000000", isIncome: false)
        func expense(_ amount: Double, on day: Date) -> TransactionItem {
            let tx = TransactionItem(
                date: day, amount: -amount, currencyCode: "PEN", note: "",
                category: food, account: account, amountInPreferredCurrency: -amount
            )
            tx.preferredCurrencyCode = "PEN"
            return tx
        }
        return Fixture(
            account: account,
            transactions: [expense(30, on: date(2026, 7, 5)), expense(70, on: date(2026, 6, 3))],
            now: date(2026, 7, 8)
        )
    }

    private func withCleanSession(_ body: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (
            session.selectedAccountIDs, session.selectedCategoryIDs, session.selectedSubcategoryIDs,
            session.selectedNeeds, session.selectedTransactionNatures, session.selectedTags,
            session.selectedCurrencies, session.amountCondition, session.searchText, session.isExcludeMode
        )
        defer {
            session.selectedAccountIDs = saved.0
            session.selectedCategoryIDs = saved.1
            session.selectedSubcategoryIDs = saved.2
            session.selectedNeeds = saved.3
            session.selectedTransactionNatures = saved.4
            session.selectedTags = saved.5
            session.selectedCurrencies = saved.6
            session.amountCondition = saved.7
            session.searchText = saved.8
            session.isExcludeMode = saved.9
        }
        try body()
    }

    private func calculate(_ period: DetailPeriod, _ fixture: Fixture) -> FinancialReportViewModel {
        let vm = FinancialReportViewModel()
        vm.clearFilters()
        vm.calculateReport(
            transactions: fixture.transactions,
            accounts: [fixture.account],
            preferredCurrency: "PEN",
            now: fixture.now,
            period: period,
            // El modo que llega con «Todo el tiempo» cuando la persona venía de comparar meses: el selector
            // está oculto para ese período, pero el modo global sigue en `.month`.
            comparisonMode: .month,
            expensesOnly: false
        )
        return vm
    }

    @Test func allTime_hasNoPreviousPeriod_soNothingIsCompared() throws {
        try withCleanSession {
            let vm = calculate(.allTime, makeFixture())

            #expect(vm.supportsComparison == false)
            #expect(vm.netFlowPrevious == nil)
            #expect(vm.netFlowVariation == nil)
            let expenseRoot = try #require(vm.rootNodes.first { !$0.isIncome })
            #expect(abs(expenseRoot.amount) == 100)
            // Con el bug, el «anterior» era el mismo 100 y la variación un «+0 %».
            #expect(expenseRoot.previousAmount == nil)
        }
    }

    /// Control: un período con anterior sigue comparando. Si el corte de arriba se aplicara a todos, este cae.
    @Test func thisMonth_stillComparesWithTheMonthBefore() throws {
        try withCleanSession {
            let vm = calculate(.thisMonth, makeFixture())

            #expect(vm.supportsComparison == true)
            let previousNet = try #require(vm.netFlowPrevious)
            #expect(abs(previousNet) == 70)
            let expenseRoot = try #require(vm.rootNodes.first { !$0.isIncome })
            #expect(abs(expenseRoot.amount) == 30)
            #expect(abs(expenseRoot.previousAmount ?? 0) == 70)
        }
    }

    /// Volver de «Todo el tiempo» a un período comparable vuelve a encender la comparación en el mismo VM.
    @Test func leavingAllTime_turnsTheComparisonBackOn() {
        withCleanSession {
            let fixture = makeFixture()
            let vm = FinancialReportViewModel()
            vm.clearFilters()
            vm.calculateReport(transactions: fixture.transactions, accounts: [fixture.account], preferredCurrency: "PEN",
                               now: fixture.now, period: .allTime, comparisonMode: .month, expensesOnly: false)
            #expect(vm.supportsComparison == false)
            vm.calculateReport(transactions: fixture.transactions, accounts: [fixture.account], preferredCurrency: "PEN",
                               now: fixture.now, period: .thisMonth, comparisonMode: .month, expensesOnly: false)
            #expect(vm.supportsComparison == true)
            #expect(vm.netFlowPrevious != nil)
        }
    }
}
