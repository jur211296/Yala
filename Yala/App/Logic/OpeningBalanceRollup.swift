//
//  OpeningBalanceRollup.swift
//  Yala
//
//  Pure-logic: resumen NETO por miembro de los saldos iniciales (estado de apertura),
//  derivado SOLO de los SplitExpense con `isOpeningBalance=true` + sus shares — NO del
//  balance vivo del grupo. Testeable sin SwiftData.
//

import Foundation

enum OpeningBalanceRollup {

    /// Una arista de saldo inicial ya resuelta a (deudor, acreedor, monto, moneda).
    struct Edge {
        let debtorMemberID: String
        let creditorMemberID: String
        let amount: Double
        let currencyCode: String
    }

    /// Neto por miembro y moneda: `+` el acreedor (le deben), `−` el deudor (debe).
    /// - Returns: `[memberID: [currencyCode: net]]`, omitiendo netos ≈ 0.
    static func netByMember(edges: [Edge]) -> [String: [String: Double]] {
        var result: [String: [String: Double]] = [:]
        for edge in edges {
            result[edge.creditorMemberID, default: [:]][edge.currencyCode, default: 0] += edge.amount
            result[edge.debtorMemberID, default: [:]][edge.currencyCode, default: 0] -= edge.amount
        }
        // Limpiar netos ≈ 0 (un miembro deudor y acreedor del mismo monto/moneda se cancela).
        for (member, byCurrency) in result {
            var cleaned = byCurrency.filter { abs($0.value) > 0.005 }
            if cleaned.isEmpty {
                result[member] = nil
            } else {
                // Redondeo a 2 decimales para mostrar.
                for (code, value) in cleaned { cleaned[code] = (value * 100).rounded() / 100 }
                result[member] = cleaned
            }
        }
        return result
    }
}
