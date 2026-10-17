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
