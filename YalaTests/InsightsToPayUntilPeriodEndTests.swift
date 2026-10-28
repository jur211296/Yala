//
//  InsightsToPayUntilPeriodEndTests.swift
//  YalaTests
//
//  «Lo que te falta pagar» (Estadísticas › Resumen) de un período EN CURSO cuenta los pagos que vencen hasta el FINAL del
//  período, no solo hasta hoy (decisión A de Jürgen, 2026-10-27; ticket
//  `insights-to-pay-this-month-leaves-out-the-rest-of-the-month`). Antes, el alquiler del 28 visto el 27 no salía: el
//  pendiente se medía con `DetailPeriod.dateInterval`, que en los períodos en curso cierra hoy a las 23:59:59.
//
//  Cada frontera, por los dos lados: el último segundo del período entra; el primero del siguiente, no. Y el resto de la
//  pantalla sigue cerrando hoy.
//
//  Sin `ModelContext`: los `@Model` sueltos bastan (molde de `StatisticsSummaryAllTimeTests`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Resumen de Estadísticas · «Lo que te falta pagar» hasta el fin del período", .serialized)
struct InsightsToPayUntilPeriodEndTests {

    /// El calendario con el que corta el calculador (primer día de la semana del usuario incluido).
    private let calendar = userConfiguredCalendar()

    /// «Hoy»: martes 27 de octubre de 2026, a mediodía.
    private var now: Date { date(2026, 10, 27, hour: 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)

    private func pago(
        _ nombre: String, _ importe: Double, vence: Date, categoria: PaymentCategory = .recurring
    ) -> ScheduledPayment {
        ScheduledPayment(
            name: nombre, amount: importe, currencyCode: "PEN",
            nextDueDate: vence, paymentCategory: categoria.rawValue, isActive: true
        )
    }

    private func resumen(
        _ pagos: [ScheduledPayment], period: DetailPeriod, txs: [TransactionItem] = []
    ) -> InsightData {
        InsightsCalculator.calculate(
            transactions: txs, accounts: [cuenta], categories: [comida], budgets: [],
            scheduledPayments: pagos, period: period, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: nil, now: now
        )
    }

    // MARK: - Este mes

    @Test("Este mes: el alquiler que vence mañana (día 28) entra (antes: fuera)")
    func thisMonth_paymentDueTomorrow_counts() {
        let c = resumen([pago("Alquiler", 1500, vence: date(2026, 10, 28))], period: .thisMonth).commitments
        #expect(c.pendingPaymentsCount == 1, "con el bug: 0")
        #expect(c.pendingPaymentsAmount == 1500)
        #expect(c.pendingOtherPaymentsCount == 1)
        #expect(c.pendingOtherPaymentsAmount == 1500)
    }

    @Test("Este mes: el último segundo del 31 entra; el 1 del mes siguiente a las 00:00, no")
    func thisMonth_boundaryAtTheEndOfTheMonth() {
        let primeroDeNoviembre = date(2026, 11, 1)
        let ultimo = pago("Último", 100, vence: primeroDeNoviembre.addingTimeInterval(-1))
        let siguiente = pago("Siguiente", 7, vence: primeroDeNoviembre)
        let c = resumen([ultimo, siguiente], period: .thisMonth).commitments
        #expect(c.pendingPaymentsCount == 1)
        #expect(c.pendingPaymentsAmount == 100)
    }

    @Test("Este mes: una suscripción que vence el 30 entra en su lado")
    func thisMonth_subscriptionLaterThisMonth_countsAsSubscription() {
        let c = resumen(
            [pago("Streaming", 40, vence: date(2026, 10, 30, hour: 9), categoria: .subscription)], period: .thisMonth
        ).commitments
        #expect(c.pendingSubscriptionsCount == 1)
        #expect(c.pendingSubscriptionsAmount == 40)
        #expect(c.pendingOtherPaymentsCount == 0)
    }

    @Test("Este mes: un pago vencido antes de hoy dentro del mes sigue contando")
    func thisMonth_overdueEarlierThisMonth_stillCounts() {
        let c = resumen([pago("Luz", 90, vence: date(2026, 10, 15))], period: .thisMonth).commitments
        #expect(c.pendingPaymentsCount == 1)
        #expect(c.pendingPaymentsAmount == 90)
    }

    @Test("Este mes: el resto del Resumen sigue cerrando hoy (un gasto de mañana no cuenta)")
    func thisMonth_restOfTheSummaryStillClosesToday() {
        let manana = TransactionItem(
            date: date(2026, 10, 28, hour: 10), amount: -80, currencyCode: "PEN", note: "",
            category: comida, account: cuenta, amountInPreferredCurrency: -80, preferredCurrencyCode: "PEN"
        )
        let summary = resumen([pago("Alquiler", 1500, vence: date(2026, 10, 28))], period: .thisMonth, txs: [manana])
            .periodSummary
        #expect(summary.totalExpense == 0)
        #expect(summary.dayCount == 27)
    }

    // MARK: - Esta semana y Este año

    @Test("Esta semana: el último segundo de la semana entra; el primero de la siguiente, no")
    func thisWeek_boundaryAtTheEndOfTheWeek() throws {
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: now))
        let ultimo = pago("Último", 30, vence: week.end.addingTimeInterval(-1))
        let siguiente = pago("Siguiente", 7, vence: week.end)
        let c = resumen([ultimo, siguiente], period: .thisWeek).commitments
        #expect(c.pendingPaymentsCount == 1, "con el bug: 0 (el último día de la semana es después de hoy)")
        #expect(c.pendingPaymentsAmount == 30)
    }

    @Test("Este año: un pago de diciembre entra; el 1 de enero, no")
    func thisYear_countsUntilTheEndOfTheYear() {
        let diciembre = pago("Seguro", 600, vence: date(2026, 12, 15))
        let enero = pago("Enero", 7, vence: date(2027, 1, 1))
        let c = resumen([diciembre, enero], period: .thisYear).commitments
        #expect(c.pendingPaymentsCount == 1, "con el bug: 0")
        #expect(c.pendingPaymentsAmount == 600)
    }

    // MARK: - Lo que no cambia

    @Test("Mes pasado (cerrado): un pago de este mes no entra")
    func lastMonth_isUnchanged() {
        let c = resumen(
            [pago("Septiembre", 50, vence: date(2026, 9, 20)), pago("Alquiler", 1500, vence: date(2026, 10, 28))],
            period: .lastMonth
        ).commitments
        #expect(c.pendingPaymentsCount == 1)
        #expect(c.pendingPaymentsAmount == 50)
    }

    @Test("Últimos 7 días (móvil): el período acaba hoy, así que un pago de mañana no entra")
    func last7Days_endsToday() {
        let c = resumen(
            [pago("Hoy", 20, vence: date(2026, 10, 27, hour: 9)), pago("Alquiler", 1500, vence: date(2026, 10, 28))],
            period: .last7Days
        ).commitments
        #expect(c.pendingPaymentsCount == 1)
        #expect(c.pendingPaymentsAmount == 20)
    }
}
