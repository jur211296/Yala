//
//  L10n+HeroClaro.swift
//  Yala
//
//  El hero claro de Estadísticas, Registros y Flujo de caja (2026-11-16): el «?» junto al rótulo y la hoja que explica la
//  cifra. Los rótulos de las cifras siguen siendo los de `StatsHeroCaption` y `CashFlowMonthSummaryLogic`; aquí solo va lo
//  nuevo de la ayuda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func heroClaroString(_ key: String) -> String {
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
    enum HeroClaro {
        /// VoiceOver del «?» junto al rótulo.
        static var infoButton: String { heroClaroString("heroClaro.infoButton") }
        static var notCountedTitle: String { heroClaroString("heroClaro.notCountedTitle") }
        static var notCountedBody: String { heroClaroString("heroClaro.notCountedBody") }
        static var filtersNote: String { heroClaroString("heroClaro.filtersNote") }
        static var incomeBody: String { heroClaroString("heroClaro.incomeBody") }
        static var expenseBody: String { heroClaroString("heroClaro.expenseBody") }

        enum Net {
            static var title: String { heroClaroString("heroClaro.net.title") }
            static var body: String { heroClaroString("heroClaro.net.body") }
            static var notBalance: String { heroClaroString("heroClaro.net.notBalance") }
        }

        enum Expense {
            static var title: String { heroClaroString("heroClaro.expense.title") }
            static var body: String { heroClaroString("heroClaro.expense.body") }
        }

        enum Income {
            static var title: String { heroClaroString("heroClaro.income.title") }
            static var body: String { heroClaroString("heroClaro.income.body") }
        }

        enum Total {
            static var title: String { heroClaroString("heroClaro.total.title") }
            static var body: String { heroClaroString("heroClaro.total.body") }
        }

        enum Balance {
            static var title: String { heroClaroString("heroClaro.balance.title") }
            static var body: String { heroClaroString("heroClaro.balance.body") }
            static var closedNote: String { heroClaroString("heroClaro.balance.closedNote") }
        }

        enum CashFlowEnd {
            static var title: String { heroClaroString("heroClaro.cashFlowEnd.title") }
            static var body: String { heroClaroString("heroClaro.cashFlowEnd.body") }
            static var netNote: String { heroClaroString("heroClaro.cashFlowEnd.netNote") }
        }

        enum CashFlowMonth {
            static var title: String { heroClaroString("heroClaro.cashFlowMonth.title") }
            static var body: String { heroClaroString("heroClaro.cashFlowMonth.body") }
        }

        static var cashFlowProjectedNote: String { heroClaroString("heroClaro.cashFlow.projectedNote") }

        enum Example {
            static var shortfall: String { heroClaroString("heroClaro.example.shortfall") }
            static var total: String { heroClaroString("heroClaro.example.total") }
            static var monthEnd: String { heroClaroString("heroClaro.example.monthEnd") }
            static var refund: String { heroClaroString("heroClaro.example.refund") }
            static var salary: String { heroClaroString("heroClaro.example.salary") }
            static var sale: String { heroClaroString("heroClaro.example.sale") }
        }
    }
}
