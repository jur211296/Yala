//
//  RecordsListSearchLogic.swift
//  Yala
//
//  «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1, 2026-11-09): el campo que asoma arriba de la lista
//  de Registros busca dentro de lo que ya se ve —con su período y sus filtros— en la nota, la categoría, la subcategoría,
//  la cuenta, las etiquetas y el importe. La pestaña Buscar no cambia.
//
//  El importe: lo escrito se lee como número si lo parece («45.90», «45,90», «S/ 45.90», «1.234,50») y se compara sin
//  signo y en la moneda del registro (un «45.90» casa en S/ y en US$, como el filtro de monto). Con decimales, al céntimo;
//  sin decimales («45»), todo lo que tenga esa parte entera (45,00 a 45,99), porque así se recuerda un importe.
//

import Foundation

nonisolated enum RecordsListSearchLogic {

    /// Lo que se busca, ya preparado: el texto tal cual (sin espacios a los lados) y, si lo parece, el importe.
    struct Query: Equatable {
        let text: String
        let amount: AmountQuery?

        var isEmpty: Bool { text.isEmpty }
    }

    /// Un importe escrito: en céntimos, y si llevaba decimales (al céntimo) o no (toda la parte entera).
    struct AmountQuery: Equatable {
        let cents: Int
        let hasDecimals: Bool

        func matches(_ signedAmount: Double) -> Bool {
            guard signedAmount.isFinite else { return false }
            let recordCents = Int((abs(signedAmount) * 100).rounded())
            if hasDecimals { return recordCents == cents }
            return recordCents / 100 == cents / 100
        }
    }

    /// Los textos de un registro que entran en la búsqueda. Sueltos, para que la regla se pruebe sin SwiftData.
    struct Fields {
        var note: String?
        var category: String?
        var subcategory: String?
        var account: String?
        var tags: [String] = []
        var signedAmount: Double
    }

    static func query(_ raw: String) -> Query {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return Query(text: text, amount: amount(from: text))
    }

    /// Casa por el importe o por cualquiera de los textos, sin distinguir mayúsculas ni tildes.
    static func matches(_ fields: Fields, query: Query) -> Bool {
        guard !query.isEmpty else { return true }
        if let amount = query.amount, amount.matches(fields.signedAmount) { return true }
        let texts = [fields.note, fields.category, fields.subcategory, fields.account].compactMap { $0 } + fields.tags
        return texts.contains { $0.localizedStandardContains(query.text) }
    }

    /// Lee un importe escrito a mano. `nil` si no lo parece: sin cifras, o con algo más que un símbolo o código de moneda.
    /// El último separador seguido de 1 o 2 cifras es el decimal; los demás, de miles («1.234,50», «1,234.50»).
    static func amount(from text: String) -> AmountQuery? {
        let separators: Set<Character> = [".", ","]
        let currencyMarks: Set<Character> = ["$", "€", "£", "¥", "₩", "₹", "₱", "/", "+", "-", "−", " "]
        var kept = ""
        var letters = ""
        for character in text {
            if character.isNumber && character.isASCII || separators.contains(character) {
                kept.append(character)
            } else if character.isLetter {
                letters.append(character)
            } else if !currencyMarks.contains(character) && !character.isWhitespace {
                return nil
            }
        }
        // «S/», «s/», «US$», «PEN», «EUR»: hasta tres letras, en mayúsculas, de una moneda. «Bus 12» no es un importe.
        let isCurrencyCode = letters.count <= 3 && (letters == letters.uppercased() || letters == "s")
        guard isCurrencyCode, kept.contains(where: \.isNumber) else { return nil }

        var integerPart = Substring(kept)
        var fraction = Substring("")
        if let lastSeparator = kept.lastIndex(where: { separators.contains($0) }) {
            let after = kept[kept.index(after: lastSeparator)...]
            if (1...2).contains(after.count), after.allSatisfy(\.isNumber) {
                integerPart = kept[..<lastSeparator]
                fraction = after
            }
        }
        let integerDigits = integerPart.filter(\.isNumber)
        guard integerDigits.count <= 12, let units = Int(integerDigits.isEmpty ? "0" : integerDigits) else { return nil }
        let fractionCents = fraction.isEmpty ? 0 : (Int(fraction.count == 1 ? fraction + "0" : String(fraction)) ?? 0)
        return AmountQuery(cents: units * 100 + fractionCents, hasDecimals: !fraction.isEmpty)
    }
}
