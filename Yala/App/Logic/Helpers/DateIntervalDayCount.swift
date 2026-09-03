//
//  DateIntervalDayCount.swift
//  Yala
//
//  Contar los días de un intervalo que puede cerrar en 23:59:59.
//  Ticket `undercount-dias-intervalos-cerrados`.
//

import Foundation

/// Cuenta los días de un `DateInterval` **tolerando que cierre en 23:59:59**.
///
/// **El problema.** `Calendar.dateComponents([.day], from:to:)` cuenta días COMPLETOS y trunca. Los
/// intervalos de este repo que evitan el doble conteo del borde de medianoche cierran restando un
/// segundo (ver «Cálculos con fechas» en `CLAUDE.md`), así que contarlos a pelo devuelve **uno menos**
/// que la longitud real: un mes de 31 días se cuenta como 30. Y como esos conteos son
/// DENOMINADORES de promedios diarios, un día de menos **infla** el promedio.
///
/// Medido sobre `.lastMonth` en el ticket: 0 de 730 días coinciden con la longitud real del mes;
/// normalizando el extremo, 730 de 730.
///
/// **Por qué la normalización es INCONDICIONAL, que era la duda de diseño.** El aviso del `CLAUDE.md`
/// —que en una función compartida por períodos EN CURSO y CERRADOS el `-1 s` no puede aplicarse a
/// ciegas— vale para CONSTRUIR el intervalo, no para contarlo. Aquí es al revés y se puede demostrar:
/// sumar un segundo a un `end` que ya es medianoche **no cambia el conteo**, porque `dateComponents`
/// trunca (`1-feb 00:00 → 1-mar 00:00:01` sigue dando 28). O sea: repara los intervalos cerrados y no
/// toca los sanos, así que no hace falta guarda ni saber de qué tipo es el período. Pinneado en
/// `DateIntervalDayCountTests`.
///
/// **Los cuatro sitios que lo necesitaban** —trazados uno a uno sobre 33 instancias del patrón, de las
/// que 28 resultaron sanas— son `WeekdaySpendingCalculator`, `InsightsCalculator`,
/// `FullFinancialContextBuilder` y el umbral de `WidgetDataCache`. Al añadir un promedio diario nuevo,
/// usa esto en vez de `dateComponents` a pelo.
enum DateIntervalDayCount {

    /// Días del intervalo, contando el último aunque cierre a las 23:59:59.
    ///
    /// Devuelve `0` para un intervalo de duración cero, y nunca negativo.
    static func days(in interval: DateInterval, calendar: Calendar = .current) -> Int {
        days(from: interval.start, to: interval.end, calendar: calendar)
    }

    /// Variante por extremos sueltos, para los sitios que no tienen un `DateInterval` a mano.
    static func days(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        guard end > start else { return 0 }
        // El +1 s es lo que convierte un cierre en 23:59:59 en el instante inicial del día siguiente,
        // que es lo que `dateComponents` necesita para contar ese último día. Sobre un `end` que ya es
        // medianoche cae dentro del mismo día truncado y no altera el resultado.
        let normalizedEnd = end.addingTimeInterval(1)
        return max(0, calendar.dateComponents([.day], from: start, to: normalizedEnd).day ?? 0)
    }
}
