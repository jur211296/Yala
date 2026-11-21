//
//  StatsMoneyTodayLogic.swift
//  Yala
//
//  «Tu dinero hoy» en el hero de Estadísticas (decisión de Jürgen del 20-nov-2026): la MISMA cifra que la línea chica del
//  hero del Panel, con las mismas piezas y en el mismo orden. Antes cada pestaña enseñaba otra cosa en ese hueco —el
//  saldo de todas las cuentas en Distribución, ingresos − gastos («Te queda») en las otras tres— y la persona veía un
//  tercer número que no existe en ningún otro sitio.
//
//  Las piezas, como en el Panel:
//  1. Las cuentas del saldo grande: `PanelTotalAccountsLogic.accountsForTotal` (el interruptor de Grupos) y
//     `LiveBalanceCalculator.liveBalanceBreakdown` con los filtros de cuenta de la sesión
//     (`PanelViewModel.displayedBalanceInDefaultCurrency`).
//  2. De esas, las que cuentan como dinero para usar: `PanelMoneyScopeLogic.moneyBreakdown` con la preferencia
//     `panelMoneyAccountOverrides` (`PanelHeroSection.computeMoney`).
//  Si el Panel cambia una de las dos, esta cifra cambia con él. Lo fija `HeroEstadisticasLimpioTests`.
//
//  Con un período cerrado la cifra es la del cierre («Tu dinero al cierre»): el mismo cálculo con el corte en el último
//  día del período, al tipo de cambio de hoy, como la cifra viva.
//

import Foundation
import SwiftData

enum StatsMoneyTodayLogic {

    struct Figure: Equatable {
        let value: Double
        let isApproximate: Bool
    }

    /// El día hasta el que se cuenta: hoy, o el último instante de un período que ya terminó.
    static func asOf(isClosed: Bool, interval: DateInterval?, now: Date = .now) -> Date {
        guard isClosed, let interval else { return now }
        return min(interval.end, now)
    }

    /// La marca «≈» de una cifra de un solo lado que la pantalla calcula por otro camino (la suma de la tarta de
    /// Distribución): la de la flecha de ese lado, solo si las dos dicen el mismo importe. Con importes distintos
    /// (devoluciones, «Sin categoría», un filtro) la proporción de la flecha no es la de lo mostrado y no se presta.
    static func sideMark(caption: StatsHeroCaption, shown: Double, flow: StatsHeroFlow?) -> Bool {
        guard let flow else { return false }
        switch caption {
        case .expensePeriod:
            return abs(abs(shown) - abs(flow.expense)) < 0.005 && flow.expenseIsApproximate
        case .incomePeriod:
            return abs(abs(shown) - abs(flow.income)) < 0.005 && flow.incomeIsApproximate
        case .moneyToday, .totalPeriod:
            return false
        }
    }

    static func figure(
        accounts: [Account],
        transactions: [TransactionItem],
        currencyCode: String,
        includeGroups: Bool,
        selectedAccountIDs: Set<PersistentIdentifier>,
        excludedAccountIDs: Set<PersistentIdentifier>,
        overrides: String,
        asOf now: Date = .now,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> Figure {
        let totalAccounts = PanelTotalAccountsLogic.accountsForTotal(
            accounts,
            includeGroups: includeGroups,
            hasSelectedAccount: PanelTotalAccountsLogic.hasAccountFilter(selectedAccountIDs: selectedAccountIDs)
        )
        let total = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: totalAccounts,
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            selectedAccountIDs: selectedAccountIDs,
            excludedAccountIDs: excludedAccountIDs,
            asOf: now,
            converter: converter
        )
        let money = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts,
            totalAccountIDs: total.eligibleAccountIDs,
            overrides: PanelMoneyScopeLogic.decode(overrides),
            transactions: transactions,
            preferredCurrencyCode: currencyCode,
            asOf: now,
            converter: converter
        )
        return Figure(
            value: (money.convertedTotal as NSDecimalNumber).doubleValue,
            isApproximate: money.amountsAreApproximate
        )
    }
}
