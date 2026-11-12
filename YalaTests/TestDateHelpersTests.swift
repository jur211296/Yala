//
//  TestDateHelpersTests.swift
//  YalaTests
//
//  `aMomentAgoToday` es la fecha de los tests cuyo código lee el reloj real y filtra por el día, el mes o el año en
//  curso (card tyzh, 2026-11-01). Con `now − 60 s` a secas, el primer minuto del día 1 dejaba la fila en el mes
//  anterior; esto fija que no salga de HOY y que nunca quede en el futuro.
//

import Foundation
import Testing

struct TestDateHelpersTests {

    private let calendar = Calendar.current

    @Test func aMomentAgoToday_inTheFirstMinuteOfTheMonth_staysInTheMonth() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, second: 30)))
        let moment = aMomentAgoToday(now: now)
        #expect(calendar.isDate(moment, inSameDayAs: now))
        #expect(calendar.isDate(moment, equalTo: now, toGranularity: .month))
        #expect(moment <= now)
    }

    @Test func aMomentAgoToday_inTheFirstMinuteOfTheYear_staysInTheYear() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 0, second: 5)))
        let moment = aMomentAgoToday(now: now)
        #expect(calendar.isDate(moment, equalTo: now, toGranularity: .year))
        #expect(moment <= now)
    }

    @Test func aMomentAgoToday_midDay_isAMinuteBefore() throws {
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        #expect(aMomentAgoToday(now: now) == now.addingTimeInterval(-60))
    }
}
