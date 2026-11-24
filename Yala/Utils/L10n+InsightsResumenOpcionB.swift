//
//  L10n+InsightsResumenOpcionB.swift
//  Yala
//
//  Estadísticas › Resumen, opción B · Decidir (Jürgen, 23-nov-2026): la franja de salud, «Para decidir hoy», los
//  gastos hormiga protagonistas, la fila «Ir a» y la cápsula de Registros por comercio. En su propia tabla
//  (`InsightsResumenOpcionB.strings`), leída con el idioma de la app como `HeroEstadisticasText`.
//

import Foundation

enum ResumenOpcionBText {
    static let table = "InsightsResumenOpcionB"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "resumenB.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    private static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: string(key), locale: AppLocale.current, arguments: args)
    }

    /// «30 nov.»: el día que cierra un período, corto y en el idioma de la app.
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.current))
    }

    /// La franja de salud financiera.
    enum Health {
        /// «Lo que más la baja: Presupuestos».
        static func lowering(_ part: String) -> String { format("health.lowering", part) }
        static var openHint: String { string("health.openHint") }
    }

    /// «Para decidir hoy».
    enum Decide {
        static var title: String { string("decide.title") }
        /// «Restaurantes va al 92 %».
        static func budgetAtRiskTitle(_ name: String, percent: String) -> String {
            format("decide.budgetAtRisk.title", name, percent)
        }
        /// «Te quedan S/ 40.00 · S/ 5.00 al día hasta el 30 nov.»
        static func budgetPerDay(remaining: String, perDay: String, until: String) -> String {
            format("decide.budgetAtRisk.perDay", remaining, perDay, until)
        }
        /// «Ya usaste todo el tope · hasta el 30 nov.»
        static func budgetSpent(until: String) -> String { format("decide.budgetAtRisk.spent", until) }
        /// «Te pasaste en Taxi».
        static func budgetOverTitle(_ name: String) -> String { format("decide.budgetOver.title", name) }
        /// «Por S/ 20.00 · el período cierra el 30 nov.»
        static func budgetOverDetail(amount: String, until: String) -> String {
            format("decide.budgetOver.detail", amount, until)
        }
        /// «Te falta pagar S/ 420.00».
        static func toPayTitle(_ amount: String) -> String { format("decide.toPay.title", amount) }
        /// «Pendientes: 5 · hasta el 30 nov.»
        static func toPayDetail(count: Int, until: String) -> String { format("decide.toPay.detail", count, until) }
        /// «Pendientes: 5».
        static func toPayCount(_ count: Int) -> String { format("decide.toPay.count", count) }
        /// «Gastas 8 % más por día».
        static func spendingUpTitle(_ percent: String) -> String { format("decide.spendingUp.title", percent) }
        /// «S/ 210.00 al día · mira en qué subió».
        static func spendingUpDetail(_ daily: String) -> String { format("decide.spendingUp.detail", daily) }
        static var openBudgetsHint: String { string("decide.hint.budgets") }
        static var openPaymentsHint: String { string("decide.hint.payments") }
        static var openTrendsHint: String { string("decide.hint.trends") }
    }

    /// Gastos hormiga, el bloque protagonista.
    enum Ant {
        /// «24 compras» (siempre 3 o más: la regla pide repetirse 3 veces).
        static func purchases(_ count: Int) -> String { format("ant.purchases", count) }
        /// «En compras de hasta S/ 18.00 que repites».
        static func caption(threshold: String) -> String { format("ant.caption", threshold) }
        /// «A este ritmo cierras el mes en S/ 410.00».
        static func closesMonth(_ amount: String) -> String { format("ant.pace.closesMonth", amount) }
        /// «A este ritmo, unos S/ 300.00 al mes».
        static func perMonth(_ amount: String) -> String { format("ant.pace.perMonth", amount) }
        /// «Yala IA juntó nombres de la misma tienda».
        static var aiMerged: String { string("ant.ai.merged") }
        static var seePurchases: String { string("ant.seePurchases") }
        static var setCap: String { string("ant.setCap") }
        static var rowHint: String { string("ant.rowHint") }
    }

    /// «Tus cifras» y «Lo que más pesa».
    enum Figures {
        /// «Lo que más pesa: Hogar 38 %».
        static func weight(_ name: String, percent: String) -> String { format("figures.weight", name, percent) }
    }

    /// La fila de accesos.
    enum GoTo {
        static var title: String { string("goTo.title") }
    }

    /// La cápsula de Registros filtrados por comercio.
    enum Records {
        /// «Solo Starbucks».
        static func only(_ label: String) -> String { format("records.only", label) }
        /// «Quitar el filtro de Starbucks».
        static func clear(_ label: String) -> String { format("records.clear", label) }
    }
}
