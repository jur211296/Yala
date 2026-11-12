//
//  TransactionCSVImportService.swift
//  Yala
//
//  Importación de transacciones desde CSV y Excel.
//
//  Desde el 2026-10-29 (auditoría del import 2.2, H1 · H3 · H4 · H5 · H7) hay UN lector (`ImportFileReader`, columnas
//  por nombre) y UN validador (`validate`): las cuatro entradas públicas —CSV y Excel, a una cuenta o por moneda— y la
//  nueva por columna `account` pasan por `importFile`. Antes la validación estaba escrita cuatro veces y cualquier
//  arreglo había que hacerlo en cuatro sitios.
//

import Foundation
import SwiftData

// MARK: - Tipos auxiliares

/// Columnas esperadas en archivos de importación (CSV/XLSX).
enum ImportColumn: String {
    case date
    case amount
    case currency
    case category
    case subcategory
    case tags
    case note
}

/// Errores de importación con detalle por fila.
enum ImportError: LocalizedError, Equatable {
    case invalidFileExtension
    case unreadableFile
    case emptyFile
    case invalidHeader(found: String)
    /// Faltan columnas obligatorias: se nombran.
    case missingColumns([String])
    /// Una columna conocida aparece dos veces: no se elige una en silencio.
    case duplicateColumn(name: String)
    case invalidColumnCount(row: Int, expected: Int, found: Int)
    case invalidDate(row: Int, value: String)
    case invalidAmount(row: Int, value: String)
    case invalidCurrency(row: Int, value: String)
    case currencyMismatchWithAccount(row: Int, fileCurrency: String, accountCurrency: String)
    case emptyCategory(row: Int)
    case emptySubcategory(row: Int)
    case unknownCategory(row: Int, name: String)
    case unknownSubcategory(row: Int, categoryName: String, name: String)
    case missingAccountForCurrency(row: Int, currency: String)
    /// Un movimiento de Grupos: no se importa (decisión de Jürgen, 2026-10-29).
    case groupRow(row: Int)
    /// La columna `account` existe y la celda de esta fila está vacía.
    case emptyAccount(row: Int)
    /// La cuenta nombrada está archivada o es la de Grupos.
    case accountUnavailable(row: Int, name: String)
    /// Dos cuentas activas con ese nombre y esa moneda.
    case ambiguousAccount(row: Int, name: String)
    /// La cuenta nombrada es de otra moneda.
    case namedAccountCurrencyMismatch(row: Int, name: String, fileCurrency: String, accountCurrency: String)
    /// La cuenta nueva no se crea: no se eligió (límite de cuentas del plan gratuito).
    case newAccountNotChosen(row: Int, name: String)

    /// La fila del archivo a la que se refiere el error, o `nil` si es del archivo entero. Solo los errores
    /// con fila se pueden saltar al importar el resto (L7-17).
    var rowNumber: Int? {
        switch self {
        case .invalidFileExtension, .unreadableFile, .emptyFile, .invalidHeader, .missingColumns, .duplicateColumn:
            return nil
        case .invalidColumnCount(let row, _, _), .invalidDate(let row, _), .invalidAmount(let row, _),
            .invalidCurrency(let row, _), .currencyMismatchWithAccount(let row, _, _), .emptyCategory(let row),
            .emptySubcategory(let row), .unknownCategory(let row, _), .unknownSubcategory(let row, _, _),
            .missingAccountForCurrency(let row, _), .groupRow(let row), .emptyAccount(let row),
            .accountUnavailable(let row, _), .ambiguousAccount(let row, _),
            .namedAccountCurrencyMismatch(let row, _, _, _), .newAccountNotChosen(let row, _):
            return row
        }
    }

