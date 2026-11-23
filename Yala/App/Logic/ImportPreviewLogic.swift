//
//  ImportPreviewLogic.swift
//  Yala
//
//  Lo que la persona ve ANTES de importar un archivo (auditoría UX 2.2, lote 7, L7-15) y el resumen de
//  después cuando alguna fila no entró (L7-17).
//

import Foundation

/// La vista previa de una importación: cuántos registros entran, en qué cuenta, entre qué fechas, cuánto
/// suman, las primeras filas y las que no van a entrar.
struct ImportPreview: Equatable {

    struct Row: Equatable {
        let date: Date
        let amount: Double
        let currencyCode: String
        let categoryName: String
        let subcategoryName: String
        /// La fila del archivo.
        var rowNumber: Int = 0
        /// Con columna `account`, la cuenta nueva a la que va (su clave); `nil` si va a una que ya existe.
        var newAccountKey: String? = nil
        /// La cuenta a la que va, como clave de comparación (H9).
        var accountKey: String = ""
        /// Parece ya importada (H11).
        var isDuplicate: Bool = false
        /// Es una pata de transferencia (H9).
        var isTransfer: Bool = false
        var note: String? = nil
        /// La pareja de transferencia que trae el archivo (H8), o vacía.
        var transferID: String = ""
    }

    /// La suma de los importes de una moneda (los gastos van en negativo, como en el archivo).
    struct Total: Equatable {
        let currencyCode: String
        let amount: Double
    }

    /// Los registros que se van a crear (sin las filas malas ni las de fecha futura).
    let count: Int
    let accountNames: [String]
    let firstDate: Date?
    let lastDate: Date?
    let totals: [Total]
    let sampleRows: [Row]
    /// Las filas que no van a entrar, ya redactadas («Fila 71: …»).
    let failures: [String]
    /// Filas con fecha de mañana o más: se dejan fuera, como siempre, pero ahora se dice.
    let ignoredFutureCount: Int
    /// Las columnas del archivo que el import no usa (H4).
    var ignoredColumns: [String] = []
    /// Las filas de Grupos que no entran (H5); también van en `failures`, con su motivo.
    var groupRowCount: Int = 0
    /// Los importes que entran con una lectura propuesta (H1).
    var doubtfulAmounts: [ImportDoubtfulAmount] = []
    /// Las cuentas que se crean al importar (H7), con sus filas.
    var newAccounts: [ImportNewAccountSummary] = []
    /// Las cuentas que ya consumen el límite del plan gratuito.
    var existingBillableAccounts: Int = 0
    /// Todas las filas que entrarían si se crearan todas las cuentas nuevas: con ellas se rehace la vista previa al
    /// cambiar cuáles se crean.
    var allRows: [Row] = []
    /// Las filas que no entran por el archivo (sin contar las de cuentas no elegidas).
    var fileFailures: [String] = []
    /// Excel con varias hojas con movimientos: la que se lee y las que no.
    var readSheet: String? = nil
    var skippedSheets: [String] = []
    /// Las filas que parecen ya importadas (H11) y si se importan igual. Por defecto se saltan.
    var duplicateCount: Int = 0
    var importsDuplicates: Bool = false
    /// Las patas de transferencia que quedan sin pareja (H9).
    var looseTransferCount: Int = 0
    /// El archivo no decidía el orden día/mes y se usó el del teléfono (H10): una fecha de ejemplo y cómo se leyó.
    var dateOrderNotice: DateOrderNotice? = nil
    /// Los saldos iniciales que el archivo fija (H8), con todas las cuentas nuevas; y los que entran con las elegidas.
    var allInitialBalances: [ImportInitialBalanceSummary] = []
    var initialBalances: [ImportInitialBalanceSummary] = []

    struct DateOrderNotice: Equatable {
        /// La fecha tal como viene en el archivo («03/04/2026»).
        let example: String
        /// Cómo se leyó.
        let readAs: Date
        let order: ImportDateOrder
    }

    var canImport: Bool { count > 0 || !initialBalances.isEmpty }
}

enum ImportPreviewLogic {

    /// Cuántas filas de muestra enseña la vista previa.
    static let sampleLimit = 3
    /// Cuántas filas malas se listan con su motivo; el resto se cuenta.
    static let failureListLimit = 10

