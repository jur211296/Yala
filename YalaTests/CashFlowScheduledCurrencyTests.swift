//
//  CashFlowScheduledCurrencyTests.swift
//  YalaTests
//
//  Ticket `cashflow-scheduled-line-ignores-payment-currency`: una línea del flujo de caja ligada a
//  un pago programado en otra divisa entra convertida a la divisa del plan, con «≈» si la tasa no
//  es exacta.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct CashFlowScheduledCurrencyTests {

    private let calendar = Calendar.current

    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
    }

    /// Pago mensual el día 10, creado mucho antes: el mes que viene tiene exactamente un pago.
    private func makeMonthlyPayment(amount: Double, currencyCode: String) -> ScheduledPayment {
        let due = calendar.date(byAdding: .day, value: 9, to: currentMonthStart)!
        let sp = ScheduledPayment(
            name: "Alquiler",
            amount: amount,
            currencyCode: currencyCode,
            transactionType: "expense",
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: due,
            paymentCategory: "recurring",
            isActive: true
        )
        sp.createdAt = calendar.date(byAdding: .year, value: -1, to: currentMonthStart)!
        return sp
    }

    /// Resultado de la línea en el mes que viene (índice 1 con `monthsBack: 0`).
    private func nextMonthLine(
        payment: ScheduledPayment,
        planCurrency: String,
        converter: MockCurrencyConverter,
        overrideAmount: Double? = nil
    ) -> CashFlowLineResult {
        let line = CashFlowLine(
            name: "Alquiler", isIncome: false, sortOrder: 0,
            estimationMethod: .scheduled, manualAmount: nil,
            category: nil, subcategory: nil, scheduledPayment: payment
        )
        if let overrideAmount {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonthStart)!
            let key = CashFlowProjectionCalculator.monthKey(for: nextMonth, calendar: calendar)
            let override = CashFlowOverride(monthKey: key, amount: overrideAmount)
            override.line = line
            line.overrides = [override]
        }
        let projection = CashFlowProjectionCalculator.calculate(
            plan: CashFlowPlan(name: "Plan", startingBalance: 0),
            lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [payment],
            monthsBack: 0, monthsAhead: 1,
            currencyCode: planCurrency, converter: converter
        )
        return projection.months[1].expenseLines[0]
    }

    @Test func paymentInOtherCurrency_isConvertedToPlanCurrency() {
        let payment = makeMonthlyPayment(amount: 100, currencyCode: "USD")
        let result = nextMonthLine(
            payment: payment, planCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75)
        )
        // Con el bug: 100 (los dólares contados como soles).
        #expect(abs(result.plannedAmount - 375) < 0.001)
        #expect(result.isPlannedApproximate == false)
    }

    @Test func paymentInPlanCurrency_isUnchanged() {
        let payment = makeMonthlyPayment(amount: 100, currencyCode: "PEN")
        let result = nextMonthLine(
            payment: payment, planCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .staticFallback)
        )
        #expect(abs(result.plannedAmount - 100) < 0.001)
        #expect(result.isPlannedApproximate == false)
    }

    @Test func approximateRate_marksTheLine() {
        let payment = makeMonthlyPayment(amount: 100, currencyCode: "USD")
        let result = nextMonthLine(
            payment: payment, planCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .staticFallback)
        )
        #expect(abs(result.plannedAmount - 375) < 0.001)
        #expect(result.isPlannedApproximate == true)
    }

    @Test func override_dropsTheMark() {
        let payment = makeMonthlyPayment(amount: 100, currencyCode: "USD")
        let result = nextMonthLine(
            payment: payment, planCurrency: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .staticFallback),
            overrideAmount: 400
        )
        #expect(result.plannedAmount == 400)
        #expect(result.isPlannedApproximate == false)
    }

    @Test func monthTotal_sumsTheConvertedAmount() {
        let payment = makeMonthlyPayment(amount: 100, currencyCode: "USD")
        let line = CashFlowLine(
            name: "Alquiler", isIncome: false, sortOrder: 0,
            estimationMethod: .scheduled, manualAmount: nil,
            category: nil, subcategory: nil, scheduledPayment: payment
        )
        let projection = CashFlowProjectionCalculator.calculate(
            plan: CashFlowPlan(name: "Plan", startingBalance: 0),
            lines: [line], transactions: [],
            allExpenseCategories: [], scheduledPayments: [payment],
            monthsBack: 0, monthsAhead: 1,
            currencyCode: "PEN", converter: MockCurrencyConverter(fixedRate: 3.75)
        )
        #expect(abs(projection.months[1].totalExpense - 375) < 0.001)
    }

    // MARK: - El helper compartido

    @Test func helper_sameCurrency_skipsTheConverter() {
        let payment = makeMonthlyPayment(amount: -80, currencyCode: "PEN")
        let r = ScheduledPaymentAmountConversion.magnitude(
            of: payment, in: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .staticFallback)
        )
        #expect(r == .init(amount: 80, isApproximate: false))
    }

    @Test func helper_otherCurrency_convertsMagnitudeAndReportsQuality() {
        let payment = makeMonthlyPayment(amount: -80, currencyCode: "USD")
        let exact = ScheduledPaymentAmountConversion.magnitude(
            of: payment, in: "PEN", converter: MockCurrencyConverter(fixedRate: 3.75)
        )
        #expect(exact == .init(amount: 300, isApproximate: false))
        let approx = ScheduledPaymentAmountConversion.magnitude(
            of: payment, in: "PEN",
            converter: MockCurrencyConverter(fixedRate: 3.75, quality: .carriedForward(fromDateKey: "2026-10-01"))
        )
        #expect(approx == .init(amount: 300, isApproximate: true))
    }
}
