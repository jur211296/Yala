//
//  DateIntervalDayCountTests.swift
//  YalaTests
//
//  `undercount-dias-intervalos-cerrados`: contar días sobre un intervalo que cierra en 23:59:59.
//

import Foundation
import Testing

@testable import Yala

struct DateIntervalDayCountTests {

    /// Calendario fijo en la zona del producto. `Calendar.current` en lógica testeada es justo lo que
    /// las reglas del repo prohíben: el resultado dependería de la máquina.
    private static var lima: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima")!
        return c
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0, _ s: Int = 0) -> Date {
        lima.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: mi, second: s))!
    }

    // MARK: - El defecto

    /// Enero tiene 31 días. Cerrado en 23:59:59 —como lo deja el `-1 s` que evita el doble conteo del
    /// borde— `dateComponents` a pelo devuelve 30, y ese 30 es el DENOMINADOR de los promedios diarios.
    @Test func closedInterval_countsItsLastDay() {
        let enero = DateInterval(
            start: Self.date(2026, 1, 1),
            end: Self.date(2026, 1, 31, 23, 59, 59)
        )
        #expect(DateIntervalDayCount.days(in: enero, calendar: Self.lima) == 31)

        // La forma vieja, para que quede escrito de qué se está protegiendo:
        let sinNormalizar = Self.lima.dateComponents([.day], from: enero.start, to: enero.end).day
        #expect(sinNormalizar == 30)
    }

    /// **La aserción que sostiene el diseño entero.** Si sumar un segundo estropeara los intervalos que
    /// cierran a medianoche, el helper necesitaría una guarda y habría que saber en cada call-site qué
    /// tipo de período llega. No la necesita: `dateComponents` trunca, así que el +1 s cae dentro del
    /// mismo día y el conteo no cambia.
    @Test func openInterval_isUnaffectedByTheNormalization() {
        // Febrero de 2026 como lo devuelve `Calendar.dateInterval(of: .month)`: end = 1 de marzo 00:00.
        let febrero = DateInterval(
            start: Self.date(2026, 2, 1),
            end: Self.date(2026, 3, 1)
        )
        #expect(DateIntervalDayCount.days(in: febrero, calendar: Self.lima) == 28)

        let sinNormalizar = Self.lima.dateComponents([.day], from: febrero.start, to: febrero.end).day
        #expect(sinNormalizar == 28, "Éste ya era correcto: el helper no puede empeorarlo.")
    }

    /// Un año cerrado: 365 contados como 364 sesga la comparación interanual.
    @Test func closedYear_countsAllItsDays() {
        let año = DateInterval(
            start: Self.date(2025, 1, 1),
            end: Self.date(2025, 12, 31, 23, 59, 59)
        )
        #expect(DateIntervalDayCount.days(in: año, calendar: Self.lima) == 365)
    }

    /// Un solo día cerrado es 1, no 0 — y un 0 como denominador es una división por cero esperando.
    @Test func singleClosedDay_isOneDayNotZero() {
        let hoy = DateInterval(
            start: Self.date(2026, 3, 15),
            end: Self.date(2026, 3, 15, 23, 59, 59)
        )
        #expect(DateIntervalDayCount.days(in: hoy, calendar: Self.lima) == 1)
    }

    /// Intervalo de duración cero: 0, sin normalizar hacia arriba. Es el caso que separa «un día» de
    /// «nada», y sin él un `max(1, …)` en el call-site taparía el error en vez de exponerlo.
    @Test func emptyInterval_isZero() {
        let instante = Self.date(2026, 3, 15, 12)
        #expect(DateIntervalDayCount.days(from: instante, to: instante, calendar: Self.lima) == 0)
    }

    /// Un mes con cambio de horario no rompe el conteo: se cuenta en días de calendario, no en
    /// múltiplos de 86 400 s. Lima no tiene DST, así que se prueba con una zona que sí.
    @Test func daylightSavingMonth_isStillCountedInCalendarDays() {
        var madrid = Calendar(identifier: .gregorian)
        madrid.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let marzo = DateInterval(
            start: madrid.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
            end: madrid.date(from: DateComponents(
                year: 2026, month: 3, day: 31, hour: 23, minute: 59, second: 59))!
        )
        #expect(DateIntervalDayCount.days(in: marzo, calendar: madrid) == 31)
    }
}
