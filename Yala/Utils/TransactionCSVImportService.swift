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
    /// Una línea con texto que no es una fila del archivo: no tiene ningún separador (H13).
    case unreadableRow(row: Int)
    /// La columna `time` trae algo que no es una hora (H18).
    case invalidTime(row: Int, value: String)
    /// La columna `exchange_rate` trae algo que no es una tasa mayor que cero (H18).
    case invalidExchangeRate(row: Int, value: String)
    /// La columna `need` trae algo que no es ninguna naturaleza (H18).
    case invalidNeed(row: Int, value: String)
    /// La columna `kind` trae algo que no es ningún tipo de movimiento (H8).
    case invalidKind(row: Int, value: String)
    /// La fila es un saldo inicial y su cuenta ya tiene otro: no se pisa (H8).
    case initialBalanceConflict(row: Int, account: String)

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
            .namedAccountCurrencyMismatch(let row, _, _, _), .newAccountNotChosen(let row, _),
            .unreadableRow(let row), .invalidTime(let row, _), .invalidExchangeRate(let row, _),
            .invalidNeed(let row, _), .invalidKind(let row, _), .initialBalanceConflict(let row, _):
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
        case .unreadableRow(let row):
            return T.unreadableRow(row)
        case .invalidTime(let row, let value):
            return T.invalidTime(row, value)
        case .invalidExchangeRate(let row, let value):
            return T.invalidExchangeRate(row, value)
        case .invalidNeed(let row, let value):
            return T.invalidNeed(row, value)
        case .invalidKind(let row, let value):
            return L10n.ExportarImportarIdaVuelta.invalidKind(row, value)
        case .initialBalanceConflict(let row, let account):
            return L10n.ExportarImportarIdaVuelta.initialBalanceConflict(row, account)
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
    /// La tasa a la moneda preferida que trae el archivo (`exchange_rate`), o `nil` para convertir como siempre (H18).
    var fixedRate: Double? = nil
    /// La naturaleza cambiada a mano (`need`), como se guarda en `TransactionItem.needOverride`.
    var needOverride: String? = nil
    /// La cuenta a la que va, como clave de comparación dentro de este import (duplicados y transferencias).
    var accountKey: String = ""
    /// Parece ya importada: hay un movimiento igual en su cuenta (H11). Si el import salta duplicados, no entra.
    var isDuplicate: Bool = false
    /// La pareja de transferencia que trae el archivo (`transfer_id`, H8), o vacía.
    var transferID: String = ""
    /// La fila es el saldo inicial de su cuenta (`kind = initial_balance`, H8): fija el saldo, no crea un movimiento.
    var isInitialBalance: Bool = false
}

/// Un saldo inicial cuya fecha retrocedió el import (para poder deshacerlo, H12).
struct ImportInitialBalanceChange {
    let transaction: TransactionItem
    let previousDate: Date
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
    /// Las columnas opcionales de la ida y vuelta (H18): `nil` si el archivo no las trae.
    var time: String? = nil
    var exchangeRate: String? = nil
    var rateCurrency: String? = nil
    var need: String? = nil
    /// Excel guardó la tasa como NÚMERO: forma canónica, como `amountIsNumber`.
    var exchangeRateIsNumber: Bool = false
    /// Las columnas de la ida y vuelta de H8: qué es la fila y la pareja de su transferencia. `nil` sin columna.
    var kind: String? = nil
    var transferID: String? = nil
    /// La fila no se pudo leer entera (más columnas que la cabecera): se informa con su número al validar.
    var readFailure: ImportError? = nil

    static func columnCountMismatch(rowNumber: Int, expected: Int, found: Int) -> RawImportRow {
        RawImportRow(
            rowNumber: rowNumber, date: "", amount: "", currency: "", category: "", subcategory: "", tags: nil,
            note: nil, readFailure: .invalidColumnCount(row: rowNumber, expected: expected, found: found))
    }

