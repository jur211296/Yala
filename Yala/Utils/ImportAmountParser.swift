//
//  ImportAmountParser.swift
//  Yala
//
//  Cómo se leen los importes de un archivo importado (H1 de la auditoría del import 2.2, card jvgc).
//
//  Hasta el 2026-10-29 el separador decimal se decidía celda a celda con «el último `,` o `.`»: «1,500» y «1.500»
//  entraban como 1,5, «1.234.567» como 1,234, y el signo «−» (U+2212, el de Numbers y de algunas webs de banco) se
//  perdía, así que un gasto entraba como ingreso. Todo en silencio.
//
//  Ahora el separador se decide por ARCHIVO, con las celdas que lo delatan, y lo que no se puede decidir no se
//  adivina en silencio: entra con una lectura propuesta y la vista previa lo enseña como dudoso.
//

import Foundation

nonisolated enum ImportAmountParser {

    enum Separator: Equatable, Sendable {
        case dot
        case comma

        var character: Character { self == .dot ? "." : "," }
        var other: Separator { self == .dot ? .comma : .dot }
    }

    /// Lo que se lee de una celda.
    struct Reading: Equatable, Sendable {
        let value: Decimal
        /// La celda podía leerse de dos formas («1,500») y el archivo no decía cuál: `value` es la propuesta.
        let isDoubtful: Bool
    }

    /// Qué dice una celda sobre el separador decimal del archivo.
    enum Shape: Equatable, Sendable {
        /// Sin separadores: un entero.
        case integer(digits: String)
        /// La celda dice ella sola cuál es su decimal («12,50», «1.234,56», «1,234,567» → el decimal es el otro).
        case decided(integer: String, fraction: String, decimal: Separator?)
        /// Un solo separador seguido de tres cifras, con una parte entera de 1 a 3 cifras que no empieza por 0:
        /// «1,500» es 1500 o 1,5 según el archivo.
        case ambiguous(integer: String, fraction: String, separator: Separator)
    }

    /// Los caracteres que cuentan como signo menos: el guion, el menos tipográfico (U+2212), la raya corta (U+2013)
    /// y la raya (U+2014). Los tres últimos los ponen Numbers, Word y algunas exportaciones de banco.
    static let minusSigns: Set<Character> = ["-", "\u{2212}", "\u{2013}", "\u{2014}"]

    // MARK: - El archivo

    /// El separador decimal que delatan las celdas de texto del archivo, o `nil` si ninguna lo dice (todas enteras o
    /// ambiguas) o se contradicen a partes iguales. Gana el que más celdas delatan.
    static func fileDecimalSeparator(for cells: [String]) -> Separator? {
        fileConvention(for: cells).decimal
    }

    /// Lo que el archivo dice del separador decimal.
    struct FileConvention: Equatable, Sendable {
        /// El que más celdas delatan, o `nil` si ninguna lo dice o empatan.
        let decimal: Separator?
        /// Hay celdas que delatan los dos: el archivo se contradice, y una celda ambigua no se lee en silencio.
        let isContested: Bool

        static let unknown = FileConvention(decimal: nil, isContested: false)
    }

    static func fileConvention(for cells: [String]) -> FileConvention {
        var dot = 0
        var comma = 0
        for cell in cells {
            guard let (_, shape) = prepare(cell), case .decided(_, _, let decimal?) = shape else { continue }
            if decimal == .dot { dot += 1 } else { comma += 1 }
        }
        let decimal: Separator? = dot == comma ? nil : (dot > comma ? .dot : .comma)
        return FileConvention(decimal: decimal, isContested: dot > 0 && comma > 0)
    }

    // MARK: - Una celda de texto

    /// Lee una celda de texto con el separador del archivo.
    ///
    /// - Parameters:
    ///   - fileDecimal: lo que devolvió `fileDecimalSeparator` para el archivo entero.
    ///   - fractionDigits: los decimales de la moneda de la fila. Con 3 (el dinar de Kuwait, por ejemplo) la lectura
    ///     propuesta de «1,500» es 1,5 y no 1500.
    /// - Returns: `nil` si la celda no es un importe.
    static func parse(_ raw: String, fileDecimal: Separator?, fractionDigits: Int) -> Reading? {
        parse(raw, convention: FileConvention(decimal: fileDecimal, isContested: false), fractionDigits: fractionDigits)
    }

    /// Lee una celda de texto con lo que dice el archivo. Una celda ambigua sale DUDOSA —entra con la lectura
    /// propuesta y la vista previa la enseña— si el archivo no decide, si se contradice, o si leerla como decimal le
    /// da más decimales de los que tiene la moneda («1,500» en soles con coma decimal en el resto del archivo: puede
    /// bastar una celda tecleada «12,5» para decidir la coma, y 1,500 soles no existe en un extracto).
    static func parse(_ raw: String, convention: FileConvention, fractionDigits: Int) -> Reading? {
        let fileDecimal = convention.decimal
        guard let (isNegative, shape) = prepare(raw) else { return nil }
        let integer: String
        let fraction: String
        var isDoubtful = false
        switch shape {
        case .integer(let digits):
            integer = digits
            fraction = ""
        case .decided(let int, let frac, _):
            integer = int
            fraction = frac
        case .ambiguous(let int, let frac, let separator):
            let readsAsDecimal: Bool
            if let fileDecimal {
                readsAsDecimal = separator == fileDecimal
                isDoubtful = convention.isContested || (readsAsDecimal && frac.count > fractionDigits)
            } else {
                readsAsDecimal = fractionDigits == 3
                isDoubtful = true
            }
            integer = readsAsDecimal ? int : int + frac
            fraction = readsAsDecimal ? frac : ""
        }
        guard let value = decimal(integer: integer, fraction: fraction, isNegative: isNegative) else { return nil }
        return Reading(value: value, isDoubtful: isDoubtful)
    }

    // MARK: - Una celda numérica de Excel

    /// Una celda que Excel guarda como NÚMERO ya viene en forma canónica («-1234.5», «1.5E3»): no pasa por el
    /// separador del archivo, que es cosa del texto. Con «1.234,56» en el resto del archivo, aplicarle la coma
    /// decimal convertiría 1500.5 en 15005.
    static func parseNumericCell(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let double = Double(trimmed), double.isFinite else { return nil }
        if let exact = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
           !trimmed.lowercased().contains("e") {
            return exact
        }
        return Decimal(double)
    }

    // MARK: - Piezas

    /// Separa el signo y deja solo cifras y separadores; clasifica la forma de la celda.
    static func prepare(_ raw: String) -> (isNegative: Bool, shape: Shape)? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // Negativo entre paréntesis, también con el símbolo fuera: «(12.50)», «S/ (12.50)», «(12.50) €» (el formato
        // Contabilidad de Excel guardado como CSV).
        var isNegative = false
        let characters = Array(text)
        if let open = characters.firstIndex(of: "("), let close = characters.lastIndex(of: ")"), open < close,
           let firstDigit = characters.firstIndex(where: { $0.isASCII && $0.isNumber }),
           let lastDigit = characters.lastIndex(where: { $0.isASCII && $0.isNumber }),
           open < firstDigit, close > lastDigit {
            isNegative = true
            text = String(characters[characters.index(after: open)..<close])
        }

        // Fuera espacios (también los no separables que usan algunos bancos como separador de miles), apóstrofos
        // de miles suizos y símbolos o letras de moneda. Se quedan cifras, separadores y signos.
        // Un punto pegado a una ABREVIATURA de moneda es suyo, no del número: «S/.12.50», «12.50 S/.», «Fr. 50».
        // Pegado a un símbolo no lo es: «$.50» es 0,50.
        var kept: [Character] = []
        var abbreviationBefore: [Bool] = []
        var previous: Character?
        var sawDigit = false
        var letterAmongDigits = false
        for character in text {
            if (character.isASCII && (character.isNumber || character == "." || character == ","))
                || minusSigns.contains(character) || character == "+" {
                kept.append(character)
                abbreviationBefore.append(previous.map { $0.isLetter || $0 == "/" } ?? false)
                if character.isNumber { sawDigit = true }
            } else if character.isLetter, sawDigit {
                // Una letra después de una cifra: solo vale si no vuelven las cifras («12.50 PEN», no «1.5E3»).
                letterAmongDigits = true
            }
            if character.isNumber, letterAmongDigits { return nil }
            previous = character
        }
        let firstDigit = kept.firstIndex(where: \.isNumber)
        let lastDigit = kept.lastIndex(where: \.isNumber)
        if let firstDigit, let lastDigit {
            var cleaned: [Character] = []
            for (index, character) in kept.enumerated() {
                let isSeparator = character == "." || character == ","
                let outside = index < firstDigit || index > lastDigit
                if isSeparator && outside && abbreviationBefore[index] { continue }
                cleaned.append(character)
            }
            kept = cleaned
        }

        // «1.500,–» y «Fr. 50.–»: la raya detrás del separador es «sin céntimos», no un signo, y ese separador es
        // el decimal de la celda.
        var noCentsDecimal: Separator?
        if let last = kept.last, minusSigns.contains(last), kept.count >= 2,
           kept[kept.count - 2] == "," || kept[kept.count - 2] == "." {
            noCentsDecimal = kept[kept.count - 2] == "," ? .comma : .dot
            kept.removeLast(2)
        }

        // El signo va al principio o al final; en medio no es un importe («1-2»).
        var body = kept[...]
        var signs = 0
        while let first = body.first, minusSigns.contains(first) || first == "+" {
            if minusSigns.contains(first) { signs += 1 }
            body = body.dropFirst()
        }
        while let last = body.last, minusSigns.contains(last) || last == "+" {
            if minusSigns.contains(last) { signs += 1 }
            body = body.dropLast()
        }
        guard signs <= 1, !body.isEmpty, body.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }),
              body.contains(where: \.isNumber)
        else { return nil }
        if signs == 1 { isNegative.toggle() }

        if let noCentsDecimal {
            guard let integer = groupedDigits(String(body), thousands: noCentsDecimal.other.character) else { return nil }
            return (isNegative, .decided(integer: integer, fraction: "", decimal: noCentsDecimal))
        }
        guard let shape = shape(of: String(body)) else { return nil }
        return (isNegative, shape)
    }

    private static func shape(of body: String) -> Shape? {
        let dots = body.filter { $0 == "." }.count
        let commas = body.filter { $0 == "," }.count

        if dots == 0 && commas == 0 { return .integer(digits: body) }

        if dots > 0 && commas > 0 {
            // Los dos: el último es el decimal y aparece una sola vez; el otro, los miles.
            guard let lastDot = body.lastIndex(of: "."), let lastComma = body.lastIndex(of: ",") else { return nil }
            let decimal: Separator = lastDot > lastComma ? .dot : .comma
            let decimalCount = decimal == .dot ? dots : commas
            guard decimalCount == 1, let index = body.lastIndex(of: decimal.character) else { return nil }
            let integerPart = String(body[..<index])
            let fraction = String(body[body.index(after: index)...])
            guard fraction.allSatisfy(\.isNumber),
                  let integer = groupedDigits(integerPart, thousands: decimal.other.character)
            else { return nil }
            return .decided(integer: integer, fraction: fraction, decimal: decimal)
        }

        let separator: Separator = dots > 0 ? .dot : .comma
        let parts = body.split(separator: separator.character, omittingEmptySubsequences: false).map(String.init)

        if parts.count > 2 {
            // El mismo separador varias veces: son miles («1.234.567»), y el decimal del archivo es el otro.
            guard let integer = groupedDigits(body, thousands: separator.character) else { return nil }
            return .decided(integer: integer, fraction: "", decimal: separator.other)
        }

        let integer = parts[0]
        let fraction = parts.count > 1 ? parts[1] : ""
        if fraction.count == 3, (1...3).contains(integer.count), integer.first != "0" {
            return .ambiguous(integer: integer, fraction: fraction, separator: separator)
        }
        // Otro número de decimales, una parte entera de más de tres cifras o que empieza por 0: es decimal.
        return .decided(integer: integer, fraction: fraction, decimal: separator)
    }

    /// Las cifras de una parte entera con separador de miles, si los grupos son de miles de verdad: el primero de 1 a
    /// 3 cifras y el resto de 3, o la agrupación india (lakh: «1,23,456», grupos de 2 y el último de 3). Sin
    /// separador, tal cual.
    private static func groupedDigits(_ text: String, thousands: Character) -> String? {
        guard text.contains(thousands) else { return text.allSatisfy(\.isNumber) ? text : nil }
        let groups = text.split(separator: thousands, omittingEmptySubsequences: false)
        guard let first = groups.first, let last = groups.last, groups.allSatisfy({ $0.allSatisfy(\.isNumber) })
        else { return nil }
        let western = (1...3).contains(first.count) && groups.dropFirst().allSatisfy { $0.count == 3 }
        let indian = groups.count >= 3 && (1...2).contains(first.count) && last.count == 3
            && groups.dropFirst().dropLast().allSatisfy { $0.count == 2 }
        guard western || indian else { return nil }
        return groups.joined()
    }

    private static func decimal(integer: String, fraction: String, isNegative: Bool) -> Decimal? {
        let digits = integer.isEmpty ? "0" : integer
        let text = fraction.isEmpty ? digits : "\(digits).\(fraction)"
        guard var value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        if isNegative && value != 0 { value.negate() }
        return value
    }
}