    /// En llano y traducido (auditoría UX 2.2, lote 7, L7-17): antes iba en español dentro del código, enseñaba
    /// el encabezado crudo y hablaba de «la creación automática». Cada fila dice qué falla y cómo arreglarla.
    var errorDescription: String? {
        typealias T = L10n.UXL7.ImportErrors
        switch self {
        case .invalidFileExtension:
            return T.invalidFileExtension
        case .unreadableFile:
            return T.unreadableFile
        case .emptyFile:
            return T.emptyFile
        case .invalidHeader:
            return T.invalidHeader
        case .missingColumns(let names):
            return T.missingColumns(names.joined(separator: ", "))
        case .duplicateColumn(let name):
            return T.duplicateColumn(name)
        case .invalidColumnCount(let row, let expected, let found):
            return T.invalidColumnCount(row, expected, found)
        case .invalidDate(let row, let value):
            return T.invalidDate(row, value)
        case .invalidAmount(let row, let value):
            return T.invalidAmount(row, value)
        case .invalidCurrency(let row, let value):
            return T.invalidCurrency(row, value)
        case .currencyMismatchWithAccount(let row, let fileCurrency, let accountCurrency):
            return T.currencyMismatch(row, fileCurrency, accountCurrency)
        case .emptyCategory(let row):
            return T.emptyCategory(row)
        case .emptySubcategory(let row):
            return T.emptySubcategory(row)
        case .unknownCategory(let row, let name):
            return T.unknownCategory(row, name)
        case .unknownSubcategory(let row, let categoryName, let name):
            return T.unknownSubcategory(row, categoryName, name)
        case .missingAccountForCurrency(let row, let currency):
            return T.missingAccountForCurrency(row, currency)
        case .groupRow(let row):
            return T.groupRow(row)
        case .emptyAccount(let row):
            return T.emptyAccount(row)
        case .accountUnavailable(let row, let name):
            return T.accountUnavailable(row, name)
        case .ambiguousAccount(let row, let name):
            return T.ambiguousAccount(row, name)
        case .namedAccountCurrencyMismatch(let row, let name, let fileCurrency, let accountCurrency):
            return T.namedAccountCurrencyMismatch(row, fileCurrency, name, accountCurrency)
        case .newAccountNotChosen(let row, let name):
            return T.newAccountNotChosen(row, name)
        }
    }
}

/// Representa un registro intermedio válido luego de parsear y validar.
/// Todavía no se ha creado ningún `TransactionItem`.
struct ParsedTransactionDraft {
    let date: Date
    let amount: Decimal
    let normalizedCurrencyCode: String
    let category: Category
    let subcategory: Subcategory
    let note: String?
    let tags: [Tag]
    /// La fila del archivo.
    var rowNumber: Int = 0
    /// Con columna `account`: la cuenta nueva a la que va (su clave), o `nil` si va a una que ya existe.
    var newAccountKey: String? = nil
}

/// Representa una fila cruda leída de un archivo CSV o XLSX antes de validación.
struct RawImportRow {
    let rowNumber: Int
    let date: String
    let amount: String
    let currency: String
    let category: String
    let subcategory: String
    let tags: String?
    let note: String?
    /// La celda de la columna `account`, o `nil` si el archivo no la trae.
    var account: String? = nil
    /// Excel guardó el importe como NÚMERO: viene en forma canónica y no pasa por el separador del archivo.
    var amountIsNumber: Bool = false
    /// La fila no se pudo leer entera (más columnas que la cabecera): se informa con su número al validar.
    var readFailure: ImportError? = nil

    static func columnCountMismatch(rowNumber: Int, expected: Int, found: Int) -> RawImportRow {
        RawImportRow(
            rowNumber: rowNumber, date: "", amount: "", currency: "", category: "", subcategory: "", tags: nil,
            note: nil, readFailure: .invalidColumnCount(row: rowNumber, expected: expected, found: found))
    }
}

/// Un importe que podía leerse de dos formas y entró con la lectura propuesta (H1): la vista previa lo enseña.
struct ImportDoubtfulAmount: Equatable {
    let rowNumber: Int
    let raw: String
    let amount: Double
    let currencyCode: String
}

/// Una cuenta que el import crea (H7), con las filas que van a ella.
struct ImportNewAccountSummary: Equatable {
    let key: String
    let name: String
    let currencyCode: String
    let rowCount: Int
}

/// A dónde van las filas.
enum ImportDestination {
    /// Todas a una cuenta, que tiene que ser de su moneda.
    case account(Account)
    /// Cada moneda a su cuenta.
    case byCurrency([String: Account])
    /// Cada fila a la cuenta que nombra su columna `account`; las que no existen se crean.
    ///
    /// - Parameter allowedNewAccountKeys: las cuentas nuevas que se pueden crear (sus claves). `nil` = todas. Sin
    ///   Pro y con más cuentas nuevas que huecos, la persona elige en la vista previa; las filas de las demás no entran.
    case accountColumn(allowedNewAccountKeys: Set<String>?)
}