    /// Una línea con texto y sin separador: se cuenta entre las que no entraron, no se salta en silencio (H13).
    static func unreadable(rowNumber: Int) -> RawImportRow {
        RawImportRow(
            rowNumber: rowNumber, date: "", amount: "", currency: "", category: "", subcategory: "", tags: nil,
            note: nil, readFailure: .unreadableRow(row: rowNumber))
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
    /// Cómo se leyeron las fechas del archivo (H10).
    var dateDecision: ImportDateDecision? = nil
    /// Las filas que parecen ya importadas (H11), entren o no.
    var duplicateRowNumbers: [Int] = []
    /// Las que no entraron por eso (el import saltaba duplicados).
    var skippedDuplicateCount: Int = 0
    /// Las patas de transferencia que quedaron sin pareja (H9).
    var looseTransferCount: Int = 0
    /// Los saldos iniciales cuya fecha retrocedió (H12).
    var initialBalanceChanges: [ImportInitialBalanceChange] = []
    /// Los saldos iniciales que el archivo fija (`kind = initial_balance`, H8), entren o no en la vista previa.
    var initialBalances: [ImportInitialBalanceSummary] = []
}

/// Un saldo inicial que el import fija (H8), con la cuenta a la que va.
struct ImportInitialBalanceSummary: Equatable {
    let rowNumber: Int
    let accountName: String
    let amount: Double
    let currencyCode: String
    /// La cuenta nueva a la que va (su clave), o `nil` si va a una que ya existe.
    let newAccountKey: String?
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
        skippingInvalidRows: Bool = false,
        skippingDuplicates: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .account(account), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows,
            skippingDuplicates: skippingDuplicates)
    }

    /// Importa un CSV con varias monedas, cada una a su cuenta.
    @MainActor
    static func importCSVMultiCurrency(
        from url: URL,
        currencyAccountMap: [String: Account],
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false,
        skippingDuplicates: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "csv" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .byCurrency(currencyAccountMap), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows,
            skippingDuplicates: skippingDuplicates)
    }

    /// Importa un Excel en una cuenta.
    @MainActor
    static func importXLSX(
        from url: URL,
        into account: Account,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false,
        skippingDuplicates: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "xlsx" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .account(account), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows,
            skippingDuplicates: skippingDuplicates)
    }

    /// Importa un Excel con varias monedas, cada una a su cuenta.
    @MainActor
    static func importXLSXMultiCurrency(
        from url: URL,
        currencyAccountMap: [String: Account],
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false,
        skippingDuplicates: Bool = false
    ) async throws -> TransactionImportResult {
        guard url.pathExtension.lowercased() == "xlsx" else { throw ImportError.invalidFileExtension }
        return try await importFile(
            from: url, destination: .byCurrency(currencyAccountMap), in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows,
            skippingDuplicates: skippingDuplicates)
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
    ///
    /// - Parameters:
    ///   - preparedTable: la tabla ya leída (la de la vista previa): así el archivo no se lee dos veces (H14).
    ///   - skippingDuplicates: las filas que parecen ya importadas no entran (H11).
    ///   - insertsTransactions: `false` en la vista previa, que solo valida: no crea movimientos para tirarlos (H14).
    @MainActor
    static func importFile(
        from url: URL,
        destination: ImportDestination,
        in context: ModelContext,
        allowCreatingNewCategories: Bool = true,
        skippingInvalidRows: Bool = false,
        skippingDuplicates: Bool = false,
        preparedTable: ImportTable? = nil,
        insertsTransactions: Bool = true
    ) async throws -> TransactionImportResult {
        let table = try preparedTable ?? ImportFileReader.readTable(from: url)
        guard !table.rows.isEmpty else { throw ImportError.emptyFile }
        return try importTable(
            table, destination: destination, in: context,
            allowCreatingNewCategories: allowCreatingNewCategories, skippingInvalidRows: skippingInvalidRows,
            skippingDuplicates: skippingDuplicates, insertsTransactions: insertsTransactions)
    }

    /// Una fila válida y a dónde va.
    private enum Target {
        case existing(Account)
        case new(key: String)

        var key: String {
            switch self {
            case .existing(let account): return "e\(ObjectIdentifier(account).hashValue)"
            case .new(let key): return "n:\(key)"
            }
        }
    }

    /// Lo ya resuelto en este import (H14): cada categoría, subcategoría de sistema y etiqueta se busca una vez, no una
    /// por fila. Con 3.000 filas eran más de 11.000 consultas en el hilo principal.
    final class ResolutionCache {
        struct CategoryKey: Hashable {
            let category: String
            let subcategory: String
            let isIncome: Bool
        }
        var categories: [CategoryKey: ImportCategoryResolution] = [:]
        var systemSubcategories: [CategoryKey: Subcategory?] = [:]
        var tagsByName: [String: Tag]?
        var usedTagColors: [String] = []
    }

    @MainActor
    static func importTable(
        _ table: ImportTable,
        destination: ImportDestination,
        in context: ModelContext,
        allowCreatingNewCategories: Bool,
        skippingInvalidRows: Bool,
        skippingDuplicates: Bool = false,
        insertsTransactions: Bool = true,
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        now: Date = .now
    ) throws -> TransactionImportResult {
        let preferredCode = CurrencyDefaults.currentPreferred

        // H1: el separador decimal se decide con todo el archivo, no celda a celda.
        let convention = ImportAmountParser.fileConvention(
            for: table.rows.filter { !$0.amountIsNumber }.map(\.amount))
        // H10: y el orden día/mes de las fechas, también.
        let dateDecision = ImportDateLogic.decide(for: table.rows.map(\.date), locale: locale)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

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
        let cache = ResolutionCache()
        let rules = RowRules(
            convention: convention, dateOrder: dateDecision.order, timeZone: timeZone, now: now,
            preferredCurrency: preferredCode)

        for row in table.rows {
            do {
                guard let (draft, target, reading) = try validate(
                    row, destination: destination, rules: rules, resolver: &resolver,
                    accountsByID: accountsByID, allowedNewKeys: allowedNewKeys, notChosen: &notChosen,
                    allowCreatingNewCategories: allowCreatingNewCategories, cache: cache, in: context)
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
                var keyed = draft
                keyed.accountKey = target.key
                validated.append((keyed, target))
            } catch let error as ImportError where skippingInvalidRows && error.rowNumber != nil {
                // Una fila mala no para el archivo entero si se pidió saltarlas (L7-17).
                failures.append(error)
            }
        }

        // H8: los saldos iniciales no son movimientos: se apartan antes de buscar duplicados y transferencias.
        let newAccountDefinitions = resolver?.newAccounts ?? []
        func targetName(_ target: Target) -> String {
            switch target {
            case .existing(let account): return account.name
            case .new(let key): return newAccountDefinitions.first { $0.key == key }?.name ?? key
            }
        }
        let initialRows = validated.filter { $0.draft.isInitialBalance }
        validated.removeAll { $0.draft.isInitialBalance }
        var initialPlans: [(draft: ParsedTransactionDraft, target: Target)] = []
        var initialAlreadyThere: [Int] = []
        var plannedInitialKeys: Set<String> = []
        for item in initialRows {
            let amount = (item.draft.amount as NSDecimalNumber).doubleValue
            var conflict = plannedInitialKeys.contains(item.target.key)
            if !conflict, case .existing(let account) = item.target,
               let current = InitialBalanceService.findInitialBalanceTransaction(for: account, in: context) {
                // El mismo saldo ya está: no hay nada que hacer. Otro distinto no se pisa.
                if abs(current.amount - amount) < 0.000_1 {
                    initialAlreadyThere.append(item.draft.rowNumber)
                    plannedInitialKeys.insert(item.target.key)
                    continue
                }
                conflict = true
            }
            if conflict {
                let error = ImportError.initialBalanceConflict(row: item.draft.rowNumber, account: targetName(item.target))
                guard skippingInvalidRows else { throw error }
                failures.append(error)
                continue
            }
            plannedInitialKeys.insert(item.target.key)
            initialPlans.append(item)
        }

        // H11: lo que parece ya importado, contra los movimientos de las cuentas que ya existen.
        let duplicateIndices = try findDuplicates(validated, calendar: calendar, in: context)
        for index in duplicateIndices { validated[index].draft.isDuplicate = true }
        let duplicateRows = (duplicateIndices.sorted().map { validated[$0].draft.rowNumber } + initialAlreadyThere).sorted()
        let valid = skippingDuplicates ? validated.filter { !$0.draft.isDuplicate } : validated

        // H9: las transferencias que quedan sin pareja, sobre lo que entra.
        let transferLegs = transferLegs(of: valid.map(\.draft), calendar: calendar)
        let pairs = ImportTransferPairingLogic.pairs(transferLegs.map(\.leg))

        // Las cuentas nuevas se crean solo si algo entra en ellas.
        var createdAccounts: [String: Account] = [:]
        var touchedAccounts: [Account] = []
        func remember(_ account: Account) {
            if !touchedAccounts.contains(where: { $0 === account }) { touchedAccounts.append(account) }
        }
        var initialBalanceChanges: [ImportInitialBalanceChange] = []
        var createdInitials: Set<ObjectIdentifier> = []
        if insertsTransactions {
            // Alineado con `valid`: `nil` si la fila no llegó a crearse.
            var inserted: [TransactionItem?] = []
            inserted.reserveCapacity(valid.count)
            func account(for target: Target) -> Account? {
                switch target {
                case .existing(let existing):
                    return existing
                case .new(let key):
                    if let created = createdAccounts[key] { return created }
                    guard let definition = newAccountDefinitions.first(where: { $0.key == key }) else { return nil }
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
                    return created
                }
            }
            for (draft, target) in valid {
                guard let account = account(for: target) else {
                    inserted.append(nil)
                    continue
                }
                remember(account)
                inserted.append(insertTransaction(for: draft, into: account, preferredCode: preferredCode, in: context))
            }

            // H8: el saldo inicial que trae el archivo, en su fecha y sin crear un movimiento más. Solo llega aquí si la
            // cuenta no tenía ninguno (arriba): `setInitialBalance` no tiene nada que borrar.
            for (draft, target) in initialPlans {
                guard let account = account(for: target) else { continue }
                remember(account)
                let initial = InitialBalanceService.setInitialBalance(
                    amount: (draft.amount as NSDecimalNumber).doubleValue, for: account, subcategory: draft.subcategory,
                    allTransactions: [], context: context)
                initial.date = draft.date
                initial.recalculatePreferredCurrency(context: context)
                createdInitials.insert(ObjectIdentifier(initial))
            }

            // El saldo inicial va siempre antes que todo lo demás: si entró algo más antiguo, su fecha retrocede.
            // Solo hace falta mirar las cuentas que recibieron algo, y con lo que ya tenían más lo de ahora.
            if !touchedAccounts.isEmpty {
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
                        let initial = InitialBalanceService.findInitialBalanceTransaction(for: account, in: context)
                        let before = initial?.date
                        InitialBalanceService.updateInitialBalanceDateIfNeeded(
                            for: account, allTransactions: allTransactions, context: context)
                        // Uno que fijó este import no se apunta: deshacer lo borra entero.
                        if let initial, let before, initial.date < before,
                           !createdInitials.contains(ObjectIdentifier(initial)) {
                            initialBalanceChanges.append(ImportInitialBalanceChange(transaction: initial, previousDate: before))
                        }
                    }
                }
            }
            for pair in pairs {
                let pairID = UUID().uuidString
                inserted[transferLegs[pair.outflow].index]?.transferPairID = pairID
                inserted[transferLegs[pair.inflow].index]?.transferPairID = pairID
            }
        }

        var rowsByNewKey: [String: Int] = [:]
        for (draft, _) in valid + initialPlans {
            if let key = draft.newAccountKey { rowsByNewKey[key, default: 0] += 1 }
        }
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
        // Los nombres de las cuentas a las que entra algo, en el orden del archivo (también en la vista previa, que no
        // crea las nuevas).
        var receivingNames: [String] = []
        for (_, target) in valid + initialPlans {
            let name: String?
            switch target {
            case .existing(let account): name = account.name
            case .new(let key): name = newAccountDefinitions.first { $0.key == key }?.name
            }
            if let name, !receivingNames.contains(name) { receivingNames.append(name) }
        }
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
            accountNames: accountNames(for: destination, receiving: receivingNames),
            readSheet: table.readSheet,
            skippedSheets: table.skippedSheets,
            dateDecision: dateDecision,
            duplicateRowNumbers: duplicateRows,
            skippedDuplicateCount: (skippingDuplicates ? duplicateIndices.count : 0) + initialAlreadyThere.count,
            looseTransferCount: transferLegs.count - pairs.count * 2,
            initialBalanceChanges: initialBalanceChanges,
            initialBalances: initialPlans.map { draft, target in
                ImportInitialBalanceSummary(
                    rowNumber: draft.rowNumber, accountName: targetName(target),
                    amount: (draft.amount as NSDecimalNumber).doubleValue, currencyCode: draft.normalizedCurrencyCode,
                    newAccountKey: draft.newAccountKey)
            }
        )
    }

    // MARK: - Duplicados (H11)

    /// Los índices de `validated` que parecen ya importados: los que van a una cuenta que ya existe y tienen un
    /// movimiento igual en ella (contando: dos iguales en el archivo y uno en la cuenta dejan uno nuevo).
    @MainActor
    private static func findDuplicates(
        _ validated: [(draft: ParsedTransactionDraft, target: Target)], calendar: Calendar, in context: ModelContext
    ) throws -> Set<Int> {
        let existingRows = validated.enumerated().filter {
            if case .existing = $0.element.target { return true } else { return false }
        }
        let dates = existingRows.map(\.element.draft.date)
        guard let first = dates.min(), let last = dates.max() else { return [] }
        let from = first.addingTimeInterval(-36 * 60 * 60)
        let to = last.addingTimeInterval(36 * 60 * 60)
        let accountKeys = Set(existingRows.map(\.element.draft.accountKey))
        let stored = try context.fetch(FetchDescriptor<TransactionItem>(
            predicate: #Predicate { $0.date >= from && $0.date <= to }))
        let existing = stored.compactMap { transaction -> ImportDuplicateLogic.Fingerprint? in
            guard let account = transaction.account else { return nil }
            let key = Target.existing(account).key
            guard accountKeys.contains(key) else { return nil }
            return ImportDuplicateLogic.fingerprint(
                date: transaction.date, amount: transaction.amount, currencyCode: transaction.currencyCode,
                accountKey: key, note: transaction.note, calendar: calendar)
        }
        guard !existing.isEmpty else { return [] }
        let prints = existingRows.map { item in
            ImportDuplicateLogic.fingerprint(
                date: item.element.draft.date, amount: (item.element.draft.amount as NSDecimalNumber).doubleValue,
                currencyCode: item.element.draft.normalizedCurrencyCode, accountKey: item.element.draft.accountKey,
                note: item.element.draft.note, calendar: calendar)
        }
        let found = ImportDuplicateLogic.duplicateIndices(rows: prints, existing: existing)
        return Set(found.map { existingRows[$0].offset })
    }

    // MARK: - Transferencias (H9)

    /// Las patas de transferencia de lo que entra, con su posición en `drafts`.
    static func transferLegs(
        of drafts: [ParsedTransactionDraft], calendar: Calendar
    ) -> [(index: Int, leg: ImportTransferPairingLogic.Leg)] {
        var legs: [(index: Int, leg: ImportTransferPairingLogic.Leg)] = []
        for (index, draft) in drafts.enumerated() where draft.subcategory.systemRole == .transfer {
            let key = ImportDuplicateLogic.fingerprint(
                date: draft.date, amount: (draft.amount as NSDecimalNumber).doubleValue,
                currencyCode: draft.normalizedCurrencyCode, accountKey: draft.accountKey, note: draft.note,
                calendar: calendar)
            legs.append((index, ImportTransferPairingLogic.Leg(
                id: legs.count, day: key.day, amount: key.amount, currencyCode: key.currencyCode,
                accountKey: key.accountKey, note: key.note, transferID: draft.transferID)))
        }
        return legs
    }

    /// Los nombres que la vista previa enseña: con una cuenta o por moneda, las elegidas (en orden de moneda); con
    /// columna `account`, las que reciben algo.
    private static func accountNames(for destination: ImportDestination, receiving: [String]) -> [String] {
        switch destination {
        case .account(let account): return [account.name]
        case .byCurrency(let map): return map.sorted { $0.key < $1.key }.map(\.value.name)
        case .accountColumn: return receiving
        }
    }

    /// Lo que vale igual para todas las filas de un archivo.
    struct RowRules {
        let convention: ImportAmountParser.FileConvention
        /// El orden día/mes del archivo (H10).
        let dateOrder: ImportDateOrder
        /// La zona del teléfono: el día se guarda a su mediodía.
        let timeZone: TimeZone
        let now: Date
        let preferredCurrency: String
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
        rules: RowRules,
        resolver: inout ImportAccountResolver?,
        accountsByID: [UUID: Account],
        allowedNewKeys: Set<String>?,
        notChosen: inout [String: Int],
        allowCreatingNewCategories: Bool,
        cache: ResolutionCache,
        in context: ModelContext
    ) throws -> (ParsedTransactionDraft, Target, ImportAmountParser.Reading)? {
        let rowNumber = row.rowNumber
        let convention = rules.convention
        if let readFailure = row.readFailure { throw readFailure }

        // 1. Grupos fuera, antes de resolver nada: así tampoco se crea una categoría «Grupos» (H5). También las filas
        // de la cuenta interna de Grupos («Grupos PEN»), que llevan la categoría real del gasto.
        let trimmedCategory = row.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubcategory = row.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if ImportGroupRowFilter.isGroupRow(category: trimmedCategory, subcategory: trimmedSubcategory)
            || ImportGroupRowFilter.isGroupAccountName(row.account ?? "") {
            throw ImportError.groupRow(row: rowNumber)
        }

        // 1b. Qué es la fila (`kind`, H8), opcional. Un valor que no se entiende deja la fila fuera con su motivo, y lo
        // que se debe en un grupo es de Grupos.
        let kind: ImportRecordFieldsLogic.RecordKind?
        switch ImportRecordFieldsLogic.parseKind(row.kind ?? "") {
        case .none: kind = nil
        case .kind(let parsed): kind = parsed
        case .invalid:
            throw ImportError.invalidKind(
                row: rowNumber, value: (row.kind ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if kind == .receivable { throw ImportError.groupRow(row: rowNumber) }

        // 2. Fecha y hora; una futura se deja fuera aquí. El día se lee con el orden día/mes del ARCHIVO y se guarda al
        // mediodía de la zona del teléfono (H10; hasta el 2026-11-22, mediodía UTC, que en UTC+13 es el día siguiente).
        // Con hora (columna `time` o dentro de la celda de la fecha), esa hora en la zona del teléfono, la misma en la
        // que la escribe el export (H18). Una fila es futura por DÍA, como en el formulario: hoy a las 23:00 no lo es.
        guard let day = ImportDateLogic.parseDay(
            row.date, order: rules.dateOrder, timeZone: rules.timeZone, now: rules.now) else {
            throw ImportError.invalidDate(row: rowNumber, value: row.date)
        }
        var date = day
        let timeText = (row.time ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !timeText.isEmpty {
            guard let time = ImportRecordFieldsLogic.parseTime(timeText),
                  let combined = ImportRecordFieldsLogic.combine(day: day, time: time, localTimeZone: rules.timeZone)
            else {
                throw ImportError.invalidTime(row: rowNumber, value: timeText)
            }
            date = combined
        } else if let time = ImportRecordFieldsLogic.timeInDateCell(row.date),
                  let combined = ImportRecordFieldsLogic.combine(day: day, time: time, localTimeZone: rules.timeZone) {
            date = combined
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rules.timeZone
        if calendar.compare(date, to: rules.now, toGranularity: .day) == .orderedDescending { return nil }

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

        // 4b. La tasa fija y la naturaleza (H18), opcionales. Un valor que no se entiende deja la fila fuera con su
        // motivo: entrar con la tasa del mercado o con otra naturaleza sería perder el dato en silencio.
        var fixedRate: Double?
        let rateText = (row.exchangeRate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !rateText.isEmpty {
            guard let rate = ImportRecordFieldsLogic.parseRate(
                rateText, convention: convention, isNumber: row.exchangeRateIsNumber) else {
                throw ImportError.invalidExchangeRate(row: rowNumber, value: rateText)
            }
            fixedRate = ImportRecordFieldsLogic.fixedRate(
                rate: rate, rateCurrency: row.rateCurrency.map(normalizeCurrencyInput), rowCurrency: currency,
                preferredCurrency: rules.preferredCurrency)
        }
        var needOverride: String?
        switch ImportRecordFieldsLogic.parseNeed(row.need ?? "") {
        case .none: needOverride = nil
        case .need(let need): needOverride = need.rawValue
        case .invalid:
            throw ImportError.invalidNeed(
                row: rowNumber, value: (row.need ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
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
        // Con `kind` de transferencia, ajuste o saldo inicial, la subcategoría de sistema con ese papel aunque el archivo
        // traiga la categoría vacía (H8).
        let kindRole: SubcategorySystemRole?
        switch kind {
        case .transfer: kindRole = .transfer
        case .adjustment, .initialBalance: kindRole = .balanceAdjustment
        default: kindRole = nil
        }
        if kindRole == nil {
            guard !trimmedCategory.isEmpty else { throw ImportError.emptyCategory(row: rowNumber) }
            guard !trimmedSubcategory.isEmpty else { throw ImportError.emptySubcategory(row: rowNumber) }
        }
        let category: Category
        let subcategory: Subcategory
        if let role = kindRole ?? systemRole(forImportedSubcategoryName: trimmedSubcategory) {
            // Una transferencia o un ajuste va a la subcategoría de sistema con ese PAPEL, no a una con ese nombre:
            // si no, en un teléfono sin la sembrada el import creaba una del usuario y sus filas dejaban de ser
            // transferencias en cuanto la subcategoría perdía el nombre como señal (2026-11-13).
            let key = ResolutionCache.CategoryKey(
                category: trimmedCategory, subcategory: "\(role)", isIncome: reading.value >= 0)
            let cached: Subcategory?
            if let hit = cache.systemSubcategories[key] {
                cached = hit
            } else {
                cached = try systemSubcategory(
                    for: role, categoryName: trimmedCategory, isIncome: reading.value >= 0, in: context)
                cache.systemSubcategories[key] = cached
            }
            guard let systemSubcategory = cached, let systemCategory = systemSubcategory.category
            else {
                throw ImportError.unknownSubcategory(row: rowNumber, categoryName: trimmedCategory, name: trimmedSubcategory)
            }
            category = systemCategory
            subcategory = systemSubcategory
        } else {
            let key = ResolutionCache.CategoryKey(
                category: trimmedCategory, subcategory: trimmedSubcategory, isIncome: reading.value >= 0)
            let resolution: ImportCategoryResolution
            if let hit = cache.categories[key] {
                resolution = hit
            } else {
                resolution = try CategoryImportHelper.resolveForImport(
                    categoryName: trimmedCategory,
                    subcategoryName: trimmedSubcategory,
                    isIncome: reading.value >= 0,
                    allowCreating: allowCreatingNewCategories,
                    in: context
                )
                cache.categories[key] = resolution
            }
            switch resolution {
            case .resolved(let resolvedCategory, let resolvedSubcategory):
                category = resolvedCategory
                subcategory = resolvedSubcategory
            case .unknownCategory:
                throw ImportError.unknownCategory(row: rowNumber, name: trimmedCategory)
            case .unknownSubcategory:
                throw ImportError.unknownSubcategory(row: rowNumber, categoryName: trimmedCategory, name: trimmedSubcategory)
            }
        }
        // Lo resuelto también: una entidad de sistema del puente con un nombre que la lista no conoce.
        if category.isSystem || subcategory.isSystem {
            throw ImportError.groupRow(row: rowNumber)
        }

        // 7. Etiquetas: se crean siempre si no existen, con el interruptor de categorías como esté.
        let tags = try resolveTags(from: row.tags, in: context, cache: cache)

        resolver = trialResolver
        var newAccountKey: String?
        if case .new(let key) = target { newAccountKey = key }
        let note = row.note?.isEmpty == true ? nil : row.note
        var draft = ParsedTransactionDraft(
            date: date, amount: reading.value, normalizedCurrencyCode: currency, category: category,
            subcategory: subcategory, note: note, tags: tags, rowNumber: rowNumber, newAccountKey: newAccountKey,
            fixedRate: fixedRate, needOverride: needOverride)
        draft.isInitialBalance = kind == .initialBalance
        if subcategory.systemRole == .transfer {
            draft.transferID = (row.transferID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (draft, target, reading)
    }

    // MARK: - Crear el movimiento

    /// Crea el `TransactionItem` de una fila válida, con su conversión a la moneda preferida.
    @MainActor
    @discardableResult
    private static func insertTransaction(
        for draft: ParsedTransactionDraft, into account: Account, preferredCode: String, in context: ModelContext
    ) -> TransactionItem {
        let amountDouble = (draft.amount as NSDecimalNumber).doubleValue

        // `convertChecked` sustituye al par `hasExactRate` + `convert`: aquél decidía por que la FILA de tasas
        // EXISTIERA, no por que trajera la divisa del archivo, así que una fila parcial hacía nacer la transacción a
        // 1:1 y con `isExchangeRateProvisional = false` — número malo sellado como oficial, y el reparador nunca
        // vuelve a mirarlo (`fx-partial-rate-rows-silent-1to1`).
        //
        // Con la tasa del archivo (`exchange_rate`, H18) manda esa, como la tasa escrita a mano en el formulario: es
        // exacta por definición y la reparación de tasas provisionales no la vuelve a tocar.
        let amountInPreferred: Decimal
        let isExactConversion: Bool
        if let fixedRate = draft.fixedRate {
            amountInPreferred = ForeignManualRateLogic.converted(amountDouble, rate: fixedRate)
            isExactConversion = true
        } else {
            let rateOutcome = CurrencyConverter.shared.convertChecked(
                draft.amount,
                from: draft.normalizedCurrencyCode,
                to: preferredCode,
                on: draft.date,
                context: context
            )
            amountInPreferred = rateOutcome.amount
            isExactConversion = rateOutcome.quality.isExact
        }
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
            isExchangeRateProvisional: !isExactConversion
        )
        transaction.needOverride = draft.needOverride

        // Transferencias y ajustes no suman a ingresos ni a gastos (el punto de decisión de S27l).
        if let systemType = systemAdjustmentType(for: draft.subcategory) {
            transaction.balanceAdjustmentType = systemType
        }
        context.insert(transaction)
        return transaction
    }

    // MARK: - Helpers de Tags

    /// Las etiquetas de una celda («viaje; trabajo»). Las que no existen se crean. Todas las etiquetas se leen UNA vez
    /// por import (`cache`), no una consulta de todas más una por nombre en cada fila (H14).
    private static func resolveTags(from rawTags: String?, in context: ModelContext, cache: ResolutionCache) throws -> [Tag] {
        guard let raw = rawTags, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let names = raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return [] }

        if cache.tagsByName == nil {
            let allTags = try context.fetch(FetchDescriptor<Tag>())
            var byName: [String: Tag] = [:]
            for tag in allTags where tag.isActive && byName[tag.name] == nil { byName[tag.name] = tag }
            cache.tagsByName = byName
            cache.usedTagColors = allTags.map(\.colorHex)
        }
        var resolved: [Tag] = []
        resolved.reserveCapacity(names.count)
        for name in names {
            if let found = cache.tagsByName?[name] {
                resolved.append(found)
            } else {
                let nextColor = Tag.nextAvailableColor(excluding: cache.usedTagColors)
                let newTag = Tag(name: name, colorHex: nextColor)
                cache.usedTagColors.append(nextColor)
                context.insert(newTag)
                cache.tagsByName?[name] = newTag
                resolved.append(newTag)
            }
        }
        return resolved
    }

    // MARK: - Helpers de CSV

    /// Detecta el delimitador principal de la cabecera: `,`, `;` o el tabulador (el «texto separado por tabuladores»
    /// de Excel y Numbers, H13), el que más aparezca. Con empate, la coma.
    static func detectDelimiter(from headerLine: String) -> Character {
        let commaCount = headerLine.filter { $0 == "," }.count
        let semicolonCount = headerLine.filter { $0 == ";" }.count
        let tabCount = headerLine.filter { $0 == "\t" }.count
        if tabCount > max(commaCount, semicolonCount) { return "\t" }
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

    /// Una fila lógica del CSV y la línea física del archivo en la que empieza (la primera es la 1).
    struct CSVRow: Equatable {
        let line: Int
        let text: String
    }

    /// Parte el CSV en filas lógicas: un salto de línea dentro de un campo entre comillas no corta la fila (RFC 4180).
    ///
    /// Una comilla solo ABRE un campo entrecomillado si es lo primero del campo (tras el separador o al principio de la
    /// línea, con espacios de relleno delante), con el mismo criterio que `splitCSVFields`. Hasta el 2026-11-12 abría y
    /// cerraba con cualquier `"`: una nota como `Tele de 50" nueva` dejaba el resto del archivo «dentro de comillas» y
    /// las filas siguientes desaparecían pegadas a esa nota, sin error (H13, card 6gh7).
    ///
    /// Una comilla de apertura que no se cierra tampoco se traga lo que viene detrás: si llega al final del archivo, o si
    /// el campo cruza un salto de línea y la comilla que lo «cierra» no va seguida de separador, salto de línea o final
    /// (la comilla de apertura de un campo de otra fila, `"Pan, leche"`), la apertura era falsa. La fila se queda con su
    /// primera línea física y se sigue partiendo desde la línea siguiente: cada fila entra o sale entre las no leídas.
    static func splitCSVRows(_ content: String, delimiter: Character) -> [CSVRow] {
        let chars = Array(content)
        var rows: [CSVRow] = []
        var start = 0
        var startLine = 1

        parsing: while start < chars.count {
            var current = ""
            var rowLine = startLine
            var line = startLine
            var rowStart = start
            var insideQuotes = false
            var fieldIsBlank = true  // el campo, hasta aquí, es solo espacio de relleno
            var fieldWasQuoted = false
            var quoteOpenLine = startLine
            var falseOpening = false
            var index = start

            while index < chars.count {
                let char = chars[index]
                if insideQuotes {
                    if char == "\"" {
                        if index + 1 < chars.count, chars[index + 1] == "\"" {
                            current.append("\"\"")
                            index += 2
                            continue
                        }
                        insideQuotes = false
                        if line > quoteOpenLine {
                            var next = index + 1
                            while next < chars.count, chars[next] == " " { next += 1 }
                            if next < chars.count, chars[next] != delimiter, !chars[next].isNewline {
                                falseOpening = true
                                break
                            }
                        }
                    } else if char.isNewline {
                        line += 1
                    }
                    current.append(char)
                } else if char.isNewline {
                    if !current.isEmpty { rows.append(CSVRow(line: rowLine, text: current)) }
                    current = ""
                    line += 1
                    rowLine = line
                    rowStart = index + 1
                    fieldIsBlank = true
                    fieldWasQuoted = false
                } else {
                    if char == delimiter {
                        fieldIsBlank = true
                        fieldWasQuoted = false
                    } else if char == "\"", fieldIsBlank, !fieldWasQuoted {
                        insideQuotes = true
                        fieldWasQuoted = true
                        fieldIsBlank = false
                        quoteOpenLine = line
                    } else if char != " " && char != "\t" {
                        fieldIsBlank = false
                    }
                    current.append(char)
                }
                index += 1
            }

            if insideQuotes || falseOpening {
                // Comilla sin cierre: la fila es su primera línea física, y se sigue tras ella.
                var end = rowStart
                while end < chars.count, !chars[end].isNewline { end += 1 }
                let firstLine = String(chars[rowStart..<end])
                if !firstLine.isEmpty { rows.append(CSVRow(line: rowLine, text: firstLine)) }
                start = end + 1
                startLine = rowLine + 1
                continue parsing
            }
            if !current.trimmingCharacters(in: .whitespaces).isEmpty {
                rows.append(CSVRow(line: rowLine, text: current))
            }
            break
        }
        return rows
    }

}

// MARK: - Movimientos de sistema y guardado atómico

extension TransactionCSVImportService {

    /// El ÚNICO sitio donde el import decide si una fila es ajuste de saldo, transferencia o un
    /// movimiento normal (`nil`). Lo llaman las cuatro rutas (CSV y Excel, una cuenta y varias divisas).
    ///
    /// Decide el PAPEL de la subcategoría (`Subcategory.systemRole`), no su nombre: una subcategoría del usuario que se
    /// llame como la de transferencias es un movimiento normal (decisión de Jürgen, 2026-11-13).
    static func systemAdjustmentType(for subcategory: Subcategory) -> String? {
        switch subcategory.systemRole {
        case .balanceAdjustment: return InitialBalanceService.typeAdjustment
        case .transfer: return TransactionItem.adjustmentTypeTransfer
        case nil: return nil
        }
    }

    /// El papel que trae una fila del archivo por el texto de su subcategoría, o `nil` para un movimiento normal.
    ///
    /// Un archivo solo trae texto, así que aquí el nombre es la única señal: los de ajuste y transferencia de TODOS los
    /// idiomas (`balanceAdjustmentNames`, `transferNames`) y los de la subcategoría de transferencia que siembra Yala
    /// (`seededTransferNames`), que desde el 2026-11-13 es de sistema en todos los idiomas. «Ajustes de saldo»
    /// sembrado en español e importado con el teléfono en inglés sigue siendo ajuste.
    static func systemRole(forImportedSubcategoryName name: String) -> SubcategorySystemRole? {
        if Subcategory.balanceAdjustmentNames.contains(name) { return .balanceAdjustment }
        if Subcategory.transferNames.contains(name) || Subcategory.seededTransferNames.contains(name) { return .transfer }
        return nil
    }

    /// La subcategoría de sistema donde va una fila con papel.
    ///
    /// Primero una con ese papel en la categoría que nombra el archivo: la de la naturaleza del signo y, si no la hay,
    /// la que tenga (un reembolso o una transferencia se quedan en la categoría que ya tiene su subcategoría, lote 12.6,
    /// y no se crea una categoría nueva para la pata de entrada). Si el archivo nombra una categoría sin ninguna, la de
    /// las transferencias según el signo o la de ajustes, que se crean si no existen, con el interruptor de categorías
    /// como esté: son de Yala, no del usuario, y el formulario de Nuevo registro también las crea.
    @MainActor
    static func systemSubcategory(
        for role: SubcategorySystemRole, categoryName: String, isIncome: Bool, in context: ModelContext
    ) throws -> Subcategory? {
        let named = try context.fetch(FetchDescriptor<Subcategory>())
            .filter { $0.systemRole == role && $0.category?.name == categoryName }
        let sameNature = named.filter { $0.category?.isIncome == isIncome }
        let currentName = role == .transfer ? L10n.Transfer.categoryName : L10n.Subcategory.balanceAdjustment
        if let match = TransferCategoryResolver.preferred(sameNature.isEmpty ? named : sameNature, currentName: currentName) {
            return match
        }
        switch role {
        case .transfer:
            return isIncome
                ? try TransferCategoryResolver.inflow(context: context)
                : try TransferCategoryResolver.outflow(context: context)
        case .balanceAdjustment:
            return InitialBalanceService.ensureBalanceAdjustmentSubcategoryExists(context: context)
        }
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
    /// - Parameter beforeSave: mira lo que el import dejó en el contexto justo antes de guardarlo (lo usa «Deshacer
    ///   importación» para apuntar lo creado).
    @MainActor
    static func importAndSave<Output>(
        in context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() },
        beforeSave: (ModelContext) -> Void = { _ in },
        _ work: () async throws -> Output
    ) async throws -> Output {
        // Si este guardado falla, no se ha importado nada y lo pendiente se queda como estaba.
        if context.hasChanges { try save(context) }
        do {
            let result = try await work()
            beforeSave(context)
            try save(context)
            // Telemetría propia: «usó esta función» (uno al día), con lo importado ya guardado.
            MetricsService.used(.importar)
            return result
        } catch {
            context.rollback()
            throw error
        }
    }
}
