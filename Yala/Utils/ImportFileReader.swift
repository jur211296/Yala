//
//  ImportFileReader.swift
//  Yala
//
//  Lee un archivo importado (CSV o Excel) a filas crudas, con las columnas por NOMBRE (H4 de la auditoría del import
//  2.2, card mnox).
//
//  Hasta el 2026-10-29 la cabecera tenía que ser exactamente `date,amount,currency,category,subcategory` con `tags` y
//  `note` opcionales al final, así que el archivo que exporta Yala (`…,account,…,split_total,split_portion`) no volvía a
//  entrar. Ahora el orden da igual, las mayúsculas y los espacios también, las columnas que el import no usa se ignoran
//  y la vista previa las nombra, y si falta una obligatoria el error dice cuál.
//

import Foundation

/// Las columnas que el import entiende.
enum ImportField: String, CaseIterable {
    case date
    case amount
    case currency
    case account
    case category
    case subcategory
    case tags
    case note
    /// Opcionales desde el 2026-11-12 (H18): la hora, la tasa fija y a qué moneda es, y la naturaleza cambiada a mano.
    case time
    case exchangeRate = "exchange_rate"
    case rateCurrency = "rate_currency"
    case need

    /// Las que tiene que traer todo archivo.
    static let required: [ImportField] = [.date, .amount, .currency, .category, .subcategory]
}

/// Dónde está cada columna conocida y qué columnas se ignoran.
struct ImportHeader: Equatable {
    let indexByField: [ImportField: Int]
    /// Las columnas que el import no usa, como estaban escritas.
    let ignoredColumns: [String]

    /// El nombre de una columna sin mayúsculas, sin espacios alrededor y con los de dentro como `_`
    /// («Split Total» = `split_total`). Fuera también el BOM de UTF-8.
    static func normalized(_ name: String) -> String {
        name.replacing("\u{FEFF}", with: "")
            .split(whereSeparator: \.isWhitespace).joined(separator: "_")
            .lowercased()
    }

    /// Lee la cabecera por nombre.
    ///
    /// - Throws: `ImportError.duplicateColumn` si una columna conocida aparece dos veces (no se elige una en silencio)
    ///   y `ImportError.missingColumns` si falta alguna obligatoria.
    static func map(_ cells: [String]) throws -> ImportHeader {
        var indexByField: [ImportField: Int] = [:]
        var ignored: [String] = []
        for (index, cell) in cells.enumerated() {
            let name = normalized(cell)
            guard !name.isEmpty else { continue }
            if let field = ImportField(rawValue: name) {
                guard indexByField[field] == nil else { throw ImportError.duplicateColumn(name: field.rawValue) }
                indexByField[field] = index
            } else {
                let shown = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                if !ignored.contains(shown) { ignored.append(shown) }
            }
        }
        let missing = ImportField.required.filter { indexByField[$0] == nil }.map(\.rawValue)
        guard missing.isEmpty else { throw ImportError.missingColumns(missing) }
        return ImportHeader(indexByField: indexByField, ignoredColumns: ignored)
    }

    /// La fila cruda a partir de sus celdas, por posición.
    func row(number: Int, cells: [String], amountIsNumber: Bool = false, exchangeRateIsNumber: Bool = false) -> RawImportRow {
        func value(_ field: ImportField) -> String? {
            guard let index = indexByField[field] else { return nil }
            return index < cells.count ? cells[index].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        return RawImportRow(
            rowNumber: number,
            date: value(.date) ?? "",
            amount: value(.amount) ?? "",
            currency: value(.currency) ?? "",
            category: value(.category) ?? "",
            subcategory: value(.subcategory) ?? "",
            tags: value(.tags),
            note: value(.note),
            account: value(.account),
            amountIsNumber: amountIsNumber,
            time: value(.time),
            exchangeRate: value(.exchangeRate),
            rateCurrency: value(.rateCurrency),
            need: value(.need),
            exchangeRateIsNumber: exchangeRateIsNumber
        )
    }
}

/// Un archivo leído: sus filas y las columnas que se ignoran.
struct ImportTable {
    let rows: [RawImportRow]
    let ignoredColumns: [String]
    /// La columna `account` existe y alguna fila la rellena: cada fila va a la cuenta que nombra.
    let usesAccountColumn: Bool
    /// Excel con varias hojas con movimientos: la que se lee y las que no.
    var readSheet: String? = nil
    var skippedSheets: [String] = []
}

/// Lo que hace falta saber de un archivo antes de elegir a dónde va.
struct ImportScan: Equatable {
    let currencies: Set<String>
    let usesAccountColumn: Bool
}

enum ImportFileReader {

