//
//  CanonicalTime.swift
//  Yala
//
//  Aritmética de calendario ENTERA y pura para el formato canónico c1 de los timestamps HLC
//  (Modo Nube, incremento I1). NO usa Calendar/DateFormatter/TimeZone: son sensibles a la zona
//  horaria del proceso, a los calendarios no gregorianos y al epoch 2001 de Foundation. Un HLC
//  DEBE serializar idéntico en cualquier dispositivo/zona/idioma o el LWW de sync divergiría.
//
//  Formato canónico c1 del componente temporal (24 chars fijos):
//      YYYY-MM-DDTHH:mm:ss.SSSZ
//  - ms enteros desde el epoch UNIX (1970-01-01T00:00:00Z), NUNCA el epoch 2001 de Swift.
//  - cuantización FLOOR hacia -∞ (los ms pre-1970 se redondean hacia el pasado).
//  - 'T' y 'Z' literales en mayúscula; años 0001..9999 (fuera → error tipado).
//
//  Algoritmo civil de Howard Hinnant (days_from_civil / civil_from_days) — dominio público,
//  exacto para el calendario gregoriano proléptico, sin dependencias de Foundation.
//

import Foundation

/// Errores tipados de la conversión canónica de tiempo.
nonisolated enum CanonicalTimeError: Error, Equatable {
    /// El año resultante cae fuera de 0001..9999.
    case yearOutOfRange(Int)
    /// La string no cumple el formato canónico c1 de 24 chars (con motivo).
    case malformedTimestamp(String)
}

