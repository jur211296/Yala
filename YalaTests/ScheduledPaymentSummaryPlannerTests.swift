//
//  ScheduledPaymentSummaryPlannerTests.swift
//  YalaTests
//
//  Tabla del planner del canal AGENDADO (decisión owner D1, 2026-07-22): qué días de la
//  ventana [hoy, hoy+14) reciben summary y con qué conteo. Mutante que debe cazar:
//  quitar el filtro de fechas skipped (o el cruce de mes de la ventana).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentSummaryPlannerTests {

    private typealias Planner = ScheduledPaymentSummaryPlanner

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Pago mensual simple con vencimiento fijo.
    private func monthlyInput(
        dueDate: Date,
        notifyOnDueDate: Bool = true,
        skippedDates: [Date] = [],
        createdAt: Date? = nil
    ) -> Planner.PaymentInput {
        let params = ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: dueDate,
            createdAt: createdAt ?? date(2025, 1, 1),
            endDate: nil,
            dayOfMonth: calendar.component(.day, from: dueDate),
            selectedWeekdays: nil,
            yearlyMonth: nil,
            yearlyDay: nil
        )
        return Planner.PaymentInput(
            params: params,
            notifyOnDueDate: notifyOnDueDate,
            skippedDateKeys: Set(skippedDates.map { ScheduledPayment.dateKey(for: $0) })
        )
    }

    private func dailyInput(anchor: Date) -> Planner.PaymentInput {
        let params = ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: true,
            recurrenceType: "daily",
            recurrenceInterval: 1,
            nextDueDate: anchor,
            createdAt: date(2025, 1, 1),
            endDate: nil,
            dayOfMonth: nil,
            selectedWeekdays: nil,
            yearlyMonth: nil,
            yearlyDay: nil
        )
        return Planner.PaymentInput(
            params: params, notifyOnDueDate: true, skippedDateKeys: []
        )
    }

    // Ahora fijo: 15 de julio de 2026, 08:00 (hora configurada default de los tests: 09:00).
    private var now: Date { date(2026, 7, 15, hour: 8) }

    private func plan(_ payments: [Planner.PaymentInput], now: Date? = nil, hour: Int = 9) -> [Planner.DayPlan] {
        Planner.plan(payments: payments, hour: hour, minute: 0, now: now ?? self.now, calendar: calendar)
    }

    // MARK: - Casos base

    @Test func singleDueTomorrow_plansOneDay() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 16))])
        #expect(plans.count == 1)
        #expect(plans.first?.dayKey == "20260716")
        #expect(plans.first?.count == 1)
        #expect(plans.first?.fireDate == date(2026, 7, 16, hour: 9))
    }

    @Test func twoPaymentsSameDay_aggregateCount() {
        let plans = plan([
            monthlyInput(dueDate: date(2026, 7, 20)),
            monthlyInput(dueDate: date(2026, 7, 20)),
        ])
        #expect(plans.count == 1)
        #expect(plans.first?.count == 2)
    }

    @Test func daysWithoutPayments_absentFromPlan() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 20))])
        #expect(plans.map(\.dayKey) == ["20260720"], "solo días con ocurrencias entran al plan")
    }

    // MARK: - Filtros

    @Test func skippedDate_excluded() {
        let due = date(2026, 7, 20)
        let plans = plan([monthlyInput(dueDate: due, skippedDates: [due])])
        #expect(plans.isEmpty, "una fecha saltada por el usuario no debe generar summary")
    }

    @Test func notifyOnDueDateOff_excluded() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 20), notifyOnDueDate: false)])
        #expect(plans.isEmpty)
    }

    @Test func consumedOccurrences_beforeNextDueDate_excluded() {
        // Pago diario cuya ocurrencia de hoy YA se consumió (aprobación avanzó nextDueDate
        // a mañana): hoy fuera, mañana sigue — nextDueDate es el SSOT de lo pendiente.
        let plans = plan([dailyInput(anchor: date(2026, 7, 16))])
        #expect(!plans.map(\.dayKey).contains("20260715"), "ocurrencia consumida no re-avisa")
        #expect(plans.map(\.dayKey).contains("20260716"), "los días futuros son forecast")
    }

    @Test func paidEarly_monthlyOccurrenceRegenerated_excluded() {
        // Hallazgo 16 del review: pagado por adelantado ⇒ nextDueDate avanzó a agosto, pero
        // el calculador RE-GENERA el 20 de julio por patrón — sin el filtro de consumidas,
        // summary falsa de un pago ya cubierto.
        let plans = plan([monthlyInput(dueDate: date(2026, 8, 20))])
        #expect(!plans.map(\.dayKey).contains("20260720"),
                "la ocurrencia del mes re-generada por patrón está consumida (día < nextDueDate)")
    }

    // MARK: - Hoy y la hora configurada

    @Test func today_beforeConfiguredHour_included() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 15))], now: date(2026, 7, 15, hour: 8))
        #expect(plans.first?.dayKey == "20260715")
    }

    @Test func today_afterConfiguredHour_excluded() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 15))], now: date(2026, 7, 15, hour: 10))
        #expect(plans.isEmpty, "un one-shot con hora pasada jamás dispararía — hoy sale del plan")
    }

    // MARK: - Ventana y cruce de mes

    @Test func windowCrossesMonthBoundary_nextMonthDaysIncluded() {
        // 25-jul + 14 días llega al 7-ago: el vencimiento mensual del día 5 debe entrar.
        let plans = plan(
            [monthlyInput(dueDate: date(2026, 8, 5))],
            now: date(2026, 7, 25, hour: 8)
        )
        #expect(plans.map(\.dayKey).contains("20260805"),
                "la ventana consulta el calculador por CADA mes tocado, no solo el actual")
    }

    @Test func occurrenceBeyondHorizon_excluded() {
        let plans = plan([monthlyInput(dueDate: date(2026, 7, 30))], now: date(2026, 7, 1, hour: 8))
        #expect(plans.isEmpty, "horizonte 14 días: el 30-jul no entra desde el 1-jul")
    }

    @Test func multipleDays_sortedByDayKey() {
        let plans = plan([
            monthlyInput(dueDate: date(2026, 7, 20)),
            dailyInput(anchor: date(2026, 7, 15)),
        ])
        #expect(plans.map(\.dayKey) == plans.map(\.dayKey).sorted())
        // El diario aporta hoy (hora aún no pasa) y cada día de la ventana.
        #expect(plans.first?.dayKey == "20260715")
    }

    @Test func emptyPayments_emptyPlan() {
        #expect(plan([]).isEmpty)
    }
}
