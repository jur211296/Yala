//
//  TransactionCSVImportService.swift
//  Neto
//
//  FIN-22: Importación de transacciones desde CSV con validaciones estrictas.
//
//  SECCIÓN FINALIZADA (FIN-22, capa de dominio):
//  No modificar la firma de `importCSV(...)` ni los tipos públicos
//  sin revisar el impacto en la UI de importación.
//
//  Supuestos:
//  - Existen helpers globales `parseDecimal(from:)` y `normalizeCurrencyCode(_:)`.
//  - La lógica de UI seleccionará SIEMPRE una cuenta antes de iniciar la importación.
//

import Foundation
import SwiftData

// MARK: - Tipos auxiliares

/// Columnas esperadas en el CSV.
enum CSVImportColumn: String {
    case date
    case amount
    case currency
    case category
    case subcategory
    case tags
    case note
}

/// Errores de importación con detalle por fila.
enum CSVImportError: LocalizedError {
    case invalidFileExtension
    case unreadableFile
    case emptyFile
    case invalidHeader(found: String)
    case invalidColumnCount(row: Int, expected: Int, found: Int)
    case invalidDate(row: Int, value: String)
    case invalidAmount(row: Int, value: String)
    case invalidCurrency(row: Int, value: String)
    case currencyMismatchWithAccount(row: Int, fileCurrency: String, accountCurrency: String)
    case emptyCategory(row: Int)
    case emptySubcategory(row: Int)
    case unknownCategory(row: Int, name: String)
    case unknownSubcategory(row: Int, categoryName: String, name: String)

    var errorDescription: String? {
        switch self {
        case .invalidFileExtension:
            return "El archivo debe tener extensión .csv."
        case .unreadableFile:
            return "No se pudo leer el contenido del archivo CSV."
        case .emptyFile:
            return "El archivo CSV está vacío."
        case .invalidHeader(let found):
            return "El encabezado del CSV no es válido. Se encontró: \(found)."
        case .invalidColumnCount(let row, let expected, let found):
            return
                "Fila \(row): número de columnas incorrecto. Esperadas: \(expected), encontradas: \(found)."
        case .invalidDate(let row, let value):
            return "Fila \(row): la fecha '\(value)' no tiene un formato soportado."
        case .invalidAmount(let row, let value):
            return "Fila \(row): el monto '\(value)' no se pudo interpretar."
        case .invalidCurrency(let row, let value):
            return "Fila \(row): la moneda '\(value)' no es válida."
        case .currencyMismatchWithAccount(let row, let fileCurrency, let accountCurrency):
            return
                "Fila \(row): la moneda '\(fileCurrency)' no coincide con la moneda de la cuenta destino '\(accountCurrency)'."
        case .emptyCategory(let row):
            return "Fila \(row): la categoría no puede estar vacía."
        case .emptySubcategory(let row):
            return "Fila \(row): la subcategoría no puede estar vacía."
        case .unknownCategory(let row, let name):
            return
                "Fila \(row): la categoría '\(name)' no existe y la creación automática está desactivada."
        case .unknownSubcategory(let row, let categoryName, let name):
            return
                "Fila \(row): la subcategoría '\(name)' no existe dentro de la categoría '\(categoryName)' y la creación automática está desactivada."
        }
    }
}

/// Representa un registro intermedio válido luego de parsear y validar el CSV.
/// Todavía no se ha creado ningún `TransactionItem`.
struct ParsedTransactionDraft {
    let date: Date
    let amount: Decimal
    let normalizedCurrencyCode: String
    let category: Category
    let subcategory: Subcategory
    let note: String?
    let tags: [Tag]
}

/// Resultado de una importación exitosa.
struct CSVImportResult {
    let createdCount: Int
    let drafts: [ParsedTransactionDraft]
}

// MARK: - Servicio principal de importación

enum TransactionCSVImportService {

    // MARK: API principal (crea TransactionItem)

