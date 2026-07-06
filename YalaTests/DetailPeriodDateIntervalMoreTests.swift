//
//  DetailPeriodDateIntervalMoreTests.swift
//  YalaTests
//
//  Cobertura ADICIONAL de DetailPeriod.dateInterval() (SharedModels.swift) para
//  los períodos NO cubiertos por DetailPeriodDateIntervalTests (que solo verifica
//  .lastMonth / .lastYear): .thisWeek, .last7Days, .last30Days, .thisYear, .allTime.
//  Boundary de medianoche del fix cd30951e.
//
//  Deterministas vía `now` inyectado. Las fechas esperadas se derivan con el MISMO
//  calendario que usa dateInterval() internamente (userConfiguredCalendar) — que solo
//  difiere de Calendar.current en `firstWeekday` (Monday por defecto). Para month/year
//  eso es irrelevante (Calendar.current basta, como en el test existente); para
//  .thisWeek SÍ importa, así que ahí replicamos userConfiguredCalendar() para no
//  desfasar la igualdad exacta del start-of-week.
//
//  NOTA: los períodos activos (.thisWeek/.last7Days/.last30Days/.thisYear/.allTime)
//  terminan en `endOfToday` = inicio de MAÑANA (start of tomorrow), NO con el ajuste
//  de -1 segundo (ese ajuste solo lo aplican los períodos cerrados .lastMonth/.lastYear).
//  Por eso el "boundary" que se verifica aquí es que el instante compartido con el día
//  siguiente (endOfToday) queda INCLUIDO (DateInterval es cerrado en ambos extremos) y
//  que la medianoche de HOY sí está dentro del intervalo.
//

import Foundation
import Testing

@testable import Yala

struct DetailPeriodDateIntervalMoreTests {

    // MARK: - Fixtures

