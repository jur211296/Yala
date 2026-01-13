//
//  TransactionsExportService.swift
//  Neto
//
//  FIN-49: Servicio central de exportación de transacciones a CSV.
//  - Aplica filtros definidos en `ExportFilters` (FIN-48).
//  - Respeta las columnas activas definidas en `ExportColumns` (FIN-48).
//  - Genera un archivo CSV en el directorio temporal y devuelve su URL.
//
//  IMPORTANTE:
//  - Este servicio NO presenta UI ni share sheet. Solo genera el archivo.
//  - Será consumido por el wizard de exportación (FIN-50, FIN-51, FIN-52).
//

import Foundation
import SwiftData

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
            return "Ocurrió un problema al generar el archivo CSV."
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
    ///   - filters: Modelo de filtros de exportación (FIN-48).
    ///   - columns: Conjunto de columnas activas y su orden (FIN-48).
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
    private static func applyInMemoryFilters(
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

        return transactions.filter { transaction in
            // 1) Filtro por cuenta (si se seleccionaron cuentas).
            if !selectedAccountSet.isEmpty {
                guard let account = transaction.account else { return false }
                if !selectedAccountSet.contains(account.id) {
                    return false
                }
            }

            // 2) Filtro por categoría (si se seleccionaron).
            if !selectedCategorySet.isEmpty {
                if let category = transaction.category {
                    if !selectedCategorySet.contains(category.id) {
                        return false
                    }
                } else {
                    // Transacción sin categoría no pasa si se han seleccionado categorías.
                    return false
                }
            }

            // 3) Filtro por subcategoría (si se seleccionaron).
            if !selectedSubcategorySet.isEmpty {
                if let subcategory = transaction.subcategory {
                    if !selectedSubcategorySet.contains(subcategory.id) {
                        return false
                    }
                } else {
                    // Transacción sin subcategoría no pasa si se han seleccionado subcategorías.
                    return false
                }
            }

            // 4) Filtro por moneda (si se seleccionaron monedas).
            if !selectedCurrencySet.isEmpty {
                // Usamos normalizeCurrencyCode para alinear con CurrencyUtils.
                let normalized = normalizeCurrencyCode(transaction.currencyCode)
                if !selectedCurrencySet.contains(normalized) {
                    return false
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
                // En tu modelo tags es [Tag] no opcional.
                let transactionTagNames = transaction.tags.map { $0.name.lowercased() }
                let transactionTagSet = Set(transactionTagNames)

                // Para que pase, la transacción debe contener al menos una de las etiquetas seleccionadas.
                if transactionTagSet.isDisjoint(with: tagFilterSet) {
                    return false
                }
            }

            // Si pasa todos los filtros, la transacción se mantiene.
            return true
        }
    }

    // MARK: - Generación del CSV

    /// Construye el contenido CSV (Data) a partir de las transacciones y columnas activas.
    private static func makeCSVData(
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
                    let names = transaction.tags.map { $0.name }
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
        return Data(csvString.utf8)
    }

    /// Escapa un valor para uso en CSV:
    /// - Si contiene coma, comillas o saltos de línea, se encierra entre comillas dobles
    ///   y se duplican las comillas internas.
    private static func csvEscaped(_ value: String) -> String {
        guard !value.isEmpty else { return "" }

        var needsQuotes = false

        if value.contains(",") || value.contains("\"") || value.contains("\n")
            || value.contains("\r")
        {
            needsQuotes = true
        }

        var escaped = value.replacingOccurrences(of: "\"", with: "\"\"")

        if needsQuotes {
            escaped = "\"\(escaped)\""
        }

        return escaped
    }

    // MARK: - Escritura de archivo

    /// Escribe los datos CSV en un archivo temporal y devuelve su URL.
    private static func writeCSVToTemporaryFile(data: Data) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory

        // Nombre de archivo con timestamp para evitar colisiones.
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let fileName = "Neto_Transacciones_\(timestamp).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL, options: .atomic)

        return fileURL
    }
}
