//
//  TransactionsExportService.swift
//  Yala
//
//  Servicio central de exportación de transacciones a CSV y XLSX.
//  - Aplica filtros definidos en `ExportFilters`.
//  - Respeta las columnas activas definidas en `ExportColumns`.
//  - Genera un archivo CSV o XLSX en el directorio temporal y devuelve su URL.
//
//  IMPORTANTE:
//  - Este servicio NO presenta UI ni share sheet. Solo genera el archivo.
//  - Consumido por el wizard de exportación.
//

import Foundation
import SwiftData

// MARK: - Export Format

/// Formato de archivo para exportación.
enum ExportFormat: String, CaseIterable, Identifiable {
    case csv
    case xlsx

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: return "CSV"
        case .xlsx: return "Excel (XLSX)"
        }
    }

    var fileExtension: String {
        rawValue
    }
}

// MARK: - Errores específicos de exportación

/// Errores que puede devolver el servicio de exportación.
enum TransactionsExportError: Error, LocalizedError {
    /// No se pudo construir un rango de fechas válido con los filtros personalizados.
    case invalidCustomDateRange
    /// No hay ninguna transacción que cumpla los filtros.
    case noTransactionsToExport
    /// Error al escribir el archivo en disco.
    case fileWriteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidCustomDateRange:
            return "El rango de fechas seleccionado no es válido."
        case .noTransactionsToExport:
            return "No se encontraron transacciones que cumplan los filtros seleccionados."
        case .fileWriteFailed:
            return "Ocurrió un problema al generar el archivo."
        }
    }
}

// MARK: - Resultado de exportación

/// Resultado de una exportación a CSV.
/// Contiene la URL del archivo generado y el número de transacciones exportadas.
struct TransactionsExportResult {
    /// URL del archivo CSV generado en el directorio temporal.
    let fileURL: URL
    /// Número de transacciones efectivamente exportadas.
    let exportedCount: Int
}

// MARK: - Servicio central TransactionsExportService

struct TransactionsExportService {

    // MARK: API principal

    /// Genera un archivo CSV en base a los filtros y columnas indicados.
    ///
    /// - Parameters:
    ///   - filters: Modelo de filtros de exportación.
    ///   - columns: Conjunto de columnas activas y su orden.
    ///   - modelContext: Contexto de SwiftData desde el que se leerán las transacciones.
    /// - Returns: `TransactionsExportResult` con la URL del archivo y el conteo de filas.
    /// - Throws:
    ///   - `TransactionsExportError.invalidCustomDateRange` si el rango personalizado es inválido.
    ///   - `TransactionsExportError.noTransactionsToExport` si no hay datos que exportar.
    ///   - `TransactionsExportError.fileWriteFailed` si ocurre un error al escribir el archivo.
    static func exportToCSV(
        using filters: ExportFilters,
        columns: ExportColumns,
        in modelContext: ModelContext
    ) throws -> TransactionsExportResult {

        // Validación mínima: debe haber al menos una columna activa.
        guard columns.hasAtLeastOneActiveColumn else {
            // La UI debería impedir esto; aquí actuamos de forma defensiva.
            throw TransactionsExportError.noTransactionsToExport
        }

        // Obtenemos el intervalo de fechas efectivo.
        let effectiveInterval = filters.effectiveDateInterval()

        // Construimos el descriptor base de búsqueda en SwiftData.
        let fetchDescriptor = makeFetchDescriptor(
            effectiveInterval: effectiveInterval
        )

        // 1) Traemos las transacciones desde SwiftData (filtradas por fecha si aplica).
        let fetchedTransactions = try modelContext.fetch(fetchDescriptor)

        // 2) Aplicamos el resto de filtros en memoria (cuentas, categorías, montos, etc.).
        let filteredTransactions = applyInMemoryFilters(
            fetchedTransactions,
            filters: filters
        )

        // Si después de todos los filtros no queda nada, devolvemos error.
        guard !filteredTransactions.isEmpty else {
            throw TransactionsExportError.noTransactionsToExport
        }

        // 3) Construimos el contenido CSV como Data.
        let csvData = makeCSVData(
            transactions: filteredTransactions,
            columns: columns
        )

        // 4) Escribimos el archivo en el directorio temporal.
        let fileURL: URL
        do {
            fileURL = try writeCSVToTemporaryFile(data: csvData)
        } catch {
            throw TransactionsExportError.fileWriteFailed(underlying: error)
        }

        // 5) Devolvemos el resultado.
        return TransactionsExportResult(
            fileURL: fileURL,
            exportedCount: filteredTransactions.count
        )
    }

