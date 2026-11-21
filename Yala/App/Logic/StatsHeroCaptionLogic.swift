//
//  StatsHeroCaptionLogic.swift
//  Yala
//
//  Pure-logic helper para el rótulo que dice QUÉ es la cifra del hero en las
//  cuatro pestañas de Estadísticas. Devuelve un enum; el texto se resuelve aparte
//  para permitir tests deterministas sin Bundle lookup.
//
//  Desde el 20-nov-2026 (decisión de Jürgen, «hero limpio») la cifra de siempre es «Tu dinero hoy», la misma del
//  Panel (`StatsMoneyTodayLogic`), en las cuatro pestañas. Antes Distribución enseñaba el saldo de todas las cuentas y
//  las otras tres ingresos − gastos del período («Te queda»): Jürgen, «te queda es un tercer número que realmente no
//  existe; confunde al usuario».
//
//  **El rótulo sigue sin ser fijo por pestaña**: hay estados en que la cifra es de un solo lado.
//
//  - Distribución con un filtro de categoría, en «Solo gastos» o con un chip de naturaleza enseña el flujo de lo que
//    pinta la tarta (gasto, ingreso, o los dos sumados).
//  - Tendencias sigue a la métrica: Ingresos o Gastos son un lado; Saldo es «Tu dinero hoy».
//  - Registros con un chip de naturaleza enseña ese lado.
//  - «Solo gastos», en todas, el gasto del período.
//
//  Un rótulo que miente es peor que ningún rótulo, así que se deriva del mismo
//  estado que elige el número.
//

import Foundation

/// Qué magnitud está enseñando el hero. El texto se resuelve en la vista.
enum StatsHeroCaption: String, Equatable, CaseIterable {
    /// Stock: «Tu dinero hoy», la misma cifra que el Panel (`StatsMoneyTodayLogic`). «Tu dinero al cierre» con un
    /// período cerrado.
    case moneyToday
    /// Flujo: solo el lado de ingresos.
    case incomePeriod
    /// Flujo: solo el lado de gastos.
    case expensePeriod
    /// Flujo: magnitudes de ingresos Y gastos sumadas (el pie usa `abs`), que no
    /// es un neto ni un solo lado. Alcanzable en Distribución con los dos chips
    /// marcados y un filtro dimensional activo.
    case totalPeriod
}

enum StatsHeroCaptionLogic {

    /// Distribución (`CategoriesTabView`).
    ///
    /// - Parameters:
    ///   - isBalanceMode: la regla derivada en la vista (sin filtro dimensional,
    ///     sin modo solo-gastos, y chips vacíos o los dos).
    ///   - natures: `viewModel.selectedTransactionNatures` tal cual. Vacío
    ///     significa GASTOS, no "todo": `TopSpendingCategoriesCalculator` aplica
    ///     `transactionNatures ?? [.expense]`.
    static func distribution(isBalanceMode: Bool, natures: Set<TransactionNature>) -> StatsHeroCaption {
        if isBalanceMode { return .moneyToday }
        // Espeja el default del calculator: sin chips, el pie es de gastos.
        let effective: Set<TransactionNature> = natures.isEmpty ? [.expense] : natures
        if effective == [.expense] { return .expensePeriod }
        if effective == [.income] { return .incomePeriod }
        return .totalPeriod
    }

    /// Tendencias (`TrendsTabView.heroKPIValue`): el hero sigue a la métrica.
    static func trends(metric: TrendMetric) -> StatsHeroCaption {
        switch metric {
        case .balance: return .moneyToday
        case .income:  return .incomePeriod
        case .expense: return .expensePeriod
        }
    }

    /// Resumen: «Tu dinero hoy».
    static let insights: StatsHeroCaption = .moneyToday

    /// En modo «Solo gastos» Resumen y Registros enseñan el gasto del período, como el Panel (decisión A de Jürgen
    /// del 2026-10-26).
    static func insights(expensesOnly: Bool) -> StatsHeroCaption {
        expensesOnly ? .expensePeriod : insights
    }

    /// Registros: «Tu dinero hoy», o el lado que deja un chip de naturaleza.
    ///
    /// - Parameter natures: las naturalezas EFECTIVAS. `FilterService` solo filtra
    ///   por naturaleza cuando hay exactamente una seleccionada, así que vacío o
    ///   las dos no son un lado.
    static func records(natures: Set<TransactionNature>) -> StatsHeroCaption {
        if natures == [.income]  { return .incomePeriod }
        if natures == [.expense] { return .expensePeriod }
        return .moneyToday
    }

    static func records(natures: Set<TransactionNature>, expensesOnly: Bool) -> StatsHeroCaption {
        expensesOnly ? .expensePeriod : records(natures: natures)
    }
}

// MARK: - Localización

/// El texto vive aquí y no en cada vista porque las cuatro pestañas comparten los
/// mismos casos: repetir el `switch` cuatro veces es justo como divergen.
/// La lógica de arriba sigue siendo pura — los tests comparan casos del enum, no
/// strings, así que no necesitan Bundle.
///
/// «Tu dinero hoy» es el rótulo del Panel, y con un período cerrado «Tu dinero al cierre» (`PeriodTenseLogic`). Por
/// eso el texto pide el tiempo y no hay un `text` a secas: un llamador nuevo no puede olvidarse de él.
extension StatsHeroCaption {
    func text(isClosed: Bool) -> String {
        switch self {
        case .moneyToday:
            return isClosed ? HeroEstadisticasText.moneyAtClose : L10n.SaldoPanel.moneyToday
        case .incomePeriod:    return L10n.Stats.Hero.captionIncomePeriod
        case .expensePeriod:   return L10n.Stats.Hero.captionExpensePeriod
        case .totalPeriod:     return L10n.Stats.Hero.captionTotalPeriod
        }
    }
}