    /// Importa un archivo CSV en una cuenta concreta y crea `TransactionItem`
    /// por cada fila válida.
    ///
    /// - Importante:
    ///   - No realiza `context.save()`. El llamador debe guardar después.
    ///   - Estratégia todo o nada: si una fila falla, lanza error y no se
    ///     debe persistir ninguna transacción.
    ///
    /// - Parameters:
    ///   - url: URL local del archivo CSV.
    ///   - account: Cuenta destino seleccionada por el usuario.
    ///   - context: ModelContext de SwiftData.
    ///
    /// - Returns: CSVImportResult con el número de registros creados.
    @MainActor
    static func importCSV(
        from url: URL,
        into account: Account,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true
    ) async throws -> CSVImportResult {

        // Resolve preferred currency once
        let preferredCode = CurrencyDefaults.currentPreferred

        // Reutilizamos la versión genérica basada en drafts y closure,
        // pero aquí concretamos la creación de `TransactionItem`.
        let result = try await importCSV(
            from: url,
            into: account,
            in: context,
            allowCreatingNewCategories: allowCreatingNewCategories
        ) { draft, context in
            let amountDouble = (draft.amount as NSDecimalNumber).doubleValue

            // Check if exact rate exists for this date (not using fallback)
            let hasExactRate = CurrencyConverter.shared.hasExactRate(
                for: draft.date, context: context)

            // Calculate Preferred Currency Amount (uses fallback if exact rate not available)
            let amountInPreferred = CurrencyConverter.shared.convert(
                draft.amount,
                from: draft.normalizedCurrencyCode,
                to: preferredCode,
                on: draft.date,
                context: context
            )

            // Derive Rate
            let effectiveRate: Double
            if abs(amountDouble) > 0.0001 {
                effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
            } else {
                effectiveRate = 1.0
            }

            let transaction = TransactionItem(
                date: draft.date,
                amount: amountDouble,
                currencyCode: draft.normalizedCurrencyCode,
                note: draft.note,
                category: draft.category,
                subcategory: draft.subcategory,
                account: account,
                tags: draft.tags,
                exchangeRate: abs(effectiveRate),
                amountInPreferredCurrency: (amountInPreferred as NSDecimalNumber).doubleValue,
                preferredCurrencyCode: preferredCode,
                isExchangeRateProvisional: !hasExactRate
            )

            context.insert(transaction)
        }

        // After import, update initial balance date if older transactions were imported
        // This ensures the initial balance always precedes all other transactions
        let allTransactionsDescriptor = FetchDescriptor<TransactionItem>()
        if let allTransactions = try? context.fetch(allTransactionsDescriptor) {
            InitialBalanceService.updateInitialBalanceDateIfNeeded(
                for: account,
                allTransactions: allTransactions,
                context: context
            )
        }

        return result
    }

    // MARK: Versión genérica con closure (para tests o extensiones futuras)

    /// Versión más genérica que permite decidir cómo crear las entidades
    /// a partir de cada `ParsedTransactionDraft`.
    ///
    /// Útil para tests o para otros modelos que no sean `TransactionItem`.
    @MainActor
    static func importCSV(
        from url: URL,
        into account: Account,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        createTransaction: (ParsedTransactionDraft, ModelContext) throws -> Void
    ) async throws -> CSVImportResult {

        // 1. Validar extensión
        guard url.pathExtension.lowercased() == "csv" else {
            throw CSVImportError.invalidFileExtension
        }

        // 2. Start accessing security-scoped resource (REQUIRED for real devices)
        // File picker URLs on iOS require explicit permission to access
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // 3. Leer contenido del fichero
        let rawContents: String
        do {
            rawContents = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw CSVImportError.unreadableFile
        }

        // 3. Dividir en líneas y limpiar vacías finales
        var lines = rawContents.components(separatedBy: .newlines)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }

        guard !lines.isEmpty else {
            throw CSVImportError.emptyFile
        }