    static func make(
        rows: [ImportPreview.Row],
        accountNames: [String],
        failures: [String],
        ignoredFutureCount: Int
    ) -> ImportPreview {
        var order: [String] = []
        var sums: [String: Decimal] = [:]
        for row in rows {
            let code = row.currencyCode
            if sums[code] == nil { order.append(code) }
            sums[code, default: 0] += Decimal(row.amount)
        }
        let totals = order.map {
            ImportPreview.Total(currencyCode: $0, amount: ((sums[$0] ?? 0) as NSDecimalNumber).doubleValue)
        }
        let dates = rows.map(\.date)
        return ImportPreview(
            count: rows.count,
            accountNames: accountNames,
            firstDate: dates.min(),
            lastDate: dates.max(),
            totals: totals,
            sampleRows: Array(rows.prefix(sampleLimit)),
            failures: failures,
            ignoredFutureCount: ignoredFutureCount
        )
    }

    /// La vista previa con todo lo que devolvió el import (sin elegir cuentas: todas las nuevas se crean).
    static func make(result: TransactionImportResult, existingBillableAccounts: Int) -> ImportPreview {
        let rows = result.drafts.map {
            ImportPreview.Row(
                date: $0.date,
                amount: ($0.amount as NSDecimalNumber).doubleValue,
                currencyCode: $0.normalizedCurrencyCode,
                categoryName: $0.category.name,
                subcategoryName: $0.subcategory.name,
                rowNumber: $0.rowNumber,
                newAccountKey: $0.newAccountKey,
                accountKey: $0.accountKey,
                isDuplicate: $0.isDuplicate,
                isTransfer: $0.subcategory.systemRole == .transfer,
                note: $0.note,
                transferID: $0.transferID
            )
        }
        let failures = result.failures.compactMap(\.errorDescription)
        var preview = make(
            rows: rows, accountNames: result.accountNames, failures: failures,
            ignoredFutureCount: result.ignoredFutureDatesCount)
        preview.ignoredColumns = result.ignoredColumns
        preview.groupRowCount = result.groupRowCount
        preview.doubtfulAmounts = result.doubtfulAmounts
        preview.newAccounts = result.newAccounts
        preview.existingBillableAccounts = existingBillableAccounts
        preview.allRows = rows
        preview.fileFailures = failures
        preview.readSheet = result.readSheet
        preview.skippedSheets = result.skippedSheets
        if let decision = result.dateDecision, !decision.decidedByFile, let example = decision.ambiguousExample,
           let readAs = ImportDateLogic.parseDay(example, order: decision.order) {
            preview.dateOrderNotice = ImportPreview.DateOrderNotice(example: example, readAs: readAs, order: decision.order)
        }
        preview.allInitialBalances = result.initialBalances
        preview.initialBalances = result.initialBalances
        preview.duplicateCount = rows.filter(\.isDuplicate).count
        preview.looseTransferCount = looseTransfers(in: rows)
        // Lo que se ve por defecto: sin los duplicados.
        return applying(chosen: Set(preview.newAccounts.map(\.key)), importDuplicates: false, to: preview)
    }

    // MARK: - Transferencias sueltas (H9)

    /// Cuántas patas de transferencia de estas filas quedan sin pareja.
    static func looseTransfers(in rows: [ImportPreview.Row], calendar: Calendar = .current) -> Int {
        let legs = rows.filter(\.isTransfer).enumerated().map { index, row in
            let key = ImportDuplicateLogic.fingerprint(
                date: row.date, amount: row.amount, currencyCode: row.currencyCode, accountKey: row.accountKey,
                note: row.note, calendar: calendar)
            return ImportTransferPairingLogic.Leg(
                id: index, day: key.day, amount: key.amount, currencyCode: key.currencyCode,
                accountKey: key.accountKey, note: key.note, transferID: row.transferID)
        }
        return ImportTransferPairingLogic.looseCount(legs)
    }

    // MARK: - Cuentas nuevas y el plan gratuito (H7)

    /// Cuántas cuentas nuevas caben, o `nil` si no hay límite (Pro).
    static func newAccountSlots(isPro: Bool, existingBillableAccounts: Int) -> Int? {
        guard !isPro, let limit = ProFeature.accounts.freeLimit else { return nil }
        return max(0, limit - existingBillableAccounts)
    }

