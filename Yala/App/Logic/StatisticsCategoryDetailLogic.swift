//
//  StatisticsCategoryDetailLogic.swift
//  Yala
//
//  Decisión 25 de la revisión 2.3 (B1, 9-nov): en Distribución, tocar una categoría abre su detalle en vez de filtrar.
//  Aquí se arma lo que enseña ese detalle a partir de lo que Distribución ya calculó, para que las cifras sean las de la
//  fila tocada: mismo período, misma comparación y mismos filtros, sin escribir ninguno.
//

import Foundation
import SwiftData

/// Lo que enseña el detalle de una categoría: lo gastado y su comparación, sus subcategorías y sus últimos registros.
struct StatisticsCategoryDetail {
    let categoryID: PersistentIdentifier
    let name: String
    let colorHex: String
    let iconName: String?
    /// La cifra de la fila tocada (`CategorySpendingSummary.amount`).
    let amount: Double
    /// Su parte del total del período, en porcentaje (0-100), la misma que enseña la fila.
    let percentage: Double
    /// Lo del período anterior; `nil` sin comparación («Todo el tiempo») o sin movimientos entonces.
    let previousAmount: Double?
    /// Subcategorías de esta categoría, de mayor a menor, con su período anterior.
    let subcategories: [SubcategorySpendingSummary]
    /// Los últimos registros que suman en la cifra, del más reciente al más antiguo (como mucho `latestRecordsLimit`).
    let latestRecords: [TransactionItem]
    /// Cuántos registros suman en la cifra.
    let recordCount: Int
}

enum StatisticsCategoryDetailLogic {
    static let latestRecordsLimit = 5

    /// - Parameters:
    ///   - summary: la fila de la categoría tal como la pinta Distribución (cifra, porcentaje y período anterior).
    ///   - current: los movimientos del período con los filtros de la pantalla (lo oculto ya fuera), los de la tarta.
    ///   - previous: lo mismo para el período anterior, ya recortado al tramo equivalente; vacío sin comparación.
    ///   - natures: la naturaleza elegida en Distribución; `nil` es «solo gastos», como en los calculadores.
    static func build(
        summary: CategorySpendingSummary,
        current: [TransactionItem],
        previous: [TransactionItem],
        interval: DateInterval,
        previousInterval: DateInterval?,
        currencyCode: String,
        natures: Set<TransactionNature>?,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> StatisticsCategoryDetail? {
        guard let category = summary.category else { return nil }
        let categoryID = category.persistentModelID

        // Solo los movimientos de la categoría: así el porcentaje de cada subcategoría es sobre la categoría, como lo
        // enseñaba Distribución al filtrarla.
        let inCategory: (TransactionItem) -> Bool = { $0.category?.persistentModelID == categoryID }
        var subcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: current.filter(inCategory),
            interval: interval,
            currencyCode: currencyCode,
            categoryFilter: nil,
            transactionNatures: natures,
            adjustment: adjustment,
            converter: converter
        )
        if let previousInterval, !previous.isEmpty {
            let previousSubcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
                transactions: previous.filter(inCategory),
                interval: previousInterval,
                currencyCode: currencyCode,
                categoryFilter: nil,
                transactionNatures: natures,
                adjustment: adjustment,
                converter: converter
            )
            // Se casan por nombre, como el `id` de la fila: así también la fila «Sin subcategoría» lleva su anterior.
            var previousByName: [String: Double] = [:]
            for item in previousSubcategories { previousByName[item.id] = item.amount }
            for index in subcategories.indices {
                subcategories[index].previousAmount = previousByName[subcategories[index].id]
            }
        }

        let counted = current.filter { counts($0, in: categoryID, interval: interval, natures: natures, adjustment: adjustment) }
        let latest = counted.sorted { $0.date > $1.date }.prefix(latestRecordsLimit)

        return StatisticsCategoryDetail(
            categoryID: categoryID,
            name: summary.name,
            colorHex: summary.colorHex,
            iconName: summary.iconName,
            amount: summary.amount,
            percentage: summary.percentage,
            previousAmount: summary.previousAmount,
            subcategories: subcategories,
            latestRecords: Array(latest),
            recordCount: counted.count
        )
    }

    /// El mismo criterio con que `TopSpendingCategoriesCalculator` suma un movimiento en la categoría: dentro del
    /// período, sin ajustes de saldo ni patas de préstamo de Grupos, y de la naturaleza elegida (la categoría manda y,
    /// sin ella, el signo).
    static func counts(
        _ transaction: TransactionItem,
        in categoryID: PersistentIdentifier,
        interval: DateInterval,
        natures: Set<TransactionNature>?,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Bool {
        guard transaction.category?.persistentModelID == categoryID else { return false }
        guard !adjustment.isSuppressed(transaction) else { return false }
        guard transaction.balanceAdjustmentType == nil else { return false }
        let nature: TransactionNature = TransactionClassificationLogic.isIncome(transaction) ? .income : .expense
        guard (natures ?? [.expense]).contains(nature) else { return false }
        return interval.contains(transaction.date)
    }
}
