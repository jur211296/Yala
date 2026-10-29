//
//  WidgetExtraLargePortraitDataTests.swift
//  YalaTests
//
//  Lo que la app calcula para los extragrandes verticales del iPhone (iOS 27, card
//  `widgets-extragrandes-en-el-iphone-con-io-5fir`):
//
//  - **Reparto por cuenta** de «Entradas y salidas» (`WidgetPeriodSummary.accountFlows`): sale de la MISMA suma que los
//    totales, así que las filas suman el neto. El fixture trae las filas que separan reglas (`ingreso-gasto.md`): un
//    movimiento sin categoría de cada signo y una devolución en una categoría de gasto.
//  - **Mes de pagos** de «Pagos planificados» (`WidgetDataCache.buildPaymentsMonth`): la cuenta de la tarjeta de Pagos
//    del Panel (total menos pagado), con los días para el calendario.
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("Widgets extragrandes · datos que calcula la app")
struct WidgetExtraLargePortraitDataTests {

    // MARK: - Reparto por cuenta

    private let main = Account(name: "Principal", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank")
    private let card = Account(name: "Tarjeta", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "credit")
    private let salary = Yala.Category(name: "Sueldo", colorHex: "#00C2CB", isIncome: true)
    private let food = Yala.Category(name: "Comida", colorHex: "#FF0080", isIncome: false)

    private func tx(_ amount: Double, _ account: Account, _ category: Yala.Category?, _ date: Date) -> TransactionItem {
        TransactionItem(
            date: date, amount: amount, currencyCode: "PEN", category: category, account: account,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    private func summary(now: Date = .now) -> WidgetPeriodSummary {
        let interval = DetailPeriod.thisMonth.dateInterval(now: now)
        let day = interval.start.addingTimeInterval(3_600)
        let txs = [
            tx(1_000, main, salary, day),   // ingreso
            tx(-200, main, food, day),      // gasto
            tx(-40, main, nil, day),        // sin categoría, negativo: gasto
            tx(-300, card, food, day),      // gasto
            tx(50, card, food, day),        // devolución en categoría de gasto: resta del gasto
            tx(10, card, nil, day),         // sin categoría, positivo: ingreso
        ]
        return WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            converter: MockCurrencyConverter()
        )
    }

    @Test("Las cuentas suman el neto del período, con la misma regla de ingreso y gasto")
    func accountFlows_addUpToTheNet() throws {
        let result = summary()
        let flows = try #require(result.accountFlows)

        #expect(result.totalIncome == 1_010)
        #expect(result.totalExpense == 490)
        #expect(flows.map(\.name) == ["Principal", "Tarjeta"], "de más a menos movimiento")
        #expect(flows.map(\.income) == [1_000, 10])
        #expect(flows.map(\.expense) == [240, 250])
        #expect(flows.map(\.net) == [760, -240])
        #expect(flows.reduce(0) { $0 + $1.net } == result.netCashFlow)
        #expect(flows.reduce(0) { $0 + $1.income } == result.totalIncome)
        #expect(flows.reduce(0) { $0 + $1.expense } == result.totalExpense)
    }

    @Test("Un período sin movimientos no trae cuentas")
    func accountFlows_emptyPeriod() {
        let interval = DetailPeriod.thisMonth.dateInterval(now: .now)
        let result = WidgetDataCache.buildPeriodSummary(
            transactions: [], periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            converter: MockCurrencyConverter()
        )
        #expect(result.accountFlows?.isEmpty == true)
    }

    // MARK: - Mes de pagos

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    /// Un día del mes QUE VIENE: el calculador descarta las fechas anteriores a la creación del pago (`createdAt`, que
    /// un pago recién creado pone en hoy), así que un mes ya empezado perdería sus primeros días.
    private func date(_ day: Int) -> Date {
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: .now) ?? .now
        var components = calendar.dateComponents([.year, .month], from: nextMonth)
        components.day = day
        components.hour = 12
        return calendar.date(from: components) ?? .distantPast
    }

    @Test("Pendientes y pagados por día, y lo que falta en la divisa principal")
    func paymentsMonth_matchesThePanelCount() {
        let rent = ScheduledPayment(
            name: "Alquiler", amount: 1_500, currencyCode: "PEN", nextDueDate: date(5), dayOfMonth: 5)
        let streaming = ScheduledPayment(
            name: "Streaming", amount: 10, currencyCode: "USD", nextDueDate: date(20), dayOfMonth: 20)
        let paycheck = ScheduledPayment(
            name: "Sueldo", amount: 5_000, currencyCode: "PEN", transactionType: "income",
            nextDueDate: date(15), dayOfMonth: 15)
        let paid = [rent.id.uuidString: [PaidOccurrenceInfo(amount: 1_480, currencyCode: "PEN", date: date(5))]]

        let month = WidgetDataCache.buildPaymentsMonth(
            payments: [rent, streaming, paycheck], paid: paid, month: date(10), currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: 4), calendar: calendar
        )

        #expect(month.paidDays == [5])
        #expect(month.pendingDays == [20], "el sueldo es un ingreso: no es un pago")
        #expect(month.remainingToPay == 40, "10 USD a 4: lo pagado no cuenta y el ingreso tampoco")
        #expect(month.monthStart == calendar.dateInterval(of: .month, for: date(10))?.start)
    }

    @Test("Una fecha saltada no es ni pendiente ni pagada")
    func paymentsMonth_skipsSkippedDates() {
        let rent = ScheduledPayment(
            name: "Alquiler", amount: 1_500, currencyCode: "PEN", nextDueDate: date(5), dayOfMonth: 5)
        rent.skipDate(date(5))

        let month = WidgetDataCache.buildPaymentsMonth(
            payments: [rent], paid: [:], month: date(10), currencyCode: "PEN",
            converter: MockCurrencyConverter(), calendar: calendar
        )

        #expect(month.pendingDays.isEmpty)
        #expect(month.paidDays.isEmpty)
        #expect(month.remainingToPay == 0)
    }
}
