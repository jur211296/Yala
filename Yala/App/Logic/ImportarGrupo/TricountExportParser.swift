//
//  TricountExportParser.swift
//  Yala
//
//  El export de un tricount. **No hay un formato oficial publicado**, y la app nueva de Tricount (bunq) dejó de exportar
//  desde la app: el CSV lo manda su soporte o sale de herramientas de terceros (medido el 2026-11-16, Paso 0 del ticket
//  `groups-import-splitwise-tricount`). Por eso este lector acepta las variantes conocidas en vez de una sola:
//
//  - una columna con quién pagó («Paid by»), el importe («Amount») y su moneda («Currency»), y a veces el importe en la
//    moneda del tricount («Amount in EUR» / «Amount in default currency»);
//  - el reparto en una columna por persona («Paid for Ana», «Impacted to Ana», «Share Ana», «Local share Ana»), o en una
//    sola columna con los nombres separados por «;» o «,», que se reparte a partes iguales;
//  - el tipo de fila («Transaction type»): un reembolso o transferencia cuenta como pago; un ingreso va al revés.
//
//  Cada fila suma al que pagó lo que puso y resta a cada persona su parte. Validarlo con un export real queda anotado.
//

import Foundation

enum TricountExportParser {

    static let paidByHeaders: Set<String> = [
        "paid by", "paye par", "pagado por", "pago por", "pagato da", "bezahlt von", "betaald door", "payer",
    ]
    private static let amountHeaders: Set<String> = [
        "amount", "montant", "importe", "monto", "valor", "betrag", "importo", "bedrag",
    ]
    private static let currencyHeaders: Set<String> = [
        "currency", "devise", "moneda", "divisa", "moeda", "wahrung", "valuta", "munt",
    ]
    private static let amountInPrefixes = ["amount in ", "montant en ", "importe en ", "monto en ", "valor em "]
    private static let dateHeaders: Set<String> = [
        "date", "date & time", "date and time", "fecha", "datum", "data", "date et heure", "fecha y hora",
    ]
    private static let typeHeaders: Set<String> = ["transaction type", "type", "tipo", "typ", "type de transaction"]
    /// Prefijos de las columnas de reparto por persona. «local share» va antes que «share»: es el mismo reparto en la
    /// moneda de la fila, y cuando están los dos manda ese.
    private static let localSharePrefixes = ["local share "]
    private static let sharePrefixes = [
        "paid for ", "impacted to ", "impacte a ", "pagado para ", "pago para ", "pour ", "share ", "part de ",
    ]
    private static let ignoredPrefixes = ["share ratio ", "allocation type "]
    /// Una sola columna con la lista de personas.
    private static let listHeaders: Set<String> = [
        "paid for", "impacted to", "for whom", "impacte a", "pagado para", "participants", "participantes", "for",
    ]
    private static let transferWords = [
        "transfer", "reimburse", "refund", "balance", "transfert", "rembourse", "transferencia", "reembolso",
        "erstattung", "uberweisung",
    ]
    private static let incomeWords = ["income", "ingreso", "revenu", "entrata", "einnahme", "receita"]

    private struct Columns {
        var paidBy: Int
        var amount: Int?
        var currency: Int?
        var amountInDefault: Int?
        var defaultCurrency: String?
        var date: Int?
        var type: Int?
        var list: Int?
        /// Persona → columna de su parte (la de «local share» si la hay).
        var shares: [(person: String, column: Int, isLocal: Bool)]
    }

