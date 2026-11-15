//
//  SetupCompleteTrialOfferLogic.swift
//  Yala
//
//  Y23-18 · Final de Primeros pasos (docs/onboarding-2-3/SPEC.md, prototipo oficial v35, pestaña 8): el mazo
//  desaparece, queda «¡Primeros pasos completos!» con chispas y, un momento después, sube la oferta de la prueba de Pro
//  de la App Store. Apple no deja activarla sola (norma 3.1.2): sin confirmar en la hoja de pago no hay Pro. Con la
//  confirmación, un aviso local antes del primer cobro.
//
//  La duración se dice como la da la App Store (decisión D21 de Jürgen, 21-oct, confirmada el 12-nov para este paso):
//  la prueba configurada es de un mes, y entonces se anuncia «1 mes» con las fechas reales, no «30 días» como la ficha.
//
//  Aquí, las reglas sin efectos: cuándo esta oferta es la del final, cuándo sube, cuándo avisa y si puede agendarse.
//

import Foundation
import UserNotifications

nonisolated enum SetupCompleteTrialOfferLogic {

    // MARK: - Cuándo sube

    /// La tarjeta del final se ve antes de que suba la oferta: 1,6 s, o 0,2 s con Reducir movimiento (el prototipo).
    static func offerDelay(reduceMotion: Bool) -> Duration {
        reduceMotion ? .milliseconds(200) : .milliseconds(1600)
    }

    // MARK: - La línea de tiempo y el aviso

    /// Días antes del primer cobro en que se avisa (la ficha: «Día 28 · Día 30»).
    static let reminderDaysBeforeCharge = 2

    /// La hora del aviso, en la mañana del día que toca.
    static let reminderHour = 10

    /// El identificador del aviso: uno solo, una prueba nueva lo sustituye.
    static let reminderIdentifier = "proTrialChargeReminder"

    /// El día del aviso: dos días de calendario antes del cobro, a las 10:00. `nil` si no se puede calcular.
    static func reminderDate(chargeDate: Date, calendar: Calendar) -> Date? {
        let chargeDay = calendar.startOfDay(for: chargeDate)
        guard let day = calendar.date(byAdding: .day, value: -reminderDaysBeforeCharge, to: chargeDay) else { return nil }
        return calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day)
    }

    /// Si el aviso se agenda: solo con fecha futura.
    static func schedulesReminder(at date: Date?, now: Date) -> Bool {
        guard let date else { return false }
        return date > now
    }

    /// Si el aviso puede agendarse con el permiso que hay. Nunca se pide: ni el diálogo de iOS (Y23-17: solo al elegir
    /// «sí, recuérdame») ni el permiso provisional, que deja el estado en `.provisional` y apaga la pregunta de los avisos
    /// de pagos, presupuestos y grupos (review del lote 05). Sin permiso no se promete el aviso.
    static func canScheduleReminder(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        case .notDetermined, .denied: false
        @unknown default: false
        }
    }

    /// La fecha del aviso solo se dice si es futura (en Sandbox un mes dura minutos y quedaría en el pasado).
    static func announcesReminder(_ reminder: Date?, scheduled: Bool, now: Date) -> Bool {
        guard scheduled, let reminder else { return false }
        return reminder > now
    }

    // MARK: - De dónde viene la oferta

    /// La oferta que se pide al completar el mazo lo deja apuntado, y la presentación lo consume: si se decidiera por el
    /// estado del mazo al pintarla, cerrar la tarjeta del final en esos 1,6 s (o una oferta retenida al siguiente
    /// arranque) sacaría la hoja de 2.2.
    static let pendingOfferKey = "onboarding23.setupCompleteOfferPending"

    /// Lee y consume la marca: con la presentación, o con la oferta que ya no saldrá nunca. Retenida para el arranque
    /// siguiente, no se toca.
    static func takePendingOffer(defaults: UserDefaults = .standard) -> Bool {
        let pending = defaults.bool(forKey: pendingOfferKey)
        defaults.removeObject(forKey: pendingOfferKey)
        return pending
    }

    // MARK: - El aviso que se debe

    /// La compra confirmada en esta oferta deja apuntado que se prometió el aviso; la app lo repone si un borrado o un
    /// cierre de sesión lo quitó, y lo retira si la prueba se cancela o termina.
    static let reminderOwedKey = "onboarding23.trialChargeReminderOwed"

    enum ReminderReconcile: Equatable {
        case nothing
        case ensure(chargeDate: Date)
        case removeAndForget
    }

    static func reconcile(owed: Bool, isTrial: Bool, willAutoRenew: Bool?, chargeDate: Date?) -> ReminderReconcile {
        guard owed else { return .nothing }
        guard isTrial, willAutoRenew != false, let chargeDate else { return .removeAndForget }
        return .ensure(chargeDate: chargeDate)
    }
}
