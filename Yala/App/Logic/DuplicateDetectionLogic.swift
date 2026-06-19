//
//  DuplicateDetectionLogic.swift
//  Yala
//
//  Pure-logic: detección fuzzy de TX personales potenciales duplicadas durante el
//  import histórico del `BridgeActivationSheet` (F5). Multi-criterio con scoring
//  (D4 incluido en V1: nota + payerName).
//

import Foundation

enum DuplicateDetectionLogic {

    /// Datos mínimos de un expense de grupo para buscar matches.
    struct ExpenseCandidate {
        let amount: Double
        let date: Date
        let currencyCode: String
        let note: String?
        let payerName: String?
    }

    /// Datos mínimos de una TX personal candidata a ser potencial duplicado.
    struct TransactionCandidate {
        let amount: Double  // absoluto (compararemos abs)
        let date: Date
        let currencyCode: String
        let note: String?
        let splitExpenseID: String?  // nil = no bridgeada
    }

    /// Nivel de confianza del match.
    enum Confidence: Equatable {
        case low   // hard match (fecha + monto + currency) solo
        case high  // hard match + soft signals (note/payerName)
    }

    /// Resultado del scan.
    struct Match: Equatable {
        let confidence: Confidence
    }

    /// Stop words ignoradas al comparar notas (palabras vacías cross-language ES/EN).
    private static let stopWords: Set<String> = [
        "de", "la", "el", "los", "las", "un", "una", "y", "a", "en",
        "the", "of", "and", "to", "for", "in", "on", "at", "with"
    ]

    /// Tolerancia de fecha en días.
    static let dateToleranceDays: Int = 2
    /// Tolerancia relativa de monto (±5%).
    static let amountTolerance: Double = 0.05

    /// Busca el mejor match para `expense` entre las `transactions` candidatas.
    /// Devuelve `nil` si no hay match. Si hay múltiples hard-matches, retorna el
    /// primero con mayor confidence.
    static func findPotentialDuplicate(
        forExpense expense: ExpenseCandidate,
        in transactions: [TransactionCandidate],
        now: Date = .now
    ) -> Match? {
        var best: Match?
        for tx in transactions {
            guard tx.splitExpenseID == nil else { continue }  // ya bridgeada
            guard tx.currencyCode == expense.currencyCode else { continue }
            let daysDiff = abs(daysBetween(tx.date, expense.date))
            guard daysDiff <= dateToleranceDays else { continue }
            let absExpense = abs(expense.amount)
            guard absExpense > 0.0001 else { continue }
            let amountDiffPct = abs(abs(tx.amount) - absExpense) / absExpense
            guard amountDiffPct <= amountTolerance else { continue }

            // Hard match alcanzado.
            let score = softScore(expense: expense, transaction: tx)
            let confidence: Confidence = score > 0 ? .high : .low
            if best == nil || (best?.confidence == .low && confidence == .high) {
                best = Match(confidence: confidence)
            }
        }
        return best
    }

    /// Soft score adicional (D4): note word overlap + payerName mención.
    /// Score 0 = solo hard match. Score >= 1 = high confidence.
    static func softScore(expense: ExpenseCandidate, transaction: TransactionCandidate) -> Int {
        var score = 0
        if let payer = expense.payerName?.lowercased(),
           !payer.isEmpty,
           let txNote = transaction.note?.lowercased(),
           txNote.contains(payer) {
            score += 1
        }
        let expenseWords = significantWords(expense.note)
        let txWords = significantWords(transaction.note)
        let overlap = expenseWords.intersection(txWords).count
        if overlap >= 3 {
            score += 1
        }
        return score
    }

    /// Tokens de la nota lowercased ignorando stop-words y palabras < 3 chars.
    static func significantWords(_ note: String?) -> Set<String> {
        guard let note, !note.isEmpty else { return [] }
        let tokens = note.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }
        return Set(tokens)
    }

    private static func daysBetween(_ a: Date, _ b: Date) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let aStart = cal.startOfDay(for: a)
        let bStart = cal.startOfDay(for: b)
        let comps = cal.dateComponents([.day], from: aStart, to: bStart)
        return comps.day ?? 0
    }
}
