//
//  XLSXReader.swift
//  Neto
//
//  Lector de archivos Excel (.xlsx) para importación de transacciones.
//  Utiliza CoreXLSX para parsear archivos Excel y devolver filas crudas.
//

import CoreXLSX
import Foundation

// MARK: - XLSX Reader

enum XLSXReader {

    // MARK: - Errors

    enum XLSXError: LocalizedError {
        case cannotOpenFile
        case noWorksheets
        case cannotParseWorksheet
        case invalidHeader(found: String)
        case missingSharedStrings

        var errorDescription: String? {
            switch self {
            case .cannotOpenFile:
                return "No se pudo abrir el archivo XLSX."
            case .noWorksheets:
                return "El archivo XLSX no contiene hojas de cálculo."
            case .cannotParseWorksheet:
                return "No se pudo leer la hoja de cálculo."
            case .invalidHeader(let found):
                return "El encabezado del XLSX no es válido. Se encontró: \(found)."
            case .missingSharedStrings:
                return "El archivo XLSX no contiene la tabla de strings compartidos."
            }
        }
    }

    // MARK: - Public API

    /// Lee un archivo XLSX y devuelve las filas como `RawImportRow`.
    ///
    /// - Parameter url: URL local del archivo XLSX.
    /// - Returns: Array de filas crudas listas para validación.
    static func readRows(from url: URL) throws -> [RawImportRow] {
        // 1. Acceder al recurso con seguridad (requerido para file picker en iOS)
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 2. Abrir archivo XLSX
        guard let xlsxFile = XLSXFile(filepath: url.path) else {
            throw XLSXError.cannotOpenFile
        }

        // 3. Obtener shared strings (texto de celdas)
        guard let sharedStrings = try xlsxFile.parseSharedStrings() else {
            throw XLSXError.missingSharedStrings
        }

        // 4. Obtener la primera hoja de cálculo
        let worksheetPaths = try xlsxFile.parseWorksheetPaths()
        guard let firstPath = worksheetPaths.first else {
            throw XLSXError.noWorksheets
        }

        let worksheet = try xlsxFile.parseWorksheet(at: firstPath)

        guard let rows = worksheet.data?.rows, !rows.isEmpty else {
            throw ImportError.emptyFile
        }

        // 5. Validar encabezado (primera fila)
        let headerRow = rows[0]
        let headerColumns = headerRow.cells.compactMap { cell -> String? in
            cell.stringValue(sharedStrings)?.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // Validar formato de encabezado
        let expectedBase = ["date", "amount", "currency", "category", "subcategory"]
        let expectedWithNote = expectedBase + ["note"]
        let expectedWithTagsAndNote = expectedBase + ["tags", "note"]
        let expectedWithTagsOnly = expectedBase + ["tags"]

        let headerMatchesBase = headerColumns == expectedBase
        let headerMatchesWithNote = headerColumns == expectedWithNote
        let headerMatchesWithTagsAndNote = headerColumns == expectedWithTagsAndNote
        let headerMatchesWithTagsOnly = headerColumns == expectedWithTagsOnly

        guard headerMatchesBase || headerMatchesWithNote || headerMatchesWithTagsAndNote || headerMatchesWithTagsOnly else {
            let foundHeader = headerColumns.joined(separator: ", ")
            throw XLSXError.invalidHeader(found: foundHeader)
        }

        let hasTagsColumn = headerMatchesWithTagsAndNote || headerMatchesWithTagsOnly
        let hasNoteColumn = headerMatchesWithNote || headerMatchesWithTagsAndNote

        // 6. Procesar filas de datos (saltando el encabezado)
        var rawRows: [RawImportRow] = []
        rawRows.reserveCapacity(rows.count - 1)

        for (index, row) in rows.dropFirst().enumerated() {
            let rowNumber = index + 2  // +2 porque saltamos header y Excel empieza en 1

            // Obtener valores de celdas
            let cellValues = extractCellValues(from: row, sharedStrings: sharedStrings, columnCount: headerColumns.count)

            // Ignorar filas completamente vacías
            let nonEmptyValues = cellValues.filter { !$0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty }
            if nonEmptyValues.isEmpty {
                continue
            }

            // Extraer valores por columna
            let dateValue = cellValues.count > 0 ? cellValues[0] : ""
            let amountValue = cellValues.count > 1 ? cellValues[1] : ""
            let currencyValue = cellValues.count > 2 ? cellValues[2] : ""
            let categoryValue = cellValues.count > 3 ? cellValues[3] : ""
            let subcategoryValue = cellValues.count > 4 ? cellValues[4] : ""

            let tagsValue: String?
            let noteValue: String?

            switch (hasTagsColumn, hasNoteColumn) {
            case (true, true):
                tagsValue = cellValues.count > 5 ? cellValues[5] : nil
                noteValue = cellValues.count > 6 ? cellValues[6] : nil
            case (true, false):
                tagsValue = cellValues.count > 5 ? cellValues[5] : nil
                noteValue = nil
            case (false, true):
                tagsValue = nil
                noteValue = cellValues.count > 5 ? cellValues[5] : nil
            case (false, false):
                tagsValue = nil
                noteValue = nil
            }

            let rawRow = RawImportRow(
                rowNumber: rowNumber,
                date: dateValue,
                amount: amountValue,
                currency: currencyValue,
                category: categoryValue,
                subcategory: subcategoryValue,
                tags: tagsValue,
                note: noteValue
            )

            rawRows.append(rawRow)
        }

        return rawRows
    }

    /// Escanea un archivo XLSX y devuelve el conjunto de monedas únicas encontradas.
    ///
    /// - Parameter url: URL local del archivo XLSX.
    /// - Returns: Set con los códigos de moneda normalizados encontrados.
    static func scanCurrencies(from url: URL) throws -> Set<String> {
        let rows = try readRows(from: url)

        var currencies = Set<String>()
        for row in rows {
            let normalized = TransactionCSVImportService.normalizeCurrencyInput(row.currency)
            if !normalized.isEmpty {
                currencies.insert(normalized)
            }
        }

        return currencies
    }

    // MARK: - Private Helpers

    /// Extrae los valores de todas las celdas de una fila como strings.
    /// Para la columna de fecha (índice 0), convierte valores numéricos de Excel a formato ISO.
    private static func extractCellValues(from row: Row, sharedStrings: SharedStrings, columnCount: Int) -> [String] {
        var values = Array(repeating: "", count: columnCount)

        for cell in row.cells {
            // Obtener índice de columna (A=0, B=1, etc.)
            guard let columnIndex = columnIndexFromReference(cell.reference.column.value) else {
                continue
            }

            guard columnIndex < columnCount else {
                continue
            }

            // Obtener valor de la celda
            var value: String
            if let stringValue = cell.stringValue(sharedStrings) {
                value = stringValue
            } else if let inlineString = cell.inlineString?.text {
                value = inlineString
            } else if let numericValue = cell.value {
                value = numericValue
            } else {
                value = ""
            }

            value = value.trimmingCharacters(in: .whitespacesAndNewlines)

            // Columna 0 es la fecha - si el valor es un número puro (Excel serial date), convertirlo
            if columnIndex == 0, !value.isEmpty {
                // Check if value is a pure number (Excel serial date)
                // Excel dates are typically 5-digit numbers (e.g., 45658 for dates in 2024+)
                if let serialDate = Double(value), serialDate > 1000 && serialDate < 100000 {
                    value = excelSerialDateToISO(serialDate)
                }
            }

            values[columnIndex] = value
        }

        return values
    }

    /// Convierte un número serial de Excel a fecha ISO (yyyy-MM-dd).
    /// Excel cuenta días desde 1899-12-30 (con el bug del año 1900 bisiesto).
    private static func excelSerialDateToISO(_ serialDate: Double) -> String {
        // Excel's epoch is December 30, 1899 (accounting for the 1900 leap year bug)
        // Serial number 1 = January 1, 1900
        // Serial number 2 = January 2, 1900
        // But Excel incorrectly treats 1900 as a leap year, so dates after Feb 28, 1900
        // are off by one day. For modern dates (>= 61), we subtract 1 to correct.
        let correctedSerial = serialDate > 60 ? serialDate - 1 : serialDate

        // Reference date: December 31, 1899 (day 1 = Jan 1, 1900)
        var components = DateComponents()
        components.year = 1899
        components.month = 12
        components.day = 31
        components.hour = 12  // Noon to avoid timezone issues

        let calendar = Calendar(identifier: .gregorian)
        guard let baseDate = calendar.date(from: components) else {
            return String(format: "%.0f", serialDate)  // Fallback to raw value
        }

        // Add the serial days
        let days = Int(correctedSerial)
        guard let resultDate = calendar.date(byAdding: .day, value: days, to: baseDate) else {
            return String(format: "%.0f", serialDate)
        }

        // Format as ISO date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: resultDate)
    }

    /// Convierte referencia de columna (A, B, ..., Z, AA, AB, ...) a índice numérico.
    private static func columnIndexFromReference(_ reference: String) -> Int? {
        var result = 0
        for char in reference.uppercased() {
            guard let asciiValue = char.asciiValue, asciiValue >= 65, asciiValue <= 90 else {
                return nil
            }
            result = result * 26 + Int(asciiValue - 64)
        }
        return result - 1  // Convertir a 0-based index
    }
}