/// Resultado de una importación exitosa.
struct TransactionImportResult {
    let createdCount: Int
    let drafts: [ParsedTransactionDraft]
    let ignoredFutureDatesCount: Int
    /// Las filas que no entraron, con su motivo, cuando la importación salta las malas en vez de parar en la
    /// primera (auditoría UX 2.2, lote 7, L7-17). Vacío en el modo de siempre, que lanza.
    var failures: [ImportError] = []
    /// Las columnas del archivo que el import no usa.
    var ignoredColumns: [String] = []
    /// Los importes leídos con una lectura propuesta.
    var doubtfulAmounts: [ImportDoubtfulAmount] = []
    /// Las cuentas que se crearon (o se crearían, en la vista previa), con sus filas.
    var newAccounts: [ImportNewAccountSummary] = []
    /// Las cuentas nuevas que el archivo pedía y no se crearon porque no se eligieron.
    var notChosenAccounts: [ImportNewAccountSummary] = []
    /// Las filas de Grupos que no entraron.
    var groupRowCount: Int = 0
    /// Los nombres de las cuentas a las que entra algo, en el orden en que aparecen.
    var accountNames: [String] = []
    /// Excel con varias hojas con movimientos: la que se leyó y las que no.
    var readSheet: String? = nil
    var skippedSheets: [String] = []
}

// MARK: - Servicio principal de importación

enum TransactionCSVImportService {

    // MARK: Entradas públicas

