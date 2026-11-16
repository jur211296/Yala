//
//  SplitwiseExportParser.swift
//  Yala
//
//  El export de un grupo de Splitwise («Export as spreadsheet»): una cabecera `Date, Description, Category, Cost,
//  Currency` y una columna por persona, con lo que esa persona puso menos lo que le tocaba en cada fila (positivo: le
//  deben). Al final, una fila «Total balance» con la suma. Los pagos entre personas son filas con categoría «Payment».
//
//  El saldo de cada persona es la suma de su columna por moneda: no se fía de la fila de total, que con varias monedas
//  no dice de cuál es. La cabecera puede venir en otro idioma: se reconocen los nombres de las cinco columnas fijas.
//

import Foundation

enum SplitwiseExportParser {

    private static let dateHeaders: Set<String> = ["date", "fecha", "data", "datum", "date et heure"]
    private static let descriptionHeaders: Set<String> = [
        "description", "descripcion", "descricao", "beschreibung", "descrizione", "omschrijving",
    ]
    // Ojo: un literal de `Set` con un elemento repetido cierra la app al cargarlo. Sin tildes (`headerKey` las quita).
    private static let categoryHeaders: Set<String> = ["category", "categoria", "categorie", "kategorie"]
    private static let costHeaders: Set<String> = [
        "cost", "costo", "coste", "custo", "cout", "kosten", "betrag", "importe", "monto", "valor", "bedrag",
    ]
    private static let currencyHeaders: Set<String> = [
        "currency", "moneda", "divisa", "moeda", "devise", "wahrung", "valuta", "munt",
    ]
    /// Lo que dice la fila del total en los idiomas que exporta Splitwise.
    private static let totalLabels: Set<String> = [
        "total balance", "saldo total", "balance total", "solde total", "gesamtsaldo", "saldo totale", "totaal saldo",
    ]
    private static let paymentCategories: Set<String> = [
        "payment", "pago", "pagamento", "paiement", "zahlung", "betaling",
    ]

    /// `nil` si las filas no tienen la cabecera de Splitwise; lanza si la tienen pero algo no se deja leer.
    static func parse(rows: [[String]], suggestedName: String?) throws -> ImportedGroupSnapshot? {
        guard let headerIndex = rows.firstIndex(where: { isHeader($0) }) else { return nil }
        let header = rows[headerIndex].map { GroupExportCSV.headerKey($0) }
        guard let currencyColumn = header.firstIndex(where: { currencyHeaders.contains($0) }),
              let costColumn = header.firstIndex(where: { costHeaders.contains($0) }),
              let dateColumn = header.firstIndex(where: { dateHeaders.contains($0) }) else { return nil }
        let descriptionColumn = header.firstIndex(where: { descriptionHeaders.contains($0) })
        let categoryColumn = header.firstIndex(where: { categoryHeaders.contains($0) })

        // Las personas: las columnas que van después de la moneda, con nombre.
        let original = rows[headerIndex]
        let personColumns = (currencyColumn + 1..<original.count).filter { !original[$0].isEmpty }
        guard !personColumns.isEmpty else { return nil }
        let people = ImportedGroupSnapshotBuilder.distinctNames(personColumns.map { original[$0] })

        var raw: [String: [String: Decimal]] = [:]
        var expenses = 0
        var payments = 0
        var firstDate: Date?
        var lastDate: Date?

        for (offset, row) in rows.enumerated() where offset > headerIndex {
            if GroupExportCSV.isBlank(row) { continue }
            let cell = { (column: Int?) -> String in
                guard let column, column < row.count else { return "" }
                return row[column]
            }
            let description = GroupExportCSV.headerKey(cell(descriptionColumn))
            let dateText = cell(dateColumn)
            // La fila del total y cualquier pie: fuera. Un gasto o un pago siempre tiene coste; la fila del total no, y
            // en los exports reales sí trae fecha, así que no basta con mirar la fecha (revisión del 2026-11-16: con su
            // texto en otro idioma se contaba como un gasto más y cada saldo salía al doble).
            if totalLabels.contains(description) || cell(costColumn).isEmpty { continue }

            let currency = try ImportedGroupSnapshotBuilder.currencyCode(cell(currencyColumn))
            var rowSum = Decimal(0)
            for (index, column) in personColumns.enumerated() {
                let text = cell(column)
                let value: Decimal
                if text.isEmpty {
                    value = 0
                } else if let parsed = GroupExportCSV.amount(text) {
                    value = parsed
                } else {
                    throw ImportedGroupError.unreadableAmount(row: offset + 1)
                }
                rowSum += value
                raw[currency, default: [:]][people[index], default: 0] += value
            }
            // En Splitwise cada fila suma cero (lo que pone uno es lo que deben los demás).
            if abs(rowSum) > Decimal(max(1, personColumns.count)) / 100 {
                throw ImportedGroupError.rowDoesNotAddUp(row: offset + 1)
            }

            if paymentCategories.contains(GroupExportCSV.headerKey(cell(categoryColumn))) {
                payments += 1
            } else {
                expenses += 1
            }
            if let date = GroupExportCSV.date(dateText) {
                firstDate = min(firstDate ?? date, date)
                lastDate = max(lastDate ?? date, date)
            }
        }

        guard expenses + payments > 0 else { throw ImportedGroupError.noEntries }
        // Que cada persona salga en cada moneda, aunque sea con cero.
        for currency in raw.keys {
            for person in people where raw[currency]?[person] == nil { raw[currency]?[person] = 0 }
        }
        return ImportedGroupSnapshot(
            source: .splitwise,
            suggestedName: suggestedName,
            people: people,
            expenseCount: expenses,
            paymentCount: payments,
            firstDate: firstDate,
            lastDate: lastDate,
            balances: try ImportedGroupSnapshotBuilder.closeBalances(raw)
        )
    }

    /// La cabecera de Splitwise: fecha, coste y moneda, y al menos una columna detrás de la moneda.
    private static func isHeader(_ row: [String]) -> Bool {
        let keys = row.map { GroupExportCSV.headerKey($0) }
        guard let currency = keys.firstIndex(where: { currencyHeaders.contains($0) }) else { return false }
        return keys.contains(where: { dateHeaders.contains($0) })
            && keys.contains(where: { costHeaders.contains($0) })
            && currency < keys.count - 1
            // Tricount también tiene «Currency», pero lleva «Paid by»: ese no es de aquí.
            && !keys.contains(where: TricountExportParser.paidByHeaders.contains)
    }
}
