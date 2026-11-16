//
//  DescriptionSuggestionLogic.swift
//  Yala
//
//  Nuevo registro · sugerencias de descripción a partir de registros anteriores (card 2.3
//  `tablero-nuevo-registro-sugerencias-de-descripcio-y6du`). Para que la persona escriba siempre igual la misma cosa
//  («Uber», no «uber» un día y «Uber viaje» otro) y el seguimiento las agrupe.
//
//  - El índice se arma UNA vez al abrir el formulario, con las descripciones de gastos e ingresos (sin transferencias
//    ni ajustes de saldo, que tienen su propio texto de sistema).
//  - Se compara sin mayúsculas, tildes ni espacios de más. La grafía que se propone es la más usada de cada texto.
//  - Primero lo que EMPIEZA por lo escrito (el texto o una de sus palabras), después lo que lo contiene; dentro de
//    cada grupo, lo más usado y, a igualdad, lo más reciente.
//  - Solo del mismo lado (gasto o ingreso) que el formulario.
//

import Foundation

struct DescriptionSuggestionEntry: Equatable {
    /// La grafía que se propone (la más usada).
    let text: String
    /// Sin mayúsculas, tildes ni espacios de más.
    let normalized: String
    let count: Int
    let lastUsed: Date
    let isIncome: Bool
}

enum DescriptionSuggestionLogic {

    static let maxSuggestions = 5
    static let minQueryLength = 2

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// El índice, a partir de registros ya cargados.
    static func buildIndex(from transactions: [TransactionItem]) -> [DescriptionSuggestionEntry] {
        buildIndex(rows: transactions.compactMap { tx in
            guard tx.balanceAdjustmentType == nil, let note = tx.note else { return nil }
            return (note, tx.date, TransactionClassificationLogic.isIncome(tx))
        })
    }

    static func buildIndex(rows: [(note: String, date: Date, isIncome: Bool)]) -> [DescriptionSuggestionEntry] {
        struct Acc { var spellings: [String: Int] = [:]; var count = 0; var lastUsed = Date.distantPast }
        var byKey: [String: Acc] = [:]
        for row in rows {
            let trimmed = row.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalize(trimmed)
            guard !normalized.isEmpty else { continue }
            // Gasto e ingreso con el mismo texto son dos entradas: se proponen cada una en su lado.
            let key = (row.isIncome ? "i:" : "e:") + normalized
            var acc = byKey[key] ?? Acc()
            acc.spellings[trimmed, default: 0] += 1
            acc.count += 1
            acc.lastUsed = max(acc.lastUsed, row.date)
            byKey[key] = acc
        }
        return byKey.map { key, acc in
            let text = acc.spellings.max { lhs, rhs in
                lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
            }?.key ?? ""
            return DescriptionSuggestionEntry(
                text: text, normalized: String(key.dropFirst(2)), count: acc.count,
                lastUsed: acc.lastUsed, isIncome: key.hasPrefix("i:"))
        }
    }

    /// Hasta `maxSuggestions` textos para lo escrito. Vacío si lo escrito es corto, si es lo mismo que ya hay o si
    /// nada coincide.
    static func suggestions(
        for query: String, isIncome: Bool, in index: [DescriptionSuggestionEntry], limit: Int = maxSuggestions
    ) -> [String] {
        let q = normalize(query)
        guard q.count >= minQueryLength else { return [] }
        var prefix: [DescriptionSuggestionEntry] = []
        var contains: [DescriptionSuggestionEntry] = []
        for entry in index where entry.isIncome == isIncome && entry.normalized != q {
            if entry.normalized.hasPrefix(q) || entry.normalized.split(separator: " ").contains(where: { $0.hasPrefix(q) }) {
                prefix.append(entry)
            } else if entry.normalized.contains(q) {
                contains.append(entry)
            }
        }
        let rank: (DescriptionSuggestionEntry, DescriptionSuggestionEntry) -> Bool = { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            if lhs.lastUsed != rhs.lastUsed { return lhs.lastUsed > rhs.lastUsed }
            return lhs.normalized < rhs.normalized
        }
        return (prefix.sorted(by: rank) + contains.sorted(by: rank)).prefix(limit).map(\.text)
    }
}