/// Conversión pura entre ms Unix (`Int64`) y el componente temporal canónico c1.
nonisolated enum CanonicalTime {

    // MARK: - Constantes

    /// Milisegundos por segundo / minuto / hora / día. Enteros: sin `Double`.
    private static let msPerSecond: Int64 = 1_000
    private static let secondsPerMinute: Int64 = 60
    private static let secondsPerHour: Int64 = 3_600
    private static let secondsPerDay: Int64 = 86_400

    // MARK: - División/módulo FLOOR (hacia -∞)

    /// División entera hacia -∞ (el `/` de Swift trunca hacia CERO → incorrecto para ms negativos).
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        let q = a / b
        let r = a % b
        // Si el resto es no-cero y su signo difiere del divisor, `/` redondeó hacia cero
        // (es decir, hacia +∞ para el caso negativo) → corrige restando 1.
        if r != 0 && (r < 0) != (b < 0) {
            return q - 1
        }
        return q
    }

    /// Módulo con el signo del divisor (resultado en [0, b) para b > 0).
    static func floorMod(_ a: Int64, _ b: Int64) -> Int64 {
        let r = a % b
        if r != 0 && (r < 0) != (b < 0) {
            return r + b
        }
        return r
    }

    // MARK: - Algoritmo civil de Hinnant

    /// Días desde 1970-01-01 (día 0) para una fecha civil gregoriana proléptica.
    /// `y` es el año civil real (puede ser <= 0). Pre-condición: fecha válida.
    static func daysFromCivil(year: Int64, month: Int64, day: Int64) -> Int64 {
        // Ajuste de Hinnant: enero/febrero pertenecen al "año anterior" del cómputo de era.
        let y = year - (month <= 2 ? 1 : 0)
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400                              // [0, 399]
        let mp = (month > 2 ? month - 3 : month + 9)         // marzo=0 .. febrero=11
        let doy = (153 * mp + 2) / 5 + day - 1               // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy      // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// Fecha civil (año, mes, día) a partir de los días desde 1970-01-01.
    /// Devuelve el año civil real (puede ser <= 0 para fechas pre-año-1).
    static func civilFromDays(_ days: Int64) -> (year: Int64, month: Int64, day: Int64) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let doe = z - era * 146097                                       // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365  // [0, 399]
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)                // [0, 365]
        let mp = (5 * doy + 2) / 153                                     // [0, 11]
        let day = doy - (153 * mp + 2) / 5 + 1                           // [1, 31]
        let month = mp < 10 ? mp + 3 : mp - 9                            // [1, 12]
        return (year: y + (month <= 2 ? 1 : 0), month: month, day: day)
    }

    // MARK: - Formateo (ms → string canónica)

    /// Formatea ms Unix como componente temporal canónico c1 de 24 chars, SIN validar el rango de año.
    /// Solo seguro cuando el llamador garantiza el invariante (año 0001..9999). Lo usa `HLC.description`,
    /// cuyo `physicalMs` ya fue validado en construcción. Externamente usa `canonicalIsoMillis(_:)`.
    static func canonicalIsoMillisUnchecked(_ unixMs: Int64) -> String {
        let totalSeconds = floorDiv(unixMs, msPerSecond)
        let millis = floorMod(unixMs, msPerSecond)

        let days = floorDiv(totalSeconds, secondsPerDay)
        let secondOfDay = floorMod(totalSeconds, secondsPerDay)

        let hour = secondOfDay / secondsPerHour
        let minute = (secondOfDay % secondsPerHour) / secondsPerMinute
        let second = secondOfDay % secondsPerMinute

        let civil = civilFromDays(days)

        return pad(civil.year, 4) + "-" + pad(civil.month, 2) + "-" + pad(civil.day, 2)
            + "T" + pad(hour, 2) + ":" + pad(minute, 2) + ":" + pad(second, 2)
            + "." + pad(millis, 3) + "Z"
    }

    /// Formatea ms Unix como componente temporal canónico c1, validando que el año caiga en 0001..9999.
    /// - Throws: `CanonicalTimeError.yearOutOfRange` si el año está fuera de rango.
    static func canonicalIsoMillis(_ unixMs: Int64) throws -> String {
        let days = floorDiv(floorDiv(unixMs, msPerSecond), secondsPerDay)
        let year = civilFromDays(days).year
        guard year >= 1 && year <= 9999 else {
            throw CanonicalTimeError.yearOutOfRange(Int(year))
        }
        return canonicalIsoMillisUnchecked(unixMs)
    }

    /// Zero-pad de un entero no-negativo a `width` dígitos.
    private static func pad(_ value: Int64, _ width: Int) -> String {
        let digits = String(value)
        if digits.count >= width { return digits }
        return String(repeating: "0", count: width - digits.count) + digits
    }

    // MARK: - Parsing estricto (string canónica → ms)

    /// Parsea el componente temporal canónico c1 de 24 chars a ms Unix. ESTRICTO: exige el layout
    /// exacto `YYYY-MM-DDTHH:mm:ss.SSSZ` con 'T'/'Z' en mayúscula, dígitos en todas las posiciones
    /// numéricas y campos en rango (mes 1..12, día válido para el mes con año bisiesto, etc.).
    /// - Throws: `CanonicalTimeError.malformedTimestamp` o `.yearOutOfRange`.
    static func parseCanonicalIsoMillis(_ string: String) throws -> Int64 {
        let scalars = Array(string.unicodeScalars)
        guard scalars.count == 24 else {
            throw CanonicalTimeError.malformedTimestamp("longitud \(scalars.count) ≠ 24")
        }

        // Separadores literales en posición fija.
        func expect(_ index: Int, _ char: Character) throws {
            guard scalars[index] == char.unicodeScalars.first! else {
                throw CanonicalTimeError.malformedTimestamp("se esperaba '\(char)' en la posición \(index)")
            }
        }
        try expect(4, "-")
        try expect(7, "-")
        try expect(10, "T")
        try expect(13, ":")
        try expect(16, ":")
        try expect(19, ".")
        try expect(23, "Z")

        // Lee `count` dígitos desde `start` como entero, o lanza si alguno no es 0-9.
        func number(_ start: Int, _ count: Int) throws -> Int64 {
            var result: Int64 = 0
            for offset in 0..<count {
                let scalar = scalars[start + offset]
                guard scalar.value >= 48 && scalar.value <= 57 else {  // '0'..'9'
                    throw CanonicalTimeError.malformedTimestamp("carácter no numérico en la posición \(start + offset)")
                }
                result = result * 10 + Int64(scalar.value - 48)
            }
            return result
        }

        let year = try number(0, 4)
        let month = try number(5, 2)
        let day = try number(8, 2)
        let hour = try number(11, 2)
        let minute = try number(14, 2)
        let second = try number(17, 2)
        let millis = try number(20, 3)

        guard year >= 1 && year <= 9999 else {
            throw CanonicalTimeError.yearOutOfRange(Int(year))
        }
        guard month >= 1 && month <= 12 else {
            throw CanonicalTimeError.malformedTimestamp("mes \(month) fuera de 1..12")
        }
        guard day >= 1 && day <= daysInMonth(year: year, month: month) else {
            throw CanonicalTimeError.malformedTimestamp("día \(day) inválido para \(year)-\(month)")
        }
        guard hour <= 23 else {
            throw CanonicalTimeError.malformedTimestamp("hora \(hour) fuera de 0..23")
        }
        guard minute <= 59 else {
            throw CanonicalTimeError.malformedTimestamp("minuto \(minute) fuera de 0..59")
        }
        guard second <= 59 else {
            throw CanonicalTimeError.malformedTimestamp("segundo \(second) fuera de 0..59")
        }
        // millis siempre 0..999 por construcción (3 dígitos).

        let days = daysFromCivil(year: year, month: month, day: day)
        return days * secondsPerDay * msPerSecond
            + hour * secondsPerHour * msPerSecond
            + minute * secondsPerMinute * msPerSecond
            + second * msPerSecond
            + millis
    }

    /// Días del mes con año bisiesto gregoriano.
    private static func daysInMonth(year: Int64, month: Int64) -> Int64 {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    private static func isLeapYear(_ year: Int64) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    // MARK: - Reloj de pared → ms

    /// ms Unix (cuantizados FLOOR hacia -∞) de una `Date` inyectada. Único punto que toca `Date`;
    /// la lógica de HLC recibe siempre el `Int64` ya cuantizado. FLOOR (no round): un instante
    /// `x.9995s` se cuantiza a `x999` ms, nunca hacia arriba.
    static func physicalMillis(from date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded(.down))
    }
}
