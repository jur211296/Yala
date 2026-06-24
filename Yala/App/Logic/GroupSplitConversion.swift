//
//  GroupSplitConversion.swift
//  Yala
//
//  Conversión inteligente entre tipos de división (monto / porcentaje / proporción)
//  y cálculo incremental de lo ya asignado. Pure-logic: sin SwiftUI ni SwiftData,
//  testeable directo. El ViewModel hace el parseo/formateo de strings; aquí solo
//  vive la aritmética.
//

import Foundation

enum GroupSplitConversion {

    /// Monto efectivo por participante según el tipo de división de ORIGEN.
    /// `rawValue`: `.exact` = monto; `.percentage` = 0-100; `.shares` = nº de partes;
    /// `.equal` = ignorado (se reparte por igual).
    static func effectiveAmounts(
        splitType: SplitType,
        total: Double,
        participants: [(id: String, rawValue: Double)]
    ) -> [(id: String, amount: Double)] {
        guard !participants.isEmpty, total > 0 else {
            return participants.map { (id: $0.id, amount: 0) }
        }
        switch splitType {
        case .equal:
            let n = Double(participants.count)
            return participants.map { (id: $0.id, amount: total / n) }
        case .exact:
            return participants.map { (id: $0.id, amount: max(0, $0.rawValue)) }
        case .percentage:
            return participants.map { (id: $0.id, amount: total * max(0, $0.rawValue) / 100) }
        case .shares:
            let sum = participants.reduce(0.0) { $0 + max(0, $1.rawValue) }
            guard sum > 0 else { return participants.map { (id: $0.id, amount: 0) } }
            return participants.map { (id: $0.id, amount: total * max(0, $0.rawValue) / sum) }
        }
    }

    /// Monto ya asignado por los valores INGRESADOS (los vacíos se omiten en `enteredValues`),
    /// usado para el "Restante" incremental que baja con cada dato.
    /// `.equal`/`.shares` reparten siempre todo el total → asignado = total (no hay "restante").
    static func assignedAmount(
        splitType: SplitType,
        total: Double,
        enteredValues: [Double]
    ) -> Double {
        switch splitType {
        case .equal, .shares:
            return total
        case .exact:
            return enteredValues.reduce(0, +)
        case .percentage:
            return total * enteredValues.reduce(0, +) / 100
        }
    }

    /// Convierte montos por participante en conteos enteros pequeños de "partes",
    /// simplificando la proporción: 60/40 → 3/2, 50/50 → 1/1, 75/25 → 3/1.
    /// Tolera el ±céntimo del reparto (33.33/33.33/33.34 → 1/1/1) probando el menor
    /// multiplicador que vuelve la proporción ~entera.
    static func deriveCounts(amounts: [(id: String, amount: Double)]) -> [(id: String, count: Int)] {
        let values = amounts.map { max(0, $0.amount) }
        guard let minPos = values.filter({ $0 > 0 }).min(), minPos > 0 else {
            return amounts.map { (id: $0.id, count: 1) }
        }
        let ratios = values.map { $0 / minPos }
        for d in 1...12 {
            let scaled = ratios.map { $0 * Double(d) }
            if scaled.allSatisfy({ abs($0 - $0.rounded()) < 0.05 }) {
                return zip(amounts, scaled).map { (id: $0.0.id, count: max(1, Int($0.1.rounded()))) }
            }
        }
        return zip(amounts, ratios).map { (id: $0.0.id, count: max(1, Int($0.1.rounded()))) }
    }
}
