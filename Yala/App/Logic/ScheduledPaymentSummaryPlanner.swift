//
//  ScheduledPaymentSummaryPlanner.swift
//  Yala
//
//  Pure-logic: plan de notificaciones-resumen AGENDADAS de pagos planificados
//  ("Tienes N pagos planificados para hoy"), una por día con vencimientos, a la hora
//  del item `scheduledPayments`. Es la pieza AGENDADA del modelo híbrido (decisión
//  owner D1, 2026-07-22): el recordatorio del día deja de depender de abrir la app.
//
//  Fuente DELIBERADA: el calculador de ocurrencias (`ScheduledPaymentDateCalculator`),
//  también para hoy — los días futuros no tienen drafts materializados, así que NO
//  re-sourcear a drafts (el forecast de hoy queda cubierto por el filtro de pagados;
//  la notificación oportunista dueToday, esa sí draft-based, es el fallback cuando
//  no hubo summary agendada).
//

import Foundation

enum ScheduledPaymentSummaryPlanner {

    /// Proyección pura de un `ScheduledPayment` para el plan (sin SwiftData).
    struct PaymentInput {
        let params: ScheduledPaymentDateCalculator.PaymentParams
        let notifyOnDueDate: Bool
        /// Keys ISO de `ScheduledPayment.dateKey(for:)` — misma semántica que `isDateSkipped`.
        let skippedDateKeys: Set<String>
    }

    struct DayPlan: Equatable {
        /// `yyyyMMdd` — sufijo del identifier `spDailySummary_<dayKey>` y key de marca del tracker.
        let dayKey: String
        /// Instante exacto de disparo (día + hora/minuto configurados).
        let fireDate: Date
        let count: Int
    }

    /// Delegado al formatter del tracker A PROPÓSITO: el service compara dayKeys de ambas
    /// fuentes (`paidDayKeys` del tracker vs `todayKey` del planner) — dos formatters
    /// "idénticos" se desincronizarían en silencio.
    static func dayKey(from date: Date) -> String {
        ScheduledPaymentNotificationTracker.dateKeyString(from: date)
    }

    /// Días de la ventana `[hoy, hoy+horizonDays)` con ≥1 ocurrencia notificable.
    /// Hoy entra SOLO si la hora configurada aún no pasó (un trigger one-shot con fecha
    /// pasada jamás dispararía; el fallback oportunista cubre ese hueco).
    static func plan(
        payments: [PaymentInput],
        hour: Int,
        minute: Int,
        now: Date,
        horizonDays: Int = 14,
        calendar: Calendar = .current
    ) -> [DayPlan] {
        guard !payments.isEmpty, horizonDays > 0 else { return [] }

        let startOfToday = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: horizonDays, to: startOfToday) else { return [] }

        // Meses tocados por la ventana (máx 2 con horizonte 14): el calculador trabaja
        // POR MES — consultar solo el mes actual dejaría sin summary los días del mes
        // siguiente cuando la ventana cruza fin de mes. El cursor avanza por INICIOS de
        // mes (avanzar +1 mes desde HOY saltaba el mes siguiente cuando la ventana
        // terminaba antes del día equivalente — cazado por el test de cruce de mes).
        var months: [Date] = []
        var monthCursor = calendar.dateInterval(of: .month, for: startOfToday)?.start
        while let monthStart = monthCursor, monthStart < windowEnd {
            months.append(monthStart)
            monthCursor = calendar.date(byAdding: .month, value: 1, to: monthStart)
        }

        var countByDay: [Date: Int] = [:]
        for payment in payments {
            guard payment.notifyOnDueDate else { continue }

            // Ocurrencias CONSUMIDAS: `nextDueDate` es el SSOT de la próxima ocurrencia
            // pendiente (avanza al aprobar/asociar/saltar). El calculador re-genera por
            // patrón las fechas ANTERIORES del mes (pagadas por adelantado, aprobadas hoy…)
            // — contarlas produciría una summary de pagos ya cubiertos. Misma fuente que
            // usa `ScheduledPaymentDraftService` para materializar la bandeja.
            let consumedBefore = calendar.startOfDay(for: payment.params.nextDueDate)

            for month in months {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.params, month: month, calendar: calendar
                )
                for date in dates {
                    let day = calendar.startOfDay(for: date)
                    guard day >= startOfToday, day < windowEnd else { continue }
                    guard day >= consumedBefore else { continue }
                    guard !payment.skippedDateKeys.contains(ScheduledPayment.dateKey(for: day)) else { continue }
                    countByDay[day, default: 0] += 1
                }
            }
        }

        var plans: [DayPlan] = []
        for (day, count) in countByDay where count > 0 {
            guard let fireDate = calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: day
            ) else { continue }
            // Hoy con la hora ya pasada: fuera del plan (y la marca del tracker de hoy
            // NO se toca — limpiarla re-abriría la oportunista y duplicaría el banner).
            if fireDate <= now { continue }
            plans.append(DayPlan(dayKey: dayKey(from: day), fireDate: fireDate, count: count))
        }

        return plans.sorted { $0.dayKey < $1.dayKey }
    }
}