        // 4. Validar encabezado
        let headerLine = lines.removeFirst()
        let delimiter = detectDelimiter(from: headerLine)
        let headerColumns =
            headerLine
            .split(separator: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        // Encabezados esperados:
        // - sin nota ni etiquetas: date,amount,currency,category,subcategory
        // - con nota: date,amount,currency,category,subcategory,note
        // - con etiquetas y nota: date,amount,currency,category,subcategory,tags,note
        // - con etiquetas sin nota (opcional): date,amount,currency,category,subcategory,tags
        let expectedBase = ["date", "amount", "currency", "category", "subcategory"]
        let expectedWithNote = expectedBase + ["note"]
        let expectedWithTagsAndNote = expectedBase + ["tags", "note"]
        let expectedWithTagsOnly = expectedBase + ["tags"]

        let headerMatchesBase = headerColumns == expectedBase
        let headerMatchesWithNote = headerColumns == expectedWithNote
        let headerMatchesWithTagsAndNote = headerColumns == expectedWithTagsAndNote
        let headerMatchesWithTagsOnly = headerColumns == expectedWithTagsOnly

        guard
            headerMatchesBase || headerMatchesWithNote || headerMatchesWithTagsAndNote
                || headerMatchesWithTagsOnly
        else {
            throw CSVImportError.invalidHeader(found: headerLine)
        }

        let hasTagsColumn = headerMatchesWithTagsAndNote || headerMatchesWithTagsOnly
        let hasNoteColumn = headerMatchesWithNote || headerMatchesWithTagsAndNote

        let expectedColumnCount: Int
        switch (hasTagsColumn, hasNoteColumn) {
        case (false, false):
            expectedColumnCount = 5
        case (false, true):
            expectedColumnCount = 6
        case (true, false):
            expectedColumnCount = 6
        case (true, true):
            expectedColumnCount = 7
        }

        // 5. Primera pasada: parsear y validar todas las filas a drafts

        var drafts: [ParsedTransactionDraft] = []
        drafts.reserveCapacity(lines.count)

        // Normalizamos la moneda de la cuenta una sola vez.
        let normalizedAccountCurrency = normalizeCurrencyCode(account.currencyCode)

        for (index, line) in lines.enumerated() {
            let rowNumber = index + 2  // +2 porque la cabecera es fila 1

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty {
                // Fila completamente vacía: la ignoramos para ser más tolerantes
                // con CSVs que incluyen saltos de línea adicionales.
                continue
            }

            // Si la línea no contiene el delimitador en absoluto, es muy probable
            // que se trate de ruido (por ejemplo, una segunda línea de una nota
            // partida, un resumen al final del archivo, etc.). La ignoramos en
            // lugar de considerarla una fila CSV inválida.
            if !trimmedLine.contains(String(delimiter)) {
                continue
            }

            // Si la línea solo contiene delimitadores y espacios, la ignoramos
            let contentWithoutDelimiters = trimmedLine.replacingOccurrences(
                of: String(delimiter), with: ""
            )
            .trimmingCharacters(in: .whitespaces)
            if contentWithoutDelimiters.isEmpty {
                continue
            }

            let rawColumns = trimmedLine.split(
                separator: delimiter, omittingEmptySubsequences: false)
            var columns = rawColumns.map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // Si hay columna de nota y el número de columnas es mayor,
            // asumimos que los delimitadores extra pertenecen a la nota
            // y los recombinamos.
            if hasNoteColumn && columns.count > expectedColumnCount {
                // Índice de la columna note según si hay tags o no
                let noteIndex = hasTagsColumn ? 6 : 5
                let fixedPrefix = Array(columns.prefix(noteIndex))
                let noteParts = columns.suffix(from: noteIndex)
                let mergedNote = noteParts.joined(separator: String(delimiter))
                columns = fixedPrefix + [mergedNote]
            }

            if columns.count != expectedColumnCount {
                throw CSVImportError.invalidColumnCount(
                    row: rowNumber,
                    expected: expectedColumnCount,
                    found: columns.count
                )
            }

            // Columnas:
            // 0: date
            // 1: amount
            // 2: currency
            // 3: category
            // 4: subcategory
            // 5: tags (opcional, si existe)
            // 6: note (opcional, si existe)

            let dateString = columns[0]
            let amountString = columns[1]
            let currencyString = columns[2]
            let categoryName = columns[3]
            let subcategoryName = columns[4]

            let tagsIndex = hasTagsColumn ? 5 : nil
            let noteIndex = hasNoteColumn ? (hasTagsColumn ? 6 : 5) : nil

            let tagsString = tagsIndex != nil ? columns[tagsIndex!] : nil
            let noteString = noteIndex != nil ? columns[noteIndex!] : nil

            // 5.1 Validar fecha
            guard let parsedDate = parseCSVDate(dateString) else {
                throw CSVImportError.invalidDate(
                    row: rowNumber,
                    value: dateString
                )
            }

            // 5.2 Validar monto usando parseDecimal (utilidad existente en Neto),
            // normalizando primero el separador decimal ("," o ".") y miles.
            let normalizedAmountString = normalizeCSVAmountString(amountString)

            guard let decimalAmount = parseDecimal(from: normalizedAmountString) else {
                throw CSVImportError.invalidAmount(
                    row: rowNumber,
                    value: amountString
                )
            }

            // 5.3 Normalizar y validar moneda (aceptando sinónimos comunes)
            let normalizedFileCurrency = normalizeCSVCurrencyCode(currencyString)
            if normalizedFileCurrency.isEmpty {
                throw CSVImportError.invalidCurrency(
                    row: rowNumber,
                    value: currencyString
                )
            }

            // 5.4 Validar compatibilidad con la cuenta destino
            guard normalizedFileCurrency == normalizedAccountCurrency else {
                throw CSVImportError.currencyMismatchWithAccount(
                    row: rowNumber,
                    fileCurrency: normalizedFileCurrency,
                    accountCurrency: normalizedAccountCurrency
                )
            }

            // 5.5 Validar categoría y subcategoría
            let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedCategory.isEmpty else {
                throw CSVImportError.emptyCategory(row: rowNumber)
            }

            let trimmedSubcategory = subcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedSubcategory.isEmpty else {
                throw CSVImportError.emptySubcategory(row: rowNumber)
            }

            // 5.6 Resolver helpers de categoría y subcategoría (FIN-19)
            // Supuesto: montos >= 0 se consideran ingresos, < 0 gastos.
            let isIncome = decimalAmount >= 0

            let category: Category
            let subcategory: Subcategory

            if allowCreatingNewCategories {
                // Modo original: crear categorías/subcategorías nuevas si no existen.
                category = try CategoryImportHelper.fetchOrCreateCategory(
                    named: trimmedCategory,
                    isIncome: isIncome,
                    in: context
                )

                subcategory = try CategoryImportHelper.fetchOrCreateSubcategory(
                    named: trimmedSubcategory,
                    in: category,
                    isIncome: isIncome,
                    in: context
                )
            } else {
                // Modo estricto: solo se permiten categorías existentes.
                // Si no existen, se aborta la importación con un error específico.
                let categoryDescriptor = FetchDescriptor<Category>(
                    predicate: #Predicate { cat in
                        cat.name == trimmedCategory && cat.isIncome == isIncome
                    }
                )
                let fetchedCategories = try context.fetch(categoryDescriptor)

                guard let existingCategory = fetchedCategories.first else {
                    throw CSVImportError.unknownCategory(
                        row: rowNumber,
                        name: trimmedCategory
                    )
                }

                category = existingCategory

                // Buscamos subcategorías por nombre y luego filtramos por categoría
                // en memoria para evitar problemas con relaciones en #Predicate.
                let subcategoryDescriptor = FetchDescriptor<Subcategory>(
                    predicate: #Predicate { sub in
                        sub.name == trimmedSubcategory
                    }
                )
                let fetchedSubcategories = try context.fetch(subcategoryDescriptor)

                guard
                    let existingSubcategory = fetchedSubcategories.first(where: {
                        $0.category === category
                    })
                else {
                    throw CSVImportError.unknownSubcategory(
                        row: rowNumber,
                        categoryName: trimmedCategory,
                        name: trimmedSubcategory
                    )
                }

                subcategory = existingSubcategory
            }

