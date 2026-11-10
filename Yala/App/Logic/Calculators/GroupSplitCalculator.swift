//
//  GroupSplitCalculator.swift
//  Yala
//
//  Per-participant split calculation for group expenses.
//  Returns array of (memberID, amount) matching GroupExpenseService.createExpense(shares:) format.
//

import Foundation

enum GroupSplitCalculator {

    struct Participant {
        let memberID: String
        var value: Double // Meaning depends on splitType
    }

    /// Calculates each participant's share of the total amount.
    /// - Returns: Array of (memberID, amount) or nil if inputs are invalid.
    static func calculate(
        total: Double,
        splitType: SplitType,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        guard total > 0, !participants.isEmpty else { return nil }

        // Un solo participante: recibe el total completo, sea cual sea el tipo de división —
        // dividir entre uno es trivial. Evita el falso "desbalanceado" en .exact/.percentage
        // cuando el usuario aún no configuró valores por participante.
        if participants.count == 1 {
            return [(memberID: participants[0].memberID, amount: roundTwo(total))]
        }

        switch splitType {
        case .equal:
            return equalSplit(total: total, participants: participants)
        case .exact:
            return exactSplit(total: total, participants: participants)
        case .percentage:
            return percentageSplit(total: total, participants: participants)
        case .shares:
            return sharesSplit(total: total, participants: participants)
        }
    }

    // MARK: - Equal Split

    /// Divides total equally. Distributes leftover cents to the first participants
    /// (array order); the sum of the parts always equals the total exactly.
    private static func equalSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let count = participants.count
        guard count > 0 else { return nil }

        let baseAmount = floor(total * 100 / Double(count)) / 100
        let totalDistributed = baseAmount * Double(count)
        var remainder = roundTwo(total - totalDistributed)

        return participants.enumerated().map { index, p in
            var amount = baseAmount
            if remainder >= 0.005 {
                amount += 0.01
                remainder -= 0.01
            }
            return (memberID: p.memberID, amount: roundTwo(amount))
        }
    }

    // MARK: - Exact Split

    /// Lo que cuenta como «cuadra»: medio céntimo, solo para el ruido de coma flotante (133.33 + 133.33 + 133.34 da
    /// 400.00000000000006). Hasta el 2026-11-10 eran dos céntimos: un gasto de 400 con partes que sumaban 399,99 se
    /// guardaba, la insignia decía «Balanceado» y ese céntimo no era de nadie —las deudas salen de las partes y el
    /// pagador puso 400—. Decisión de Jürgen (lote 02 de mejoras necesarias de 2.3): no se guarda hasta cuadrar. La
    /// usa también la insignia del formulario (`GroupExpenseViewModel.isSharesBalanced`).
    static let balanceTolerance = 0.005

    /// Each participant.value is the exact amount they owe.
    /// Validates that sum of values equals total, al céntimo (`balanceTolerance`).
    private static func exactSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let sum = participants.reduce(0.0) { $0 + $1.value }
        guard abs(sum - total) < balanceTolerance else { return nil }
        guard participants.allSatisfy({ $0.value >= 0 }) else { return nil }

        return participants.map { (memberID: $0.memberID, amount: roundTwo($0.value)) }
    }

    // MARK: - Percentage Split

    /// Each participant.value is their percentage (0–100).
    /// Validates that percentages sum to 100 (con el mismo margen de coma flotante que «Monto»). Antes admitía 0,1 %, y
    /// la diferencia iba entera al último por `adjustLastForRounding` (en 400, hasta 0,36).
    private static func percentageSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        let sumPct = participants.reduce(0.0) { $0 + $1.value }
        guard abs(sumPct - 100) < balanceTolerance else { return nil }
        guard participants.allSatisfy({ $0.value >= 0 }) else { return nil }

        var results = participants.map { p in
            (memberID: p.memberID, amount: roundTwo(total * p.value / 100))
        }

        adjustLastForRounding(&results, total: total)
        return results
    }

    // MARK: - Shares Split

    /// Each participant.value is their share count (integer-like).
    /// Calculates proportional amount based on share ratio.
    private static func sharesSplit(
        total: Double,
        participants: [Participant]
    ) -> [(memberID: String, amount: Double)]? {
        guard participants.allSatisfy({ $0.value > 0 }) else { return nil }

        let totalShares = participants.reduce(0.0) { $0 + $1.value }
        guard totalShares > 0 else { return nil }

        var results = participants.map { p in
            (memberID: p.memberID, amount: roundTwo(total * p.value / totalShares))
        }

        adjustLastForRounding(&results, total: total)
        return results
    }

    // MARK: - Helpers

    /// Adjusts last participant's amount so distributed total matches expected total.
    private static func adjustLastForRounding(
        _ results: inout [(memberID: String, amount: Double)],
        total: Double
    ) {
        let distributed = results.reduce(0.0) { $0 + $1.amount }
        let diff = roundTwo(total - distributed)
        if abs(diff) > 0 && !results.isEmpty {
            let last = results.count - 1
            results[last].amount = roundTwo(results[last].amount + diff)
        }
    }

    private static func roundTwo(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
