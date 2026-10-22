//
//  StatsHeroCaptionLogic.swift
//  Yala
//
//  Pure-logic helper para el rótulo que dice QUÉ es la cifra del hero en las
//  cuatro pestañas de Estadísticas. Devuelve un enum; la localización vive en el
//  callsite UI (igual que `DistributionInsightLogic`), para permitir tests
//  deterministas sin Bundle lookup.
//
//  Por qué existe: las cuatro pestañas comparten el mismo hueco visual y se
//  deslizan entre sí, pero desde `distribution-balance-kpi-skips-fx` (2026-09-06)
//  Distribución puede enseñar un SALDO (stock) donde las otras tres enseñan un
//  NETO del período (flujo). Sin rótulo, el mismo sitio significaba dos cosas.
//
//  **El rótulo NO puede ser fijo por pestaña**, y esa es la trampa de este
//  fichero: medido el 2026-09-07, ninguna de las cuatro cifras es siempre la
//  misma magnitud.
//
//  - Distribución solo muestra saldo en `isBalanceMode`. Fuera de él —filtro de
//    categoría, modo solo-gastos, un chip de naturaleza— vuelve al flujo del
//    período, que es una decisión explícita del owner del 2026-08-26
//    ("Ingresos/Gastos siguen siendo flujo"). Un rótulo fijo "Saldo de cuentas"
//    mentiría en todos esos estados.
//  - Tendencias pinta uno de TRES números según `selectedMetric`
//    (`TrendsTabView.heroKPIValue`), no solo el neto.
//  - Registros acumula `income - expense` sobre lo YA filtrado: con un chip de
//    naturaleza activo el otro lado es 0 y la cifra deja de ser un neto.
//
//  Un rótulo que miente es peor que ningún rótulo, así que se deriva del mismo
//  estado que elige el número.
//

import Foundation

/// Qué magnitud está enseñando el hero. El texto se resuelve en la vista.
enum StatsHeroCaption: String, Equatable, CaseIterable {
    /// Stock: saldo de las cuentas, misma semántica que el KPI del Panel.
    case accountsBalance
    /// Flujo: ingresos − gastos del período.
    case netPeriod
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
        if isBalanceMode { return .accountsBalance }
        // Espeja el default del calculator: sin chips, el pie es de gastos.
        let effective: Set<TransactionNature> = natures.isEmpty ? [.expense] : natures
        if effective == [.expense] { return .expensePeriod }
        if effective == [.income] { return .incomePeriod }
        return .totalPeriod
    }

    /// Tendencias (`TrendsTabView.heroKPIValue`): el hero sigue a la métrica.
    static func trends(metric: TrendMetric) -> StatsHeroCaption {
        switch metric {
        case .balance: return .netPeriod
        case .income:  return .incomePeriod
        case .expense: return .expensePeriod
        }
    }

    /// Insights (`InsightsTabView.heroSummary`): siempre `summary.netBalance`.
    /// El hero no se pinta en modo solo-gastos, así que no hay caso de un lado.
    static let insights: StatsHeroCaption = .netPeriod

    /// Registros (`RecordsViewModel.recordsSummary.balance` = `income - expense`
    /// sobre lo ya filtrado).
    ///
    /// - Parameter natures: las naturalezas EFECTIVAS. `FilterService` solo filtra
    ///   por naturaleza cuando hay exactamente una seleccionada, así que vacío o
    ///   las dos dejan la cifra como un neto de verdad.
    static func records(natures: Set<TransactionNature>) -> StatsHeroCaption {
        if natures == [.income]  { return .incomePeriod }
        if natures == [.expense] { return .expensePeriod }
        return .netPeriod
    }
}

// MARK: - Localización

/// El texto vive aquí y no en cada vista porque las cuatro pestañas comparten los
/// mismos cinco casos: repetir el `switch` cuatro veces es justo como divergen.
/// La lógica de arriba sigue siendo pura — los tests comparan casos del enum, no
/// strings, así que no necesitan Bundle.
extension StatsHeroCaption {
    var text: String {
        switch self {
        case .accountsBalance: return L10n.Stats.Hero.captionAccountsBalance
        case .netPeriod:       return L10n.Stats.Hero.captionNetPeriod
        case .incomePeriod:    return L10n.Stats.Hero.captionIncomePeriod
        case .expensePeriod:   return L10n.Stats.Hero.captionExpensePeriod
        case .totalPeriod:     return L10n.Stats.Hero.captionTotalPeriod
        }
    }
}
