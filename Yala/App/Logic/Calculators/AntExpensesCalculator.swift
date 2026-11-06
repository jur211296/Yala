//
//  AntExpensesCalculator.swift
//  Yala
//
//  «Gastos hormiga»: compras pequeñas que se repiten y que, sumadas, pesan. Card 2.3
//  `tablero-detectar-gastos-hormiga-y-decir-cuanto-s-ea78`.
//
//  La regla, sin IA y la misma para Free y Pro:
//  - Entra un GASTO real del período: no ingresos (`TransactionClassificationLogic.isIncome`), no ajustes de saldo
//    ni transferencias (`balanceAdjustmentType`), no devoluciones (importe positivo en una categoría de gasto), no
//    pagos planificados (una suscripción no es un gasto hormiga: ya tiene su tarjeta) y no las patas suprimidas de
//    Grupos.
//  - «Pequeño» es relativo a la persona: hasta la MEDIANA de sus gastos del período. Un umbral fijo no sirve en
//    54 divisas, y la mediana se enseña en la tarjeta para que la regla se entienda.
//  - Se agrupa por descripción normalizada (`MerchantCanonicalizer`); sin descripción, por subcategoría. Sin
//    ninguna de las dos no hay nada que nombrar y el gasto no entra.
//  - Un grupo es «hormiga» si se repite `minOccurrences` veces o más en el período.
//

import Foundation

struct AntExpenseGroup: Equatable {
    /// La clave normalizada del grupo (estable entre recálculos).
    let key: String
    /// Lo que se enseña: la descripción tal como la escribió la persona más veces, o la subcategoría.
    let label: String
    let count: Int
    let total: Double
}

struct AntExpensesSummary: Equatable {
    /// Suma de todos los grupos hormiga del período, en la divisa de la pantalla.
    let total: Double
    /// Cuántas compras suman ese total.
    let count: Int
    /// Los grupos, del que más suma al que menos.
    let groups: [AntExpenseGroup]
    /// El importe máximo que contó como pequeño (la mediana del período).
    let threshold: Double
    /// El total llevado a un mes de 30 días cuando el período es más largo que un mes; `nil` si el período ya es
    /// de un mes o menos (ahí el total del período ES el del mes).
    let monthlyEstimate: Double?
}

enum AntExpensesCalculator {

    /// Veces que una compra tiene que repetirse en el período para contar como hormiga.
    static let minOccurrences = 3
    /// Gastos mínimos en el período para que la mediana signifique algo.
    static let minExpenses = 6
    /// Por encima de estos días, el total del período se acompaña de su equivalente mensual.
    static let monthDays = 31

    /// - Parameters:
    ///   - transactions: los movimientos YA filtrados al período y a la sesión.
    ///   - amountOf: la magnitud en la divisa de la pantalla (la parte propia en un gasto de grupo).
    ///   - isSuppressed: las patas de Grupos que la pantalla no cuenta.
    ///   - dayCount: los días sobre los que se reparte el período (el mismo denominador del promedio diario).
    static func calculate(
        transactions: [TransactionItem],
        amountOf: (TransactionItem) -> Double,
        isSuppressed: (TransactionItem) -> Bool = { _ in false },
        dayCount: Int
    ) -> AntExpensesSummary? {
        var expenses: [(key: String, label: String, amount: Double)] = []
        for tx in transactions {
            guard !isSuppressed(tx) else { continue }
            guard !TransactionClassificationLogic.isIncome(tx) else { continue }
            guard tx.balanceAdjustmentType == nil else { continue }
            guard tx.scheduledPaymentID == nil else { continue }
            // Una devolución en una categoría de gasto no es una compra.
            guard tx.amount < 0 else { continue }
            guard let group = groupKey(for: tx) else { continue }
            let amount = abs(amountOf(tx))
            guard amount > 0 else { continue }
            expenses.append((group.key, group.label, amount))
        }

        guard expenses.count >= minExpenses else { return nil }
        let threshold = median(expenses.map(\.amount))

        var byKey: [String: (labels: [String: Int], count: Int, total: Double)] = [:]
        for expense in expenses where expense.amount <= threshold {
            var entry = byKey[expense.key] ?? ([:], 0, 0)
            entry.labels[expense.label, default: 0] += 1
            entry.count += 1
            entry.total += expense.amount
            byKey[expense.key] = entry
        }

        let groups = byKey
            .filter { $0.value.count >= minOccurrences }
            .map { key, value in
                // La grafía más usada; a igualdad, la primera en orden alfabético (estable).
                let label = value.labels.max { lhs, rhs in
                    lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
                }?.key ?? key
                return AntExpenseGroup(key: key, label: label, count: value.count, total: value.total)
            }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.key < rhs.key
            }

        guard !groups.isEmpty else { return nil }
        let total = groups.reduce(0) { $0 + $1.total }
        let count = groups.reduce(0) { $0 + $1.count }
        let days = max(1, dayCount)
        let monthlyEstimate = days > monthDays ? total / Double(days) * 30 : nil
        return AntExpensesSummary(
            total: total, count: count, groups: groups, threshold: threshold, monthlyEstimate: monthlyEstimate)
    }

    /// La descripción normalizada, o la subcategoría si no hay descripción. `nil` si no hay ninguna.
    static func groupKey(for tx: TransactionItem) -> (key: String, label: String)? {
        if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            let key = MerchantCanonicalizer.canonicalize(note)
            if !key.isEmpty { return ("note:" + key, note) }
        }
        if let subcategory = tx.subcategory {
            return ("sub:" + subcategory.name.uppercased(), subcategory.name)
        }
        return nil
    }

    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