    /// Importa un CSV en una cuenta. No guarda: el llamador guarda (o usa `importAndSave`).
    @MainActor
    static func importCSV(
        from url: URL,
        into account: Account,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .account(account), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows)
    }

    /// Importa un CSV con varias monedas, cada una a su cuenta.
    @MainActor
    static func importCSVMultiCurrency(
        from url: URL,
        currencyAccountMap: [String: Account],
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .byCurrency(currencyAccountMap), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows)
    }

    /// Importa un Excel en una cuenta.
    @MainActor
    static func importXLSX(
        from url: URL,
        into account: Account,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "xlsx" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .account(account), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows)
    }

    /// Importa un Excel con varias monedas, cada una a su cuenta.
    @MainActor
    static func importXLSXMultiCurrency(
        from url: URL,
        currencyAccountMap: [String: Account],
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "xlsx" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .byCurrency(currencyAccountMap), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows)
    }

    /// Escanea un archivo CSV y devuelve el conjunto de monedas únicas encontradas.
    static func scanCurrencies(from url: URL) throws -> Set<String> {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }
        return try ImportFileReader.scan(url).currencies
    }

    /// Escanea un archivo (CSV o XLSX) y devuelve el conjunto de monedas únicas encontradas.
    static func scanCurrenciesFromFile(from url: URL) throws -> Set<String> {
        try ImportFileReader.scan(url).currencies
    }

    // MARK: - El import

    /// Lee el archivo, valida cada fila en un solo sitio y crea los movimientos (y, con columna `account`, las
    /// cuentas nuevas). No guarda.
    @MainActor
    static func importFile(
        from url: URL,
        destination: ImportDestination,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false
    ) async throws -> TransactionImportResult {
        let table = try ImportFileReader.readTable(from: url)
        guard !table.rows.isEmpty else { throw ImportError.emptyFile }
        return try importTable(
            table, destination: destination, in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows)
    }

    /// Una fila válida y a dónde va.
    private enum Target {
        case existing(Account)
        case new(key: String)
    }

    @MainActor
    static func importTable(
        _ table: ImportTable,
        destination: ImportDestination,
        in context: ModelContext,
        allowCreatingNewCategories: Bool,
        skippingInvalidRows: Bool
    ) throws -> TransactionImportResult {
        let preferredCode = CurrencyDefaults.currentPreferred
        // Para emparejar transferencias SOLO entre lo que entra ahora (no con huérfanas viejas).
        let importStart = Date.now

        // H1: el separador decimal se decide con todo el archivo, no celda a celda.
        let convention = ImportAmountParser.fileConvention(
            for: table.rows.filter { !$0.amountIsNumber }.map(\.amount))

        // H7: con columna `account`, las cuentas del usuario (todas: archivadas y de sistema para no reutilizarlas).
        var resolver: ImportAccountResolver?
        var accountsByID: [UUID: Account] = [:]
        var allowedNewKeys: Set<String>?
        if case .accountColumn(let allowed) = destination {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            for account in accounts where accountsByID[account.shortcutID] == nil {
                accountsByID[account.shortcutID] = account
            }
            resolver = ImportAccountResolver(accounts: accounts.map {
                ImportAccountCandidate(
                    id: $0.shortcutID, name: $0.name, currencyCode: $0.currencyCode, isArchived: $0.isArchived,
                    isSystem: $0.isSystemAccount, parentID: $0.parentAccountID)
            })
            allowedNewKeys = allowed
        }

        var validated: [(draft: ParsedTransactionDraft, target: Target)] = []
        validated.reserveCapacity(table.rows.count)
        var failures: [ImportError] = []
        var doubtful: [ImportDoubtfulAmount] = []
        var notChosen: [String: Int] = [:]
        var futureCount = 0
        // Las de fecha futura se dejan fuera, como siempre; desde S27m antes de crear nada por ellas.
        let today = Date.now

        for row in table.rows {
            do {
                guard let (draft, target, reading) = try validate(
                    row, destination: destination, convention: convention, today: today, resolver: &resolver,
                    accountsByID: accountsByID, allowedNewKeys: allowedNewKeys, notChosen: &notChosen,
                    allowCreatingNewCategories: allowCreatingNewCategories, in: context)
                else {
                    futureCount += 1
                    continue
                }
                if reading.isDoubtful {
                    doubtful.append(ImportDoubtfulAmount(
                        rowNumber: row.rowNumber, raw: row.amount,
                        amount: (reading.value as NSDecimalNumber).doubleValue,
                        currencyCode: draft.normalizedCurrencyCode))
                }
                validated.append((draft, target))
            } catch let error as ImportError where skippingInvalidRows && error.rowNumber != nil {
                // Una fila mala no para el archivo entero si se pidió saltarlas (L7-17).
                failures.append(error)
            }
        }

        let valid = validated

        // Las cuentas nuevas se crean solo si algo entra en ellas.
        var createdAccounts: [String: Account] = [:]
        let newAccountDefinitions = resolver?.newAccounts ?? []
        var touchedAccounts: [Account] = []
        func remember(_ account: Account) {
            if !touchedAccounts.contains(where: { $0 === account }) { touchedAccounts.append(account) }
        }
        for (draft, target) in valid {
            let account: Account
            switch target {
            case .existing(let existing):
                account = existing
            case .new(let key):
                if let created = createdAccounts[key] {
                    account = created
                } else {
                    guard let definition = newAccountDefinitions.first(where: { $0.key == key }) else { continue }
                    let created = Account(
                        name: definition.name,
                        currencyCode: definition.currencyCode,
                        colorHex: AppConstants.defaultColorHex,
                        iconName: iconName(for: .general),
                        type: AccountType.general.rawValue,
                        adjustmentMode: AdjustmentMode.changeInitialBalance.rawValue
                    )
                    context.insert(created)
                    createdAccounts[key] = created
                    account = created
                }
            }
            remember(account)
            insertTransaction(for: draft, into: account, preferredCode: preferredCode, in: context)
        }

        // El saldo inicial va siempre antes que todo lo demás: si entró algo más antiguo, su fecha retrocede.
        let allTransactions: [TransactionItem]
        do {
            allTransactions = try context.fetch(FetchDescriptor<TransactionItem>())
        } catch {
            #if DEBUG
            print("TransactionCSVImportService: Error fetching all transactions for initial balance update: \(error)")
            #endif
            allTransactions = []
        }
        if !allTransactions.isEmpty {
            for account in touchedAccounts {
                InitialBalanceService.updateInitialBalanceDateIfNeeded(
                    for: account, allTransactions: allTransactions, context: context)
            }
        }
        applyTransferPairingHeuristic(allTransactions.filter { $0.createdAt >= importStart })

        var rowsByNewKey: [String: Int] = [:]
        for (draft, _) in valid { if let key = draft.newAccountKey { rowsByNewKey[key, default: 0] += 1 } }
        let newSummaries = newAccountDefinitions.compactMap { definition -> ImportNewAccountSummary? in
            guard let count = rowsByNewKey[definition.key] else { return nil }
            return ImportNewAccountSummary(
                key: definition.key, name: definition.name, currencyCode: definition.currencyCode, rowCount: count)
        }
        let notChosenSummaries = newAccountDefinitions.compactMap { definition -> ImportNewAccountSummary? in
            guard let count = notChosen[definition.key] else { return nil }
            return ImportNewAccountSummary(
                key: definition.key, name: definition.name, currencyCode: definition.currencyCode, rowCount: count)
        }

        let drafts = valid.map(\.draft)
        failures.sort { ($0.rowNumber ?? 0) < ($1.rowNumber ?? 0) }
        return TransactionImportResult(
            createdCount: drafts.count,
            drafts: drafts,
            ignoredFutureDatesCount: futureCount,
            failures: failures,
            ignoredColumns: table.ignoredColumns,
            doubtfulAmounts: doubtful,
            newAccounts: newSummaries,
            notChosenAccounts: notChosenSummaries,
            groupRowCount: failures.filter { if case .groupRow = $0 { return true } else { return false } }.count,
            accountNames: accountNames(for: destination, touched: touchedAccounts),
            readSheet: table.readSheet,
            skippedSheets: table.skippedSheets
        )
    }

    /// Los nombres que la vista previa enseña: con una cuenta o por moneda, las elegidas (en orden de moneda); con
    /// columna `account`, las que reciben algo.
    private static func accountNames(for destination: ImportDestination, touched: [Account]) -> [String] {
        switch destination {
        case .account(let account): return [account.name]
        case .byCurrency(let map): return map.sorted { $0.key < $1.key }.map(\.value.name)
        case .accountColumn: return touched.map(\.name)
        }
    }

    // MARK: - Validación de una fila (el ÚNICO sitio)

    /// Valida una fila. Devuelve `nil` si la fila es de fecha futura (se deja fuera y se cuenta, sin crear nada).
    ///
    /// El orden importa: todo lo que puede dejar la fila fuera (Grupos, fecha, moneda, importe, cuenta y si su cuenta
    /// nueva se eligió) va ANTES de resolver la categoría y las etiquetas, que pueden CREAR entidades; si no, una fila
    /// que no entra dejaba sus categorías y etiquetas guardadas.
    @MainActor
    private static func validate(
        _ row: RawImportRow,
        destination: ImportDestination,
        convention: ImportAmountParser.FileConvention,
        today: Date,
        resolver: inout ImportAccountResolver?,
        accountsByID: [UUID: Account],
        allowedNewKeys: Set<String>?,
        notChosen: inout [String: Int],
        allowCreatingNewCategories: Bool,
        in context: ModelContext
    ) throws -> (ParsedTransactionDraft, Target, ImportAmountParser.Reading)? {
        let rowNumber = row.rowNumber
        if let readFailure = row.readFailure { throw readFailure }

        // 1. Grupos fuera, antes de resolver nada: así tampoco se crea una categoría «Grupos» (H5). También las filas
        // de la cuenta interna de Grupos («Grupos PEN»), que llevan la categoría real del gasto.
        let trimmedCategory = row.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubcategory = row.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if ImportGroupRowFilter.isGroupRow(category: trimmedCategory, subcategory: trimmedSubcategory)
            || ImportGroupRowFilter.isGroupAccountName(row.account ?? "") {
            throw ImportError.groupRow(row: rowNumber)
        }

        // 2. Fecha; una futura se deja fuera aquí.
        guard let date = parseDate(row.date) else {
            throw ImportError.invalidDate(row: rowNumber, value: row.date)
        }
        if date > today { return nil }

        // 3. Moneda (antes que el importe: sus decimales deciden la lectura propuesta de «1,500»).
        let currency = normalizeCurrencyInput(row.currency)
        guard !currency.isEmpty else {
            throw ImportError.invalidCurrency(row: rowNumber, value: row.currency)
        }

        // 4. Importe (H1).
        let reading: ImportAmountParser.Reading
        if row.amountIsNumber, let value = ImportAmountParser.parseNumericCell(row.amount) {
            reading = ImportAmountParser.Reading(value: value, isDoubtful: false)
        } else if let parsed = ImportAmountParser.parse(
            row.amount, convention: convention,
            fractionDigits: AccountCurrencyPlanLogic.fractionDigits(for: currency)) {
            reading = parsed
        } else {
            throw ImportError.invalidAmount(row: rowNumber, value: row.amount)
        }

        // 5. La cuenta. El resolvedor se prueba en una copia y solo se queda con la fila si la fila entra: una cuenta
        // nueva toma la moneda de su primera fila VÁLIDA.
        var trialResolver = resolver
        let target: Target
        switch destination {
        case .account(let account):
            let accountCurrency = normalizeCurrencyCode(account.currencyCode)
            guard currency == accountCurrency else {
                throw ImportError.currencyMismatchWithAccount(
                    row: rowNumber, fileCurrency: currency, accountCurrency: accountCurrency)
            }
            target = .existing(account)
        case .byCurrency(let map):
            guard let account = map[currency] else {
                throw ImportError.missingAccountForCurrency(row: rowNumber, currency: currency)
            }
            let accountCurrency = normalizeCurrencyCode(account.currencyCode)
            guard currency == accountCurrency else {
                throw ImportError.currencyMismatchWithAccount(
                    row: rowNumber, fileCurrency: currency, accountCurrency: accountCurrency)
            }
            target = .existing(account)
        case .accountColumn:
            guard var accountResolver = trialResolver else { throw ImportError.emptyAccount(row: rowNumber) }
            let outcome = accountResolver.resolve(name: row.account, currency: currency)
            trialResolver = accountResolver
            switch outcome {
            case .success(.existing(let id)):
                guard let account = accountsByID[id] else { throw ImportError.emptyAccount(row: rowNumber) }
                target = .existing(account)
            case .success(.new(let key)):
                // Una cuenta nueva que no se eligió (plan gratuito): la fila no entra.
                if let allowedNewKeys, !allowedNewKeys.contains(key) {
                    resolver = trialResolver  // para nombrarla en el resumen de las no elegidas
                    notChosen[key, default: 0] += 1
                    let name = accountResolver.newAccounts.first { $0.key == key }?.name ?? key
                    throw ImportError.newAccountNotChosen(row: rowNumber, name: name)
                }
                target = .new(key: key)
            case .failure(.empty):
                throw ImportError.emptyAccount(row: rowNumber)
            case .failure(.unavailable(let name)):
                throw ImportError.accountUnavailable(row: rowNumber, name: name)
            case .failure(.ambiguous(let name)):
                throw ImportError.ambiguousAccount(row: rowNumber, name: name)
            case .failure(.currencyMismatch(let name, let accountCurrency)):
                throw ImportError.namedAccountCurrencyMismatch(
                    row: rowNumber, name: name, fileCurrency: currency, accountCurrency: accountCurrency)
            }
        }

        // 6. Categoría y subcategoría, por nombre y naturaleza: con «Otros» de gasto y de ingreso, la del signo de la
        // fila; un reembolso o una transferencia se quedan en la categoría que ya tiene su subcategoría.
        guard !trimmedCategory.isEmpty else { throw ImportError.emptyCategory(row: rowNumber) }
        guard !trimmedSubcategory.isEmpty else { throw ImportError.emptySubcategory(row: rowNumber) }
        let category: Category
        let subcategory: Subcategory
        switch try CategoryImportHelper.resolveForImport(
            categoryName: trimmedCategory,
            subcategoryName: trimmedSubcategory,
            isIncome: reading.value >= 0,
            allowCreating: allowCreatingNewCategories,
            in: context
        ) {
        case .resolved(let resolvedCategory, let resolvedSubcategory):
            category = resolvedCategory
            subcategory = resolvedSubcategory
        case .unknownCategory:
            throw ImportError.unknownCategory(row: rowNumber, name: trimmedCategory)
        case .unknownSubcategory:
            throw ImportError.unknownSubcategory(row: rowNumber, categoryName: trimmedCategory, name: trimmedSubcategory)
        }
        // Lo resuelto también: una entidad de sistema del puente con un nombre que la lista no conoce.
        if category.isSystem || subcategory.isSystem {
            throw ImportError.groupRow(row: rowNumber)
        }

        // 7. Etiquetas: se crean siempre si no existen, con el interruptor de categorías como esté.
        let tags = try resolveTags(from: row.tags, in: context, allowCreatingNewTags: true)

        resolver = trialResolver
        var newAccountKey: String?
        if case .new(let key) = target { newAccountKey = key }
        let note = row.note?.isEmpty == true ? nil : row.note
        let draft = ParsedTransactionDraft(
            date: date, amount: reading.value, normalizedCurrencyCode: currency, category: category,
            subcategory: subcategory, note: note, tags: tags, rowNumber: rowNumber, newAccountKey: newAccountKey)
        return (draft, target, reading)
    }

    // MARK: - Crear el movimiento

    /// Crea el `TransactionItem` de una fila válida, con su conversión a la moneda preferida.
    @MainActor
    private static func insertTransaction(
        for draft: ParsedTransactionDraft, into account: Account, preferredCode: String, in context: ModelContext
    ) {
        let amountDouble = (draft.amount as NSDecimalNumber).doubleValue

        // `convertChecked` sustituye al par `hasExactRate` + `convert`: aquél decidía por que la FILA de tasas
        // EXISTIERA, no por que trajera la divisa del archivo, así que una fila parcial hacía nacer la transacción a
        // 1:1 y con `isExchangeRateProvisional = false` — número malo sellado como oficial, y el reparador nunca
        // vuelve a mirarlo (`fx-partial-rate-rows-silent-1to1`).
        let rateOutcome = CurrencyConverter.shared.convertChecked(
            draft.amount,
            from: draft.normalizedCurrencyCode,
            to: preferredCode,
            on: draft.date,
            context: context
        )
        let amountInPreferred = rateOutcome.amount
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
            isExchangeRateProvisional: !rateOutcome.quality.isExact
        )

        // Transferencias y ajustes no suman a ingresos ni a gastos (el punto de decisión de S27l).
        if let systemType = systemAdjustmentType(for: draft.subcategory) {
            transaction.balanceAdjustmentType = systemType
        }
        context.insert(transaction)
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
        let allTags: [Tag]
        do {
            allTags = try context.fetch(allTagsDescriptor)
        } catch {
            #if DEBUG
            print("TransactionCSVImportService: Error fetching all tags: \(error)")
            #endif
            allTags = []
        }
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

    /// Intenta parsear la fecha usando varios formatos soportados.
    ///
    /// Formatos de ejemplo:
    /// - yyyy-MM-dd
    /// - dd/MM/yyyy
    /// - MM/dd/yyyy
    private static func parseDate(_ value: String) -> Date? {
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
                        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

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
    static func detectDelimiter(from headerLine: String) -> Character {
        let commaCount = headerLine.filter { $0 == "," }.count
        let semicolonCount = headerLine.filter { $0 == ";" }.count
        return semicolonCount > commaCount ? ";" : ","
    }

    /// Normaliza códigos de moneda aceptando sinónimos habituales en CSV.
    static func normalizeCurrencyInput(_ rawValue: String) -> String {
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

    // MARK: - CSV Line Parsing (RFC 4180 compliant)

    /// Los nombres de columna del encabezado, sin comillas, sin espacios y en minúsculas.
    ///
    /// Las columnas vacías se descartan, como hacía el `split` de antes: un encabezado exportado
    /// con `;` de sobra al final (`date;amount;…;note;;`) tiene que seguir valiendo.
    static func headerFields(_ headerLine: String, delimiter: Character) -> [String] {
        splitCSVFields(headerLine, delimiter: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    /// Parte una fila en sus campos respetando las comillas (RFC 4180).
    ///
    /// Existe porque la plantilla que la propia app genera pone cada campo entre comillas, y el
    /// `split` por delimitador las dejaba pegadas: el encabezado `"date","amount",…` no casaba con
    /// el esperado y el archivo oficial no se podía importar (lote 7 de la auditoría UX 2.2, B9).
    /// - Un campo entre comillas puede llevar el delimitador y saltos de línea dentro; `""` es una
    ///   comilla literal.
    /// - Una comilla **en medio** de un campo sin comillas se queda tal cual (`Pepe's "bar"`), igual
    ///   que antes: solo abre un campo entrecomillado si es lo primero del campo.
    /// - Siempre devuelve tantos campos como delimitadores fuera de comillas haya, más uno; los
    ///   vacíos se conservan, como el `split(omittingEmptySubsequences: false)` al que sustituye.
    static func splitCSVFields(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        var fieldStartedQuoted = false
        let chars = Array(line)
        var index = 0

        while index < chars.count {
            let char = chars[index]
            if insideQuotes {
                if char == "\"" {
                    if index + 1 < chars.count, chars[index + 1] == "\"" {
                        current.append("\"")
                        index += 2
                        continue
                    }
                    insideQuotes = false
                } else {
                    current.append(char)
                }
            } else if char == delimiter {
                fields.append(current)
                current = ""
                fieldStartedQuoted = false
            } else if char == "\"",
                !fieldStartedQuoted,
                current.allSatisfy({ $0 == " " || $0 == "\t" })
            {
                // Comilla de apertura: lo que hubiera antes era solo espacio de relleno.
                current = ""
                insideQuotes = true
                fieldStartedQuoted = true
            } else {
                current.append(char)
            }
            index += 1
        }
        fields.append(current)
        return fields
    }

    /// Splits CSV content into logical rows, correctly handling quoted fields with embedded newlines.
    /// RFC 4180: Fields containing line breaks must be enclosed in double-quotes.
    static func splitCSVIntoRows(_ content: String) -> [String] {
        var rows: [String] = []
        var currentRow = ""
        var insideQuotes = false

        for char in content {
            if char == "\"" {
                insideQuotes.toggle()
                currentRow.append(char)
            } else if char.isNewline {
                if insideQuotes {
                    // Newline inside quoted field - keep it in current row
                    currentRow.append(char)
                } else {
                    // End of logical row
                    if !currentRow.isEmpty {
                        rows.append(currentRow)
                    }
                    currentRow = ""
                }
            } else {
                currentRow.append(char)
            }
        }

        // Don't forget the last row if file doesn't end with newline
        if !currentRow.trimmingCharacters(in: .whitespaces).isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    // MARK: - Transfer Pair Heuristic

    /// Aplica heurística de pairing a TXs recién importadas marcadas como transfer pero sin
    /// `transferPairID`. Empareja por (día, abs(amount), currency) cuando el grupo es balanced
    /// (1 negativo + 1 positivo). Comparte la lógica con
    /// `TransferPairReconcileService.computePairingPlan` (SSOT pure-logic). Orphans no emparejables
    /// quedan con pairID=nil; el reconciler boot-time intentará repair posterior.
    private static func applyTransferPairingHeuristic(_ transactions: [TransactionItem]) {
        let orphans = transactions.filter {
            $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer && $0.transferPairID == nil
        }
        guard !orphans.isEmpty else { return }

        var idMap: [UUID: TransactionItem] = [:]
        let infos = orphans.map { tx -> TransferPairReconcileService.TransferInfo in
            let localID = UUID()
            idMap[localID] = tx
            return TransferPairReconcileService.TransferInfo(
                id: localID,
                date: tx.date,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                transferPairID: nil,
                isTransferType: true
            )
        }

        let pairings = TransferPairReconcileService.computePairingPlan(orphans: infos)
        for pairing in pairings {
            idMap[pairing.txAID]?.transferPairID = pairing.pairID
            idMap[pairing.txBID]?.transferPairID = pairing.pairID
        }
    }
}

// MARK: - Movimientos de sistema y guardado atómico

extension TransactionCSVImportService {

    /// El ÚNICO sitio donde el import decide si una fila es ajuste de saldo, transferencia o un
    /// movimiento normal (`nil`). Lo llaman las cuatro rutas (CSV y Excel, una cuenta y varias divisas).
    ///
    /// El ajuste se reconoce con los nombres de TODOS los idiomas (`balanceAdjustmentNames`), no con el
    /// texto del idioma actual: «Ajustes de saldo» sembrado en español e importado con el teléfono en
    /// inglés sigue siendo ajuste. Cualquier otra subcategoría de sistema es transferencia, como antes.
    static func systemAdjustmentType(for subcategory: Subcategory) -> String? {
        guard subcategory.isAnySystem else { return nil }
        if Subcategory.balanceAdjustmentNames.contains(subcategory.name) {
            return InitialBalanceService.typeAdjustment
        }
        return TransactionItem.adjustmentTypeTransfer
    }

    /// Importa y guarda en `context`; si la importación o el guardado fallan, deshace lo insertado
    /// (`rollback()`) antes de relanzar el error. Sin esto, las categorías, etiquetas y movimientos que el
    /// import ya había insertado se quedaban pendientes en el contexto principal y los guardaba el
    /// siguiente `save()` de cualquier pantalla.
    ///
    /// El rollback solo puede llevarse lo del import: lo que otra pantalla dejó pendiente se guarda
    /// ANTES de empezar (es lo mismo que haría el `save()` del import si todo sale bien), y el cuerpo del
    /// import no suspende (todo corre en el main actor), así que nadie más ensucia el contexto entre la
    /// primera inserción y el rollback. Un `rollback()` a secas tiraría también lo ajeno: es lo que
    /// `CurrencyChangeService` evita restaurando registro a registro.
    ///
    /// - Parameter save: seam de tests para forzar el fallo del guardado; producción usa `context.save()`.
    @MainActor
    static func importAndSave<Output>(
        in context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() },
        _ work: () async throws -> Output
    ) async throws -> Output {
        // Si este guardado falla, no se ha importado nada y lo pendiente se queda como estaba.
        if context.hasChanges { try save(context) }
        do {
            let result = try await work()
            try save(context)
            return result
        } catch {
            context.rollback()
            throw error
        }
    }
}
