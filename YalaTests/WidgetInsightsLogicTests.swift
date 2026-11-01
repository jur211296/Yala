//
//  WidgetInsightsLogicTests.swift
//  YalaTests
//
//  Lo que los widgets rediseñados en 2.2 deducen de la foto del App Group (`WidgetInsightsLogic`, compartido con la
//  extensión por membership exception): variación del saldo, gasto contra el período anterior a la misma fecha, ritmo
//  de un presupuesto, cuándo vence un pago y la cifra compacta de la pantalla bloqueada.
//

import Foundation
import Testing

@testable import Yala

struct WidgetInsightsLogicTests {

    /// Lima, lunes primero: el calendario no depende del simulador.
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    // MARK: - Saldo

    @Test func balanceChange_usaElCierreDelDiaAnteriorAlInicio() {
        let closings = [
            (date: Self.day(2026, 9, 29, hour: 0), balance: 900.0),
            (date: Self.day(2026, 9, 30, hour: 0), balance: 1_000.0),
            (date: Self.day(2026, 10, 1, hour: 0), balance: 1_100.0),
            (date: Self.day(2026, 10, 15, hour: 0), balance: 700.0),
        ]
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        // El 30 de setiembre cerró en 1000: el día 1, que ya es del período, no es la base.
        #expect(WidgetInsightsLogic.balanceChange(balance: 820, closings: closings, periodStart: start) == -180)
    }

    @Test func balanceChange_sinCurvaAntesDelInicio_noHayVariacion() {
        let closings = [(date: Self.day(2026, 10, 3, hour: 0), balance: 500.0)]
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        #expect(WidgetInsightsLogic.balanceChange(balance: 600, closings: closings, periodStart: start) == nil)
    }

    @Test func balanceChange_noDependeDelOrdenDeLosPuntos() {
        let closings = [
            (date: Self.day(2026, 9, 30, hour: 0), balance: 1_000.0),
            (date: Self.day(2026, 9, 1, hour: 0), balance: 50.0),
        ]
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        #expect(WidgetInsightsLogic.balanceChange(balance: 1_200, closings: closings, periodStart: start) == 200)
    }

    // MARK: - Gasto contra el período anterior

