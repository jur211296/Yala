//
//  DevSeedAccountLinesMonthTests.swift
//  YalaTests
//
//  El perfil `tarjeta-dos-lineas` fecha sus movimientos «hace 1 a 4 días». Los días 1 a 3 del mes eso caía en el mes
//  anterior y `AccountCardPickersUITests.test_budgetOnTheCard_countsTheLineExpense` leía el presupuesto del mes al 0 %
//  (card xn78, 2026-11-01). Aquí se fija, con `now` inyectado y sin esperar al día 1, que ninguna fecha de la semilla
//  sale del mes en curso ni queda en el futuro, cualquier día del año.
//

import Foundation
import Testing

@testable import Yala

struct DevSeedAccountLinesMonthTests {

    private let calendar = Calendar.current

    /// Todos los días de 2026 a las 00:30 (el primer tramo del día, el que tumbó al CI) y a las 23:30, más febrero
    /// de 2028 (bisiesto).
    private func everyMomentToCheck() -> [Date] {
        var moments: [Date] = []
        var day = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .now
        let end = calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)) ?? .now
        while day < end {
            for (hour, minute) in [(0, 30), (23, 30)] {
                if let moment = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) {
                    moments.append(moment)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for leapDay in 25...29 {
            if let moment = calendar.date(from: DateComponents(year: 2028, month: 2, day: leapDay, hour: 0, minute: 30)) {
                moments.append(moment)
            }
        }
        return moments
    }

    @Test func seedDates_stayInTheCurrentMonth_andNeverInTheFuture_everyDay() {
        let offsets = 1...4  // los de `DevSeedAccountLines.create`
        var escapes: [String] = []
        for now in everyMomentToCheck() {
            for offset in offsets {
                let date = DevSeedAccountLines.seedDate(daysAgo: offset, now: now, calendar: calendar)
                if !calendar.isDate(date, equalTo: now, toGranularity: .month) || date > now {
                    escapes.append("\(now) −\(offset) → \(date)")
                }
            }
        }
        #expect(escapes.isEmpty, "Fechas de la semilla fuera del mes en curso: \(escapes.prefix(5))")
    }

    @Test func seedDates_onTheFirst_landOnTheFirstAtMidnight() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 20, minute: 15)))
        let first = calendar.startOfDay(for: now)
        for offset in 1...4 {
            #expect(DevSeedAccountLines.seedDate(daysAgo: offset, now: now, calendar: calendar) == first)
        }
    }

    /// Lejos del borde, «hace N días» sigue siendo exactamente eso: el clamp no cambia el escenario de los demás días.
    @Test func seedDates_midMonth_areExactlyNDaysAgo() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let today = calendar.startOfDay(for: now)
        for offset in 1...4 {
            let expected = try #require(calendar.date(byAdding: .day, value: -offset, to: today))
            #expect(DevSeedAccountLines.seedDate(daysAgo: offset, now: now, calendar: calendar) == expected)
        }
    }
}
