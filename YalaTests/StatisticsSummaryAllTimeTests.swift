//
//  StatisticsSummaryAllTimeTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 11 (Estadísticas), tres bugs del Resumen medidos en el simulador con el corpus «realista»:
//
//  - B1. «Todo el tiempo» se comparaba consigo mismo: `PreviousPeriodHelper.previousInterval(.allTime)` devuelve el
//    propio intervalo y las cuatro variaciones salían 0 % («= +0 %» y «Tu balance se mantiene estable»).
//  - B3. «Todo el tiempo» repartía el gasto entre los diez años del intervalo: «Promedio diario» S/ 55 a quien gasta
//    S/ 277 al día desde hace dos años. Lo mismo el día de más gasto y el gasto diario por necesidad.
//  - B2. La tarjeta «Suscripciones» sumaba todos los pagos planificados que se repiten (el alquiler incluido), y no
//    solo las suscripciones que cuenta «Suscripciones activas» de Compromisos.
//
//  Sin `ModelContext`: los `@Model` sueltos bastan (molde de `StatisticsCalculatorsZeroConvertedTests`).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Resumen de Estadísticas · «Todo el tiempo» y suscripciones (lote 11)", .serialized)
struct StatisticsSummaryAllTimeTests {

    private let calendar = Calendar.current

    /// «Hoy» fijo a mediodía, para que ningún intervalo dependa del reloj de la máquina.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)) ?? Date()
    }

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: now) ?? now
    }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)

    private func gasto(_ importe: Double, hace dias: Int) -> TransactionItem {
        TransactionItem(
            date: daysAgo(dias), amount: -importe, currencyCode: "PEN", note: "",
            category: comida, account: cuenta,
            amountInPreferredCurrency: -importe, preferredCurrencyCode: "PEN"
        )
    }

    private func ingreso(_ importe: Double, hace dias: Int) -> TransactionItem {
        TransactionItem(
            date: daysAgo(dias), amount: importe, currencyCode: "PEN", note: "",
            category: sueldo, account: cuenta,
            amountInPreferredCurrency: importe, preferredCurrencyCode: "PEN"
        )
    }

    private func resumen(
        _ txs: [TransactionItem], period: DetailPeriod, pagos: [ScheduledPayment] = []
    ) -> InsightData {
        InsightsCalculator.calculate(
            transactions: txs, accounts: [cuenta], categories: [comida, sueldo], budgets: [],
            scheduledPayments: pagos, period: period, criteria: FilterCriteria(), currencyCode: "PEN",
            customRange: nil, now: now
        )
    }

    // MARK: - B1 · «Todo el tiempo» no tiene período anterior

    @Test("B1: con «Todo el tiempo» no hay variación (antes: 0 % en las cuatro)")
    func allTime_hasNoVariations() {
        let txs = [ingreso(3000, hace: 40), gasto(500, hace: 40), ingreso(3000, hace: 5), gasto(800, hace: 5)]
        let summary = resumen(txs, period: .allTime).periodSummary
        #expect(summary.expenseVariation == nil, "con el bug: 0 (\(String(describing: summary.expenseVariation)))")
        #expect(summary.incomeVariation == nil)
        #expect(summary.balanceVariation == nil)
        #expect(summary.dailyAverageVariation == nil)
    }

    @Test("B1, control: un período con anterior sí compara")
    func lastMonth_keepsVariations() {
        // 15 de octubre: «Mes pasado» es septiembre y su anterior, agosto.
        let txs = [gasto(500, hace: 50), gasto(800, hace: 20)]
        let summary = resumen(txs, period: .lastMonth).periodSummary
        #expect(summary.expenseVariation != nil)
        #expect(summary.dailyAverageVariation != nil)
    }

    // MARK: - B3 · los días de «Todo el tiempo» empiezan en el primer registro

    @Test("B3: el promedio diario de «Todo el tiempo» reparte desde el primer registro, no en diez años")
    func allTime_dailyAverageCountsFromFirstRecord() {
        // Primer registro hace 100 días: del día de ese registro a hoy, ambos incluidos, son 101 días.
        let txs = [gasto(600, hace: 100), gasto(410, hace: 3)]
        let summary = resumen(txs, period: .allTime).periodSummary
        #expect(summary.dayCount == 101, "con el bug: ~3.653 días (\(summary.dayCount))")
        #expect(abs(summary.dailyAverageExpense - 1010.0 / 101.0) < 0.001,
                "con el bug: ~0,28 al día (\(summary.dailyAverageExpense))")
    }

    @Test("B3: el día de más gasto de «Todo el tiempo» promedia sobre las semanas con datos")
    func allTime_weekdayAverageCountsFromFirstRecord() {
        // Un solo gasto de 700 hace 14 días: ese día de la semana sale 2 o 3 veces desde entonces, no ~520.
        let best = resumen([gasto(700, hace: 14)], period: .allTime).quickStats.highestAvgWeekday
        let average = best?.average ?? 0
        #expect(average > 200, "con el bug: ~1,3 (\(average))")
    }

    @Test("B3, control: «Este mes» sigue contando sus días")
    func thisMonth_dayCountUnchanged() {
        // 15 de octubre: del 1 al 15, 15 días.
        let summary = resumen([gasto(150, hace: 2)], period: .thisMonth).periodSummary
        #expect(summary.dayCount == 15)
    }

    // MARK: - B2 · «Suscripciones» cuenta solo suscripciones

    private func pago(_ nombre: String, _ importe: Double, categoria: PaymentCategory, activo: Bool = true) -> ScheduledPayment {
        ScheduledPayment(
            name: nombre, amount: importe, currencyCode: "PEN",
            nextDueDate: daysAgo(-5), paymentCategory: categoria.rawValue, isActive: activo
        )
    }

    @Test("B2: «Suscripciones» suma lo mismo que «Suscripciones activas» (antes: todo lo recurrente)")
    func subscriptionsCard_matchesCommitments() {
        let pagos = [
            pago("Netflix", 45, categoria: .subscription),
            pago("Spotify", 25, categoria: .subscription),
            pago("Alquiler", 2200, categoria: .recurring),
            pago("Gimnasio viejo", 90, categoria: .subscription, activo: false),
        ]
        let data = resumen([gasto(100, hace: 1)], period: .thisMonth, pagos: pagos)
        #expect(data.quickStats.subscriptionsTotal == 70, "con el bug: 2.270 (\(data.quickStats.subscriptionsTotal))")
        #expect(data.quickStats.subscriptionsTotal == data.commitments.activeSubscriptionsMonthly)
    }
}