    /// Genera un archivo en el formato especificado (CSV o XLSX).
    ///
    /// - Parameters:
    ///   - format: Formato de exportación (.csv o .xlsx).
    ///   - filters: Modelo de filtros de exportación.
    ///   - columns: Conjunto de columnas activas y su orden.
    ///   - modelContext: Contexto de SwiftData desde el que se leerán las transacciones.
    /// - Returns: `TransactionsExportResult` con la URL del archivo y el conteo de filas.
    static func export(
        format: ExportFormat,
        using filters: ExportFilters,
        columns: ExportColumns,
        in modelContext: ModelContext
    ) throws -> TransactionsExportResult {

        // Validación mínima: debe haber al menos una columna activa.
        guard columns.hasAtLeastOneActiveColumn else {
            throw TransactionsExportError.noTransactionsToExport
        }

        // Obtenemos el intervalo de fechas efectivo.
        let effectiveInterval = filters.effectiveDateInterval()

        // Construimos el descriptor base de búsqueda en SwiftData.
        let fetchDescriptor = makeFetchDescriptor(
            effectiveInterval: effectiveInterval
        )

        // 1) Traemos las transacciones desde SwiftData.
        let fetchedTransactions = try modelContext.fetch(fetchDescriptor)

        // 2) Aplicamos el resto de filtros en memoria.
        let filteredTransactions = applyInMemoryFilters(
            fetchedTransactions,
            filters: filters
        )

        // Si después de todos los filtros no queda nada, devolvemos error.
        guard !filteredTransactions.isEmpty else {
            throw TransactionsExportError.noTransactionsToExport
        }

        // 3) Generamos el archivo según el formato.
        let fileURL: URL
        do {
            switch format {
            case .csv:
                let csvData = makeCSVData(transactions: filteredTransactions, columns: columns)
                fileURL = try writeToTemporaryFile(data: csvData, extension: "csv")

            case .xlsx:
                let (headers, rows) = makeExportData(transactions: filteredTransactions, columns: columns)
                fileURL = try writeXLSXToTemporaryFile(headers: headers, rows: rows)
            }
        } catch {
            throw TransactionsExportError.fileWriteFailed(underlying: error)
        }

        let result = TransactionsExportResult(
            fileURL: fileURL,
            exportedCount: filteredTransactions.count
        )

        TelemetryService.track(.exportCompleted, parameters: ["format": format.rawValue])

        return result
    }

    // MARK: - Construcción de FetchDescriptor (filtro por fecha)

    /// Construye un `FetchDescriptor<TransactionItem>` con orden por fecha ascendente.
    /// Aplica el intervalo de fechas como filtro.
    private static func makeFetchDescriptor(
        effectiveInterval: DateInterval
    ) -> FetchDescriptor<TransactionItem> {
        // Ordenamos por fecha de forma ascendente para un CSV cronológico.
        var descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        let start = effectiveInterval.start
        let end = effectiveInterval.end
        descriptor.predicate = #Predicate<TransactionItem> { transaction in
            transaction.date >= start && transaction.date <= end
        }

