//
//  ScheduledPaymentNotificationGateLogic.swift
//  Yala
//
//  Pure-logic: ¿pueden salir AHORA las notificaciones de pagos planificados?
//
//  Reemplaza el gate falla-abierto histórico (`isWithinNotificationWindow`), que devolvía
//  `true` con item ausente, INACTIVO o fetch en error — con el default de fábrica en OFF,
//  eso significaba "sin gate horario para nadie" y un toggle maestro que no apagaba nada.
//
//  Semántica honesta (decisión owner 2026-07-22, ticket
//  pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega):
//  - `active`  → gate horario real: enviar solo desde la hora configurada.
//  - `inactive`→ silencio TOTAL de notifs de pagos (el toggle manda). El flip one-shot
//                (`flipMasterToggleIfNeeded`) activa el item a los usuarios existentes para
//                no cortarles los recordatorios que hoy sí reciben.
//  - `absent`  → silencio; auto-sana: `seedDefaultNotificationsIfNeeded` re-crea el item
//                (ahora con `isActive: true`) en el próximo bootstrap con onboarding completo.
//  - `fetchError` → fail-closed: diferir el pass SIN marcar ningún dedup (reintenta en el
//                próximo foreground). Jamás abrir la ventana por un error.
//

import Foundation

enum ScheduledPaymentNotificationGateLogic {

    enum ItemState: Equatable {
        /// Item `scheduledPayments` activo con su hora configurada.
        case active(hour: Int, minute: Int)
        /// Item presente pero apagado por el usuario.
        case inactive
        /// Item inexistente en el store (pre-seed / post-wipe).
        case absent
        /// El fetch del item lanzó — estado desconocido.
        case fetchError
    }

    enum Decision: Equatable {
        /// Ventana abierta: el loop de notificaciones puede correr.
        case send
        /// Toggle maestro apagado (o item ausente): no notificar pagos.
        case silenced
        /// Aún no llega la hora configurada de hoy.
        case waitForHour
        /// Estado desconocido por error de fetch: diferir sin marcar dedup.
        case deferFetchError
    }

    static func decide(itemState: ItemState, now: Date, calendar: Calendar = .current) -> Decision {
        switch itemState {
        case .inactive, .absent:
            return .silenced
        case .fetchError:
            return .deferFetchError
        case .active(let hour, let minute):
            guard let scheduledToday = calendar.date(
                bySettingHour: hour, minute: minute, second: 0, of: now
            ) else {
                // Hora inconstruible (config corrupta): fail-closed, mismo trato que un error.
                return .deferFetchError
            }
            return now >= scheduledToday ? .send : .waitForHour
        }
    }
}
