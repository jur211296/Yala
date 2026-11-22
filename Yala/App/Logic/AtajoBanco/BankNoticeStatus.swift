//
//  BankNoticeStatus.swift
//  Yala
//
//  Atajo del banco, B2: qué dice la pantalla de un banco. Yala no ve la automatización: el estado sale de lo que llegó
//  (`BankNoticeActivity`) y de lo que eligió la persona (`BankNoticeSettings`).
//
//  - Esperando: aún no llegó ningún aviso de ese banco.
//  - Funcionando: llegan avisos.
//  - Silencio: «Hace 9 días que no llega nada». Solo si antes llegaban con frecuencia: con cinco avisos o más y un hueco
//    de al menos 7 días que triplica el hueco típico entre avisos. No es una notificación: se ve al entrar.
//  - Pausado: lo eligió la persona; manda sobre lo demás.
//
//  Pura y con el reloj inyectado, para los tests.
//

import Foundation

nonisolated enum BankNoticeStatus: Equatable {
    case waiting
    case working(lastArrival: Date)
    case silent(days: Int, lastArrival: Date)
    case paused

    /// Avisos que tiene que haber visto Yala antes de hablar de silencio.
    static let silenceMinimumArrivals = 5
    /// El hueco más corto que cuenta como silencio, en días.
    static let silenceMinimumDays = 7
    /// Cuántas veces el hueco típico tiene que durar el silencio.
    static let silenceFactor = 3

    static func status(
        activity: BankNoticeActivity, settings: BankNoticeSettings, now: Date = .now, calendar: Calendar = .current
    ) -> BankNoticeStatus {
        if settings.isPaused { return .paused }
        guard let last = activity.lastArrival else { return .waiting }
        let days = daysBetween(last, now, calendar: calendar)
        guard activity.arrivals.count >= silenceMinimumArrivals, days >= silenceMinimumDays else {
            return .working(lastArrival: last)
        }
        let typical = typicalGapDays(activity.arrivals, calendar: calendar)
        return days >= max(silenceMinimumDays, typical * silenceFactor)
            ? .silent(days: days, lastArrival: last)
            : .working(lastArrival: last)
    }

    /// La mediana de los huecos entre avisos, en días de calendario (al menos 1: dos avisos del mismo día no hacen que un
    /// día sin avisos parezca un silencio).
    static func typicalGapDays(_ arrivals: [Double], calendar: Calendar) -> Int {
        let dates = arrivals.map { Date(timeIntervalSince1970: $0) }.sorted()
        guard dates.count >= 2 else { return 1 }
        let gaps = zip(dates, dates.dropFirst()).map { daysBetween($0, $1, calendar: calendar) }.sorted()
        return max(1, gaps[(gaps.count - 1) / 2])
    }

    /// Días de calendario entre dos fechas. Por días y no por segundos: un cambio de hora no lo mueve.
    static func daysBetween(_ from: Date, _ to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }
}

/// Un aviso de ejemplo por banco, para «Probar con un aviso de ejemplo»: corre la lectura sin guardar nada. Son los
/// formatos de las reglas (`BankNoticeRules`), con cifras ficticias.
nonisolated enum BankNoticeSamples {
    static func text(for bank: BankNoticeBank) -> String {
        switch bank {
        case .bcp:
            return "Consumo con tu tarjeta\nRealizaste un consumo de S/ 45.90 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES."
        case .yape:
            return "Yape\nYape! JUAN PEREZ te envió un pago por S/ 10.00"
        case .plin:
            return "Plin\nPlineaste S/ 15.00 a ANA TORRES."
        case .interbank:
            return "Interbank\nCompra por S/ 32.50 en WONG BENAVIDES con tu tarjeta ****1234."
        case .bbva:
            return "BBVA\nCompra aprobada por S/ 58.00 en PLAZA VEA SURCO con tu tarjeta ****5678."
        case .scotiabank:
            return "Scotiabank\nConsumo de S/ 120.00 en PRIMAX JAVIER PRADO con tu tarjeta ****9012."
        case .other:
            return "Tu banco\nPagaste S/ 25.00 en STARBUCKS LARCOMAR con tu tarjeta ****3456."
        }
    }
}