    /// Lee un CSV o un Excel.
    static func readTable(from url: URL) throws -> ImportTable {
        switch url.pathExtension.lowercased() {
        case "csv": return try readCSV(from: url)
        case "xlsx": return try XLSXReader.readTable(from: url)
        default: throw ImportError.invalidFileExtension
        }
    }

    /// Las monedas del archivo y si trae cuenta por fila.
    static func scan(_ url: URL) throws -> ImportScan {
        let table = try readTable(from: url)
        var currencies = Set<String>()
        for row in table.rows {
            let code = TransactionCSVImportService.normalizeCurrencyInput(row.currency)
            if !code.isEmpty { currencies.insert(code) }
        }
        return ImportScan(currencies: currencies, usesAccountColumn: table.usesAccountColumn)
    }

    static func table(rows: [RawImportRow], header: ImportHeader) -> ImportTable {
        let usesAccount = header.indexByField[.account] != nil
            && rows.contains { !($0.account ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return ImportTable(rows: rows, ignoredColumns: header.ignoredColumns, usesAccountColumn: usesAccount)
    }

    // MARK: - CSV

    static func readCSV(from url: URL) throws -> ImportTable {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }

        // Los archivos que llegan del selector de archivos piden permiso explícito en un dispositivo real.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadableFile
        }
        guard let contents = decodeText(data) else { throw ImportError.unreadableFile }
        return try parseCSV(contents)
    }

    /// El texto del archivo en la codificación en la que venga (H13). Hasta el 2026-11-12 solo se leía UTF-8, y el «CSV»
    /// que guarda Excel en Windows (Windows-1252) o el «texto Unicode» (UTF-16) no se abrían. Orden: UTF-8 (con o sin
    /// BOM), UTF-16 si trae su BOM, Windows-1252 y, como último recurso, ISO Latin-1, que lee cualquier byte.
    static func decodeText(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        // Casi todo UTF-8 con algún byte roto (un archivo pegado de dos sitios): leerlo entero como Windows-1252 rompería
        // todas sus tildes («AlimentaciÃ³n») y las categorías dejarían de casar. Si trae secuencias UTF-8 de varios
        // bytes, es UTF-8: solo el byte roto se pierde.
        if containsMultibyteUTF8(data) { return String(decoding: data, as: UTF8.self) }
        if let text = String(data: data, encoding: .windowsCP1252) { return text }
        return String(data: data, encoding: .isoLatin1)
    }

    /// ¿Hay al menos una secuencia UTF-8 válida de 2 a 4 bytes? En un texto Windows-1252 o Latin-1 una letra con tilde es
    /// un solo byte alto seguido casi siempre de una letra ASCII, que no forma esa secuencia.
    static func containsMultibyteUTF8(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            let lead = bytes[index]
            let length: Int
            switch lead {
            case 0xC2...0xDF: length = 2
            case 0xE0...0xEF: length = 3
            case 0xF0...0xF4: length = 4
            default: index += 1; continue
            }
            if index + length <= bytes.count, bytes[(index + 1)..<(index + length)].allSatisfy({ $0 & 0xC0 == 0x80 }) {
                return true
            }
            index += 1
        }
        return false
    }

