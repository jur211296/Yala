//
//  CashFlowLineSideLogicTests.swift
//  YalaTests
//
//  Lote 18 de la auditoría UX 2.2: en el flujo de caja pasarse del plan es alarma solo en un gasto, y un
//  pago programado se ofrece solo en su lado (ingresos o gastos).
//

import Testing

@testable import Yala

struct CashFlowLineSideLogicTests {

    // MARK: - Barra de avance

    @Test func anExpenseOverThePlan_isAnAlarm() {
        #expect(CashFlowLineSideLogic.progressIsAlarm(progress: 1.81, isIncome: false))
    }

    /// El caso del bug: «Facturación y freelance · 191 %» salía en el mismo rosa que un gasto desbordado.
    @Test func anIncomeOverThePlan_isNotAnAlarm() {
        #expect(!CashFlowLineSideLogic.progressIsAlarm(progress: 1.91, isIncome: true))
    }

    /// El borde: justo el plan no es pasarse, en ningún lado.
    @Test func exactlyThePlan_isNotAnAlarm_onEitherSide() {
        #expect(!CashFlowLineSideLogic.progressIsAlarm(progress: 1.0, isIncome: false))
        #expect(!CashFlowLineSideLogic.progressIsAlarm(progress: 1.0, isIncome: true))
    }

    @Test func belowThePlan_isNotAnAlarm_onEitherSide() {
        #expect(!CashFlowLineSideLogic.progressIsAlarm(progress: 0.68, isIncome: false))
        #expect(!CashFlowLineSideLogic.progressIsAlarm(progress: 0.68, isIncome: true))
    }

    // MARK: - Pagos programados por lado

    /// El caso del bug: la pestaña Ingresos de «Agregar línea» listaba Netflix, el alquiler y los demás gastos.
    @Test func anExpensePayment_isNotOfferedOnTheIncomeSide() {
        #expect(!CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "expense", isIncome: true))
    }

    @Test func anExpensePayment_isOfferedOnTheExpenseSide() {
        #expect(CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "expense", isIncome: false))
    }

    @Test func anIncomePayment_isOfferedOnlyOnTheIncomeSide() {
        #expect(CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "income", isIncome: true))
        #expect(!CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "income", isIncome: false))
    }

    /// La misma regla con la que el plan clasifica la línea al crearla (`transactionType == "income"`): un valor
    /// que no es «income» cuenta como gasto, y así no hay pago que acabe en un lado distinto del que se eligió.
    @Test func anyOtherType_followsThePlansRule_andCountsAsExpense() {
        #expect(CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "", isIncome: false))
        #expect(!CashFlowLineSideLogic.scheduledPaymentMatchesSide(transactionType: "", isIncome: true))
    }
}
