//
//  ScheduledPaymentNotificationGateLogicTests.swift
//  YalaTests
//
//  Tabla del gate horario honesto de pagos planificados (decisión owner D2, 2026-07-22).
//  El mutante que debe cazar: restaurar el falla-abierto histórico (`return true` con
//  item inactivo/ausente o fetch en error).
//

import Foundation
import Testing

@testable import Yala

struct ScheduledPaymentNotificationGateLogicTests {

    private typealias Gate = ScheduledPaymentNotificationGateLogic

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return cal
    }

    private func date(hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: hour, minute: minute))!
    }

    // MARK: - Item activo: gate horario real

    @Test func active_afterConfiguredHour_sends() {
        let decision = Gate.decide(
            itemState: .active(hour: 9, minute: 0),
            now: date(hour: 10, minute: 30),
            calendar: calendar
        )
        #expect(decision == .send)
    }

    @Test func active_exactlyAtConfiguredHour_sends() {
        let decision = Gate.decide(
            itemState: .active(hour: 9, minute: 0),
            now: date(hour: 9, minute: 0),
            calendar: calendar
        )
        #expect(decision == .send)
    }

    @Test func active_beforeConfiguredHour_waits() {
        let decision = Gate.decide(
            itemState: .active(hour: 9, minute: 0),
            now: date(hour: 8, minute: 0),
            calendar: calendar
        )
        #expect(decision == .waitForHour)
    }

    @Test func active_minutesMatter_beforeConfiguredMinute_waits() {
        let decision = Gate.decide(
            itemState: .active(hour: 9, minute: 30),
            now: date(hour: 9, minute: 15),
            calendar: calendar
        )
        #expect(decision == .waitForHour)
    }

    // MARK: - Toggle honesto: inactive/absent silencian (antes falla-abierto)

    @Test func inactive_silences_atAnyHour() {
        for hour in [0, 8, 12, 23] {
            let decision = Gate.decide(
                itemState: .inactive,
                now: date(hour: hour, minute: 0),
                calendar: calendar
            )
            #expect(decision == .silenced, "inactive debe silenciar a las \(hour)h")
        }
    }

    @Test func absent_silences() {
        let decision = Gate.decide(
            itemState: .absent,
            now: date(hour: 12, minute: 0),
            calendar: calendar
        )
        #expect(decision == .silenced)
    }

    // MARK: - Fail-closed: fetchError difiere, jamás abre la ventana

    @Test func fetchError_defers_neverSends() {
        for hour in [0, 8, 12, 23] {
            let decision = Gate.decide(
                itemState: .fetchError,
                now: date(hour: hour, minute: 0),
                calendar: calendar
            )
            #expect(decision == .deferFetchError, "fetchError debe diferir a las \(hour)h")
        }
    }
}
