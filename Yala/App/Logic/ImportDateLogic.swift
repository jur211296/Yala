//
//  ImportDateLogic.swift
//  Yala
//
//  Cómo lee el import las fechas de un archivo (H10 de la auditoría del import 2.2, ticket
//  `import-guesses-date-order-per-row`). Hasta el 2026-11-22 se adivinaba fila a fila: con «/» siempre día/mes, los
//  formatos de respaldo aceptaban «/» también, el año de dos cifras solo se corregía en la ruta de «/» y la fecha se
//  guardaba a las 12:00 UTC, que en Nueva Zelanda en verano (UTC+13) es el día siguiente.
//
//  Ahora el orden día/mes se decide UNA vez por archivo: si alguna fila lo deja claro (un número mayor que 12 solo
//  puede ser el día), manda el archivo; si nada lo decide, el orden del idioma del teléfono, y la vista previa lo enseña
//  con un ejemplo. La fecha se guarda al mediodía LOCAL, en calendario gregoriano.
//

import Foundation

/// El orden de día y mes en las fechas que no empiezan por el año.
nonisolated enum ImportDateOrder: Equatable, Sendable {
    case dayFirst
    case monthFirst
}

/// El orden elegido para un archivo y por qué.
nonisolated struct ImportDateDecision: Equatable, Sendable {
    let order: ImportDateOrder
    /// Alguna fila del archivo lo decidió. Si es `false`, se usó el del teléfono.
    let decidedByFile: Bool
    /// La primera fecha del archivo que se podía leer de las dos formas («03/04/2026»), si el archivo no lo decidió:
    /// la vista previa la enseña con la lectura elegida.
    let ambiguousExample: String?
}

nonisolated enum ImportDateLogic {

    /// Las tres piezas numéricas de una fecha.
    private struct Parts {
        let first: Int
        let second: Int
        let third: Int
        let yearFirst: Bool
        /// El año venía con dos cifras.
        let shortYear: Bool
    }

    /// La parte de la fecha de una celda, sin la hora («2026-10-27T14:30» → «2026-10-27»).
    static func datePart(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = trimmed.firstIndex(where: { $0 == "T" || $0 == " " }) else { return trimmed }
        return String(trimmed[..<index])
    }

    /// Parte «03/04/2026», «2026-04-03», «03.04.26» en tres números. `nil` si no tiene esa forma.
    private static func parts(_ raw: String) -> Parts? {
        let text = datePart(raw)
        guard let separator = text.first(where: { $0 == "/" || $0 == "-" || $0 == "." }) else { return nil }
        let pieces = text.split(separator: separator, omittingEmptySubsequences: false)
        guard pieces.count == 3,
              pieces.allSatisfy({ !$0.isEmpty && $0.count <= 4 && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let a = Int(pieces[0]), let b = Int(pieces[1]), let c = Int(pieces[2]) else { return nil }
        if pieces[0].count == 4 {
            // Año primero: año-mes-día, siempre (nadie escribe año-día-mes).
            guard pieces[1].count <= 2, pieces[2].count <= 2 else { return nil }
            return Parts(first: a, second: b, third: c, yearFirst: true, shortYear: false)
        }
        guard pieces[0].count <= 2, pieces[1].count <= 2, pieces[2].count == 2 || pieces[2].count == 4 else { return nil }
        return Parts(first: a, second: b, third: c, yearFirst: false, shortYear: pieces[2].count == 2)
    }

    /// El orden del idioma y la región del teléfono: el que usa su formato de fecha corto.
    static func localeOrder(_ locale: Locale) -> ImportDateOrder {
        let pattern = DateFormatter.dateFormat(fromTemplate: "dMy", options: 0, locale: locale) ?? "d/M/y"
        guard let day = pattern.firstIndex(of: "d"), let month = pattern.firstIndex(of: "M") else { return .dayFirst }
        return month < day ? .monthFirst : .dayFirst
    }

    /// Decide el orden día/mes del archivo entero mirando todas sus fechas.
    ///
    /// Si alguna fila trae un primer número mayor que 12 (y un segundo que puede ser mes), es día/mes; si alguna trae un
    /// segundo número mayor que 12, mes/día. Si pasan las dos cosas, el archivo se contradice y manda el teléfono: las
    /// filas que no casen salen como fecha inválida, con su número. Si nada lo decide, también el teléfono.
    static func decide(for cells: [String], locale: Locale) -> ImportDateDecision {
        var dayFirstEvidence = false
        var monthFirstEvidence = false
        var firstAmbiguous: String?
        for cell in cells {
            guard let p = parts(cell), !p.yearFirst else { continue }
            if p.first > 12, (1...12).contains(p.second) { dayFirstEvidence = true }
            if p.second > 12, (1...12).contains(p.first) { monthFirstEvidence = true }
            if firstAmbiguous == nil, (1...12).contains(p.first), (1...12).contains(p.second), p.first != p.second {
                firstAmbiguous = datePart(cell)
            }
        }
        if dayFirstEvidence != monthFirstEvidence {
            return ImportDateDecision(
                order: dayFirstEvidence ? .dayFirst : .monthFirst, decidedByFile: true, ambiguousExample: nil)
        }
        return ImportDateDecision(order: localeOrder(locale), decidedByFile: false, ambiguousExample: firstAmbiguous)
    }

    /// Un año de dos cifras: con «hoy» en 2026, «26» es 2026 y «99» es 1999. Se elige el siglo que deja el año en el
    /// pasado o en el presente: un archivo de movimientos no trae fechas de dentro de 70 años.
    static func expandYear(_ short: Int, now: Date, calendar: Calendar) -> Int {
        let currentYear = calendar.component(.year, from: now)
        let candidate = (currentYear / 100) * 100 + short
        return candidate > currentYear ? candidate - 100 : candidate
    }

    /// Lee el DÍA de una celda con el orden del archivo, al mediodía de `timeZone`, en calendario gregoriano. `nil` si
    /// la celda no es una fecha o el día no existe (31/02).
    static func parseDay(
        _ raw: String, order: ImportDateOrder, timeZone: TimeZone = .current, now: Date = .now
    ) -> Date? {
        guard let p = parts(raw) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year: Int
        let month: Int
        let day: Int
        if p.yearFirst {
            (year, month, day) = (p.first, p.second, p.third)
        } else {
            year = p.shortYear ? expandYear(p.third, now: now, calendar: calendar) : p.third
            (day, month) = order == .dayFirst ? (p.first, p.second) : (p.second, p.first)
        }
        guard year >= 1900, (1...12).contains(month), (1...31).contains(day) else { return nil }
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) else {
            return nil
        }
        // Sin desbordes: el 31 de febrero no es el 3 de marzo.
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        return date
    }
}
