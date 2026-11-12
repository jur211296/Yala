//
//  DevSeedTodayRecordTests.swift
//  YalaTests
//
//  El «Bus» de `-uitest-seed-today-record` (card 30pv) tiene que caer HOY a cualquier hora, también a las 00:00:30 del
//  día 1, y no en el futuro: es lo que deja a `UsageModeUITests` con un registro conocido en «Este mes» sea el día que
//  sea. `now` fijo, sin esperar a ningún día.
//

import Foundation
import Testing

@testable import Yala

struct DevSeedTodayRecordTests {

    private let calendar = Calendar.current

    @Test(arguments: [(0, 0, 0), (0, 0, 30), (0, 1, 0), (0, 30, 0), (12, 0, 0), (23, 59, 59)])
    func cae_hoy_yNoEnElFuturo(hour: Int, minute: Int, second: Int) throws {
        let now = try #require(calendar.date(from: DateComponents(
            year: 2026, month: 11, day: 1, hour: hour, minute: minute, second: second)))
        let date = DevSeedTodayRecord.date(now: now, calendar: calendar)
        #expect(calendar.isDate(date, inSameDayAs: now), "El registro salió del día: \(date) para \(now).")
        #expect(date <= now, "El registro quedó en el futuro: \(date) para \(now).")
    }

    /// Control positivo: con tiempo de sobra, es un minuto antes, no la medianoche (sin el `max`, también lo sería).
    @Test func aMediodia_esUnMinutoAntes() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12)))
        #expect(DevSeedTodayRecord.date(now: now, calendar: calendar) == now.addingTimeInterval(-60))
    }
}
