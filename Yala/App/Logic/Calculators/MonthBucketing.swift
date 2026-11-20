//
//  MonthBucketing.swift
//  Yala
//
//  YALA-IOS-P / -12 / -Q (build 2.3 (4), 19-nov-2026): el Flujo de caja y la proyección del Panel recorren todos los
//  movimientos en el hilo principal, y por cada uno pedían al calendario el intervalo de su mes y armaban la clave
//  «AAAA-MM» con `String(format:)`. Con miles de movimientos y varias pasadas por cálculo, la app se trababa segundos.
//  Aquí, las dos cosas baratas: el mes sale de un intervalo ya conocido si la fecha cae dentro, y la clave se arma sin
//  formato de C.
//

import Foundation

/// El mes de una fecha, recordando el último intervalo de mes pedido al calendario. Los movimientos llegan casi siempre
/// ordenados por fecha, así que la mayoría cae en el mismo mes que el anterior. La pertenencia es exacta
/// (`inicio <= fecha < fin`, el mismo intervalo que da el calendario), así que el resultado no cambia con el huso ni con
/// el cambio de hora: solo se ahorra la pregunta.
struct MonthBucketer {
    let calendar: Calendar
    private var cached: (start: Date, end: Date)?
    private var keys: [Date: String] = [:]

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// El primer instante del mes de `date`, como `calendar.dateInterval(of: .month, for:)?.start`.
    mutating func monthStart(of date: Date) -> Date? {
        if let cached, cached.start <= date, date < cached.end { return cached.start }
        #if DEBUG
        Self._testCalendarLookups += 1
        #endif
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        cached = (interval.start, interval.end)
        return interval.start
    }

    /// La clave «AAAA-MM» del mes de `date`, la misma que `CashFlowProjectionCalculator.monthKey(for:calendar:)`.
    mutating func monthKey(of date: Date) -> String {
        guard let start = monthStart(of: date) else {
            return CashFlowProjectionCalculator.monthKey(for: date, calendar: calendar)
        }
        if let key = keys[start] { return key }
        let key = CashFlowProjectionCalculator.monthKey(for: start, calendar: calendar)
        keys[start] = key
        return key
    }

    #if DEBUG
    /// Cuántas veces se preguntó de verdad al calendario. Testigo de `YalaTests/RegistrosFluidez`: sin la caché crece con
    /// los movimientos; con ella, con los meses. Solo lo leen y lo ponen a cero los tests.
    nonisolated(unsafe) static var _testCalendarLookups = 0
    #endif
}

/// «2026-07»: el año a cuatro cifras y el mes a dos, como `String(format: "%04d-%02d", …)` para años de 0 a 9999.
enum MonthKeyText {
    static func make(year: Int, month: Int) -> String {
        guard (0...9999).contains(year), (0...99).contains(month) else {
            return String(format: "%04d-%02d", year, month)
        }
        let y = String(year)
        let m = String(month)
        return String(repeating: "0", count: 4 - y.count) + y + "-" + (m.count < 2 ? "0" : "") + m
    }
}
