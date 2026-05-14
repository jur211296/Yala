//
//  DistributionInsightLogic.swift
//  Yala
//
//  Pure-logic helper para el hallazgo principal del Distribution Insight Card.
//  Devuelve un enum con el caso correspondiente; la localización vive en el
//  callsite UI (CategoriesTabView.findingText). Sin dependencias de L10n para
//  permitir tests deterministas sin Bundle lookup.
//
//  V1 cubre 6 reglas en cascada por prioridad. V2 podría añadir TREND
//  SOSTENIDO o múltiples categorías nuevas — requiere historicalTotals[N].
//

import Foundation

struct DistributionCategoryInput: Equatable {
    let name: String
    let amount: Double
    let percentage: Double           // escala 0-100 (matches CategorySpendingSummary.percentage)
    let previousAmount: Double?
    let variation: Double?
}

struct DistributionTopSubInput: Equatable {
    let name: String
    let parent: String
    let percentageOfCategory: Double // escala 0-100
}

enum DistributionInsightFinding: Equatable {
    case onset
    case newCategory(name: String, period: String)
    case shifted(percent: Int, category: String, direction: Direction, previousLabel: String)
    case concentrated(percent: Int, topCategory: String)
    case topSubFallback(percent: Int, sub: String, parent: String)
    case balanced(maxPercent: Int)

    enum Direction: Equatable { case up, down }
}

enum DistributionInsightLogic {
    /// Decide hallazgo según prioridad:
    ///   1. ONSET → categories vacías o todas amount==0.
    ///   2. NEW_CATEGORY → existe categoría con previousAmount==nil && amount>0
    ///      (orden: la de mayor amount). Skip si previousLabel == nil
    ///      (`.allTime` no tiene previous válido).
    ///   3. SHIFTED → top1.variation absoluta >= 20% Y previousLabel disponible.
    ///   4. CONCENTRATED → top1.percentage >= 40.
    ///   5. TOP_SUB_FALLBACK → top1.percentage < 40 Y topSub.percentageOfCategory >= 30.
    ///   6. BALANCED → fallback con maxPercent del top1.
    static func finding(
        categories: [DistributionCategoryInput],
        topSub: DistributionTopSubInput?,
        previousLabel: String?,
        period: String
    ) -> DistributionInsightFinding {
        let active = categories.filter { $0.amount > 0 }
        guard !active.isEmpty, let top = active.first else { return .onset }

        // Rule 2: NEW_CATEGORY (skip si .allTime — no hay previous válido)
        if previousLabel != nil,
           let firstNew = active.first(where: { $0.previousAmount == nil }) {
            return .newCategory(name: firstNew.name, period: period)
        }

        // Rule 3: SHIFTED
        if let variation = top.variation,
           abs(variation) >= 20,
           let prev = previousLabel {
            let percent = Int(abs(variation).rounded())
            let direction: DistributionInsightFinding.Direction = variation > 0 ? .up : .down
            return .shifted(percent: percent, category: top.name, direction: direction, previousLabel: prev)
        }

        // Rule 4: CONCENTRATED
        if top.percentage >= 40 {
            return .concentrated(percent: Int(top.percentage.rounded()), topCategory: top.name)
        }

        // Rule 5: TOP_SUB_FALLBACK
        if let sub = topSub, sub.percentageOfCategory >= 30 {
            return .topSubFallback(percent: Int(sub.percentageOfCategory.rounded()), sub: sub.name, parent: sub.parent)
        }

        // Rule 6: BALANCED fallback
        return .balanced(maxPercent: Int(top.percentage.rounded()))
    }
}