    /// Las cuentas nuevas que se crean si la persona no toca nada: todas si caben; si no, las de más filas hasta
    /// llenar los huecos (a igualdad, la que aparece antes en el archivo).
    static func defaultChosenAccounts(_ accounts: [ImportNewAccountSummary], slots: Int?) -> Set<String> {
        guard let slots, accounts.count > slots else { return Set(accounts.map(\.key)) }
        let ranked = accounts.enumerated().sorted {
            $0.element.rowCount != $1.element.rowCount ? $0.element.rowCount > $1.element.rowCount : $0.offset < $1.offset
        }
        return Set(ranked.prefix(slots).map(\.element.key))
    }

    /// ¿Se puede marcar una cuenta nueva más? Sin límite, siempre.
    static func canChoose(_ key: String, chosen: Set<String>, slots: Int?) -> Bool {
        guard let slots, !chosen.contains(key) else { return true }
        return chosen.count < slots
    }

    /// La vista previa con solo las cuentas nuevas elegidas (las filas de las demás pasan a no entrar, con su motivo) y
    /// con los duplicados fuera, salvo que se pida importarlos igual (H11).
    static func applying(chosen: Set<String>, importDuplicates: Bool = false, to preview: ImportPreview) -> ImportPreview {
        guard !preview.newAccounts.isEmpty || preview.allRows.contains(where: \.isDuplicate) else { return preview }
        let keptInitialBalances = preview.allInitialBalances.filter { $0.newAccountKey.map(chosen.contains) ?? true }
        let excludedKeys = Set(preview.newAccounts.map(\.key)).subtracting(chosen)
        let accountKept = preview.allRows.filter { row in row.newAccountKey.map { !excludedKeys.contains($0) } ?? true }
        let kept = importDuplicates ? accountKept : accountKept.filter { !$0.isDuplicate }
        let excludedRows = preview.allRows.filter { row in row.newAccountKey.map(excludedKeys.contains) ?? false }
        let nameByKey = Dictionary(uniqueKeysWithValues: preview.newAccounts.map { ($0.key, $0.name) })
        let excludedNames = Set(excludedKeys.compactMap { nameByKey[$0] })
        let notChosenLines = excludedRows.compactMap { row -> String? in
            guard let key = row.newAccountKey, let name = nameByKey[key] else { return nil }
            return ImportError.newAccountNotChosen(row: row.rowNumber, name: name).errorDescription
        }
        var result = make(
            rows: kept,
            accountNames: preview.accountNames.filter { !excludedNames.contains($0) },
            failures: preview.fileFailures + notChosenLines,
            ignoredFutureCount: preview.ignoredFutureCount)
        let keptRows = Set(kept.map(\.rowNumber))
        result.ignoredColumns = preview.ignoredColumns
        result.groupRowCount = preview.groupRowCount
        result.doubtfulAmounts = preview.doubtfulAmounts.filter { keptRows.contains($0.rowNumber) }
        result.newAccounts = preview.newAccounts
        result.existingBillableAccounts = preview.existingBillableAccounts
        result.allRows = preview.allRows
        result.fileFailures = preview.fileFailures
        result.readSheet = preview.readSheet
        result.skippedSheets = preview.skippedSheets
        result.duplicateCount = accountKept.filter(\.isDuplicate).count
        result.importsDuplicates = importDuplicates
        result.looseTransferCount = looseTransfers(in: kept)
        result.dateOrderNotice = preview.dateOrderNotice
        result.allInitialBalances = preview.allInitialBalances
        result.initialBalances = keptInitialBalances
        return result
    }

    /// Las filas malas que caben en la lista, y cuántas quedan sin listar.
    static func listedFailures(_ failures: [String]) -> (shown: [String], hidden: Int) {
        let shown = Array(failures.prefix(failureListLimit))
        return (shown, failures.count - shown.count)
    }

    /// El mensaje del final: «Importamos 69 registros. 1 fila no entró:» y la lista corta (L7-17).
    ///
    /// - Parameters:
    ///   - importedLine: la frase de los importados, ya con su plural (`L10n.Import.recordsImported`).
    ///   - notImportedLine: la frase de las que no entraron, con su plural; solo se usa si hay alguna.
    ///   - moreLine: «… y N más», con su plural; solo si la lista se corta.
    static func outcomeMessage(
        importedLine: String,
        failures: [String],
        notImportedLine: (Int) -> String,
        moreLine: (Int) -> String
    ) -> String {
        guard !failures.isEmpty else { return importedLine }
        let (shown, hidden) = listedFailures(failures)
        var lines = [importedLine, "", notImportedLine(failures.count)]
        lines.append(contentsOf: shown)
        if hidden > 0 { lines.append(moreLine(hidden)) }
        return lines.joined(separator: "\n")
    }
}