    /// `nil` si las filas no tienen la cabecera de Tricount; lanza si la tienen pero algo no se deja leer.
    static func parse(rows: [[String]], suggestedName: String?) throws -> ImportedGroupSnapshot? {
        guard let headerIndex = rows.firstIndex(where: { $0.map { GroupExportCSV.headerKey($0) }.contains(where: { paidByHeaders.contains($0) }) }),
              let columns = columns(in: rows[headerIndex]) else { return nil }

        var people: [String] = []
        func note(_ person: String) { if !people.contains(person) { people.append(person) } }
        for share in columns.shares { note(share.person) }

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
            let payer = cell(columns.paidBy)
            let amountText = cell(columns.amount ?? columns.amountInDefault)
            // Un pie o un subtotal sin quién pagó ni importe.
            if payer.isEmpty && amountText.isEmpty { continue }
            guard !payer.isEmpty, let signedAmount = GroupExportCSV.amount(amountText) else {
                throw ImportedGroupError.unreadableAmount(row: offset + 1)
            }

            // Una fila a cero (un gasto anulado) no mueve ningún saldo.
            if signedAmount == 0 { continue }
            var amount = abs(signedAmount)
            var currency: String
            let currencyText = cell(columns.currency)
            if !currencyText.isEmpty {
                currency = try ImportedGroupSnapshotBuilder.currencyCode(currencyText)
            } else if let fallback = columns.defaultCurrency {
                currency = fallback
            } else {
                throw ImportedGroupError.unknownCurrency("")
            }

            let typeKey = GroupExportCSV.headerKey(cell(columns.type))
            let isIncome = incomeWords.contains { typeKey.contains($0) }
            let isTransfer = transferWords.contains { typeKey.contains($0) }
            // Un importe negativo (un reembolso apuntado como gasto) y un ingreso van al revés: el que «pagó» recibe.
            let direction: Decimal = (signedAmount < 0) != isIncome ? -1 : 1

            var shares: [(person: String, value: Decimal)] = []
            if !columns.shares.isEmpty {
                for share in columns.shares {
                    let text = cell(share.column)
                    if text.isEmpty { continue }
                    guard let value = GroupExportCSV.amount(text) else {
                        throw ImportedGroupError.unreadableAmount(row: offset + 1)
                    }
                    if value != 0 { shares.append((share.person, abs(value))) }
                }
                let sum = shares.reduce(Decimal(0)) { $0 + $1.value }
                let tolerance = Decimal(max(1, shares.count)) / 100
                let defaultAmount = GroupExportCSV.amount(cell(columns.amountInDefault)).map(abs)
                if abs(sum - amount) <= tolerance {
                    // Las partes son de la moneda de la fila.
                } else if let defaultAmount, let defaultCurrency = columns.defaultCurrency,
                          abs(sum - defaultAmount) <= tolerance {
                    // Las partes vienen en la moneda del tricount: la fila entera se cuenta en esa.
                    amount = defaultAmount
                    currency = defaultCurrency
                } else if sum == 0, columns.list != nil {
                    shares = []
                } else {
                    throw ImportedGroupError.rowDoesNotAddUp(row: offset + 1)
                }
            }
            if shares.isEmpty {
                let names = listNames(cell(columns.list))
                guard !names.isEmpty else { throw ImportedGroupError.rowDoesNotAddUp(row: offset + 1) }
                shares = equalSplit(amount, among: names)
            }

            note(payer)
            // Al que pagó, la suma de las partes y no el importe: la comprobación de arriba tolera un céntimo por
            // persona, y ese resto, sumado fila a fila, dejaba a alguien con un saldo distinto del de Tricount.
            let paid = shares.reduce(Decimal(0)) { $0 + $1.value }
            raw[currency, default: [:]][payer, default: 0] += direction * paid
            for share in shares {
                note(share.person)
                raw[currency, default: [:]][share.person, default: 0] -= direction * share.value
            }

            if isTransfer { payments += 1 } else { expenses += 1 }
            if let date = GroupExportCSV.date(cell(columns.date)) {
                firstDate = min(firstDate ?? date, date)
                lastDate = max(lastDate ?? date, date)
            }
        }

        guard expenses + payments > 0 else { throw ImportedGroupError.noEntries }
        for currency in raw.keys {
            for person in people where raw[currency]?[person] == nil { raw[currency]?[person] = 0 }
        }
        return ImportedGroupSnapshot(
            source: .tricount,
            suggestedName: suggestedName,
            people: people,
            expenseCount: expenses,
            paymentCount: payments,
            firstDate: firstDate,
            lastDate: lastDate,
            balances: try ImportedGroupSnapshotBuilder.closeBalances(raw)
        )
    }

    private static func columns(in header: [String]) -> Columns? {
        let keys = header.map { GroupExportCSV.headerKey($0) }
        guard let paidBy = keys.firstIndex(where: { paidByHeaders.contains($0) }) else { return nil }
        var columns = Columns(paidBy: paidBy, shares: [])
        columns.amount = keys.firstIndex(where: { amountHeaders.contains($0) })
        columns.currency = keys.firstIndex(where: { currencyHeaders.contains($0) })
        columns.date = keys.firstIndex(where: { dateHeaders.contains($0) })
        columns.type = keys.firstIndex(where: { typeHeaders.contains($0) })
        columns.list = keys.firstIndex(where: { listHeaders.contains($0) })
        if let index = keys.firstIndex(where: { key in amountInPrefixes.contains { key.hasPrefix($0) } }) {
            columns.amountInDefault = index
            let key = keys[index]
            if let prefix = amountInPrefixes.first(where: { key.hasPrefix($0) }) {
                let suffix = String(header[index].dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                // «Amount in default currency» no nombra la moneda: entonces no hay moneda por defecto.
                columns.defaultCurrency = ImportedGroupSnapshotBuilder.knownCurrency(suffix)
            }
        }
        guard columns.amount != nil || columns.amountInDefault != nil else { return nil }

        for (index, key) in keys.enumerated() {
            if ignoredPrefixes.contains(where: { key.hasPrefix($0) }) { continue }
            let original = header[index]
            if let prefix = localSharePrefixes.first(where: { key.hasPrefix($0) }) {
                let person = String(original.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                guard !person.isEmpty else { continue }
                columns.shares.removeAll { $0.person == person }
                columns.shares.append((person, index, true))
            } else if let prefix = sharePrefixes.first(where: { key.hasPrefix($0) }) {
                let person = String(original.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                guard !person.isEmpty, !columns.shares.contains(where: { $0.person == person && $0.isLocal }) else { continue }
                columns.shares.append((person, index, false))
            }
        }
        guard !columns.shares.isEmpty || columns.list != nil else { return nil }
        return columns
    }

    /// Los nombres de una celda con la lista: separados por «;» si los hay, si no por «,».
    static func listNames(_ text: String) -> [String] {
        let separator: Character = text.contains(";") ? ";" : ","
        return text.split(separator: separator)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Partes iguales en céntimos; los céntimos que sobran van a los primeros de la lista.
    static func equalSplit(_ amount: Decimal, among names: [String]) -> [(person: String, value: Decimal)] {
        let total = GroupExportCSV.cents(amount)
        let base = total / names.count
        let remainder = total - base * names.count
        return names.enumerated().map { index, name in
            (name, Decimal(base + (index < remainder ? 1 : 0)) / 100)
        }
    }
}
