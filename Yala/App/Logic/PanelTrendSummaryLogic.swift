//
//  PanelTrendSummaryLogic.swift
//  Yala
//
//  La gráfica de saldo del Panel dice con palabras lo que compara (decisión 11 de la revisión 2.3, opción A + B):
//  el chip nombra la fecha del período anterior («+10.3 % vs 20 oct») y, debajo de la gráfica, una fila dice de dónde
//  partió el saldo y dónde está («1 nov S/ 68,203 → hoy S/ 64,690 · −5.2 %»). La escala no se toca: el eje sigue sin
//  arrancar en cero (opción C descartada); la fila da el tamaño real del cambio sin que haya que leer el eje.
//

import Foundation

enum PanelTrendSummaryLogic {

    /// De dónde partió la curva del período y dónde está.
    struct StartEnd: Equatable {
        let startDate: Date
        let startValue: Double
        let endDate: Date
        let endValue: Double
        /// El final es el saldo de hoy (el período lo cubre): la fila dice «hoy» en vez de la fecha.
        let endIsToday: Bool
        /// El cambio en %, contra el valor de partida. `nil` si se partió de 0 (no hay porcentaje que valga).
        let variation: Double?
    }

    /// La fila de inicio y fin. El final es el saldo vivo cuando el período cubre hoy (`liveAnchor`, la misma cifra que
    /// la cabecera de la tarjeta); si no, el último punto que no pasa de hoy. Con un solo día no hay recorrido que
    /// contar y no sale nada: la gráfica se queda con su punto suelto (decisión 10).
    static func startEnd(
        rawPoints: [BarPoint],
        liveAnchor: BarPoint?,
        today: Date,
        calendar: Calendar
    ) -> StartEnd? {
        guard let first = rawPoints.first else { return nil }
        let startOfToday = calendar.startOfDay(for: today)
        let end: BarPoint
        let endIsToday: Bool
        if let liveAnchor {
            end = liveAnchor
            endIsToday = true
        } else {
            guard let last = rawPoints.last(where: { calendar.startOfDay(for: $0.date) <= startOfToday }) else {
                return nil
            }
            end = last
            endIsToday = calendar.isDate(last.date, inSameDayAs: today)
        }
        guard calendar.startOfDay(for: end.date) > calendar.startOfDay(for: first.date) else { return nil }
        return StartEnd(
            startDate: first.date,
            startValue: first.value,
            endDate: end.date,
            endValue: end.value,
            endIsToday: endIsToday,
            variation: PreviousPeriodHelper.calculateVariation(currentAmount: end.value, previousAmount: first.value)
        )
    }

    /// Una fecha corta de la gráfica: «20 oct»; con el año si no es el de hoy («20 nov 2025»), para que la comparación
    /// con el año anterior no se lea como de este año.
    static func shortDate(_ date: Date, today: Date, calendar: Calendar, locale: Locale) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: today)
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "dMMM" : "dMMMyyyy")
        return formatter.string(from: date).lowercased().replacing(".", with: "")
    }
}