    /// Reference `now`: 2026-07-15 12:00 (timezone local). Mediodía para evitar
    /// cualquier borde de medianoche/DST. Mes = julio, año = 2026, miércoles.
    private var now: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 15; c.hour = 12
        return Calendar.current.date(from: c)!
    }

    /// Calendario que replica el interno de dateInterval() (firstWeekday desde
    /// UserDefaults.standard, Monday por defecto). Necesario para derivar el
    /// start-of-week esperado igual que la función bajo prueba.
    private var configuredCal: Calendar { userConfiguredCalendar() }

    /// startOfDay(now) — inicio de hoy con el calendario local.
    private var startOfToday: Date { Calendar.current.startOfDay(for: now) }

    /// endOfToday = inicio de mañana (top boundary de todos los períodos activos).
    private var startOfTomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
    }

    // MARK: - .thisWeek

    @Test func dateInterval_thisWeek_startsAtStartOfWeek_endsAtStartOfTomorrow() {
        // El start se deriva con el MISMO calendario configurado (firstWeekday).
        let cal = configuredCal
        let expectedStart = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        let interval = DetailPeriod.thisWeek.dateInterval(now: now)
        #expect(interval.start == expectedStart)
        #expect(interval.end == startOfTomorrow)
    }

    @Test func dateInterval_thisWeek_startIsAtMidnight() {
        // El inicio de semana cae en medianoche (00:00:00), no arrastra la hora de `now`.
        let cal = configuredCal
        let interval = DetailPeriod.thisWeek.dateInterval(now: now)
        let comps = cal.dateComponents([.hour, .minute, .second], from: interval.start)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    @Test func dateInterval_thisWeek_containsNowButNotStartOfNextWeekTop() {
        // `now` cae dentro; el end (inicio de mañana) es el borde superior inclusivo.
        let interval = DetailPeriod.thisWeek.dateInterval(now: now)
        #expect(interval.contains(now))
        #expect(interval.contains(startOfTomorrow))            // cerrado: top incluido
        #expect(interval.contains(startOfToday))               // medianoche de hoy incluida
    }

    // MARK: - .last7Days

    @Test func dateInterval_last7Days_starts7DaysBeforeStartOfToday() {
        let expectedStart = Calendar.current.date(byAdding: .day, value: -7, to: startOfToday)!

        let interval = DetailPeriod.last7Days.dateInterval(now: now)
        #expect(interval.start == expectedStart)
        #expect(interval.end == startOfTomorrow)
    }

    @Test func dateInterval_last7Days_startIsAtMidnight() {
        // El start es startOfDay(-7) → medianoche exacta, sin arrastrar la hora de `now`.
        let cal = Calendar.current
        let interval = DetailPeriod.last7Days.dateInterval(now: now)
        let comps = cal.dateComponents([.hour, .minute, .second], from: interval.start)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    // MARK: - .last30Days

    @Test func dateInterval_last30Days_starts30DaysBeforeStartOfToday() {
        let expectedStart = Calendar.current.date(byAdding: .day, value: -30, to: startOfToday)!

        let interval = DetailPeriod.last30Days.dateInterval(now: now)
        #expect(interval.start == expectedStart)
        #expect(interval.end == startOfTomorrow)
    }

    @Test func dateInterval_last30Days_startIsAtMidnight() {
        let cal = Calendar.current
        let interval = DetailPeriod.last30Days.dateInterval(now: now)
        let comps = cal.dateComponents([.hour, .minute, .second], from: interval.start)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    // MARK: - .thisYear

    @Test func dateInterval_thisYear_startsAtStartOfYear_endsAtStartOfTomorrow() {
        let cal = Calendar.current
        let expectedStart = cal.date(from: cal.dateComponents([.year], from: now))!

        let interval = DetailPeriod.thisYear.dateInterval(now: now)
        #expect(interval.start == expectedStart)
        #expect(interval.end == startOfTomorrow)
    }

    @Test func dateInterval_thisYear_startIsJanuaryFirstAtMidnight() {
        let cal = Calendar.current
        let interval = DetailPeriod.thisYear.dateInterval(now: now)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: interval.start)
        #expect(comps.year == 2026)
        #expect(comps.month == 1)
        #expect(comps.day == 1)
        #expect(comps.hour == 0)
        #expect(comps.minute == 0)
        #expect(comps.second == 0)
    }

    // MARK: - .allTime

    @Test func dateInterval_allTime_starts10YearsBeforeNow_endsAtStartOfTomorrow() {
        // El start es `now - 10 años` (NO startOfDay: la función usa `now` directo aquí).
        let expectedStart = Calendar.current.date(byAdding: .year, value: -10, to: now)!

        let interval = DetailPeriod.allTime.dateInterval(now: now)
        #expect(interval.start == expectedStart)
        #expect(interval.end == startOfTomorrow)
    }

    @Test func dateInterval_allTime_spansAtLeastTenYears() {
        let interval = DetailPeriod.allTime.dateInterval(now: now)
        // Contiene una fecha claramente vieja (hace ~9 años) y el `now`.
        let nineYearsAgo = Calendar.current.date(byAdding: .year, value: -9, to: now)!
        #expect(interval.contains(nineYearsAgo))
        #expect(interval.contains(now))
    }

    // MARK: - Boundary compartido con el día siguiente (medianoche)

    @Test func dateInterval_activePeriods_shareStartOfTomorrowAsInclusiveEnd() {
        // Todos los períodos activos terminan EXACTAMENTE en el inicio de mañana
        // (medianoche del día siguiente), no en `now` ni con ajuste de -1s.
        // Ese instante es el borde superior inclusivo (DateInterval cerrado).
        let periods: [DetailPeriod] = [.thisWeek, .last7Days, .last30Days, .thisYear, .allTime]
        for p in periods {
            let interval = p.dateInterval(now: now)
            #expect(interval.end == startOfTomorrow)
            #expect(interval.contains(now))
        }
    }
}
