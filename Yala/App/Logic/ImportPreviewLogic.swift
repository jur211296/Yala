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

    var canImport: Bool { count > 0 }
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
                newAccountKey: $0.newAccountKey
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
        return preview
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

    /// La vista previa con solo las cuentas nuevas elegidas: las filas de las demás pasan a no entrar, con su motivo.
    static func applying(chosen: Set<String>, to preview: ImportPreview) -> ImportPreview {
        guard !preview.newAccounts.isEmpty else { return preview }
        let excludedKeys = Set(preview.newAccounts.map(\.key)).subtracting(chosen)
        let kept = preview.allRows.filter { row in row.newAccountKey.map { !excludedKeys.contains($0) } ?? true }
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
