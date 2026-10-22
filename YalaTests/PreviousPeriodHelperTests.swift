//
//  PreviousPeriodHelperTests.swift
//  YalaTests
//
//  Unit tests for PreviousPeriodHelper (pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct PreviousPeriodHelperTests {

    // MARK: - isSelectorVisible

    @Test func isSelectorVisible_thisWeek_true() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisWeek) == true)
    }

    @Test func isSelectorVisible_thisMonth_true() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisMonth) == true)
    }

    @Test func isSelectorVisible_thisYear_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisYear) == false)
    }

    @Test func isSelectorVisible_lastYear_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .lastYear) == false)
    }

    @Test func isSelectorVisible_allTime_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .allTime) == false)
    }

    // MARK: - defaultMode

    @Test func defaultMode_thisWeek_month() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisWeek) == .month)
    }

    @Test func defaultMode_thisMonth_month() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisMonth) == .month)
    }

    @Test func defaultMode_thisYear_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisYear) == .year)
    }

    @Test func defaultMode_lastYear_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .lastYear) == .year)
    }

    @Test func defaultMode_allTime_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .allTime) == .year)
    }

    // MARK: - previousInterval

    @Test func previousInterval_thisWeek_month_previousCalendarWeek() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        cal.firstWeekday = 2 // lunes
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 8))! // miércoles
        let interval = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .month, now: now)
        let currentInterval = DetailPeriod.thisWeek.dateInterval(now: now)
        // Semana calendario anterior: no solapa el primer día de esta (F1).
        #expect(interval.end < currentInterval.start)
        let expectedStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentInterval.start)!
        #expect(interval.start == expectedStart)
        let days = interval.duration / 86400
        #expect(days >= 6.9 && days <= 7.1)
    }


    @Test func previousInterval_thisWeek_month_noOverlapCurrentStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        cal.firstWeekday = 2 // lunes
        let now = cal.date(from: DateComponents(year: 2026, month: 7, day: 8))! // miércoles
        let currentInterval = DetailPeriod.thisWeek.dateInterval(now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .month, now: now)
        let mondayMidnight = currentInterval.start
        #expect(!previous.contains(mondayMidnight))
        #expect(currentInterval.contains(mondayMidnight) || mondayMidnight == currentInterval.start)
    }

    @Test func previousInterval_thisMonth_month_previousMonth() {
        // `now` INYECTADO: antes usaba el reloj real, y con el -1s del borde la duración
        // pasa a 27,99999 días cuando el mes previo es febrero => el test sólo se habría
        // puesto rojo en marzo de un año no bisiesto, meses después del cambio.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!  // previo = febrero, 28d
        let interval = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month, now: now)
        let currentInterval = DetailPeriod.thisMonth.dateInterval(now: now)

        #expect(interval.start < currentInterval.start)
        // Días de CALENDARIO, no `duration / 86400`: el intervalo cierra en 23:59:59, así
        // que hay que normalizar el extremo antes de contar o sale uno de menos.
        let dias = cal.dateComponents([.day], from: interval.start, to: interval.end.addingTimeInterval(1)).day
        #expect(dias == 28)   // febrero de 2026
    }

    /// Espejo de `previousInterval_thisWeek_month_noOverlapCurrentStart` para `.thisMonth`.
    /// `DateInterval` es CERRADO en ambos extremos: sin el -1s de la rama, una TX fechada
    /// el día 1 a medianoche —lo que dejan el DatePicker de sólo-fecha y los pagos
    /// programados— caía a la vez en el período actual y en el previo. Medido antes del
    /// fix: contaminaba la columna «anterior» del informe los 730 días barridos.
    @Test func previousInterval_thisMonth_month_noOverlapCurrentStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let currentInterval = DetailPeriod.thisMonth.dateInterval(now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month, now: now)

        let dia1Medianoche = currentInterval.start
        #expect(!previous.contains(dia1Medianoche))
        #expect(currentInterval.contains(dia1Medianoche))
        // Y no deja hueco: el previo cierra justo 1s antes.
        #expect(previous.end == dia1Medianoche.addingTimeInterval(-1))
    }

    /// `.thisYear` el 31-dic: el previo desplazado un año cerraba exactamente en el inicio
    /// del año en curso. Sólo 2 días de 730, pero contaminaba la comparativa interanual.
    @Test func previousInterval_thisYear_year_noOverlapOnDec31() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        let now = cal.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        let currentInterval = DetailPeriod.thisYear.dateInterval(now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: .thisYear, mode: .year, now: now)

        #expect(!previous.contains(currentInterval.start))
    }

    /// El -1s de `sameIntervalPreviousYear` está CONDICIONADO a que el extremo sea
    /// medianoche. Un período CERRADO ya cierra en 23:59:59 y restarle otro segundo le
    /// quitaría un instante real — medido: pasaría los 730 días.
    @Test func previousInterval_lastMonth_year_keepsClosedEndIntact() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima")!
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 15))!
        let currentInterval = DetailPeriod.lastMonth.dateInterval(now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: .lastMonth, mode: .year, now: now)

        let esperado = cal.date(byAdding: .year, value: -1, to: currentInterval.end)!
        #expect(previous.end == esperado)   // sin segundo de más
    }

    @Test func previousInterval_lastMonth_month_twoMonthsAgo_exactBoundaries() {
        let interval = PreviousPeriodHelper.previousInterval(for: .lastMonth, mode: .month)
        let currentInterval = DetailPeriod.lastMonth.dateInterval()
        let cal = Calendar.current

        // Debe empezar exactamente el día 1 del mes (sin drift por anclar en .end)
        #expect(cal.component(.day, from: interval.start) == 1)
        #expect(cal.component(.hour, from: interval.start) == 0)

        // Debe terminar 1 segundo antes de que empiece currentInterval (contigüidad, sin gap ni overlap)
        let expectedEnd = cal.date(byAdding: .second, value: -1, to: currentInterval.start)!
        #expect(interval.end == expectedEnd)
        #expect(interval.start < currentInterval.start)
    }

    @Test func previousInterval_lastYear_year_sameYearAgo_noDrift() {
        let interval = PreviousPeriodHelper.previousInterval(for: .lastYear, mode: .year)
        let currentInterval = DetailPeriod.lastYear.dateInterval()
        let cal = Calendar.current

        // Debe empezar el 1 de enero (sin drift)
        #expect(cal.component(.day, from: interval.start) == 1)
        #expect(cal.component(.month, from: interval.start) == 1)

        // El día/mes del end debe coincidir con el de currentInterval.end (31-dic ambos), solo el año difiere
        let intervalEndComponents = cal.dateComponents([.month, .day], from: interval.end)
        let currentEndComponents = cal.dateComponents([.month, .day], from: currentInterval.end)
        #expect(intervalEndComponents.month == currentEndComponents.month)
        #expect(intervalEndComponents.day == currentEndComponents.day)
    }

    @Test func previousInterval_thisWeek_year_sameWeekLastYear() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .year)
        let cal = Calendar.current
        // Year component should be previous year
        let yearComponent = cal.component(.year, from: interval.start)
        let currentYear = cal.component(.year, from: Date())
        #expect(yearComponent == currentYear - 1)
    }

    @Test func previousInterval_thisMonth_year_sameMonthLastYear() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .year)
        let cal = Calendar.current
        let yearComponent = cal.component(.year, from: interval.start)
        let currentYear = cal.component(.year, from: Date())
        #expect(yearComponent == currentYear - 1)
        // Same month
        let monthComponent = cal.component(.month, from: interval.start)
        let currentMonth = cal.component(.month, from: Date())
        #expect(monthComponent == currentMonth)
    }

    @Test func previousInterval_allTime_returnsSameInterval() {
        let interval = PreviousPeriodHelper.previousInterval(for: .allTime, mode: .month)
        // allTime in month mode returns the same interval (no "previous" concept)
        // Duration should be very long (years worth of seconds)
        #expect(interval.duration > 86400 * 365)
    }

    // MARK: - calculateVariation

    @Test func calculateVariation_increase() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 1200, previousAmount: 1000)
        #expect(result == 20.0)
    }

    @Test func calculateVariation_decrease() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 800, previousAmount: 1000)
        #expect(result == -20.0)
    }

    @Test func calculateVariation_previousZero_nil() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 100, previousAmount: 0)
        #expect(result == nil)
    }

    @Test func calculateVariation_bothZero_nil() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 0, previousAmount: 0)
        #expect(result == nil)
    }

    // MARK: - calculateVariation (caller contract: expenses as positive magnitude)

    @Test func calculateVariation_expenseDoubled_positive100() {
        // Caller passes abs(): 3300→6600 = spent double
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 6600, previousAmount: 3300)
        #expect(result == 100.0)
    }

    @Test func calculateVariation_expenseHalved_negativeFifty() {
        // Caller passes abs(): 6600→3300 = spent half
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 3300, previousAmount: 6600)
        #expect(result == -50.0)
    }

    @Test func calculateVariation_signedNetFlow_worseningDeficit() {
        // Net flow stays signed: -200→-500 = deficit grew
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: -500, previousAmount: -200)
        #expect(result == -150.0)
    }

    // MARK: - formatVariation

    @Test func formatVariation_nil_NA() {
        #expect(PreviousPeriodHelper.formatVariation(nil) == "N/A")
    }

    @Test func formatVariation_positive() {
        let result = PreviousPeriodHelper.formatVariation(12.5)
        #expect(result == "+12.5%")
    }

    @Test func formatVariation_negative() {
        let result = PreviousPeriodHelper.formatVariation(-3.2)
        #expect(result == "-3.2%")
    }

    @Test func formatVariation_zero() {
        let result = PreviousPeriodHelper.formatVariation(0.0)
        #expect(result == "+0%")
    }
}