        return descriptor
    }

    // MARK: - Filtros en memoria

    /// Aplica los filtros restantes que no se han aplicado en el descriptor:
    /// - Cuentas
    /// - Categorías / subcategorías
    /// - Monedas
    /// - Monto
    /// - Nota
    /// - Etiquetas
    static func applyInMemoryFilters(
        _ transactions: [TransactionItem],
        filters: ExportFilters
    ) -> [TransactionItem] {

        // Preprocesamos algunas colecciones en sets para acelerar búsquedas.
        let selectedAccountSet = Set(filters.selectedAccounts.map { $0.id })
        let selectedCategorySet = Set(filters.selectedCategories.map { $0.id })
        let selectedSubcategorySet = Set(filters.selectedSubcategories.map { $0.id })
        let selectedCurrencySet = Set(filters.selectedCurrencies.map { $0.rawValue })

        let noteFilter = filters.noteContains?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let tagFilterSet: Set<String> = Set(
            filters.selectedTagNames.map { $0.lowercased() }
        )

        let isExclude = filters.isExcludeMode

        return transactions.filter { transaction in
            // 1) Filtro por cuenta (si se seleccionaron cuentas).
            if !selectedAccountSet.isEmpty {
                if isExclude {
                    if let account = transaction.account, selectedAccountSet.contains(account.id) {
                        return false
                    }
                } else {
                    guard let account = transaction.account else { return false }
                    if !selectedAccountSet.contains(account.id) {
                        return false
                    }
                }
            }

            // 2) Filtro por categoría (si se seleccionaron).
            if !selectedCategorySet.isEmpty {
                if isExclude {
                    if let category = transaction.category, selectedCategorySet.contains(category.id) {
                        return false
                    }
                } else {
                    if let category = transaction.category {
                        if !selectedCategorySet.contains(category.id) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }

            // 3) Filtro por subcategoría (si se seleccionaron).
            if !selectedSubcategorySet.isEmpty {
                if isExclude {
                    if let subcategory = transaction.subcategory, selectedSubcategorySet.contains(subcategory.id) {
                        return false
                    }
                } else {
                    if let subcategory = transaction.subcategory {
                        if !selectedSubcategorySet.contains(subcategory.id) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }

            // 4) Filtro por moneda (si se seleccionaron monedas).
            if !selectedCurrencySet.isEmpty {
                let normalized = normalizeCurrencyCode(transaction.currencyCode)
                if isExclude {
                    if selectedCurrencySet.contains(normalized) { return false }
                } else {
                    if !selectedCurrencySet.contains(normalized) { return false }
                }
            }

            // 5) Filtro por monto utilizando `AmountFilterCondition`.
            // amount es Double en tu modelo, lo convertimos a Decimal para el filtro.
            let amountDecimal = Decimal(transaction.amount)
            if !filters.amountCondition.matches(amountDecimal) {
                return false
            }

            // 6) Filtro por nota (texto que debe contener).
            if let noteFilter, !noteFilter.isEmpty {
                let noteText = (transaction.note ?? "").lowercased()
                if !noteText.contains(noteFilter) {
                    return false
                }
            }

            // 7) Filtro por etiquetas (nombres).
            if !tagFilterSet.isEmpty {
                let transactionTagNames = (transaction.tags ?? []).map { $0.name.lowercased() }
                let transactionTagSet = Set(transactionTagNames)

                if isExclude {
                    // Exclude: if transaction has ANY excluded tag → hide it
                    if !transactionTagSet.isDisjoint(with: tagFilterSet) { return false }
                } else {
                    // Include: transaction must contain at least one selected tag
                    if transactionTagSet.isDisjoint(with: tagFilterSet) { return false }
                }
            }

            // Si pasa todos los filtros, la transacción se mantiene.
            return true
        }
    }

    // MARK: - Generación del CSV

    /// Construye el contenido CSV (Data) a partir de las transacciones y columnas activas.
    static func makeCSVData(
        transactions: [TransactionItem],
        columns: ExportColumns
    ) -> Data {

        // 1) Encabezado.
        var lines: [String] = []
        let headerTitles = columns.csvHeaderTitles
        lines.append(headerTitles.joined(separator: ","))

        // 2) Filas de datos.
        let orderedColumns = columns.orderedActiveColumns

        // Formatter para fechas (yyyy-MM-dd).
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Formatter para montos con punto decimal y 2 decimales.
        let amountFormatter = NumberFormatter()
        amountFormatter.locale = Locale(identifier: "en_US_POSIX")
        amountFormatter.numberStyle = .decimal
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.groupingSeparator = ""  // sin separadores de miles

        for transaction in transactions {
            var rowValues: [String] = []

            for column in orderedColumns {
                let value: String

                switch column {
                case .date:
                    value = dateFormatter.string(from: transaction.date)

                case .amount:
                    // amount es Double en tu modelo.
                    let number = NSNumber(value: transaction.amount)
                    value = amountFormatter.string(from: number) ?? "0.00"

                case .currency:
                    // Código de moneda normalizado para ser consistente con CurrencyUtils.
                    let normalized = normalizeCurrencyCode(transaction.currencyCode)
                    value = normalized

                case .account:
                    value = transaction.account?.name ?? ""

                case .category:
                    value = transaction.category?.name ?? ""

                case .subcategory:
                    value = transaction.subcategory?.name ?? ""

                case .tags:
                    // Etiquetas separadas por ';'.
                    let names = (transaction.tags ?? []).map { $0.name }
                    value = names.joined(separator: ";")

                case .note:
                    value = transaction.note ?? ""
                }

                rowValues.append(csvEscaped(value))
            }

            let line = rowValues.joined(separator: ",")
            lines.append(line)
        }

        // 3) Unimos todas las líneas con salto de línea Unix.
        let csvString = lines.joined(separator: "\n")

        // 4) Prepend UTF-8 BOM for Excel compatibility with special characters
        var csvData = Data([0xEF, 0xBB, 0xBF])  // UTF-8 BOM
        csvData.append(Data(csvString.utf8))
        return csvData
    }

    /// Escapa un valor para uso en CSV:
    /// - Si contiene coma, comillas o saltos de línea, se encierra entre comillas dobles
    ///   y se duplican las comillas internas.
    static func csvEscaped(_ value: String) -> String {
        guard !value.isEmpty else { return "" }

        var needsQuotes = false

        if value.contains(",") || value.contains("\"") || value.contains("\n")
            || value.contains("\r")
        {
            needsQuotes = true
        }

        var escaped = value.replacing("\"", with: "\"\"")

        if needsQuotes {
            escaped = "\"\(escaped)\""
        }

        return escaped
    }

    // MARK: - Escritura de archivo

    /// Escribe los datos CSV en un archivo temporal y devuelve su URL.
    private static func writeCSVToTemporaryFile(data: Data) throws -> URL {
        return try writeToTemporaryFile(data: data, extension: "csv")
    }

    /// Escribe datos en un archivo temporal con la extensión especificada.
    /// Uses completeFileProtection to secure financial data when device is locked.
    private static func writeToTemporaryFile(data: Data, extension ext: String) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date.now)

        let fileName = "Yala_Transacciones_\(timestamp).\(ext)"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])

        return fileURL
    }

    /// Genera headers y filas de datos para exportación (usado por XLSX).
    static func makeExportData(
        transactions: [TransactionItem],
        columns: ExportColumns
    ) -> (headers: [String], rows: [[String]]) {

        let orderedColumns = columns.orderedActiveColumns
        let headers = columns.csvHeaderTitles

        // Formatters
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let amountFormatter = NumberFormatter()
        amountFormatter.locale = Locale(identifier: "en_US_POSIX")
        amountFormatter.numberStyle = .decimal
        amountFormatter.minimumFractionDigits = 2
        amountFormatter.maximumFractionDigits = 2
        amountFormatter.groupingSeparator = ""

        var rows: [[String]] = []

        for transaction in transactions {
            var rowValues: [String] = []

            for column in orderedColumns {
                let value: String

                switch column {
                case .date:
                    value = dateFormatter.string(from: transaction.date)
                case .amount:
                    let number = NSNumber(value: transaction.amount)
                    value = amountFormatter.string(from: number) ?? "0.00"
                case .currency:
                    value = normalizeCurrencyCode(transaction.currencyCode)
                case .account:
                    value = transaction.account?.name ?? ""
                case .category:
                    value = transaction.category?.name ?? ""
                case .subcategory:
                    value = transaction.subcategory?.name ?? ""
                case .tags:
                    let names = (transaction.tags ?? []).map { $0.name }
                    value = names.joined(separator: ";")
                case .note:
                    value = transaction.note ?? ""
                }

                rowValues.append(value)
            }

            rows.append(rowValues)
        }

        return (headers, rows)
    }

    /// Escribe un archivo XLSX temporal usando XLSXWriter.
    /// Applies completeFileProtection to secure financial data when device is locked.
    private static func writeXLSXToTemporaryFile(headers: [String], rows: [[String]]) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date.now)

        let fileName = "Yala_Transacciones_\(timestamp).xlsx"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try XLSXWriter.write(to: fileURL, headers: headers, rows: rows)

        // Apply file protection to the created XLSX file
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )

        return fileURL
    }
}
