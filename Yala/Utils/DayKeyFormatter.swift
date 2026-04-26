//
//  DayKeyFormatter.swift
//  Yala
//
//  Helper estático compartido para formatear fechas como `yyyy-MM-dd`
//  (POSIX locale + timezone actual). Usado para keys de UserDefaults y caches diarios.
//

import Foundation

nonisolated enum DayKeyFormatter {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Devuelve `yyyy-MM-dd` para la fecha en el timezone actual.
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
