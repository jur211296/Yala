//
//  DraftFutureDateLogic.swift
//  Yala
//
//  Cuándo la fecha de un borrador cuenta como futura y no se deja aprobar (2026-10-12). Puro, con el reloj y el
//  calendario inyectables, para probarlo a cualquier hora.
//

import Foundation

/// La fecha de un borrador es futura si cae en un DÍA posterior a hoy, no si su instante es posterior a ahora.
///
/// La foto y la voz fijan la fecha leída a las 12:00 de ese día (`VisionDraftFactory.parseDate`,
/// `TranscriptionParserService`). Comparada por instante, un registro de «hoy» era futuro hasta el mediodía: «Guardar»
/// salía apagado en las hojas de imagen y de voz, y la Bandeja no lo dejaba aprobar. Es el criterio del formulario
/// manual (`NewTransactionViewModel.preValidate`).
enum DraftFutureDateLogic {
    static func isFuture(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.compare(date, to: now, toGranularity: .day) == .orderedDescending
    }
}
