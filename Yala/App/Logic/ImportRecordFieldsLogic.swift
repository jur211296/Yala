//
//  ImportRecordFieldsLogic.swift
//  Yala
//
//  La hora, la tasa de cambio fija y la naturaleza de un registro, en el archivo que exporta Yala y en el que importa
//  (H18 de la auditoría del import 2.2, card xx0g). Hasta el 2026-11-12 el export escribía solo la fecha y el import
//  quitaba la hora; la tasa que la persona fijó y la naturaleza cambiada a mano no viajaban, así que tras la ida y vuelta
//  el movimiento volvía al mediodía, convertido con la tasa del mercado y con la naturaleza de su subcategoría.
//
//  Las tres columnas son opcionales al importar: un archivo de antes, sin ellas, entra como siempre.
//

import Foundation

enum ImportRecordFieldsLogic {

    // MARK: - Hora

    /// Una hora del día leída del archivo. `timeZone` solo si el texto la traía («Z», «-05:00»); si no, la del teléfono.
    struct TimeOfDay: Equatable {
        let hour: Int
        let minute: Int
        let second: Int
        var timeZone: TimeZone? = nil
    }

    /// Lee una hora: «14:30», «14:30:05», «14:30:05.250», «2:30 PM», «2:30 p. m.», «14:30:05Z», «14:30:05-05:00». `nil` si
    /// no es una hora. Una hora que Excel guardó como número (fracción de día) ya llega convertida a texto por el lector
    /// de Excel: aquí un «0.30» no se adivina (sería las 00:30 escrito con punto o las 07:12 de Excel).
    static func parseTime(_ raw: String) -> TimeOfDay? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Zona horaria al final.
        var zone: TimeZone?
        if text.hasSuffix("Z") || text.hasSuffix("z") {
            zone = TimeZone(secondsFromGMT: 0)
            text.removeLast()
        } else if let signIndex = text.lastIndex(where: { $0 == "+" || $0 == "-" }), signIndex != text.startIndex {
            let offsetText = text[text.index(after: signIndex)...].replacing(":", with: "")
            guard offsetText.count == 4 || offsetText.count == 2, offsetText.allSatisfy(\.isASCII),
                  let value = Int(offsetText) else { return nil }
            let hours = offsetText.count == 4 ? value / 100 : value
            let minutes = offsetText.count == 4 ? value % 100 : 0
            guard hours <= 14, minutes < 60 else { return nil }
            let seconds = (hours * 3600 + minutes * 60) * (text[signIndex] == "-" ? -1 : 1)
            zone = TimeZone(secondsFromGMT: seconds)
            text = String(text[..<signIndex])
        }

