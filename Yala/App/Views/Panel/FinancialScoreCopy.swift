//
//  FinancialScoreCopy.swift
//  Yala
//
//  Los textos de la nota de salud que dependen de la nota (decisión 9 de la revisión 2.3, PN-2): qué falta para tener
//  nota, lo que la nota no ve y el titular de la hoja. Los comparten la tarjeta (Panel y Estadísticas › Resumen) y su
//  hoja, para que digan lo mismo.
//

import Foundation

enum FinancialScoreCopy {

    /// Sin nota: qué falta para tenerla. `nil` si hay nota.
    static func missingLine(for score: FinancialScore) -> String? {
        guard score.total == nil else { return nil }
        let missing = score.partsWithoutData
        // Sin nota quedan dos o tres partes sin datos (con dos con datos ya hay nota).
        guard missing.count == 2 else { return L10n.Panel.Health.missingAllParts }
        return L10n.Panel.Health.missingTwoParts(partName(missing[0]), partName(missing[1]))
    }

    /// Lo que va mal y la nota no ve, en una línea. `nil` si no hay nada.
    static func unseenLine(for score: FinancialScore, isExpensesOnlyMode: Bool) -> String? {
        let items = score.alerts.unseen(isExpensesOnlyMode: isExpensesOnlyMode).map { item in
            switch item {
            case .negativeAccount(let name): return L10n.Panel.Health.unseenNegativeAccount(name)
            case .overBudget(let name): return L10n.Panel.Health.unseenOverBudget(name)
            }
        }
        guard !items.isEmpty else { return nil }
        return L10n.Panel.Health.unseen(items.joined(separator: " · "))
    }

    /// El titular de la hoja de la nota. Con alertas no felicita aunque la nota sea alta, y con datos pero sin nota no
    /// invita a hacer el primer registro.
    static func totalHeadline(for score: FinancialScore, isExpensesOnlyMode: Bool) -> String {
        guard let total = score.total else {
            return score.partsWithoutData.count < 3
                ? L10n.Panel.Health.totalHeadlineNotYet
                : L10n.Panel.Health.totalHeadlineEmpty
        }
        if total >= 90 {
            return score.alerts.hasAlerts(isExpensesOnlyMode: isExpensesOnlyMode)
                ? L10n.Panel.Health.totalHeadlineHighWithAlerts
                : L10n.Panel.Health.totalHeadlineHigh
        }
        if total >= 70 { return L10n.Panel.Health.totalHeadlineMid }
        return L10n.Panel.Health.totalHeadlineLow
    }

    /// El mensaje breve de la tarjeta del Panel (lote 1 de la nota de salud, 11-nov-2026): siempre positivo o neutro y
    /// con un paso concreto, nunca «vas mal». Sin nota, qué hacer para tenerla (la parte más fácil de completar
    /// primero); con nota, la parte que más la sube (`weakestPart`); si todas van bien, «vas bien», salvo que haya algo
    /// que la nota no ve (decisión 9: con alertas no felicita).
    static func cardMessage(for score: FinancialScore, isExpensesOnlyMode: Bool = false) -> String {
        guard score.total != nil else {
            let missing = Set(score.partsWithoutData)
            if missing.contains(.activity) { return L10n.Panel.Health.cardStartActivity }
            if missing.contains(.budget) { return L10n.Panel.Health.cardStartBudget }
            return L10n.Panel.Health.cardStartBills
        }
        switch FinancialScoreCalculator.weakestPart(of: score) {
        case .activity: return L10n.Panel.Health.cardStepActivity
        case .budget: return L10n.Panel.Health.cardStepBudget
        case .bills: return L10n.Panel.Health.cardStepBills
        case .total, nil:
            return score.alerts.hasAlerts(isExpensesOnlyMode: isExpensesOnlyMode)
                ? L10n.Panel.Health.totalHeadlineHighWithAlerts
                : L10n.Panel.Health.cardStepGood
        }
    }

    static func partName(_ kind: FinancialScoreDetailKind) -> String {
        switch kind {
        case .budget: return L10n.Panel.Health.subScoreBudget
        case .activity: return L10n.Panel.Health.subScoreActivity
        case .bills: return L10n.Panel.Health.subScoreBills
        case .total: return L10n.Panel.Health.cardTitle
        }
    }
}
