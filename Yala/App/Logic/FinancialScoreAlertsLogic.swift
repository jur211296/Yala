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

    /// Presupuestos activos cuyo período en curso ya se pasó del límite, por nombre. La nota ya los cuenta: desde el
    /// 22-nov-2026 un presupuesto cuenta desde el período en que se creó (`FinancialScoreCalculator.bucketIsValid`).
    var overBudgets: [String] = []
    /// Cuentas con saldo negativo, por nombre. Sin tarjetas de crédito: ahí el negativo es lo que debes, no un rojo.
    var negativeAccounts: [String] = []

    /// Lo que va mal y la nota no ve: las cuentas en negativo. Un presupuesto pasado ya no sale aquí, porque la nota
    /// lo cuenta. En «Solo gastos» no hay saldos que valgan (no se apuntan ingresos) y las cuentas no salen.
    func unseen(isExpensesOnlyMode: Bool) -> [Unseen] {
        isExpensesOnlyMode ? [] : negativeAccounts.map(Unseen.negativeAccount)
    }

    /// Hay algo que mirar: con eso la hoja no felicita aunque la nota sea alta.
    func hasAlerts(isExpensesOnlyMode: Bool) -> Bool {
        !overBudgets.isEmpty || (!isExpensesOnlyMode && !negativeAccounts.isEmpty)
    }

    enum Unseen: Equatable {
        case negativeAccount(String)
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
        converter: CurrencyConverting,
        movimientosEn: ((DateInterval) -> [TransactionItem])? = nil
    ) -> FinancialScoreAlerts {
        guard periodInterval.contains(now) else { return FinancialScoreAlerts() }
        return FinancialScoreAlerts(
            overBudgets: overBudgets(
                transactions: transactions, budgets: budgets, now: now, calendar: calendar,
                adjustment: adjustment, converter: converter, movimientosEn: movimientosEn
            ),
            negativeAccounts: negativeAccounts(
                accounts: accounts, transactions: transactions, now: now, converter: converter
            )
        )
    }

    /// Lo gastado con la cuenta de Planificación (`BudgetsViewModel.calculateSpending`) en el período EN CURSO de cada
    /// presupuesto (`BudgetPeriodInterval.current`), y «pasado» con la regla de la fila (`BudgetRemainingLogic.isOver`).
    ///
    /// `movimientosEn` (lote 4 de eficiencia) da los movimientos de un intervalo sin recorrer los 16 mil por presupuesto
    /// (`IndiceFechasMovimientos`, en el orden original): `calculateSpending` filtra igual por dentro, así que la cifra es
    /// la misma.
    static func overBudgets(
        transactions: [TransactionItem],
        budgets: [Budget],
        now: Date,
        calendar: Calendar,
        adjustment: GroupBridgeStatsAdjustment,
        converter: CurrencyConverting,
        movimientosEn: ((DateInterval) -> [TransactionItem])? = nil
    ) -> [String] {
        budgets
            .filter { $0.isActive && $0.limitAmount > 0 }
            .compactMap { budget -> String? in
                let current = BudgetPeriodInterval.current(for: budget, now: now, calendar: calendar)
                guard current.contains(now) else { return nil }
                let spent = BudgetsViewModel.calculateSpending(
                    budget: budget, transactions: movimientosEn?(current) ?? transactions, interval: current,
                    adjustment: adjustment, converter: converter
                )
                guard BudgetRemainingLogic.isOver(limit: budget.limitAmount, spent: spent) else { return nil }
                return budget.name
            }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// El saldo de hoy de cada cuenta, el de su tarjeta en el carrusel (`AccountBalanceCalculator`). Fuera: tarjetas de
    /// crédito y sus líneas (el negativo es la deuda), cuentas de Grupos y las que no suman en un saldo
    /// (`Account.sumsInBalance`: excluidas de las estadísticas o archivadas, decisión 6 de 2.3).
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
        account.sumsInBalance
            && !account.isSystemAccount
            && account.parentAccountID == nil
            && AccountType(rawValue: account.type) != .creditCard
    }
}