        // AM / PM al final («p. m.», «PM», «pm», «a.m.»): letras, puntos y espacios detrás de la hora.
        var clock = text.trimmingCharacters(in: .whitespaces)
        var meridiem: Character?
        let tail = clock.reversed().prefix { $0.isLetter || $0 == "." || $0 == " " }
        let letters = String(tail.reversed()).lowercased().filter(\.isLetter)
        if !tail.isEmpty {
            guard letters == "am" || letters == "pm" else { return nil }
            meridiem = letters.first
            clock = String(clock.dropLast(tail.count))
        }

        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        // Los segundos pueden traer fracción («05.250»): se queda el segundo entero.
        let secondText = parts.count == 3 ? String(parts[2].split(separator: ".", maxSplits: 1).first ?? "") : "0"
        let pieces = [String(parts[0]), String(parts[1]), secondText]
        guard parts[0].count >= 1, parts[0].count <= 2, parts[1].count == 2, secondText.count <= 2,
              pieces.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              var hour = Int(parts[0]), let minute = Int(parts[1]), let second = Int(secondText),
              minute < 60, second < 60 else { return nil }
        if let meridiem {
            guard hour >= 1, hour <= 12 else { return nil }
            if meridiem == "a", hour == 12 { hour = 0 }
            if meridiem == "p", hour < 12 { hour += 12 }
        }
        guard hour < 24 else { return nil }
        return TimeOfDay(hour: hour, minute: minute, second: second, timeZone: zone)
    }

    /// La hora escrita dentro de la celda de la fecha («2026-01-05 14:30», «2026-01-05T14:30:00-05:00»), o `nil` si
    /// la celda solo trae la fecha o lo de detrás no es una hora.
    static func timeInDateCell(_ raw: String) -> TimeOfDay? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = trimmed.firstIndex(where: { $0 == "T" || $0 == " " }) else { return nil }
        return parseTime(String(trimmed[trimmed.index(after: index)...]))
    }

    /// El día que leyó el import (siempre al mediodía UTC de su año, mes y día) a la hora `time`, en la zona que trae
    /// la hora o, si no trae, en la del teléfono: la misma en la que el export la escribió.
    static func combine(day: Date, time: TimeOfDay, localTimeZone: TimeZone = .current) -> Date? {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let ymd = utc.dateComponents([.year, .month, .day], from: day)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = time.timeZone ?? localTimeZone
        var components = DateComponents()
        components.year = ymd.year
        components.month = ymd.month
        components.day = ymd.day
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        return calendar.date(from: components)
    }

    // MARK: - Tasa de cambio

    /// Lee una tasa con el mismo lector que los importes y la convención del archivo (H1): «3.75», «3,75», «0.000063»; con
    /// coma decimal en el archivo, «1.350» es 1350. Una tasa ambigua que el archivo no decide («1,350» sin más pistas: 1350
    /// o 1,35) NO se adivina: una tasa fija mal leída cambia el importe convertido mil veces y nadie la vuelve a mirar.
    /// `isNumber`: Excel la guardó como número (forma canónica, sin separador del archivo). `nil` si no es una tasa > 0.
    static func parseRate(
        _ raw: String, convention: ImportAmountParser.FileConvention = .unknown, isNumber: Bool = false
    ) -> Double? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        // Excel ya la escribe en la forma canónica de un `Double` («3.93E-05»): se lee tal cual, sin pasar por `Decimal`.
        if isNumber, let numeric = Double(text), numeric.isFinite, numeric > 0 { return numeric }
        guard text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }),
              let reading = ImportAmountParser.parse(text, convention: convention, fractionDigits: 12),
              !reading.isDoubtful else { return nil }
        let value = reading.value
        // Por su texto y no por `NSDecimalNumber.doubleValue`, que deja «3.751» en 3.7510000000000003: la tasa vuelve a
        // pasar por texto al convertir (`ForeignManualRateLogic.converted`) y ese residuo llegaría al importe.
        guard let rate = Double("\(value)"), rate.isFinite, rate > 0 else { return nil }
        return rate
    }

    /// La tasa con la que entra la fila, o `nil` para convertir como siempre. Solo si la fila está en otra moneda que la
    /// preferida y la tasa es a la preferida de este teléfono (`rateCurrency` vacía cuenta como la preferida: es lo que
    /// escribiría a mano quien prepara su archivo). Una tasa a otra moneda no se puede aplicar aquí.
    static func fixedRate(rate: Double, rateCurrency: String?, rowCurrency: String, preferredCurrency: String) -> Double? {
        let preferred = normalizeCurrencyCode(preferredCurrency)
        guard normalizeCurrencyCode(rowCurrency) != preferred else { return nil }
        let target = (rateCurrency ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard target.isEmpty || normalizeCurrencyCode(target) == preferred else { return nil }
        return rate
    }

    // MARK: - Naturaleza

    /// Lo que dice la celda `need`.
    enum NeedReading: Equatable {
        /// Vacía: la naturaleza de su subcategoría.
        case none
        case need(SubcategoryNeed)
        /// Escrita y no es ninguna naturaleza.
        case invalid
    }

    /// El código que escribe el export, el mismo en todos los idiomas.
    static func exportCode(for need: SubcategoryNeed) -> String {
        switch need {
        case .essential: return "essential"
        case .priority: return "priority"
        case .optional: return "optional"
        case .unclassified: return "unclassified"
        }
    }

    /// La celda `need` del export: solo si la persona cambió la naturaleza de ESE registro; vacía si es la de su
    /// subcategoría (así, al volver, sigue la de la subcategoría como antes).
    static func exportNeedCode(override: String?) -> String {
        guard let override else { return "" }
        return exportCode(for: SubcategoryNeed(rawValue: override) ?? .unclassified)
    }

    /// Lee la celda `need`: el código del export, el valor interno («esencial») o el nombre en el idioma de la app, sin
    /// mayúsculas ni tildes.
    static func parseNeed(_ raw: String, displayNames: [SubcategoryNeed: String]? = nil) -> NeedReading {
        let key = fold(raw)
        guard !key.isEmpty else { return .none }
        for need in SubcategoryNeed.allCases {
            var names = [exportCode(for: need), need.rawValue]
            if let display = (displayNames ?? currentDisplayNames())[need] { names.append(display) }
            if names.contains(where: { fold($0) == key }) { return .need(need) }
        }
        return .invalid
    }

    private static func currentDisplayNames() -> [SubcategoryNeed: String] {
        Dictionary(uniqueKeysWithValues: SubcategoryNeed.allCases.map { ($0, $0.displayName) })
    }

    private static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacing("_", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
