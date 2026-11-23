//
//  PieTotalApproximateMark.swift
//  Yala
//
//  La marca «≈» del TOTAL de una tarta de Distribución (categorías, subcategorías, etiquetas).
//
//  Ticket `pie-header-total-unmarked` (2026-11-23): «Análisis del gasto» enseñaba sin marca el mismo número que el
//  Panel, Resumen y Registros marcaban como aproximado. Las calculadoras de las tartas suman importes ya convertidos y
//  tiran la calidad por el camino, así que la marca se mide aquí aparte, sobre LAS MISMAS transacciones, con el mismo
//  criterio de entrada y el mismo reparto en trozos que la calculadora de cada tarta. Las tajadas y las filas del
//  desglose siguen sin marca (`fx-category-totals-unmarked`): la incertidumbre puede estar entera en otra categoría.
//

import Foundation
import SwiftData

enum PieTotalApproximateMark {

    /// En qué trozo cae un movimiento: así se forma el total que pinta la tarta.
    enum Slices {
        /// Por categoría; «Sin categoría» con un trozo por lado (`TopSpendingCategoriesCalculator`).
        case categories
        /// Por subcategoría, «sin subcategoría» por categoría y «Sin categoría» por lado (`TopSubcategoriesCalculator`).
        case subcategories
        /// Por etiqueta: cada movimiento suma su magnitud una vez por etiqueta (`TagSpendingCalculator`).
        case tags
    }

    /// La clave de un trozo: la misma partición que la calculadora. «Sin categoría» va por lado: su fila suma la
    /// magnitud de cada lado, y un ingreso y un gasto sin categoría no se restan entre sí.
    private enum SliceKey: Hashable {
        case uncategorized(isIncome: Bool)
        case category(PersistentIdentifier)
        case subcategory(PersistentIdentifier)
        case noSubcategory(category: PersistentIdentifier)
    }

    /// ¿Lleva «≈» el total de la tarta?
    ///
    /// El numerador suma MAGNITUDES dudosas (`ApproximateMarkThreshold`: dos errores no se cancelan). El denominador es
    /// el número que se pinta: en categorías y subcategorías, `Σ|neto de cada trozo|`, porque un reembolso resta dentro
    /// de su trozo; con la suma de magnitudes de cada movimiento, un gasto y su devolución inflaban el denominador y la
    /// marca se perdía (lo cazó el revisor con checklist del 2026-11-23). En etiquetas, la suma de magnitudes por
    /// etiqueta, que es lo que suma su calculadora.
    ///
    /// - Parameters:
    ///   - transactions: las que recibe la calculadora de la tarta (ya con los filtros de la pantalla).
    ///   - natures: las de la calculadora (`nil` = solo gastos).
    ///   - includes: el filtro propio de la calculadora (la categoría de la tarta de subcategorías).
    static func marks(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        natures: Set<TransactionNature>?,
        slices: Slices,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting = CurrencyConverter.shared,
        includes: (TransactionItem) -> Bool = { _ in true }
    ) -> Bool {
        let naturesToInclude = natures ?? [.expense]
        var approximate = 0.0
        var signedBySlice: [SliceKey: Double] = [:]
        var tagTotal = 0.0
        for tx in transactions {
            // El criterio de entrada de `TopSpendingCategoriesCalculator`, `TopSubcategoriesCalculator` y
            // `TagSpendingCalculator`, que es el mismo en las tres.
            guard !adjustment.isSuppressed(tx), tx.balanceAdjustmentType == nil else { continue }
            let isIncome = TransactionClassificationLogic.isIncome(tx)
            let nature: TransactionNature = isIncome ? .income : .expense
            guard naturesToInclude.contains(nature), interval.contains(tx.date), includes(tx) else { continue }
            let resolved = CashFlowCalculator.resolvedAmount(
                tx, currencyCode: currencyCode, adjustment: adjustment, converter: converter
            )
            switch slices {
            case .tags:
                let times = Double((tx.resolvedTagIDs(scheduleBackfill: false) ?? []).count)
                guard times > 0 else { continue }
                approximate += resolved.approximateMagnitude * times
                tagTotal += abs(resolved.value) * times
            case .categories, .subcategories:
                approximate += resolved.approximateMagnitude
                signedBySlice[sliceKey(tx, slices: slices, isIncome: isIncome), default: 0] += resolved.value
            }
        }
        let total = slices == .tags ? tagTotal : signedBySlice.values.reduce(0) { $0 + abs($1) }
        return ApproximateMarkThreshold.marks(approximate: approximate, total: total)
    }

    private static func sliceKey(_ tx: TransactionItem, slices: Slices, isIncome: Bool) -> SliceKey {
        guard let category = tx.category else { return .uncategorized(isIncome: isIncome) }
        guard slices == .subcategories else { return .category(category.persistentModelID) }
        if let sub = tx.subcategory { return .subcategory(sub.persistentModelID) }
        return .noSubcategory(category: category.persistentModelID)
    }
}
