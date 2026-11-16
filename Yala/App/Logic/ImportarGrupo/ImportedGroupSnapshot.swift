//
//  ImportedGroupSnapshot.swift
//  Yala
//
//  Lo que se saca de un export de Splitwise o de Tricount: quiénes están, cuántos gastos y pagos, entre qué fechas y el
//  saldo neto de cada persona en cada moneda. No guarda los gastos uno a uno: el import trae SALDOS (Paso 0 del ticket
//  `groups-import-splitwise-tricount`), y el saldo es lo único que tiene que coincidir con el de la otra app.
//

import Foundation

struct ImportedGroupSnapshot: Equatable, Codable, Sendable {

    enum Source: String, Codable, Sendable {
        case splitwise
        case tricount
    }

    let source: Source
    /// Nombre propuesto para el grupo, sacado del nombre del archivo; `nil` si no dice nada.
    let suggestedName: String?
    /// Las personas, en el orden del export.
    let people: [String]
    let expenseCount: Int
    let paymentCount: Int
    let firstDate: Date?
    let lastDate: Date?
    /// Moneda (código ISO) → persona → saldo en céntimos. Positivo: le deben; negativo: debe. Cada moneda suma cero.
    let balances: [String: [String: Int]]

    /// Las monedas, de la que más mueve a la que menos (y por código en un empate): la primera se propone al grupo.
    var currencies: [String] {
        balances.keys.sorted { lhs, rhs in
            let left = volume(of: lhs), right = volume(of: rhs)
            return left == right ? lhs < rhs : left > right
        }
    }

    private func volume(of currency: String) -> Int {
        (balances[currency] ?? [:]).values.reduce(0) { $0 + abs($1) }
    }

    /// El saldo de una persona en cada moneda, solo las que no son cero, en el orden de `currencies`.
    func balances(of person: String) -> [(currency: String, cents: Int)] {
        currencies.compactMap { currency in
            guard let cents = balances[currency]?[person], cents != 0 else { return nil }
            return (currency, cents)
        }
    }

    /// Las personas con algún saldo distinto de cero: las únicas que hay que emparejar.
    var peopleWithBalance: [String] {
        people.filter { !balances(of: $0).isEmpty }
    }
}

/// Lo que no deja leer un export. Cada caso tiene su texto en la vista previa (`ImportarGrupoErrorCopy`).
enum ImportedGroupError: Error, Equatable {
    /// No parece un export de Splitwise ni de Tricount.
    case unrecognizedFormat
    /// Se reconoce el formato pero no trae ni un gasto.
    case noEntries
    /// Una moneda que Yala no conoce.
    case unknownCurrency(String)
    /// Un importe que no se puede leer (número de fila del archivo, contando desde 1).
    case unreadableAmount(row: Int)
    /// Una fila cuyo reparto no suma el importe.
    case rowDoesNotAddUp(row: Int)
    /// Los saldos de una moneda no suman cero.
    case balancesDoNotAddUp(currency: String)
    /// El archivo no es texto.
    case unreadableFile
}

enum ImportedGroupSnapshotBuilder {

    /// Acumula saldos en `Decimal` y los cierra en céntimos, comprobando que cada moneda sume cero. El redondeo puede
    /// dejar un céntimo suelto por persona: ese resto lo absorbe quien tiene el saldo mayor (el mismo criterio de
    /// Splitwise al repartir). Más de un céntimo por persona es un export que no cuadra.
    static func closeBalances(_ raw: [String: [String: Decimal]]) throws -> [String: [String: Int]] {
        var result: [String: [String: Int]] = [:]
        for (currency, people) in raw {
            var cents = people.mapValues { GroupExportCSV.cents($0) }
            let drift = cents.values.reduce(0, +)
            if drift != 0 {
                guard abs(drift) <= max(1, cents.count) else {
                    throw ImportedGroupError.balancesDoNotAddUp(currency: currency)
                }
                let absorber = cents.max { lhs, rhs in
                    abs(lhs.value) == abs(rhs.value) ? lhs.key > rhs.key : abs(lhs.value) < abs(rhs.value)
                }
                if let absorber { cents[absorber.key] = absorber.value - drift }
            }
            result[currency] = cents
        }
        return result
    }

    /// Dos personas con el mismo nombre en el export son dos personas: «Carlos» y «Carlos (2)». Sin esto, sus saldos se
    /// sumaban bajo un solo nombre.
    static func distinctNames(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return names.map { name in
            let count = (seen[name] ?? 0) + 1
            seen[name] = count
            return count == 1 ? name : "\(name) (\(count))"
        }
    }

    /// La moneda de una fila: el código ISO, o un alias que Yala reconozca («S/», «US$»).
    static func currencyCode(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let code = knownCurrency(trimmed) else { throw ImportedGroupError.unknownCurrency(trimmed) }
        return code
    }

    /// El código de una moneda que Yala conoce, o `nil`.
    static func knownCurrency(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let code = CurrencyCode(rawValue: trimmed.uppercased()) { return code.rawValue }
        return CurrencyCode.fromAlias(trimmed)?.rawValue
    }

    /// Nombre propuesto a partir del archivo: «viaje-a-cusco_2026-03-01_export.csv» → «Viaje a cusco»;
    /// «Transactions Depa Miraflores.csv» → «Depa Miraflores». `nil` si no queda nada útil.
    static func suggestedName(fileName: String?) -> String? {
        guard let fileName else { return nil }
        var base = (fileName as NSString).deletingPathExtension
        base = base.replacingOccurrences(of: #"_?\d{4}-\d{2}-\d{2}.*$"#, with: "", options: .regularExpression)
        base = base.replacingOccurrences(of: #"(?i)[ _-]*export$"#, with: "", options: .regularExpression)
        base = base.replacingOccurrences(of: #"(?i)^(transactions|tricount|splitwise)[ _-]*"#, with: "",
                                         options: .regularExpression)
        base = base.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        base = base.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        guard base.count >= 2, base.contains(where: \.isLetter) else { return nil }
        return base.prefix(1).uppercased() + base.dropFirst()
    }

    /// Lee el archivo con el lector que lo reconozca: primero Splitwise, después Tricount.
    static func snapshot(fromCSV text: String, fileName: String?) throws -> ImportedGroupSnapshot {
        let rows = GroupExportCSV.rows(from: text)
        let name = suggestedName(fileName: fileName)
        if let splitwise = try SplitwiseExportParser.parse(rows: rows, suggestedName: name) {
            return splitwise
        }
        if let tricount = try TricountExportParser.parse(rows: rows, suggestedName: name) {
            return tricount
        }
        throw ImportedGroupError.unrecognizedFormat
    }

    /// El texto de un archivo: UTF-8 (con o sin BOM), UTF-16 o, como último recurso, Latin-1 (Excel en Windows).
    static func text(from data: Data) throws -> String {
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let utf16 = String(data: data, encoding: .utf16) { return utf16 }
        if let latin = String(data: data, encoding: .isoLatin1), !latin.contains("\u{0}") { return latin }
        throw ImportedGroupError.unreadableFile
    }
}