    @Test func spendingComparison_cuentaElAnteriorHastaElMismoDia() throws {
        let previous = [
            (date: Self.day(2026, 9, 1, hour: 0), expense: 100.0),
            (date: Self.day(2026, 9, 10, hour: 0), expense: 200.0),
            (date: Self.day(2026, 9, 11, hour: 0), expense: 400.0),
            (date: Self.day(2026, 9, 25, hour: 0), expense: 1_000.0),
        ]
        let result = try #require(WidgetInsightsLogic.spendingComparison(
            current: 450,
            previousDaily: previous,
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 10, 1)),
            now: Self.day(2026, 10, 10, hour: 23),
            calendar: Self.calendar
        ))
        // Hasta el día 10 incluido: 100 + 200. El 11 y el 25 quedan fuera.
        #expect(result.previousToDate == 300)
        #expect(result.change == 150)
        #expect(result.fraction == 0.5)
    }

    @Test func spendingComparison_unMesAnteriorMasCortoCuentaEntero() throws {
        let previous = [
            (date: Self.day(2026, 2, 3, hour: 0), expense: 80.0),
            (date: Self.day(2026, 2, 28, hour: 0), expense: 20.0),
        ]
        let result = try #require(WidgetInsightsLogic.spendingComparison(
            current: 50,
            previousDaily: previous,
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 2, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 3, 1)),
            now: Self.day(2026, 3, 31),
            calendar: Self.calendar
        ))
        #expect(result.previousToDate == 100)
        #expect(result.change == -50)
    }

    @Test func spendingComparison_sinDatosDelAnterior_noCompara() {
        #expect(WidgetInsightsLogic.spendingComparison(
            current: 50,
            previousDaily: [],
            previousStart: Self.day(2026, 9, 1),
            currentStart: Self.day(2026, 10, 1),
            now: Self.day(2026, 10, 5),
            calendar: Self.calendar
        ) == nil)
    }

    /// La app rellena con ceros cada día del mes anterior aunque no hubiera nada (`buildCashFlowByDay`): eso tampoco es
    /// «tener datos». Con el `isEmpty` de la primera versión salía «En setiembre a esta fecha: S/ 0» a quien empezaba.
    @Test func spendingComparison_unAnteriorRellenoDeCeros_noCompara() {
        let zeros = (1...30).map { (date: Self.day(2026, 9, $0, hour: 0), expense: 0.0) }
        #expect(WidgetInsightsLogic.spendingComparison(
            current: 50,
            previousDaily: zeros,
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 10, 1)),
            now: Self.day(2026, 10, 5),
            calendar: Self.calendar
        ) == nil)
    }

    @Test func spendingComparison_sinGastoEntonces_noHayProporcion() throws {
        let result = try #require(WidgetInsightsLogic.spendingComparison(
            current: 50,
            previousDaily: [(date: Self.day(2026, 9, 28, hour: 0), expense: 10.0)],
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 10, 1)),
            now: Self.day(2026, 10, 5),
            calendar: Self.calendar
        ))
        #expect(result.previousToDate == 0)
        #expect(result.fraction == nil)
    }

    // MARK: - Entradas y salidas

    /// Setiembre: cobro el 1 y gastos el 2, el 10 y el 20 (este último, después del corte del día 15).
    private static var septemberFlow: [(date: Date, income: Double, expense: Double)] {
        [
            (date: day(2026, 9, 1, hour: 0), income: 5_000, expense: 0),
            (date: day(2026, 9, 2, hour: 0), income: 0, expense: 300),
            (date: day(2026, 9, 10, hour: 0), income: -100, expense: 700),  // una devolución resta de su lado
            (date: day(2026, 9, 20, hour: 0), income: 0, expense: 2_000),
        ]
    }

    @Test func flowComparison_cuentaElNetoDelAnteriorHastaElMismoDia() throws {
        let result = try #require(WidgetInsightsLogic.flowComparison(
            currentNet: 3_000,
            previousDaily: Self.septemberFlow,
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 10, 1)),
            now: Self.day(2026, 10, 15, hour: 20),
            calendar: Self.calendar))
        // Hasta el 15 de setiembre incluido: 5000 − 100 − 300 − 700 = 3900. El gasto del 20 no entra.
        #expect(result.previousNetToDate == 3_900)
        #expect(result.change == -900)
    }

    @Test func flowComparison_elUltimoDiaDelCorteEntra_yElSiguienteNo() throws {
        let previous = [
            (date: Self.day(2026, 9, 15, hour: 0), income: 0.0, expense: 100.0),
            (date: Self.day(2026, 9, 16, hour: 0), income: 0.0, expense: 1_000.0),
        ]
        let result = try #require(WidgetInsightsLogic.flowComparison(
            currentNet: 0, previousDaily: previous,
            previousStart: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            currentStart: Self.calendar.startOfDay(for: Self.day(2026, 10, 1)),
            now: Self.day(2026, 10, 15, hour: 0), calendar: Self.calendar))
        #expect(result.previousNetToDate == -100)
        #expect(result.change == 100)
    }

    @Test func flowComparison_unAnteriorRellenoDeCeros_noCompara() {
        let zeros = (1...30).map { (date: Self.day(2026, 9, $0, hour: 0), income: 0.0, expense: 0.0) }
        #expect(WidgetInsightsLogic.flowComparison(
            currentNet: 100, previousDaily: zeros,
            previousStart: Self.day(2026, 9, 1), currentStart: Self.day(2026, 10, 1),
            now: Self.day(2026, 10, 10), calendar: Self.calendar) == nil)
    }

    @Test func flowComparison_soloConIngresosEntonces_siCompara() throws {
        let previous = [(date: Self.day(2026, 9, 1, hour: 0), income: 800.0, expense: 0.0)]
        let result = try #require(WidgetInsightsLogic.flowComparison(
            currentNet: 1_000, previousDaily: previous,
            previousStart: Self.day(2026, 9, 1), currentStart: Self.day(2026, 10, 1),
            now: Self.day(2026, 10, 10), calendar: Self.calendar))
        #expect(result.change == 200)
    }

    @Test func flowBuckets_porDia_ocupaElPeriodoEnteroConLosDiasPorLlegarEnCero() {
        let buckets = WidgetInsightsLogic.flowBuckets(
            Self.septemberFlow,
            start: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)),
            end: Self.day(2026, 9, 30, hour: 23),
            byMonth: false, calendar: Self.calendar)
        #expect(buckets.count == 30)
        #expect(buckets[0].income == 5_000)
        #expect(buckets[9].income == -100 && buckets[9].expense == 700)
        #expect(buckets[19].expense == 2_000)
        #expect(buckets[29].income == 0 && buckets[29].expense == 0)
    }

    @Test func flowBuckets_porMes_sumaCadaMesYDejaFueraLoDeOtroAnio() {
        let points = [
            (date: Self.day(2025, 12, 31, hour: 0), income: 9.0, expense: 9.0),
            (date: Self.day(2026, 1, 3, hour: 0), income: 100.0, expense: 10.0),
            (date: Self.day(2026, 1, 31, hour: 0), income: 0.0, expense: 40.0),
            (date: Self.day(2026, 3, 1, hour: 0), income: 0.0, expense: 5.0),
        ]
        let buckets = WidgetInsightsLogic.flowBuckets(
            points,
            start: Self.calendar.startOfDay(for: Self.day(2026, 1, 1)),
            end: Self.day(2026, 12, 31, hour: 23),
            byMonth: true, calendar: Self.calendar)
        #expect(buckets.count == 12)
        #expect(buckets[0].income == 100 && buckets[0].expense == 50)
        #expect(buckets[1].income == 0 && buckets[1].expense == 0)
        #expect(buckets[2].expense == 5)
    }

    @Test func flowBuckets_porMes_desdeMitadDeMes_cuentaElMesDelInicio() {
        // «Todo el tiempo» arranca el día del primer movimiento: del 15 de marzo al 1 de octubre son 8 meses, no 7.
        let points = [
            (date: Self.day(2026, 3, 20, hour: 0), income: 10.0, expense: 0.0),
            (date: Self.day(2026, 4, 2, hour: 0), income: 20.0, expense: 0.0),
            (date: Self.day(2026, 10, 1, hour: 0), income: 0.0, expense: 30.0),
        ]
        let buckets = WidgetInsightsLogic.flowBuckets(
            points, start: Self.calendar.startOfDay(for: Self.day(2026, 3, 15)), end: Self.day(2026, 10, 1, hour: 20),
            byMonth: true, calendar: Self.calendar)
        #expect(buckets.count == 8)
        #expect(buckets[0].income == 10)
        #expect(buckets[1].income == 20)
        #expect(buckets[7].expense == 30)
    }

    @Test func flowBuckets_loPosteriorAlFinNoEntra() {
        let points = [
            (date: Self.day(2026, 9, 30, hour: 0), income: 0.0, expense: 5.0),
            (date: Self.day(2026, 10, 1, hour: 0), income: 0.0, expense: 999.0),
        ]
        let buckets = WidgetInsightsLogic.flowBuckets(
            points, start: Self.calendar.startOfDay(for: Self.day(2026, 9, 1)), end: Self.day(2026, 9, 30, hour: 23),
            byMonth: false, calendar: Self.calendar)
        #expect(buckets.count == 30)
        #expect(buckets.reduce(0) { $0 + $1.expense } == 5)
    }

    @Test func flowChartRange_apilaCadaDiaYMiraLasDevoluciones() {
        // Día 1: cobro 800 y devolución de 600 (gasto −600: su barra sube y se apila sobre el ingreso).
        // Día 2: gasto 300. Día 3: devolución sin ingresos.
        let buckets = [(income: 800.0, expense: -600.0), (income: 0.0, expense: 300.0), (income: 0.0, expense: -50.0)]
        #expect(WidgetInsightsLogic.flowChartRange(buckets, expensesUp: false) == -300...1_400)
        // En «Solo gastos» lo gastado sube y la devolución baja.
        #expect(WidgetInsightsLogic.flowChartRange(
            [(income: 0, expense: 300), (income: 0, expense: -50)], expensesUp: true) == -50...300)
        #expect(WidgetInsightsLogic.flowChartRange([], expensesUp: false) == -1...1)
    }

    @Test func daysElapsed_cuentaLosDosExtremos() {
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        #expect(WidgetInsightsLogic.daysElapsed(from: start, to: Self.day(2026, 10, 1, hour: 0), calendar: Self.calendar) == 1)
        #expect(WidgetInsightsLogic.daysElapsed(from: start, to: Self.day(2026, 10, 31, hour: 23), calendar: Self.calendar) == 31)
        // Un período que cierra a las 23:59:59 no pierde su último día.
        let endOfOctober = Self.calendar.startOfDay(for: Self.day(2026, 11, 1)).addingTimeInterval(-1)
        #expect(WidgetInsightsLogic.daysElapsed(from: start, to: endOfOctober, calendar: Self.calendar) == 31)
    }

    @Test func cumulativeByDay_acumulaYRepiteLosDiasSinMovimientos() {
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        let daily = [
            (date: Self.day(2026, 10, 1, hour: 0), value: 10.0),
            (date: Self.day(2026, 10, 3, hour: 0), value: 5.0),
            (date: Self.day(2026, 10, 3, hour: 0), value: 1.0),
            (date: Self.day(2026, 9, 30, hour: 0), value: 99.0),
            (date: Self.day(2026, 10, 9, hour: 0), value: 99.0),
        ]
        #expect(WidgetInsightsLogic.cumulativeByDay(daily, start: start, days: 4, calendar: Self.calendar) == [10, 10, 16, 16])
    }

    @Test func dailyAverage_enCursoDivideEntreLosDiasQueVan_yPasadoEntreLosQueTuvo() {
        let start = Self.calendar.startOfDay(for: Self.day(2026, 10, 1))
        let end = Self.calendar.startOfDay(for: Self.day(2026, 11, 1)).addingTimeInterval(-1)
        #expect(WidgetInsightsLogic.dailyAverage(total: 300, start: start, end: end, now: Self.day(2026, 10, 10), calendar: Self.calendar) == 30)
        #expect(WidgetInsightsLogic.dailyAverage(total: 310, start: start, end: end, now: Self.day(2026, 12, 5), calendar: Self.calendar) == 10)
    }

    // MARK: - Presupuestos

    @Test func elapsedFraction_mesSemanaYAnio() throws {
        let now = Self.day(2026, 10, 16, hour: 12)
        let month = try #require(WidgetInsightsLogic.elapsedFraction(periodType: "monthly", now: now, calendar: Self.calendar))
        #expect(abs(month - (15.5 / 31)) < 0.0001)
        // Viernes a mediodía con la semana empezando en lunes: 4,5 de 7 días.
        let week = try #require(WidgetInsightsLogic.elapsedFraction(periodType: "weekly", now: now, calendar: Self.calendar))
        #expect(abs(week - (4.5 / 7)) < 0.0001)
        let year = try #require(WidgetInsightsLogic.elapsedFraction(periodType: "yearly", now: now, calendar: Self.calendar))
        #expect(year > 0.78 && year < 0.80)
    }

    @Test func elapsedFraction_unicoODesconocido_noTieneRitmo() {
        #expect(WidgetInsightsLogic.elapsedFraction(periodType: "unique", now: Self.day(2026, 10, 16), calendar: Self.calendar) == nil)
        #expect(WidgetInsightsLogic.elapsedFraction(periodType: "biweekly", now: Self.day(2026, 10, 16), calendar: Self.calendar) == nil)
    }

    @Test(arguments: [(1_800.0, 2_967.0), (800, 800), (3_200, 2_720), (1_800, 1_800.004), (500, 0), (0, 10)])
    func budgetRemaining_esLaMismaCuentaQueLaApp(limit: Double, spent: Double) {
        #expect(WidgetInsightsLogic.budgetRemaining(limit: limit, spent: spent)
                == BudgetRemainingLogic.remaining(limit: limit, spent: spent))
        #expect(WidgetInsightsLogic.budgetIsOver(limit: limit, spent: spent)
                == BudgetRemainingLogic.isOver(limit: limit, spent: spent))
    }

    // MARK: - Fechas

    @Test func dueLabel_cubreCadaCaso() {
        let now = Self.day(2026, 10, 31, hour: 20)
        let due = { (days: Int) in Self.calendar.date(byAdding: .day, value: days, to: Self.day(2026, 10, 31, hour: 9)) ?? now }
        #expect(WidgetInsightsLogic.dueLabel(due: due(3), isOverdue: true, now: now, calendar: Self.calendar) == .overdue)
        #expect(WidgetInsightsLogic.dueLabel(due: due(-1), isOverdue: false, now: now, calendar: Self.calendar) == .overdue)
        #expect(WidgetInsightsLogic.dueLabel(due: due(0), isOverdue: false, now: now, calendar: Self.calendar) == .today)
        #expect(WidgetInsightsLogic.dueLabel(due: due(1), isOverdue: false, now: now, calendar: Self.calendar) == .tomorrow)
        #expect(WidgetInsightsLogic.dueLabel(due: due(2), isOverdue: false, now: now, calendar: Self.calendar) == .inDays(2))
        #expect(WidgetInsightsLogic.dueLabel(due: due(6), isOverdue: false, now: now, calendar: Self.calendar) == .inDays(6))
        #expect(WidgetInsightsLogic.dueLabel(due: due(7), isOverdue: false, now: now, calendar: Self.calendar) == .date)
    }

    @Test func dayLabel_hoyAyerYFecha() {
        let now = Self.day(2026, 10, 31, hour: 8)
        #expect(WidgetInsightsLogic.dayLabel(for: Self.day(2026, 10, 31, hour: 0), now: now, calendar: Self.calendar) == .today)
        #expect(WidgetInsightsLogic.dayLabel(for: Self.day(2026, 10, 30, hour: 23), now: now, calendar: Self.calendar) == .yesterday)
        #expect(WidgetInsightsLogic.dayLabel(for: Self.day(2026, 10, 29), now: now, calendar: Self.calendar) == .date)
    }

    // MARK: - Pantalla bloqueada

    @Test func compactAmount_usaElSeparadorDelIdioma() {
        #expect(WidgetInsightsLogic.compactAmount(79_434.75, locale: Locale(identifier: "es_ES")) == "79,4K")
        #expect(WidgetInsightsLogic.compactAmount(79_434.75, locale: Locale(identifier: "en_US")) == "79.4K")
        #expect(WidgetInsightsLogic.compactAmount(1_234_567, locale: Locale(identifier: "de_DE")) == "1,2M")
        #expect(WidgetInsightsLogic.compactAmount(950, locale: Locale(identifier: "es_ES")) == "950")
        #expect(WidgetInsightsLogic.compactAmount(-1_500, locale: Locale(identifier: "en_US")) == "-1.5K")
        #expect(WidgetInsightsLogic.compactAmount(9_000, locale: Locale(identifier: "en_US")) == "9K")
    }

    @Test func compactAmount_noEscribeMilKNiMilUnidades() {
        #expect(WidgetInsightsLogic.compactAmount(999_960, locale: Locale(identifier: "en_US")) == "1M")
        #expect(WidgetInsightsLogic.compactAmount(999.6, locale: Locale(identifier: "en_US")) == "1K")
        #expect(WidgetInsightsLogic.compactAmount(999.4, locale: Locale(identifier: "en_US")) == "999")
    }
}
