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
    func row(number: Int, cells: [String], amountIsNumber: Bool = false) -> RawImportRow {
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
            amountIsNumber: amountIsNumber
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

        let contents: String
        do {
            contents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ImportError.unreadableFile
        }
        return try parseCSV(contents)
    }

    static func parseCSV(_ contents: String) throws -> ImportTable {
        // El BOM de UTF-8 fuera antes de partir: delante de una cabecera entre comillas impedía abrir la comilla.
        let contents = contents.hasPrefix("\u{FEFF}") ? String(contents.dropFirst()) : contents
        var lines = TransactionCSVImportService.splitCSVIntoRows(contents)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        guard !lines.isEmpty else { throw ImportError.emptyFile }

        let headerLine = lines.removeFirst()
        let delimiter = TransactionCSVImportService.detectDelimiter(from: headerLine)
        let headerCells = TransactionCSVImportService.splitCSVFields(headerLine, delimiter: delimiter)
        let header = try ImportHeader.map(headerCells)
        // La nota recoge los delimitadores de más solo si es la última columna con nombre.
        let lastNamed = headerCells.lastIndex { !ImportHeader.normalized($0).isEmpty } ?? 0
        let noteIndex = header.indexByField[.note]
        let columnCount = lastNamed + 1

        var rows: [RawImportRow] = []
        rows.reserveCapacity(lines.count)
        for (index, line) in lines.enumerated() {
            let rowNumber = index + 2  // la cabecera es la fila 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Una línea sin delimitador es ruido (la segunda línea de una nota partida, un resumen al final).
            if trimmed.isEmpty || !trimmed.contains(delimiter) { continue }
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
