//
//  ReportExpensesOnlyLogicTests.swift
//  YalaTests
//
//  Lógica pura del gating de Solo Gastos en Reportes:
//  - ReportTab.visibleTabs / effectiveTab (oculta Flujo de Caja).
//  - FinancialReportViewModel.transactionTypeFilter (fuerza .expense en el pivot).
//  Sin ModelContext ni singletons → sin @Suite(.serialized).
//

import Testing

@testable import Yala

struct ReportExpensesOnlyLogicTests {

    // MARK: - ReportTab.visibleTabs

    @Test func visibleTabs_normalMode_showsBoth() {
        #expect(ReportTab.visibleTabs(expensesOnly: false) == [.comparativa, .flujoDeCaja])
    }

    @Test func visibleTabs_expensesOnly_hidesCashFlow() {
        #expect(ReportTab.visibleTabs(expensesOnly: true) == [.comparativa])
    }

    // MARK: - ReportTab.effectiveTab

    @Test func effectiveTab_expensesOnly_coercesCashFlowToComparativa() {
        // Un estado previo .flujoDeCaja no debe dejar la pantalla en blanco.
        #expect(ReportTab.effectiveTab(selected: .flujoDeCaja, expensesOnly: true) == .comparativa)
    }

    @Test func effectiveTab_expensesOnly_keepsComparativa() {
        #expect(ReportTab.effectiveTab(selected: .comparativa, expensesOnly: true) == .comparativa)
    }

    @Test func effectiveTab_normalMode_passthrough() {
        #expect(ReportTab.effectiveTab(selected: .flujoDeCaja, expensesOnly: false) == .flujoDeCaja)
        #expect(ReportTab.effectiveTab(selected: .comparativa, expensesOnly: false) == .comparativa)
    }

    // MARK: - FinancialReportViewModel.transactionTypeFilter

    @Test @MainActor func pivotFilter_expensesOnly_forcesExpense() {
        #expect(FinancialReportViewModel.transactionTypeFilter(expensesOnly: true) == .expense)
    }

    @Test @MainActor func pivotFilter_normalMode_isAll() {
        #expect(FinancialReportViewModel.transactionTypeFilter(expensesOnly: false) == .all)
    }
}
