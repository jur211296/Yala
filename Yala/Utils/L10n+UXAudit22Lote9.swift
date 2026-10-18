//
//  L10n+UXAudit22Lote9.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 9 (presupuestos). Van en su propio fichero para no pisar `L10n.swift` con los
//  otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l9(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum UXL9 {

        // MARK: - Lo que queda (L9-1, L9-6, L9-10)

        static var remainingLabel: String { l9("budgets.l9.remainingLabel") }
        static var overLabel: String { l9("budgets.l9.overLabel") }

        /// «S/ 1,408.00 de S/ 1,800.00»
        static func spentOfLimit(_ spent: String, _ limit: String) -> String {
            String(format: l9("budgets.l9.spentOfLimit"), spent, limit)
        }

        /// «18 días», «1 día»; -1 = «Cerrado»; 0 = «Aún no empieza».
        static func shortDays(_ days: Int) -> String {
            switch days {
            case ..<0: return l9("budgets.period.past")
            case 0: return l9("budgets.l9.notStarted")
            case 1: return l9("budgets.l9.days.one")
            default: return String(format: l9("budgets.l9.days"), "\(days)")
            }
        }

        /// «Puedes gastar S/ 22.00 al día»
        static func perDay(_ amount: String) -> String {
            String(format: l9("budgets.l9.perDay"), amount)
        }

        static var countsAllExpenses: String { l9("budgets.l9.countsAllExpenses") }

        // MARK: - Editor (L9-2, L9-3, L9-4, L9-12, L9-13)

        static var limitLabel: String { l9("budgets.l9.limitLabel") }
        static var whatCountsTitle: String { l9("budgets.l9.whatCountsTitle") }
        static var allExpensesChip: String { l9("budgets.l9.allExpensesChip") }
        static var chooseCategories: String { l9("budgets.l9.chooseCategories") }
        static var whatCountsAllHint: String { l9("budgets.l9.whatCountsAllHint") }
        static var whatCountsSomeHint: String { l9("budgets.l9.whatCountsSomeHint") }

        static func typeHint(_ type: BudgetPeriodType) -> String {
            switch type {
            case .weekly: return l9("budgets.l9.typeHint.weekly")
            case .monthly: return l9("budgets.l9.typeHint.monthly")
            case .yearly: return l9("budgets.l9.typeHint.yearly")
            case .unique: return l9("budgets.l9.typeHint.unique")
            }
        }

        static var alertsOffHint: String { l9("budgets.l9.alertsOffHint") }
        static var activateAlerts: String { l9("budgets.l9.activateAlerts") }
        static var alertsOffInNotifications: String { l9("budgets.l9.alertsOffInNotifications") }

        static var showInWidget: String { l9("budgets.l9.showInWidget") }
        static var showInWidgetHint: String { l9("budgets.l9.showInWidgetHint") }
        static var hideFromWidget: String { l9("budgets.l9.hideFromWidget") }

        // MARK: - Borrar (L9-14)

        static func deleteTitle(_ name: String) -> String {
            String(format: l9("budgets.l9.deleteTitle"), name)
        }

        // MARK: - Gráficas (L9-7)

        static func historyTitle(_ type: BudgetPeriodType?) -> String {
            switch type {
            case .weekly: return l9("budgets.l9.historyTitle.weekly")
            case .yearly: return l9("budgets.l9.historyTitle.yearly")
            default: return l9("budgets.l9.historyTitle.monthly")
            }
        }

        /// «Límite 2K»
        static func limitShort(_ amount: String) -> String {
            String(format: l9("budgets.l9.limitShort"), amount)
        }

        // MARK: - Plan gratis (L9-9)

        static func freePlanBanner(_ limit: Int) -> String {
            String(format: l9("budgets.l9.freePlanBanner"), limit)
        }

        static func freePlanSheet(_ limit: Int) -> String {
            String(format: l9("budgets.l9.freePlanSheet"), limit)
        }

        static var seePro: String { l9("budgets.l9.seePro") }

        // MARK: - Panel y widget (L9-10, L9-11)

        static var chooseWhich: String { l9("budgets.l9.chooseWhich") }
        static var previewEmpty: String { l9("budgets.l9.previewEmpty") }
    }
}
