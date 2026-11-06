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
    /// Cada grafía con sus veces, tal como se escribió. Solo la lee la versión Pro con IA en modo nube.
    var spellings: [String: Int] = [:]
    /// La subcategoría (o categoría) más usada del grupo; `nil` sin ninguna. Ídem.
    var categoryLabel: String? = nil
    /// Cada compra del grupo (fecha e importe en la divisa de la pantalla), de la más reciente a la más antigua. Ídem.
    var purchases: [AntPurchase] = []
}

/// Una compra pequeña suelta: lo que el modo nube deja leer a la IA para precisar.
struct AntPurchase: Equatable {
    let date: Date
    let amount: Double
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
    /// Todas las compras pequeñas del período agrupadas, se repitan o no (las de 1 y 2 veces incluidas): lo que la
    /// versión Pro con IA puede juntar cuando la misma tienda se escribió de dos formas (ticket
    /// `insights-ant-expenses-ai-version-for-pro`). La tarjeta gratis no lo lee.
    var candidates: [AntExpenseGroup] = []
    /// Las mismas compras pequeñas (con el MISMO tope) en el período anterior, para que el consejo diga si algo subió.
    /// Lo rellena `InsightsCalculator`; `nil` sin período anterior.
    var previousCandidates: [AntExpenseGroup]? = nil
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
        let expenses = smallExpenseCandidates(transactions: transactions, amountOf: amountOf, isSuppressed: isSuppressed)

        guard expenses.count >= minExpenses else { return nil }
        let threshold = median(expenses.map(\.amount))

        let all = grouped(expenses.filter { $0.amount <= threshold })
        let groups = all.filter { $0.count >= minOccurrences }

        guard !groups.isEmpty else { return nil }
        let total = groups.reduce(0) { $0 + $1.total }
        let count = groups.reduce(0) { $0 + $1.count }
        let days = max(1, dayCount)
        let monthlyEstimate = days > monthDays ? total / Double(days) * 30 : nil
        return AntExpensesSummary(
            total: total, count: count, groups: groups, threshold: threshold, monthlyEstimate: monthlyEstimate,
            candidates: all)
    }

    /// Las compras pequeñas (hasta `threshold`) de otro conjunto de movimientos, agrupadas con la misma regla y sin
    /// mínimo de repeticiones. Para el período anterior: con el tope del período actual, «pequeño» significa lo mismo
    /// en los dos lados.
    static func smallGroups(
        transactions: [TransactionItem],
        amountOf: (TransactionItem) -> Double,
        isSuppressed: (TransactionItem) -> Bool = { _ in false },
        threshold: Double
    ) -> [AntExpenseGroup] {
        let expenses = smallExpenseCandidates(transactions: transactions, amountOf: amountOf, isSuppressed: isSuppressed)
        return grouped(expenses.filter { $0.amount <= threshold })
    }

    private struct SmallExpense {
        let key: String
        let label: String
        let amount: Double
        let date: Date
        let categoryLabel: String?
    }

    /// Los gastos que pueden ser hormiga, con su grupo. La regla de qué entra está en la cabecera del fichero.
    private static func smallExpenseCandidates(
        transactions: [TransactionItem],
        amountOf: (TransactionItem) -> Double,
        isSuppressed: (TransactionItem) -> Bool
    ) -> [SmallExpense] {
        var expenses: [SmallExpense] = []
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
            expenses.append(SmallExpense(
                key: group.key, label: group.label, amount: amount, date: tx.date,
                categoryLabel: tx.subcategory?.name ?? tx.category?.name))
        }
        return expenses
    }

    /// Agrupa por clave, del que más suma al que menos.
    private static func grouped(_ expenses: [SmallExpense]) -> [AntExpenseGroup] {
        struct Entry {
            var labels: [String: Int] = [:]
            var categories: [String: Int] = [:]
            var purchases: [AntPurchase] = []
            var count = 0
            var total = 0.0
        }
        var byKey: [String: Entry] = [:]
        for expense in expenses {
            var entry = byKey[expense.key] ?? Entry()
            entry.labels[expense.label, default: 0] += 1
            if let category = expense.categoryLabel { entry.categories[category, default: 0] += 1 }
            entry.purchases.append(AntPurchase(date: expense.date, amount: expense.amount))
            entry.count += 1
            entry.total += expense.amount
            byKey[expense.key] = entry
        }

        return byKey
            .map { key, value in
                return AntExpenseGroup(
                    key: key, label: mostUsed(value.labels) ?? key, count: value.count, total: value.total,
                    spellings: value.labels, categoryLabel: mostUsed(value.categories),
                    purchases: value.purchases.sorted { $0.date > $1.date })
            }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.key < rhs.key
            }
    }

    /// El valor más repetido; a igualdad, el primero en orden alfabético (estable).
    private static func mostUsed(_ counts: [String: Int]) -> String? {
        counts.max { lhs, rhs in lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key }?.key
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
