//
//  FinancialScoreFewDataAndAlertsTests.swift
//  YalaTests
//
//  Decisión 9 de la revisión 2.3 (Panel, PN-2): la nota de salud daba 99-100 con pocos datos y no veía un presupuesto
//  pasado ni una cuenta en rojo. A: sin nota hasta tener dos de las tres partes, y la tarjeta dice qué falta. B: una
//  línea con lo que la nota no ve, y la hoja deja de decir «¡Vas increíble!» con alertas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct FinancialScoreFewDataAndAlertsTests {

    private let calendar = Calendar.current

    /// Martes 17 de marzo de 2026, 12:00.
    private var now: Date { date(2026, 3, 17) }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func account(_ name: String, type: AccountType = .checking) -> Account {
        Account(name: name, currencyCode: "USD", colorHex: "#000000", iconName: "creditcard", type: type.rawValue)
    }

    private func tx(_ amount: Double, _ date: Date, _ account: Account? = nil) -> TransactionItem {
        let category = YalaCategory(name: amount < 0 ? "Comida" : "Sueldo", colorHex: "#FF0000", isIncome: amount >= 0)
        return TransactionItem(
            date: date, amount: amount, currencyCode: "USD", note: nil, category: category, account: account,
            tags: [], amountInPreferredCurrency: amount, preferredCurrencyCode: "USD"
        )
    }

    private func budget(_ name: String, limit: Double, createdAt: Date) -> Budget {
        let budget = Budget(currencyCode: "USD", limitAmount: limit, name: name, periodType: "monthly")
        budget.createdAt = createdAt
        return budget
    }

    private func payment(nextDueDate: Date) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: "Alquiler", amount: 500, currencyCode: "USD", isRecurring: false, nextDueDate: nextDueDate, isActive: true
        )
        payment.createdAt = date(2026, 1, 1)
        return payment
    }

    private func score(
        transactions: [TransactionItem] = [],
        budgets: [Budget] = [],
        scheduledPayments: [ScheduledPayment] = [],
        accounts: [Account] = [],
        period: DetailPeriod = .thisMonth
    ) -> FinancialScore {
        FinancialScoreCalculator.calculate(
            transactions: transactions, budgets: budgets, scheduledPayments: scheduledPayments, accounts: accounts,
            paidAmounts: [:], period: period, preferredCurrencyCode: "USD", converter: MockCurrencyConverter(),
            now: now, calendar: calendar
        )
    }

    private var threeDays: [TransactionItem] {
        [tx(-10, date(2026, 3, 15)), tx(-10, date(2026, 3, 16)), tx(-10, date(2026, 3, 17))]
    }

    // MARK: - A · dos de tres

    @Test("Una sola parte con datos no da nota (antes, 100)")
    func onePart_noScore() {
        let result = score(transactions: threeDays)
        #expect(result.activity == 100)
        #expect(result.total == nil)
    }

    @Test("Dos partes con datos sí dan nota, con los pesos de siempre")
    func twoParts_score() {
        let result = score(transactions: threeDays, scheduledPayments: [payment(nextDueDate: date(2026, 3, 28))])
        #expect(result.activity == 100)
        #expect(result.bills != nil)
        #expect(result.total != nil)
    }

    @Test("Sin nota, la tarjeta nombra las dos partes que faltan")
    func missingLine_namesTheTwoMissingParts() {
        let line = FinancialScoreCopy.missingLine(for: score(transactions: threeDays))
        #expect(line == L10n.Panel.Health.missingTwoParts(L10n.Panel.Health.subScoreBudget, L10n.Panel.Health.subScoreBills))
    }

    @Test("Sin ninguna parte, la tarjeta dice la regla; con nota, no dice nada")
    func missingLine_withoutPartsAndWithScore() {
        #expect(FinancialScoreCopy.missingLine(for: score()) == L10n.Panel.Health.missingAllParts)
        let scored = FinancialScore(total: 90, budget: 90, activity: 90, bills: nil)
        #expect(FinancialScoreCopy.missingLine(for: scored) == nil)
    }

    @Test("Con datos pero sin nota, la hoja no invita al primer registro")
    func headline_notYetWithSomeData() {
        #expect(FinancialScoreCopy.totalHeadline(for: score(transactions: threeDays), isExpensesOnlyMode: false)
            == L10n.Panel.Health.totalHeadlineNotYet)
        #expect(FinancialScoreCopy.totalHeadline(for: score(), isExpensesOnlyMode: false)
            == L10n.Panel.Health.totalHeadlineEmpty)
    }

    // MARK: - B · lo que la nota no ve

    @Test("Una cuenta en negativo es una alerta que la nota no ve; una tarjeta de crédito en negativo, no")
    func negativeAccount_isUnseen_creditCardIsNot() {
        let cash = account("Efectivo")
        let card = account("Visa", type: .creditCard)
        let bank = account("Banco")
        let txs = [tx(-58, date(2026, 3, 16), cash), tx(-300, date(2026, 3, 16), card), tx(1000, date(2026, 3, 15), bank)]
        let result = score(transactions: txs, accounts: [cash, card, bank])
        #expect(result.alerts.negativeAccounts == ["Efectivo"])
        #expect(result.alerts.unseen(isExpensesOnlyMode: false) == [.negativeAccount("Efectivo")])
        #expect(FinancialScoreCopy.unseenLine(for: result, isExpensesOnlyMode: false)
            == L10n.Panel.Health.unseen(L10n.Panel.Health.unseenNegativeAccount("Efectivo")))
    }

    @Test("Archivadas, excluidas, de Grupos y líneas de tarjeta no cuentan como cuenta en rojo")
    func negativeAccount_skipsAccountsThatDoNotCount() {
        let archived = account("Vieja"); archived.isArchived = true
        let excluded = account("Fuera"); excluded.excludeFromStatistics = true
        let system = account("Grupos USD"); system.isSystemAccount = true
        let line = account("Visa USD"); line.parentAccountID = UUID()
        let all = [archived, excluded, system, line]
        let txs = all.map { tx(-50, date(2026, 3, 16), $0) }
        #expect(score(transactions: txs, accounts: all).alerts.negativeAccounts.isEmpty)
    }

    @Test("En «Solo gastos» las cuentas en negativo no salen: no hay ingresos apuntados")
    func expensesOnly_hidesNegativeAccounts() {
        let cash = account("Efectivo")
        let result = score(transactions: [tx(-58, date(2026, 3, 16), cash)], accounts: [cash])
        #expect(result.alerts.unseen(isExpensesOnlyMode: true).isEmpty)
        #expect(FinancialScoreCopy.unseenLine(for: result, isExpensesOnlyMode: true) == nil)
        #expect(!result.alerts.hasAlerts(isExpensesOnlyMode: true))
    }

    @Test("Un presupuesto pasado creado a mitad de mes no cuenta en la nota y sale en la línea; uno que cuenta, no")
    func overBudget_unseenOnlyWhenNotCounted() {
        let newOne = budget("Comidas fuera", limit: 100, createdAt: date(2026, 3, 10))
        let oldOne = budget("Mercado", limit: 100, createdAt: date(2026, 1, 1))
        let result = score(transactions: [tx(-150, date(2026, 3, 15))], budgets: [newOne, oldOne])
        #expect(result.alerts.overBudgets == [
            .init(name: "Comidas fuera", countedByScore: false),
            .init(name: "Mercado", countedByScore: true)
        ])
        #expect(result.alerts.unseen(isExpensesOnlyMode: false) == [.overBudget("Comidas fuera")])
    }

    @Test("Con alertas, una nota alta no dice «¡Vas increíble!»")
    func headline_highWithAlerts() {
        var high = FinancialScore(total: 99, budget: nil, activity: 100, bills: 99)
        #expect(FinancialScoreCopy.totalHeadline(for: high, isExpensesOnlyMode: false) == L10n.Panel.Health.totalHeadlineHigh)
        high.alerts = FinancialScoreAlerts(overBudgets: [], negativeAccounts: ["Cuenta Principal"])
        #expect(FinancialScoreCopy.totalHeadline(for: high, isExpensesOnlyMode: false)
            == L10n.Panel.Health.totalHeadlineHighWithAlerts)
        // En «Solo gastos» la cuenta en negativo no es alerta.
        #expect(FinancialScoreCopy.totalHeadline(for: high, isExpensesOnlyMode: true) == L10n.Panel.Health.totalHeadlineHigh)
    }

    @Test("Un período que no incluye hoy no trae alertas de hoy")
    func pastPeriod_noAlerts() {
        let cash = account("Efectivo")
        let result = score(transactions: [tx(-58, date(2026, 2, 10), cash)], accounts: [cash], period: .lastMonth)
        #expect(result.alerts == FinancialScoreAlerts())
    }
}
