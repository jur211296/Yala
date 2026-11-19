//
//  AsistentePagoPlanificadoLogica.swift
//  Yala
//
//  Las reglas, sin vista, del asistente de «Nuevo pago planificado» (encargo del 17-nov): las preguntas, cuándo se puede
//  seguir, los días que se ofrecen y lo que pasa al formulario con «Usar formulario». Las respuestas son las de Primeros
//  pasos (`FirstScheduledPaymentFlowLogic`: tipo, frecuencia y aviso), y se guarda por el mismo camino
//  (`PrimerosPasosPlanningCreator.createScheduledPayment`). La vista es `AsistentePagoPlanificadoView`; lo respondido
//  vive en `AsistentePagoPlanificadoEstado`.
//

import Foundation
import SwiftData

enum AsistentePagoPlanificadoLogica {
    typealias Tipo = FirstScheduledPaymentFlowLogic.Kind
    typealias Frecuencia = FirstScheduledPaymentFlowLogic.Frequency
    typealias Aviso = FirstScheduledPaymentFlowLogic.Reminder

    enum Paso: String, Hashable, CaseIterable {
        /// ¿Qué pagas cada cierto tiempo? (el tipo: una subcategoría) y «Es una suscripción».
        case tipo
        /// ¿Cómo lo llamamos?
        case nombre
        /// ¿Cuánto pagas cada vez? y «Cambia cada vez».
        case monto
        /// ¿Cada cuánto toca pagar?
        case frecuencia
        /// ¿Qué día? (del mes, de la semana, la fecha del año o la del único pago).
        case dia
        /// ¿Te avisamos antes de que toque pagar?
        case aviso
        /// ¿Lo creamos así? (el resumen, que crea).
        case resumen
    }

    /// Las preguntas, en orden. Ninguna aparece ni desaparece: «¿Qué día?» cambia de forma con la frecuencia.
    static let pasos: [Paso] = Paso.allCases

    /// Lo contestado, para decidir si «Siguiente» se enciende.
    struct Respuestas: Equatable {
        var tieneTipo = false
        var nombre = ""
        var monto: Double?
        var frecuencia: Frecuencia = .monthly
        var diaDelMes = 1
        var fecha: Date = .now
    }

    static func puedeSeguir(en paso: Paso, _ r: Respuestas, hoy: Date = .now, calendar: Calendar = .current) -> Bool {
        switch paso {
        case .tipo:
            return r.tieneTipo
        case .nombre:
            return !nombreLimpio(r.nombre).isEmpty
        case .monto:
            return montoValido(r.monto)
        case .frecuencia, .aviso:
            return true
        case .dia:
            return diaValido(r, hoy: hoy, calendar: calendar)
        case .resumen:
            // Todo lo obligatorio, por si algo se vació al volver atrás.
            return r.tieneTipo && !nombreLimpio(r.nombre).isEmpty && montoValido(r.monto)
                && diaValido(r, hoy: hoy, calendar: calendar)
        }
    }

    static func nombreLimpio(_ nombre: String) -> String {
        nombre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func montoValido(_ monto: Double?) -> Bool {
        FirstBudgetFlowLogic.isValidLimit(monto)
    }

    /// El día del mes entre 1 y 31; «Una vez», de hoy en adelante (como el formulario de un pago nuevo). Semana y año
    /// valen siempre.
    static func diaValido(_ r: Respuestas, hoy: Date = .now, calendar: Calendar = .current) -> Bool {
        switch r.frecuencia {
        case .monthly: return FirstScheduledPaymentFlowLogic.isValidMonthDay(r.diaDelMes)
        case .weekly, .yearly: return true
        case .once: return calendar.startOfDay(for: r.fecha) >= calendar.startOfDay(for: hoy)
        }
    }

    // MARK: - Lo sugerido

    /// Los días del mes que se ofrecen: los atajos de Primeros pasos y el de hoy, que es el que llega elegido (el
    /// formulario de un pago nuevo también arranca en hoy).
    static func diasDelMes(hoy: Date = .now, calendar: Calendar = .current) -> [Int] {
        let deHoy = calendar.component(.day, from: hoy)
        return Array(Set(FirstScheduledPaymentFlowLogic.monthDayShortcuts + [deHoy])).sorted()
    }

    /// Lo que llega elegido en cada pregunta: hoy (día del mes, de la semana y fecha), mensual y el aviso tres días
    /// antes. «Es una suscripción», encendido si se abrió desde la pestaña Suscripciones.
    static func borradorInicial(
        esSuscripcion: Bool,
        hoy: Date = .now,
        calendar: Calendar = .current
    ) -> FirstScheduledPaymentDraft {
        var draft = FirstScheduledPaymentDraft()
        draft.isSubscription = esSuscripcion
        draft.frequency = .monthly
        draft.dayOfMonth = calendar.component(.day, from: hoy)
        draft.weekday = calendar.component(.weekday, from: hoy)
        draft.date = calendar.startOfDay(for: hoy)
        draft.reminder = FirstScheduledPaymentFlowLogic.proposedReminder
        return draft
    }

    // MARK: - Al formulario

    /// Lo respondido, tal cual lo recibe el formulario. Un monto o un tipo aún sin contestar no se pasan, y el aviso solo
    /// si se llegó a contestar (el formulario tiene el suyo por defecto). Lo de las preguntas aún no vistas llega con lo
    /// sugerido, que es lo mismo con que arranca el formulario (hoy, mensual).
    static func alFormulario(
        _ draft: FirstScheduledPaymentDraft,
        monto: Double?,
        respondidos: Set<Paso>,
        calendar: Calendar = .current
    ) -> ScheduledPaymentWizardPrefill {
        let aviso: Aviso? = respondidos.contains(.aviso) ? (draft.reminder ?? Aviso.none) : nil
        return ScheduledPaymentWizardPrefill(
            name: nombreLimpio(draft.name),
            amount: montoValido(monto) ? monto : nil,
            isVariableAmount: draft.isVariableAmount,
            isSubscription: draft.isSubscription,
            subcategoryID: draft.subcategoryID,
            isRecurring: draft.frequency.isRecurring,
            recurrenceType: draft.frequency.recurrenceType,
            dayOfMonth: draft.dayOfMonth,
            weekday: draft.weekday,
            date: calendar.startOfDay(for: draft.date),
            notifyOnDueDate: aviso?.notifyOnDueDate,
            notifyDaysBefore: aviso?.notifyDaysBefore
        )
    }
}
