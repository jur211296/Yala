//
//  L10n+UXAudit22Lote18Decididas.swift
//  Yala
//
//  Textos de la implementación de la auditoría UX 2.2, lote 18 decidido (Reportes: Comparativa y Flujo de caja). Van en
//  su propio fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func l18(_ key: String) -> String {
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
    enum UXL18 {

        // MARK: - Comparativa sin período anterior (L18-2)

        static var allTimeCardTitle: String { l18("report.l18.allTime.title") }

        // MARK: - La tabla de la Comparativa (L18-3)

        /// «Octubre comparado con setiembre».
        static func heading(_ current: String, _ previous: String) -> String {
            String(format: l18("report.l18.heading"), current, previous)
        }
        /// «Octubre comparado con el 1–21 de septiembre» (el tramo es de días, no un mes entero).
        static func headingRange(_ current: String, _ range: String) -> String {
            String(format: l18("report.l18.headingRange"), current, range)
        }
        static var chipPreviousMonth: String { l18("report.l18.chip.previousMonth") }
        static var chipPreviousWeek: String { l18("report.l18.chip.previousWeek") }
        static var chipPrevious7Days: String { l18("report.l18.chip.previous7Days") }
        static var chipPrevious30Days: String { l18("report.l18.chip.previous30Days") }
        static var chipPreviousPeriod: String { l18("report.l18.chip.previousPeriod") }
        /// «Con octubre de 2025».
        static func chipYearAgo(_ period: String) -> String { String(format: l18("report.l18.chip.yearAgo"), period) }
        static var columnChange: String { l18("report.l18.column.change") }
        /// «en 1–21 sept» (bajo cada monto, antes del monto anterior).
        static func inPeriod(_ period: String) -> String { String(format: l18("report.l18.inPeriod"), period) }
        static var netGain: String { l18("report.l18.net.gain") }
        static var netLoss: String { l18("report.l18.net.loss") }
        static var netCaption: String { l18("report.l18.net.caption") }
        /// «Ingresos menos gastos. En setiembre te quedaron S/ 5,617.»
        static func netCaptionGainBefore(_ period: String, _ amount: String) -> String {
            String(format: l18("report.l18.net.captionGainBefore"), period, amount)
        }
        static func netCaptionLossBefore(_ period: String, _ amount: String) -> String {
            String(format: l18("report.l18.net.captionLossBefore"), period, amount)
        }
        /// Lo que VoiceOver lee por fila: «S/ 12,666 en octubre, S/ 9,976 en setiembre».
        static func rowAmountsA11y(_ current: String, _ currentPeriod: String, _ previous: String, _ previousPeriod: String) -> String {
            String(format: l18("report.l18.row.amountsA11y"), current, currentPeriod, previous, previousPeriod)
        }

        // MARK: - El desglose (L18-4)

        static var exampleTitle: String { l18("report.l18.example.title") }
        static var exampleIncomeAndExpenses: String { l18("report.l18.example.expenses") }
        static var exampleCategory: String { l18("report.l18.example.category") }
        static var exampleSubcategory: String { l18("report.l18.example.subcategory") }
        static var exampleTag: String { l18("report.l18.example.tag") }
        static var exampleAccount: String { l18("report.l18.example.account") }
        static var exampleCurrency: String { l18("report.l18.example.currency") }
        static var exampleNeed: String { l18("report.l18.example.need") }
        static var onlyIncomeAndExpenses: String { l18("report.l18.onlyIncomeAndExpenses") }

        // MARK: - Crear el plan y el saldo inicial (L18-5, L18-10)

        static var startTitle: String { l18("cashflow.l18.start.title") }
        static var startCaptionOne: String { l18("cashflow.l18.start.captionOne") }
        /// «Lo que tienes hoy en tus 2 cuentas».
        static func startCaption(_ count: Int) -> String {
            String(format: l18("cashflow.l18.start.caption"), count)
        }
        static var startCaptionNone: String { l18("cashflow.l18.start.captionNone") }
        static var startCaptionTyped: String { l18("cashflow.l18.start.captionTyped") }
        static var startChange: String { l18("cashflow.l18.start.change") }
        static var sectionIn: String { l18("cashflow.l18.section.in") }
        static var sectionOut: String { l18("cashflow.l18.section.out") }
        /// «Gastos que cambian · 22».
        static func variableTitle(_ count: Int) -> String {
            String(format: l18("cashflow.l18.variable.title"), count)
        }
        /// «Restaurantes, taxis, compras… Los sumamos como un promedio.»
        static func variableCaption(_ examples: String) -> String {
            String(format: l18("cashflow.l18.variable.caption"), examples)
        }
        static var variableShow: String { l18("cashflow.l18.variable.show") }
        static var variableHide: String { l18("cashflow.l18.variable.hide") }
        static var summaryIncome: String { l18("cashflow.l18.summary.income") }
        static var summaryExpense: String { l18("cashflow.l18.summary.expense") }
        static var summarySurplus: String { l18("cashflow.l18.summary.surplus") }
        static var summaryShortfall: String { l18("cashflow.l18.summary.shortfall") }
        /// «Hoy tienes S/ 83,666 en tus cuentas».
        static func todayBalance(_ amount: String) -> String {
            String(format: l18("cashflow.l18.sheet.todayBalance"), amount)
        }
        static var useThisAmount: String { l18("cashflow.l18.sheet.useThisAmount") }
        /// «Empezaste con S/ 0».
        static func startedWith(_ amount: String) -> String {
            String(format: l18("cashflow.l18.startedWith"), amount)
        }
        static var change: String { l18("cashflow.l18.change") }

        // MARK: - Detalle de una línea (L18-7, L18-8, L18-9)

        static var howItsCalculated: String { l18("cashflow.l18.detail.howItsCalculated") }
        /// «Desde noviembre: S/ 9,000 cada mes».
        static func changeFrom(_ month: String, _ amount: String) -> String {
            String(format: l18("cashflow.l18.detail.changeFrom"), month, amount)
        }
        /// «Monto para noviembre».
        static func amountFor(_ month: String) -> String {
            String(format: l18("cashflow.l18.detail.amountFor"), month)
        }
        /// «¿Solo noviembre, o noviembre y los siguientes?»
        static func scopeQuestion(_ month: String) -> String {
            String(format: l18("cashflow.l18.scope.question"), month, month)
        }
        static var scopeOnlyThatMonth: String { l18("cashflow.l18.scope.onlyThatMonth") }
        static var scopeAlsoFollowing: String { l18("cashflow.l18.scope.alsoFollowing") }

        // MARK: - La tira de meses y el resumen (L18-11)

        static var surplusThisMonth: String { l18("cashflow.l18.hero.surplusThisMonth") }
        static var shortfallThisMonth: String { l18("cashflow.l18.hero.shortfallThisMonth") }
        static func surplusFuture(_ month: String) -> String { String(format: l18("cashflow.l18.hero.surplusFuture"), month) }
        static func shortfallFuture(_ month: String) -> String { String(format: l18("cashflow.l18.hero.shortfallFuture"), month) }
        static func surplusPast(_ month: String) -> String { String(format: l18("cashflow.l18.hero.surplusPast"), month) }
        static func shortfallPast(_ month: String) -> String { String(format: l18("cashflow.l18.hero.shortfallPast"), month) }
        /// «Si sigue así, a fin de diciembre tendrías S/ 12,028».
        static func projectedEnd(_ month: String, _ amount: String) -> String {
            String(format: l18("cashflow.l18.hero.projectedEnd"), month, amount)
        }
        /// «Llevas el 68 % de lo que planeaste gastar».
        static func spentShare(_ percent: Int) -> String {
            String(format: l18("cashflow.l18.month.spentShare"), percent)
        }
        static var toReceive: String { l18("cashflow.l18.row.toReceive") }
        static var receivedExtra: String { l18("cashflow.l18.row.receivedExtra") }
        /// «Desde noviembre» (subtítulo de una línea con un cambio «desde este mes»).
        static func fromMonth(_ month: String) -> String { String(format: l18("cashflow.l18.row.fromMonth"), month) }

        // MARK: - Gráficas (L18-12)

        /// «De agosto de 2026 a febrero de 2027».
        static func periodRange(_ from: String, _ to: String) -> String {
            String(format: l18("cashflow.l18.chart.periodRange"), from, to)
        }
        /// «Saldo a fin de febrero».
        static func projectionKPI(_ month: String) -> String {
            String(format: l18("cashflow.l18.chart.projectionKPI"), month)
        }
        /// «Promedio de 3 meses · De agosto a octubre».
        static func savingsKPI(_ months: Int, _ range: String) -> String {
            String(format: l18("cashflow.l18.chart.savingsKPI"), months, range)
        }
        /// «Promedio por mes, de agosto a octubre. Por eso no coincide con el detalle de un mes.»
        static func deviationPeriod(_ range: String) -> String {
            String(format: l18("cashflow.l18.chart.deviationPeriod"), range)
        }
        /// «S/ 158 de S/ 136 al mes».
        static func deviationLine(_ actual: String, _ planned: String) -> String {
            String(format: l18("cashflow.l18.chart.deviationLine"), actual, planned)
        }

        // MARK: - Agregar línea (L18-13)

        static var fromHistoryExpenseExample: String { l18("cashflow.l18.add.historyExpense") }
        static var fromHistoryIncomeExample: String { l18("cashflow.l18.add.historyIncome") }
        static var fromScheduledExpenseExample: String { l18("cashflow.l18.add.scheduledExpense") }
        static var fromScheduledIncomeExample: String { l18("cashflow.l18.add.scheduledIncome") }
        static var customExample: String { l18("cashflow.l18.add.custom") }
        /// «S/ 10,900 en 6 meses».
        static func inSixMonths(_ amount: String) -> String { String(format: l18("cashflow.l18.add.inSixMonths"), amount) }
    }
}
