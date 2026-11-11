//
//  MonthEndBalanceLogic.swift
//  Yala
//
//  «Al 30 de noviembre tendrías» (decisión 30 de la revisión 2.3, opción A, 9-nov-2026): una sola cifra para «¿llego a
//  fin de mes?», la misma en el Panel («Ver proyectado» con Saldo y «Este mes») y en el mes en curso del flujo de caja,
//  con su cuenta debajo: lo que tienes hoy, lo que falta entrar y lo que falta salir.
//
//  No es otro cálculo: es la cuenta del Panel. Las mismas cuentas que su cifra grande sin filtro de cuentas
//  (`PanelBalanceScopeLogic`, con el interruptor de Grupos), el mismo saldo vivo (`LiveBalanceCalculator`) y el mismo
//  `ProjectedFlowBuilder` hasta el último día del mes, sin filtros de sesión. Si el Panel cambia de cuenta, esta pieza
//  cambia con él: lo fija `MonthEndBalanceParityTests`.
//

import Foundation
import SwiftData

@MainActor
enum MonthEndBalanceLogic {

    struct Result: Equatable {
        /// «Tienes hoy»: el saldo vivo de las cuentas que suma el Panel.
        let today: Double
        /// Lo que falta entrar y salir de mañana a fin de mes, cada lado con su signo (una devolución resta).
        let incomeLeft: Double
        let expenseLeft: Double
        /// Último día del mes, a medianoche: el «30 de noviembre» del rótulo.
        let endDate: Date
        /// Alguna cifra salió de una tasa aproximada («≈»): el saldo de hoy o lo que falta.
        let isApproximate: Bool
        /// De dónde sale lo estimado («Estimado con tu plan…»).
        let source: ProjectedFlowCalculator.Source

        /// «Al 30 de noviembre tendrías»: hoy + lo que falta entrar − lo que falta salir.
        var closing: Double { today + incomeLeft - expenseLeft }
    }

    /// La cuenta del mes de `now`. `nil` sin cuentas que sumen: entonces no hay «Tienes hoy» del que partir.
    static func compute(
        accounts: [Account],
        transactions: [TransactionItem],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        includeGroups: Bool,
        adjustment: GroupBridgeStatsAdjustment,
        converter: any CurrencyConverting,
        context: ModelContext?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Result? {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return nil }
        // Las cuentas de la cifra grande del Panel sin filtro de cuentas (`PanelViewModel.computeEligibleAccounts` +
        // `PanelBalanceScopeLogic.accounts`).
        let eligible = accounts.filter { !$0.excludeFromStatistics }
        let balanceAccounts = PanelBalanceScopeLogic.accounts(
            eligible: eligible, includeGroups: includeGroups, selectedAccountIDs: []
        )
        guard !balanceAccounts.isEmpty else { return nil }
        let balanceTransactions = PanelBalanceScopeLogic.transactions(
            transactions, accountIDs: Set(balanceAccounts.map(\.persistentModelID))
        )
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: balanceAccounts,
            transactions: balanceTransactions,
            preferredCurrencyCode: currencyCode,
            asOf: now,
            converter: converter
        )
        let today = (breakdown.convertedTotal as NSDecimalNumber).doubleValue

        // El mes entero, como `ProjectedFlowCalculator.horizon(for: .thisMonth, …)`: hasta su último segundo.
        let horizon = DateInterval(start: month.start, end: month.end.addingTimeInterval(-1))
        let days = ProjectedFlowCalculator.futureDays(in: horizon, today: now, calendar: calendar)
        let endDate = calendar.startOfDay(for: horizon.end)

        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: now,
                calendar: calendar,
                overdueWindowStart: ProjectedFlowBuilder.overdueWindowStart(today: now, calendar: calendar),
                days: days,
                allTransactions: transactions,
                countedTransactions: balanceTransactions,
                hasSessionFilters: false,
                scheduledPayments: scheduledPayments,
                paymentFilter: ProjectedFlowBuilder.PaymentFilter(
                    accounts: EntityFilter(included: Set(balanceAccounts.map(\.persistentModelID)))
                ),
                currencyCode: currencyCode,
                adjustment: adjustment,
                converter: converter
            ),
            context: context
        )
        var incomeLeft = 0.0
        var expenseLeft = 0.0
        for day in days {
            guard let flow = built.flows[day] else { continue }
            incomeLeft += flow.income
            expenseLeft += flow.expense
        }
        return Result(
            today: today,
            incomeLeft: incomeLeft,
            expenseLeft: expenseLeft,
            endDate: endDate,
            isApproximate: breakdown.amountsAreApproximate || built.isApproximate,
            source: built.source(for: .balance)
        )
    }

    // MARK: - Rótulos

    /// «30 de noviembre»: día y mes en la forma de dentro de una frase; con año si no es el de `now`.
    static func dayAndMonth(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale? = nil
    ) -> String {
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = locale ?? AppLocale.current
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(sameYear ? "dMMMM" : "dMMMMy")
        return formatter.string(from: date)
    }

    /// El rótulo de la cifra al final de lo proyectado, en el Panel y Tendencias: «Al 30 de noviembre tendrías» con
    /// Saldo, «Gastos al 30 de noviembre» e «Ingresos al 30 de noviembre» con los otros dos. Sustituye a «Proyectado al
    /// cierre», que no decía de qué era la cifra ni hasta cuándo.
    static func closingLabel(metric: TrendType, endDate: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let day = dayAndMonth(endDate, now: now, calendar: calendar)
        switch metric {
        case .balance: return L10n.ProjectedFlow.closingBalance(day)
        case .expense: return L10n.ProjectedFlow.closingExpense(day)
        case .income: return L10n.ProjectedFlow.closingIncome(day)
        }
    }
}
