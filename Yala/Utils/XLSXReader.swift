//
//  XLSXReader.swift
//  Yala
//
//  Lector de archivos Excel (.xlsx) para importación de transacciones.
//  Utiliza CoreXLSX para parsear archivos Excel y devolver filas crudas, con las columnas por nombre.
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

        /// En llano y traducido (auditoría UX 2.2, lote 7, L7-17), sin el encabezado crudo.
        var errorDescription: String? {
            switch self {
            case .cannotOpenFile:
                return L10n.UXL7.ImportErrors.xlsxCannotOpen
            case .noWorksheets:
                return L10n.UXL7.ImportErrors.xlsxNoSheets
            case .cannotParseWorksheet:
                return L10n.UXL7.ImportErrors.xlsxCannotRead
            }
        }
    }

    // MARK: - Public API

    /// Lee un archivo XLSX a filas crudas, con las columnas por nombre (`ImportHeader`).
    ///
    /// Desde el 2026-10-29 (H3 de la auditoría del import 2.2, card 7wh5):
    /// - **Sin tabla de textos compartidos se sigue**: un Excel escrito por un script (openpyxl, el caso real de Jürgen)
    ///   guarda cada texto DENTRO de su celda (`inlineStr`) y no trae `sharedStrings.xml`. Antes eso era «No pudimos
    ///   abrir el archivo de Excel» y la cabecera solo se leía de esa tabla.
    /// - **Con varias hojas, la primera cuya cabecera se reconoce**: una portada o una hoja de notas delante ya no
    ///   tapan los datos.
    /// - **La fecha se convierte en la columna `date`**, no en la primera.
    static func readTable(from url: URL) throws -> ImportTable {
        guard url.pathExtension.lowercased() == "xlsx" else { throw ImportError.invalidFileExtension }

        // Acceder al recurso con seguridad (requerido para el selector de archivos en iOS).
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let xlsxFile = XLSXFile(filepath: url.path) else {
            throw XLSXError.cannotOpenFile
        }

        // Puede no estar: entonces no hay celdas de texto compartido que leer.
        let sharedStrings = try xlsxFile.parseSharedStrings()

        let sheets = try orderedSheets(of: xlsxFile)
        guard !sheets.isEmpty else {
            throw XLSXError.noWorksheets
        }

        var firstHeaderError: Error?
        var chosen: ImportTable?
        var chosenName: String?
        var skippedWithData: [String] = []
        for sheet in sheets {
            let worksheet: Worksheet
            do {
                worksheet = try xlsxFile.parseWorksheet(at: sheet.path)
            } catch {
                // Una hoja que no se deja leer no tapa a las demás.
                #if DEBUG
                print("XLSXReader: Error: hoja \(sheet.path) ilegible: \(error)")
                #endif
                if firstHeaderError == nil { firstHeaderError = XLSXError.cannotParseWorksheet }
                continue
            }
            guard let rows = worksheet.data?.rows,
                  let headerRow = rows.first(where: { row in
                      row.cells.contains { !cellText($0, sharedStrings: sharedStrings).isEmpty }
                  })
            else { continue }

            let headerCells = cellValues(of: headerRow, sharedStrings: sharedStrings, dateColumn: nil)
            let header: ImportHeader
            do {
                header = try ImportHeader.map(headerCells.map(\.text))
            } catch {
                if firstHeaderError == nil { firstHeaderError = error }
                continue
            }

            let dateColumn = header.indexByField[.date]
            let amountColumn = header.indexByField[.amount]
            let timeColumn = header.indexByField[.time]
            let rateColumn = header.indexByField[.exchangeRate]
            var rawRows: [RawImportRow] = []
            rawRows.reserveCapacity(rows.count)
            for row in rows where row.reference > headerRow.reference {
                let cells = cellValues(
                    of: row, sharedStrings: sharedStrings, dateColumn: dateColumn, timeColumn: timeColumn)
                guard cells.contains(where: { !$0.text.isEmpty }) else { continue }
                let amountIsNumber = amountColumn.map { $0 < cells.count && cells[$0].isNumber } ?? false
                let rateIsNumber = rateColumn.map { $0 < cells.count && cells[$0].isNumber } ?? false
                rawRows.append(header.row(
                    number: Int(row.reference), cells: cells.map(\.text), amountIsNumber: amountIsNumber,
                    exchangeRateIsNumber: rateIsNumber))
            }
            if chosen == nil {
                chosen = ImportFileReader.table(rows: rawRows, header: header)
                chosenName = sheet.name
            } else if !rawRows.isEmpty {
                // Otra hoja con movimientos que no se lee: la vista previa lo dice.
                skippedWithData.append(sheet.name ?? sheet.path)
            }
        }

        if var chosen {
            if !skippedWithData.isEmpty {
                chosen.readSheet = chosenName
                chosen.skippedSheets = skippedWithData
            }
            return chosen
        }

        if let firstHeaderError { throw firstHeaderError }
        throw ImportError.emptyFile
    }

    /// Lee un archivo XLSX y devuelve las filas como `RawImportRow`.
    static func readRows(from url: URL) throws -> [RawImportRow] {
        try readTable(from: url).rows
    }

    /// Escanea un archivo XLSX y devuelve el conjunto de monedas únicas encontradas.
    static func scanCurrencies(from url: URL) throws -> Set<String> {
        try ImportFileReader.scan(url).currencies
    }

    // MARK: - Private Helpers

    /// Las hojas en el orden de sus PESTAÑAS (el de `workbook.xml`), con su nombre. `parseWorksheetPaths` sigue el
    /// orden de las relaciones, que no tiene por qué ser el que ve la persona.
    private static func orderedSheets(of file: XLSXFile) throws -> [(name: String?, path: String)] {
        guard let workbook = try file.parseWorkbooks().first else {
            return try file.parseWorksheetPaths().map { (name: nil, path: $0) }
        }
        let byName = try file.parseWorksheetPathsAndNames(workbook: workbook)
        let order = workbook.sheets.items.compactMap(\.name)
        return byName.sorted { lhs, rhs in
            (lhs.name.flatMap { order.firstIndex(of: $0) } ?? Int.max)
                < (rhs.name.flatMap { order.firstIndex(of: $0) } ?? Int.max)
        }
    }

    /// El texto de una celda: de la tabla compartida (si la hay y el índice existe), del texto en línea o del valor.
    private static func cellText(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        let raw: String?
        switch cell.type {
        case .sharedString:
            if let sharedStrings, let index = cell.value.flatMap(Int.init), sharedStrings.items.indices.contains(index) {
                let item = sharedStrings.items[index]
                raw = item.text ?? item.richText.compactMap(\.text).joined()
            } else {
                raw = nil
            }
        case .inlineStr:
            raw = cell.inlineString?.text ?? cell.value
        default:
            raw = cell.value ?? cell.inlineString?.text
        }
        return (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Las celdas de una fila por su columna (A=0, B=1…), con su texto y si eran un número.
    /// En la columna de la fecha, un número de serie de Excel se convierte a fecha ISO.
    private static func cellValues(
        of row: Row, sharedStrings: SharedStrings?, dateColumn: Int?, timeColumn: Int? = nil
    ) -> [(text: String, isNumber: Bool)] {
        var values: [(text: String, isNumber: Bool)] = []
        for cell in row.cells {
            guard let columnIndex = columnIndexFromReference(cell.reference.column.value), columnIndex < 1_000 else {
                continue
            }
            var value = cellText(cell, sharedStrings: sharedStrings)
            let isNumber = (cell.type == nil || cell.type == .number) && !value.isEmpty && Double(value) != nil

            // Excel guarda las fechas como días desde 1899 (45658 es un día de 2025).
            if columnIndex == dateColumn, isNumber, let serialDate = Double(value), serialDate > 1000 && serialDate < 100000 {
                value = excelSerialDateToISO(serialDate)
            }
            // Una hora es una fracción de día («0» es medianoche, «0.5» mediodía): a «HH:mm:ss» (H18).
            if columnIndex == timeColumn, isNumber, let serial = Double(value), let time = excelTimeText(serial) {
                value = time
            }

            while values.count <= columnIndex { values.append((text: "", isNumber: false)) }
            values[columnIndex] = (text: value, isNumber: isNumber)
        }
        return values
    }

    /// La hora de un número de Excel: la parte decimal es la fracción del día (una fecha con hora trae también los días
    /// delante, y se quedan fuera). `nil` si no es un número de Excel válido.
    static func excelTimeText(_ serial: Double) -> String? {
        guard serial.isFinite, serial >= 0 else { return nil }
        var seconds = Int(((serial - serial.rounded(.down)) * 86_400).rounded())
        if seconds == 86_400 { seconds = 0 }
        return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
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
        let day = formatter.string(from: resultDate)

        // Una fecha con hora guarda la hora como fracción del día: se escribe detrás para que el import la conserve
        // (H18). Sin fracción, solo la fecha, como siempre.
        let seconds = Int(((correctedSerial - correctedSerial.rounded(.down)) * 86_400).rounded())
        guard seconds > 0, seconds < 86_400 else { return day }
        return day + String(format: " %02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
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
