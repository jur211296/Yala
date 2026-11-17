//
//  GroupExportCSV.swift
//  Yala
//
//  Lectura de bajo nivel de los exports de Splitwise y Tricount: filas de un CSV (comillas, saltos de línea dentro de un
//  campo, `,`/`;`/tabulador), importes con punto o coma decimal y fechas. Puro y sin SwiftData: lo usan los dos lectores
//  de `ImportarGrupo` y lo fijan sus tests.
//
//  No reusa los helpers de `TransactionCSVImportService` a propósito: viven dentro de un servicio acoplado a los
//  movimientos personales y extraerlos tocaba ese fichero (fuera del encargo). Esto es lo justo para dos formatos.
//

import Foundation

enum GroupExportCSV {

    // MARK: - Filas

    /// Las filas del texto, con el separador que más aparece en la primera línea con contenido.
    static func rows(from text: String) -> [[String]] {
        var characters = Array(text)
        if characters.first == "\u{FEFF}" { characters.removeFirst() }
        let delimiter = detectDelimiter(in: String(characters))
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        while index < characters.count {
            let char = characters[index]
            index += 1
            if inQuotes {
                if char == "\"" {
                    if index < characters.count, characters[index] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
                continue
            }
            switch char {
            case "\"":
                inQuotes = true
            case delimiter:
                row.append(field)
                field = ""
            case "\r\n", "\n", "\r":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            default:
                field.append(char)
            }
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.map { $0.map { $0.trimmingCharacters(in: .whitespaces) } }
    }

    /// `,`, `;` o tabulador: el que más veces aparece fuera de comillas en la primera línea con contenido.
    static func detectDelimiter(in text: String) -> Character {
        let candidates: [Character] = [",", ";", "\t"]
        var counts: [Character: Int] = [:]
        var inQuotes = false
        for char in text {
            if char == "\"" { inQuotes.toggle(); continue }
            if inQuotes { continue }
            if char == "\n" || char == "\r" || char == "\r\n" {
                if counts.values.contains(where: { $0 > 0 }) { break }
                continue
            }
            if candidates.contains(char) { counts[char, default: 0] += 1 }
        }
        return candidates.max { (counts[$0] ?? 0) < (counts[$1] ?? 0) } ?? ","
    }

    static func isBlank(_ row: [String]) -> Bool {
        row.allSatisfy { $0.isEmpty }
    }

    // MARK: - Importes

    /// Un importe escrito como lo escriben los exports: «-15.00», «1,234.56», «1.234,56», «12,5», «(3.00)», «S/ 20».
    /// `nil` si no hay ningún dígito o queda algo que no es un número. Vacío no es cero: lo decide quien llama.
    static func amount(_ raw: String) -> Decimal? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.contains(where: \.isNumber) else { return nil }
        var negative = false
        if text.hasPrefix("(") && text.hasSuffix(")") {
            negative = true
            text = String(text.dropFirst().dropLast())
        }
        // Lo que va antes del primer dígito es símbolo o signo: «S/. 20» no es «.20», es 20 (revisión del 2026-11-16).
        guard let firstDigit = text.firstIndex(where: { $0.isASCII && $0.isNumber }) else { return nil }
        let prefix = text[..<firstDigit]
        if prefix.contains("-") { negative.toggle() }
        text = String(text[firstDigit...])
        // Fuera espacios (también el fino y el de no separar), apóstrofes de miles y un símbolo detrás («20 USD»).
        text = String(text.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == "," || $0 == "-" || $0 == "+") })
        if text.hasSuffix("-") {
            negative.toggle()
            text.removeLast()
        }
        guard !text.isEmpty, !text.contains("-"), !text.contains("+") else { return nil }

        let normalized: String
        switch (text.lastIndex(of: "."), text.lastIndex(of: ",")) {
        case let (dot?, comma?):
            // Los dos: el que va último es el decimal.
            normalized = dot > comma
                ? text.replacingOccurrences(of: ",", with: "")
                : text.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        case let (nil, comma?):
            let commas = text.filter { $0 == "," }.count
            let decimals = text.distance(from: text.index(after: comma), to: text.endIndex)
            // Una sola coma con 1-2 cifras detrás es decimal («12,5», «1234,56»); si no, de miles («1,234»).
            normalized = commas == 1 && (1...2).contains(decimals)
                ? text.replacingOccurrences(of: ",", with: ".")
                : text.replacingOccurrences(of: ",", with: "")
        case (_?, nil):
            // Varios puntos son de miles («1.234.567»). Uno solo es decimal: así escriben Splitwise y Tricount.
            normalized = text.filter { $0 == "." }.count > 1 ? text.replacingOccurrences(of: ".", with: "") : text
        case (nil, nil):
            normalized = text
        }
        guard normalized.contains(where: \.isNumber),
              normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              normalized.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return negative ? -value : value
    }

    /// Céntimos de un importe, redondeado a dos decimales (lo que guardan los saldos de un grupo).
    static func cents(_ value: Decimal) -> Int {
        var scaled = value * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    // MARK: - Fechas

    private static let dateFormats = [
        "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "dd/MM/yyyy", "dd/MM/yyyy HH:mm", "dd/MM/yyyy HH:mm:ss", "dd.MM.yyyy",
        "dd.MM.yyyy HH:mm", "dd-MM-yyyy", "MM/dd/yyyy",
    ]

    /// La fecha de una fila. Solo sirve para enseñar el rango del export en la vista previa: si no se lee, `nil`.
    static func date(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    // MARK: - Cabeceras

    /// Una cabecera en minúsculas, sin tildes y sin espacios de sobra, para compararla con las listas de nombres.
    static func headerKey(_ raw: String) -> String {
        raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}
