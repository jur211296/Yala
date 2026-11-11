//
//  FinancialScoreAlertsLogic.swift
//  Yala
//
//  Decisión 9 de la revisión 2.3 (Panel, PN-2 · B): la nota de salud daba 99 y «¡Vas increíble!» con un presupuesto
//  pasado y una cuenta en −S/ 53,738.91 a la vista. La nota no cambia de fórmula; la tarjeta dice lo que va mal y ella
//  no ve, y el mensaje deja de felicitar con alertas. Aquí se decide qué es una alerta; los textos son de la vista.
//

import Foundation
import SwiftData

/// Lo que va mal HOY, para la nota de salud.
struct FinancialScoreAlerts: Equatable {

    struct OverBudget: Equatable {
        let name: String
        /// La nota ya lo cuenta: su período en curso entra en la parte de Presupuestos y la baja. Uno creado a mitad
        /// de período no cuenta hasta el siguiente (`FinancialScoreCalculator.bucketIsValid`).
        let countedByScore: Bool
    }

    /// Presupuestos activos cuyo período en curso ya se pasó del límite, por nombre.
    var overBudgets: [OverBudget] = []
    /// Cuentas con saldo negativo, por nombre. Sin tarjetas de crédito: ahí el negativo es lo que debes, no un rojo.
    var negativeAccounts: [String] = []

    /// Lo que va mal y la nota no ve, en el orden de la línea: cuentas en negativo y presupuestos pasados que aún no
    /// cuentan. En «Solo gastos» no hay saldos que valgan (no se apuntan ingresos) y las cuentas no salen.
    func unseen(isExpensesOnlyMode: Bool) -> [Unseen] {
        let accounts = isExpensesOnlyMode ? [] : negativeAccounts.map(Unseen.negativeAccount)
        let budgets = overBudgets.filter { !$0.countedByScore }.map { Unseen.overBudget($0.name) }
        return accounts + budgets
    }

    /// Hay algo que mirar: con eso la hoja no felicita aunque la nota sea alta.
    func hasAlerts(isExpensesOnlyMode: Bool) -> Bool {
        !overBudgets.isEmpty || (!isExpensesOnlyMode && !negativeAccounts.isEmpty)
    }

    enum Unseen: Equatable {
        case negativeAccount(String)
        case overBudget(String)
    }
}

enum FinancialScoreAlertsLogic {

    /// Las alertas de hoy. Vacías si el período de la nota no incluye hoy: una alerta de hoy bajo «Mes pasado» hablaría
    /// de otra cosa que la nota.
    static func alerts(
        transactions: [TransactionItem],
        budgets: [Budget],
        accounts: [Account],
        periodInterval: DateInterval,
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting
    ) -> FinancialScoreAlerts {
        guard periodInterval.contains(now) else { return FinancialScoreAlerts() }
        return FinancialScoreAlerts(
            overBudgets: overBudgets(
                transactions: transactions, budgets: budgets, now: now, calendar: calendar,
                adjustment: adjustment, converter: converter
            ),
            negativeAccounts: negativeAccounts(
                accounts: accounts, transactions: transactions, now: now, converter: converter
            )
        )
    }

    /// Lo gastado con la cuenta de Planificación (`BudgetsViewModel.calculateSpending`) en el período EN CURSO de cada
    /// presupuesto (`BudgetPeriodInterval.current`), y «pasado» con la regla de la fila (`BudgetRemainingLogic.isOver`).
    static func overBudgets(
        transactions: [TransactionItem],
        budgets: [Budget],
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting
    ) -> [FinancialScoreAlerts.OverBudget] {
        budgets
            .filter { $0.isActive && $0.limitAmount > 0 }
            .compactMap { budget -> FinancialScoreAlerts.OverBudget? in
                let current = BudgetPeriodInterval.current(for: budget, now: now, calendar: calendar)
                guard current.contains(now) else { return nil }
                let spent = BudgetsViewModel.calculateSpending(
                    budget: budget, transactions: transactions, interval: current,
                    adjustment: adjustment, converter: converter
                )
                guard BudgetRemainingLogic.isOver(limit: budget.limitAmount, spent: spent) else { return nil }
                return FinancialScoreAlerts.OverBudget(
                    name: budget.name,
                    countedByScore: FinancialScoreCalculator.bucketIsValid(current, for: budget, calendar: calendar)
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// El saldo de hoy de cada cuenta, el de su tarjeta en el carrusel (`AccountBalanceCalculator`). Fuera: tarjetas de
    /// crédito y sus líneas (el negativo es la deuda), cuentas de Grupos, archivadas y excluidas de las estadísticas.
    static func negativeAccounts(
        accounts: [Account],
        transactions: [TransactionItem],
        now: Date,
        converter: CurrencyConverting
    ) -> [String] {
        let watched = accounts.filter { isWatched($0) }
        guard !watched.isEmpty else { return [] }
        let balances = AccountBalanceCalculator.batchCalculateBalances(
            accounts: watched, transactions: transactions, asOf: now, converter: converter
        )
        return watched
            .filter { account in
                let value = ((balances[account.persistentModelID] ?? 0) as NSDecimalNumber).doubleValue
                return value < 0 && !CurrencyFormattingHelper.isShownAsZero(value)
            }
            .map(\.name)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func isWatched(_ account: Account) -> Bool {
        !account.isArchived
            && !account.excludeFromStatistics
            && !account.isSystemAccount
            && account.parentAccountID == nil
            && AccountType(rawValue: account.type) != .creditCard
    }
}
