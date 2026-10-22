//
//  BudgetPeriodInterval.swift
//  Yala
//
//  El periodo de un presupuesto y los días que le quedan, en UN sitio.
//
//  `DateInterval` es cerrado en los dos extremos: un periodo construido con `end` = inicio del
//  periodo siguiente cuenta ese instante en los dos. Un gasto del 1 de octubre sin hora (el
//  selector de fecha lo guarda a las 00:00) entraba en el presupuesto de octubre y también en el
//  de septiembre, y lo mismo con el lunes siguiente y el 1 de enero. Aquí todo periodo cierra en
//  el último segundo de su último día (regla «Cálculos con fechas» del `CLAUDE.md`).
//
//  Decisión de Jürgen (2026-09-06): el último día de un presupuesto todavía cuenta, así que le
//  queda 1 día, no 0.
//

import Foundation

enum BudgetPeriodInterval {

    // MARK: - Periodos

    /// `[start, nextStart − 1 s]`. Si `nextStart` no es posterior a `start` (un calendario que no
    /// supo sumar), devuelve un intervalo de duración cero en vez de lanzar.
    static func closing(start: Date, nextStart: Date, calendar: Calendar) -> DateInterval {
        guard nextStart > start else { return DateInterval(start: start, duration: 0) }
        let end = calendar.date(byAdding: .second, value: -1, to: nextStart) ?? nextStart.addingTimeInterval(-1)
        return DateInterval(start: start, end: max(start, end))
    }

    /// Cierra un intervalo que acaba en la medianoche del periodo siguiente, como los que devuelve
    /// `Calendar.dateInterval(of:for:)`. Uno que ya cierra en otro instante (23:59:59, un único) se
    /// devuelve tal cual: restarle el segundo le quitaría un instante real.
    static func closing(_ interval: DateInterval, calendar: Calendar) -> DateInterval {
        guard calendar.startOfDay(for: interval.end) == interval.end else { return interval }
        return closing(start: interval.start, nextStart: interval.end, calendar: calendar)
    }

    static func week(startingAt weekStart: Date, calendar: Calendar) -> DateInterval {
        // `startOfDay`: donde el cambio de horario se salta la medianoche (America/Santiago), el
        // lunes siguiente puede empezar a la 01:00 y sumar 7 días daría esa hora, no su inicio.
        let next = calendar.date(byAdding: .day, value: 7, to: weekStart).map { calendar.startOfDay(for: $0) } ?? weekStart
        return closing(start: weekStart, nextStart: next, calendar: calendar)
    }

    static func month(startingAt monthStart: Date, calendar: Calendar) -> DateInterval {
        let next = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        return closing(start: monthStart, nextStart: next, calendar: calendar)
    }

    /// `fallbackStart` es lo que usaban los llamadores si el calendario no sabía construir el 1 de enero.
    static func year(_ year: Int, calendar: Calendar, fallbackStart: Date) -> DateInterval {
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? fallbackStart
        let next = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? start
        return closing(start: start, nextStart: next, calendar: calendar)
    }

    /// Presupuesto único: el editor solo deja elegir el DÍA de inicio y de fin, y los dos cuentan
    /// enteros, como en el conector de Claude. Lo guardado puede llevar cualquier hora (el valor
    /// inicial del editor es `Date.now`), y la hora no decide nada.
    static func unique(start: Date, end: Date, calendar: Calendar) -> DateInterval {
        let firstDay = calendar.startOfDay(for: start)
        let lastDay = calendar.startOfDay(for: end)
        let next = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return closing(start: firstDay, nextStart: next, calendar: calendar)
    }

    /// El periodo EN CURSO del presupuesto. Lo comparten el Panel, Insights (y con él el chat) y
    /// los avisos de umbral; Presupuestos usa las piezas de arriba con el periodo que tenga elegido.
    static func current(for budget: Budget, now: Date, calendar: Calendar) -> DateInterval {
        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            return month(startingAt: calendar.startOfMonth(for: now), calendar: calendar)
        }
        switch periodType {
        case .weekly:
            return week(startingAt: calendar.startOfWeek(for: now), calendar: calendar)
        case .monthly:
            return month(startingAt: calendar.startOfMonth(for: now), calendar: calendar)
        case .yearly:
            return year(calendar.component(.year, from: now), calendar: calendar, fallbackStart: now)
        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                return month(startingAt: calendar.startOfMonth(for: now), calendar: calendar)
            }
            return unique(start: start, end: end, calendar: calendar)
        }
    }

    // MARK: - Días que quedan

    /// Días que le quedan al periodo contando HOY: 1 si acaba hoy, 2 si acaba mañana, 0 si ya acabó.
    /// Dentro del periodo nunca devuelve 0, así que un promedio diario puede dividir entre él.
    static func daysLeft(now: Date, in interval: DateInterval, calendar: Calendar) -> Int {
        guard now <= interval.end else { return 0 }
        let today = calendar.startOfDay(for: now)
        let lastDay = calendar.startOfDay(for: interval.end)
        let between = calendar.dateComponents([.day], from: today, to: lastDay).day ?? 0
        return max(0, between) + 1
    }

    /// Lo que pinta la fila de un presupuesto (`BudgetSummary.daysRemaining`): `-1` si el periodo ya
    /// acabó («Finalizado»), `0` si aún no empieza, y si está en curso, `daysLeft`.
    static func summaryDaysRemaining(now: Date, in interval: DateInterval, calendar: Calendar) -> Int {
        if now > interval.end { return -1 }
        guard interval.contains(now) else { return 0 }
        return daysLeft(now: now, in: interval, calendar: calendar)
    }
}
