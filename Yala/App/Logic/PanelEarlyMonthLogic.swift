//
//  PanelEarlyMonthLogic.swift
//  Yala
//
//  El día 1 del mes el Panel opinaba con un solo día: nota 96, gráfica de un punto y −100 % (PN-3). Decisión 10 de la
//  revisión 2.3, opción E con umbral en el día 3: el período manda siempre —la app nunca lo cambia sola ni enseña otra
//  ventana—. Los días 1 y 2 de «Este mes» el hero dice «Día N de 31» con dos atajos que cambian el selector de verdad
//  («Ver últimos 30 días», «Ver <mes anterior>»), y los porcentajes contra el período anterior no se pintan: solo el
//  monto. La gráfica se queda como está, con su punto suelto.
//

import Foundation

enum PanelEarlyMonthLogic {

    /// Desde este día del mes los porcentajes vuelven y la línea se va.
    static let firstComparableDay = 3

    struct MonthStart: Equatable {
        let day: Int
        let daysInMonth: Int
    }

    /// El día del mes y cuántos tiene, solo los días 1 y 2 de «Este mes»; `nil` en cualquier otro caso.
    static func monthStart(period: DetailPeriod, now: Date, calendar: Calendar) -> MonthStart? {
        guard period == .thisMonth else { return nil }
        let day = calendar.component(.day, from: now)
        guard day < firstComparableDay,
              let days = calendar.range(of: .day, in: .month, for: now)?.count else { return nil }
        return MonthStart(day: day, daysInMonth: days)
    }

    /// Los porcentajes contra el período anterior se ocultan mientras dure la línea del mes recién empezado.
    static func hidesVariations(period: DetailPeriod, now: Date, calendar: Calendar) -> Bool {
        monthStart(period: period, now: now, calendar: calendar) != nil
    }

    /// El nombre del mes anterior para el atajo («Ver octubre»), en el idioma de la app y en su forma de dentro de una
    /// frase: la misma que usa la Comparativa (`ComparativeLabelsLogic.monthName`), con el año si es de otro.
    static func previousMonthName(now: Date, calendar: Calendar, locale: Locale) -> String {
        let previous = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        return ComparativeLabelsLogic.monthName(of: previous, now: now, calendar: calendar, locale: locale).inSentence
    }
}
