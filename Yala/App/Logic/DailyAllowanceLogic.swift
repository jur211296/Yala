//
//  DailyAllowanceLogic.swift
//  Yala
//
//  «Cuánto puedo gastar hoy» (2.3): el cupo del día de un presupuesto, que baja con cada gasto de hoy.
//
//  La cuenta: lo que quedaba del presupuesto al EMPEZAR el día se reparte entre los días que faltan (hoy incluido), y a
//  esa parte se le resta lo gastado hoy. Así el cupo de hoy no se mueve por lo que gastes hoy —solo baja lo que te
//  queda de él—, y mañana se recalcula con lo que de verdad quedó.
//
//  «Lo que quedaba al empezar el día» es el límite menos todo lo gastado en el período FUERA de hoy: lo de días
//  anteriores y también lo ya apuntado para días posteriores del período (un alquiler fechado el 30 ya está
//  comprometido). Con eso, cupo × días − gastado hoy es exactamente el «Te quedan» de la fila.
//

import Foundation

enum DailyAllowanceLogic {

    enum State: Equatable {
        /// Lo que aún puedes gastar hoy (0 si lo gastaste justo).
        case available(Double)
        /// Hoy gastaste más que tu cupo del día, por esta cantidad.
        case overToday(Double)
    }

    /// `nil` cuando no hay cupo que enseñar: período cerrado o que no empieza (`daysRemaining <= 0`), presupuesto sin
    /// límite, o el presupuesto ya agotado —antes de hoy o con lo de hoy—. Agotado, la fila ya lo dice con «Te pasaste
    /// por» / «Te quedan S/ 0.00», y un segundo «te pasaste» con otra cifra en la misma tarjeta la contradiría.
    static func state(limit: Double, spent: Double, spentToday: Double, daysRemaining: Int) -> State? {
        guard daysRemaining > 0, limit > 0 else { return nil }
        guard BudgetRemainingLogic.remaining(limit: limit, spent: spent) > 0 else { return nil }
        let today = max(0, spentToday)
        // Con lo que queda > 0 y lo de hoy ≥ 0, esto es siempre positivo: no hay división entre nada raro.
        let leftAtStartOfDay = limit - (spent - today)
        let allowance = leftAtStartOfDay / Double(daysRemaining)
        let left = allowance - today
        // Medio céntimo de holgura, como `BudgetRemainingLogic.remaining`: una conversión deja «0.004».
        if abs(left) < halfCent { return .available(0) }
        return left > 0 ? .available(left) : .overToday(-left)
    }

    /// El intervalo de HOY dentro del período del presupuesto: `[inicio de hoy, último segundo de hoy]` recortado al
    /// período. `nil` si hoy no cae dentro.
    static func todayInterval(in period: DateInterval, now: Date, calendar: Calendar) -> DateInterval? {
        guard period.contains(now) else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        // `startOfDay`: donde el cambio de hora se salta la medianoche (America/Santiago), sumar un día a un inicio a las
        // 01:00 da las 01:00 de mañana, y lo fechado mañana a las 00:00 contaría como de hoy.
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            .map { calendar.startOfDay(for: $0) } ?? startOfToday
        let today = BudgetPeriodInterval.closing(start: startOfToday, nextStart: startOfTomorrow, calendar: calendar)
        let start = max(today.start, period.start)
        let end = min(today.end, period.end)
        guard end >= start else { return nil }
        return DateInterval(start: start, end: end)
    }

    private static let halfCent = 0.005
}