            // 5.7 Resolver etiquetas (tags) a partir de la columna opcional
            // NOTA: Tags siempre se crean si no existen, independiente del toggle de categorías
            let resolvedTags = try resolveTags(
                from: tagsString,
                in: context,
                allowCreatingNewTags: true  // Tags always get created
            )
            // 5.8 Construimos el draft
            let draft = ParsedTransactionDraft(
                date: parsedDate,
                amount: decimalAmount,
                normalizedCurrencyCode: normalizedFileCurrency,
                category: category,
                subcategory: subcategory,
                note: noteString?.isEmpty == true ? nil : noteString,
                tags: resolvedTags
            )

            drafts.append(draft)
        }

        // NOTE: Removed ensureRates() call here.
        // CurrencyConverter.convert() already has fallback logic that uses:
        // 1. Exact rate for the date (if available)
        // 2. Most recent rate before the date (fallback)
        // 3. Static fallback rates (last resort)
        // The ensureRates() call was causing multiple context.save() which
        // triggered @Query updates and reset @State in ImportIntroSheet.

        // 6. Segunda pasada: solo si TODO es válido, creamos las transacciones reales
        for draft in drafts {
            try createTransaction(draft, context)
        }

        return CSVImportResult(
            createdCount: drafts.count,
            drafts: drafts
        )
    }

    // MARK: - Helpers de Tags
    /// Resuelve la lista de etiquetas a partir de una cadena opcional con nombres
    /// separados por punto y coma (;). Si `allowCreatingNewTags` es true, se crean
    /// etiquetas nuevas cuando no existan. Si es false, se ignoran las etiquetas
    /// inexistentes (no se aborta la importación).
    private static func resolveTags(
        from rawTags: String?,
        in context: ModelContext,
        allowCreatingNewTags: Bool
    ) throws -> [Tag] {
        guard let raw = rawTags,
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return []
        }

        let names =
            raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if names.isEmpty {
            return []
        }

        // Obtener colores ya usados para asignar colores únicos a tags nuevos
        let allTagsDescriptor = FetchDescriptor<Tag>()
        let allTags = (try? context.fetch(allTagsDescriptor)) ?? []
        var usedColors = allTags.map { $0.colorHex }

        var resolved: [Tag] = []
        resolved.reserveCapacity(names.count)

        for name in names {
            let descriptor = FetchDescriptor<Tag>(
                predicate: #Predicate { tag in
                    tag.name == name && tag.isActive
                }
            )

            let existing = try context.fetch(descriptor)

            if let found = existing.first {
                resolved.append(found)
            } else if allowCreatingNewTags {
                let nextColor = Tag.nextAvailableColor(excluding: usedColors)
                let newTag = Tag(name: name, colorHex: nextColor)
                usedColors.append(nextColor)
                context.insert(newTag)
                resolved.append(newTag)
            } else {
                // Si no se permite crear nuevas etiquetas, simplemente ignoramos
                // los nombres que no encontremos para no bloquear la importación.
                continue
            }
        }

        return resolved
    }

    // MARK: - Parseo de fechas

    /// Intenta parsear la fecha del CSV usando varios formatos soportados.
    ///
    /// Formatos de ejemplo:
    /// - yyyy-MM-dd
    /// - dd/MM/yyyy
    /// - MM/dd/yyyy
    private static func parseCSVDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        // Remove time component if present
        let datePart: String
        if let idx = trimmed.firstIndex(where: { $0 == "T" || $0 == " " }) {
            datePart = String(trimmed[..<idx])
        } else {
            datePart = trimmed
        }

        // STRATEGY 1: Manual parsing for dd/MM/yy and dd/MM/yyyy (Most common & User's case)
        // This bypasses DateFormatter ambiguity and Timezone shifts/Month-1 bugs.
        if datePart.contains("/") {
            let parts = datePart.split(separator: "/")
            if parts.count == 3 {
                // Assuming dd/MM/yy or dd/MM/yyyy
                if let day = Int(parts[0]), let month = Int(parts[1]), let yearPart = Int(parts[2])
                {

                    var year = yearPart
                    // Handle 2-digit year (e.g., 25 -> 2025)
                    if year < 100 {
                        year += 2000
                    }

                    // Validate valid ranges to avoid false positives (e.g. 99/99/99)
                    if month >= 1 && month <= 12 && day >= 1 && day <= 31 {
                        var components = DateComponents()
                        components.year = year
                        components.month = month
                        components.day = day
                        // Force NOON UTC to avoid timezone shifts
                        components.hour = 12
                        components.minute = 0
                        components.second = 0

                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

                        if let date = calendar.date(from: components) {
                            return date
                        }
                    }
                }
            }
        }

        // STRATEGY 2: Fallback to DateFormatter for other formats (yyyy-MM-dd, etc.)
        let formats = [
            "yyyy-MM-dd",
            "yyyy/MM/dd",
            "dd-MM-yyyy",
            "MM-dd-yyyy",
            "dd.MM.yyyy",
            "yyyy.MM.dd",
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: datePart) {
                // Return date at Noon UTC (12:00)
                return date.addingTimeInterval(43200)
            }
        }

        return nil
    }

    // MARK: - Helpers de CSV

    /// Detecta el delimitador principal de la primera línea ("," o ";").
    private static func detectDelimiter(from headerLine: String) -> Character {
        let commaCount = headerLine.filter { $0 == "," }.count
        let semicolonCount = headerLine.filter { $0 == ";" }.count

        if semicolonCount > commaCount {
            return ";"
        } else {
            return ","
        }
    }

    /// Normaliza el valor numérico de amount para que `parseDecimal` pueda interpretarlo.
    /// Soporta:
    /// - "1234.56"
    /// - "1,234.56"
    /// - "1.234,56"
    /// - "1234,56"
    /// - Signos + y - al inicio.
    private static func normalizeCSVAmountString(_ value: String) -> String {
        var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return s }

        // Eliminamos espacios internos para simplificar.
        s = s.replacingOccurrences(of: " ", with: "")

        // Detectamos el último separador decimal potencial.
        let lastComma = s.lastIndex(of: ",")
        let lastDot = s.lastIndex(of: ".")

        // Si no hay ni coma ni punto, devolvemos tal cual (puede ser un entero).
        if lastComma == nil && lastDot == nil {
            return s
        }

        let decimalChar: Character
        if let cIdx = lastComma, let dIdx = lastDot {
            decimalChar = cIdx > dIdx ? "," : "."
        } else if lastComma != nil {
            decimalChar = ","
        } else {
            decimalChar = "."
        }

        let parts = s.split(separator: decimalChar, maxSplits: 1, omittingEmptySubsequences: false)
        var integerPart = String(parts[0])
        let fractionalPart = parts.count > 1 ? String(parts[1]) : ""

        var sign = ""
        if let first = integerPart.first, first == "-" || first == "+" {
            sign = String(first)
            integerPart.removeFirst()
        }

        // Eliminamos posibles separadores de miles de la parte entera.
        integerPart = integerPart.replacingOccurrences(of: ",", with: "")
        integerPart = integerPart.replacingOccurrences(of: ".", with: "")

        if fractionalPart.isEmpty {
            return sign + integerPart
        } else {
            return sign + integerPart + "." + fractionalPart
        }
    }

    /// Normaliza códigos de moneda aceptando sinónimos habituales en CSV.
    private static func normalizeCSVCurrencyCode(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let upper = trimmed.uppercased()

        let canonical: String
        switch upper {
        case "S/", "S/.", "S", "PEN", "PEN.":
            canonical = "PEN"
        case "$", "US$", "USD", "USD.":
            canonical = "USD"
        case "€", "EUR", "EUR.":
            canonical = "EUR"
        default:
            canonical = upper
        }

        return normalizeCurrencyCode(canonical)
    }
}
