//
//  ReportUpcomingLogic.swift
//  Yala
//
//  UX 2.2 · L11-12 (decisión B de Jürgen, 2026-10-18). El editor del informe decía «Cada lunes recibirás un resumen de
//  gastos de la semana» y no qué días entraban, «Probar» sin permiso de notificaciones no hacía nada, y el mensual del
//  día 1 decía «este mes» hablando del mes anterior. Aquí vive lo que no es pantalla: cuándo sale el próximo informe y
//  qué días cuenta (los mismos que `ReportNotificationService.getIntervalForReportType`), y qué hace «Probar» según el
//  permiso.
//

import Foundation
import UserNotifications

enum ReportUpcomingLogic {

    /// El próximo envío y los días que contará.
    struct Upcoming: Equatable {
        let sendDate: Date
        let interval: DateInterval
    }

    /// El próximo envío de un informe semanal o mensual a partir de `now`, y el tramo que contará en ese momento.
    /// `nil` para los demás tipos: el diario ya dice a qué hora llega y de qué día habla.
    static func upcoming(
        type: NotificationType,
        config: ReportConfig,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> Upcoming? {
        guard let sendDate = nextSendDate(type: type, dayPreference: config.dayPreference, hour: hour, minute: minute,
                                          now: now, calendar: calendar)
        else { return nil }
        let interval = ReportNotificationService.getIntervalForReportType(
            config, type: type, now: sendDate, calendar: calendar
        )
        return Upcoming(sendDate: sendDate, interval: interval)
    }

    /// El primer momento a partir de `now` en que el informe sale (`ReportNotificationService.shouldSendNow`: el día que
    /// toca, desde su hora). Si hoy es el día y la hora aún no llegó, es hoy.
    static func nextSendDate(
        type: NotificationType,
        dayPreference: ReportDayPreference,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        // Hasta un año y un día por delante: cubre cualquier combinación de día y hora.
        for offset in 0...366 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let candidate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  candidate >= now
            else { continue }
            if isSendDay(day, type: type, dayPreference: dayPreference, calendar: calendar) { return candidate }
        }
        return nil
    }

    private static func isSendDay(
        _ day: Date, type: NotificationType, dayPreference: ReportDayPreference, calendar: Calendar
    ) -> Bool {
        switch type {
        case .weeklyReport:
            let weekday = calendar.component(.weekday, from: day)
            return weekday == (dayPreference == .sunday ? 1 : 2)
        case .monthlyReport:
            let dayOfMonth = calendar.component(.day, from: day)
            if dayPreference == .firstDay { return dayOfMonth == 1 }
            return dayOfMonth == calendar.range(of: .day, in: .month, for: day)?.count
        default:
            return false
        }
    }

    // MARK: - «Probar» y el permiso

    /// Qué hace «Probar» con el permiso que hay.
    enum TestStep: Equatable {
        /// Ya hay permiso: se manda.
        case send
        /// Nunca se pidió: se pide y, si lo da, se manda.
        case askThenSend
        /// Lo negó: sin él no llega nada, así que se le explica y se le ofrece ir a Ajustes.
        case explainAndOfferSettings
    }

    static func testStep(for status: UNAuthorizationStatus) -> TestStep {
        switch status {
        case .authorized, .provisional, .ephemeral: return .send
        case .notDetermined: return .askThenSend
        case .denied: return .explainAndOfferSettings
        @unknown default: return .explainAndOfferSettings
        }
    }
}
