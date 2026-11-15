//
//  RecordsMonthSectionsLogic.swift
//  Yala
//
//  Revisión 2.3, decisión 17 (T1 + T2, 9-nov): la lista de Registros va por meses. Entre meses, un separador fijo
//  arriba que lleva a otro mes («Octubre 2026 · 182 registros · S/ -6,420»), y cada cabecera de día dice lo gastado
//  ese día y el año cuando no es el actual. Sin vistas: la vista solo pone los textos.
//

import Foundation

enum RecordsMonthSectionsLogic {

    /// Un día de la lista, con lo gastado (`DailySpendingCalculator.dayTotals`, el mismo cálculo que el calendario).
    struct Day<Record> {
        let date: Date
        let records: [Record]
        let spent: Double
    }

    /// Un mes de la lista: sus días en el orden en que llegan y lo que suman.
    struct Month<Record> {
        /// El primer instante del mes. Es también su id en la lista (salto con `ScrollViewReader`).
        let start: Date
        let days: [Day<Record>]

        var recordCount: Int { days.reduce(0) { $0 + $1.records.count } }
        /// Con signo, como el calendario: una devolución en una categoría de gasto resta.
        var spent: Double { days.reduce(0) { $0 + $1.spent } }
    }

    /// Agrupa los días por mes sin reordenar: los días consecutivos del mismo mes forman un mes. La lista llega
    /// ordenada (de reciente a antiguo), así que cada mes sale una vez y en ese mismo orden.
    static func months<Record>(
        _ groups: [(date: Date, records: [Record])],
        calendar: Calendar = .current,
        spent: ([Record]) -> Double
    ) -> [Month<Record>] {
        var result: [Month<Record>] = []
        var currentStart: Date?
        var currentDays: [Day<Record>] = []
        for group in groups {
            let start = monthStart(of: group.date, calendar: calendar)
            if start != currentStart, let previous = currentStart {
                result.append(Month(start: previous, days: currentDays))
                currentDays = []
            }
            currentStart = start
            currentDays.append(Day(date: group.date, records: group.records, spent: spent(group.records)))
        }
        if let last = currentStart {
            result.append(Month(start: last, days: currentDays))
        }
        return result
    }

    /// El separador solo cuando la lista cruza meses: con «Esta semana» o «Este mes» no lleva a ningún sitio (la
    /// propia maqueta T2 lo apuntaba en contra) y sería una cabecera fija más sin nada que decir.
    static func showsMonthSeparator(monthCount: Int) -> Bool {
        monthCount >= 2
    }

    /// «vie 4 jul 2025»: el año solo cuando el día no es del año en curso (decisión 17, «año solo cuando toca»).
    static func dayHeaderIncludesYear(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(date, equalTo: now, toGranularity: .year)
    }

    /// Lo gastado que se nombra: por debajo de medio céntimo (o negativo: solo hubo devoluciones) no sale cifra.
    /// El mismo umbral que el resumen del día del calendario.
    static func shownSpent(_ spent: Double) -> Double? {
        spent >= RecordsCalendarDaySummaryLogic.minimumAmount ? spent : nil
    }

    static func monthStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    /// Clave estable del mes para los ids de XCUITest (`records_month_2026-10`), sin depender del idioma.
    static func monthKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }
}