    static func parseCSV(_ contents: String) throws -> ImportTable {
        // El BOM fuera antes de partir: delante de una cabecera entre comillas impedía abrir la comilla.
        let contents = contents.hasPrefix("\u{FEFF}") ? String(contents.dropFirst()) : contents
        // El separador sale de la cabecera, la primera línea con texto; hace falta ANTES de partir las filas, porque
        // una comilla solo abre al principio de un campo y el campo empieza tras el separador (H13).
        let firstLine = contents.split(whereSeparator: \.isNewline)
            .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(String.init) ?? ""
        let delimiter = TransactionCSVImportService.detectDelimiter(from: firstLine)
        // Con tabulador como separador, un tabulador al principio o al final es una celda vacía, no relleno.
        let padding: CharacterSet = delimiter == "\t" ? CharacterSet.newlines.union(CharacterSet(charactersIn: " ")) : .whitespacesAndNewlines

        var lines = TransactionCSVImportService.splitCSVRows(contents, delimiter: delimiter)
            .filter { !$0.text.trimmingCharacters(in: padding).isEmpty }
        guard !lines.isEmpty else { throw ImportError.emptyFile }

        let headerLine = lines.removeFirst().text
        let headerCells = TransactionCSVImportService.splitCSVFields(headerLine, delimiter: delimiter)
        let header = try ImportHeader.map(headerCells)
        // La nota recoge los delimitadores de más solo si es la última columna con nombre.
        let lastNamed = headerCells.lastIndex { !ImportHeader.normalized($0).isEmpty } ?? 0
        let noteIndex = header.indexByField[.note]
        let columnCount = lastNamed + 1

        var rows: [RawImportRow] = []
        rows.reserveCapacity(lines.count)
        for line in lines {
            // La línea física del archivo donde empieza la fila (la cabecera es la 1): las líneas en blanco no la
            // desplazan, así que el número que sale en «filas que no entraron» es el que la persona ve en su editor.
            let rowNumber = line.line
            let trimmed = line.text.trimmingCharacters(in: padding)
            // Una línea con texto y sin separador (la segunda línea de una nota partida, un total al final) no se
            // salta en silencio: sale entre las que no entraron, con su número (H13).
            if !trimmed.contains(delimiter) {
                rows.append(RawImportRow.unreadable(rowNumber: rowNumber))
                continue
            }
            if trimmed.replacing(String(delimiter), with: "").trimmingCharacters(in: .whitespaces).isEmpty { continue }

            let rawCells = TransactionCSVImportService.splitCSVFields(trimmed, delimiter: delimiter)
            var cells = rawCells.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            // Una fila de solo comillas vacías (`"","",…`) es tan vacía como `,,,`.
            if cells.allSatisfy(\.isEmpty) { continue }
            while cells.count > columnCount && cells.last?.isEmpty == true { cells.removeLast() }
            if cells.count > columnCount {
                if let noteIndex, noteIndex == lastNamed {
                    // Con el texto tal cual: «uno, dos» conserva su espacio.
                    let merged = rawCells[noteIndex..<min(rawCells.count, cells.count)]
                        .joined(separator: String(delimiter)).trimmingCharacters(in: .whitespacesAndNewlines)
                    cells = Array(cells[..<noteIndex]) + [merged]
                } else {
                    rows.append(RawImportRow.columnCountMismatch(
                        rowNumber: rowNumber, expected: columnCount, found: cells.count))
                    continue
                }
            }
            // Con celdas de menos no se sabe cuál falta: rellenar desplazaría columnas (una nota acabaría en tags).
            guard cells.count == columnCount else {
                rows.append(RawImportRow.columnCountMismatch(
                    rowNumber: rowNumber, expected: columnCount, found: cells.count))
                continue
            }
            rows.append(header.row(number: rowNumber, cells: cells))
        }
        return table(rows: rows, header: header)
    }
}
