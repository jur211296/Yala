//
//  HeroBucketsCalculatorTests.swift
//  YalaTests
//
//  Unit tests for HeroBucketsCalculator — produce los 6 valores que consume
//  el Hero del Panel (mes, mes anterior, período) en una sola pasada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct HeroBucketsCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeAccount(name: String = "Main") -> Account {
        Account(
            name: name,
            currencyCode: "USD",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank"
        )
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date,
        account: Account?,
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    /// Mes calendario abril 2026.
    private var aprilInterval: DateInterval {
        DateInterval(start: date(2026, 4, 1), end: date(2026, 5, 1))
    }

    /// Mes calendario marzo 2026.
    private var marchInterval: DateInterval {
        DateInterval(start: date(2026, 3, 1), end: date(2026, 4, 1))
    }

    /// Última semana de abril (período distinto del mes).
    private var lastWeekInterval: DateInterval {
        DateInterval(start: date(2026, 4, 23), end: date(2026, 4, 30))
    }

    // MARK: - Empty / no-op

    @Test func calculate_emptyTransactions_returnsZeroBuckets() {
        let result = HeroBucketsCalculator.calculate(
            transactions: [],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: []
        )

        #expect(result.monthIncome == 0)
        #expect(result.monthExpense == 0)
        #expect(result.prevExpense == 0)
        #expect(result.prevHasAnyTx == false)
        #expect(result.periodIncome == 0)
        #expect(result.periodExpense == 0)
    }

    // MARK: - Filtro de cuenta — núcleo del bug p20-12

    /// Caso central: las transacciones de cuentas NO elegibles (excluidas
    /// de estadísticas o no seleccionadas) NO deben sumar en NINGÚN bucket.
    @Test func calculate_excludesAllBucketsForIneligibleAccounts() {
        let kept = makeAccount(name: "Kept")
        let excluded = makeAccount(name: "Excluded")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            // Mes actual (abril): kept gasta 100, excluded gasta 999.
            makeTransaction(amount: -100, date: date(2026, 4, 5), account: kept, category: food),
            makeTransaction(amount: -999, date: date(2026, 4, 5), account: excluded, category: food),
            // Mes anterior (marzo): kept gasta 200, excluded gasta 888.
            makeTransaction(amount: -200, date: date(2026, 3, 10), account: kept, category: food),
            makeTransaction(amount: -888, date: date(2026, 3, 10), account: excluded, category: food),
            // Última semana (abril 25): kept gasta 50, excluded gasta 700.
            makeTransaction(amount: -50, date: date(2026, 4, 25), account: kept, category: food),
            makeTransaction(amount: -700, date: date(2026, 4, 25), account: excluded, category: food),
            // Ingresos abril: kept 1000, excluded 5000.
            makeTransaction(amount: 1000, date: date(2026, 4, 1), account: kept, category: salary),
            makeTransaction(amount: 5000, date: date(2026, 4, 1), account: excluded, category: salary),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            eligibleAccountIDs: [kept.persistentModelID]
        )

        // Mes (kept): 100 (food del 5) + 50 (food del 25) = 150 expense, 1000 income.
        #expect(result.monthIncome == 1000)
        #expect(result.monthExpense == 150)
        // Mes anterior (kept): 200 expense.
        #expect(result.prevExpense == 200)
        #expect(result.prevHasAnyTx == true)
        // Período = última semana abril (kept): solo el del 25 = 50 expense.
        #expect(result.periodIncome == 0)
        #expect(result.periodExpense == 50)
    }

    /// Sin filtro de cuenta (todas elegibles): suma agregado total.
    @Test func calculate_allAccountsEligible_sumsAllBuckets() {
        let a = makeAccount(name: "A")
        let b = makeAccount(name: "B")
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            makeTransaction(amount: 1500, date: date(2026, 4, 1), account: a, category: salary),
            makeTransaction(amount: -300, date: date(2026, 4, 10), account: b, category: food),
            makeTransaction(amount: -250, date: date(2026, 3, 5), account: a, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [a.persistentModelID, b.persistentModelID]
        )

        #expect(result.monthIncome == 1500)
        #expect(result.monthExpense == 300)
        #expect(result.prevExpense == 250)
        #expect(result.prevHasAnyTx == true)
        #expect(result.periodIncome == 1500)
        #expect(result.periodExpense == 300)
    }

    // MARK: - Independencia entre buckets

    /// Cuando `period == month`, los buckets de mes y período tienen los
    /// mismos valores — verifica que la card "Disponible" coincide con los
    /// pills del mes cuando el usuario está en "Este mes".
    @Test func calculate_periodEqualsMonth_periodBucketsMatchMonthBuckets() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let txs = [
            makeTransaction(amount: 2000, date: date(2026, 4, 1), account: account, category: salary),
            makeTransaction(amount: -400, date: date(2026, 4, 15), account: account, category: food),
        ]

        let result = HeroBucketsCalculator.calculate(
            transactions: txs,
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.monthIncome == result.periodIncome)
        #expect(result.monthExpense == result.periodExpense)
        #expect(result.monthIncome == 2000)
        #expect(result.monthExpense == 400)
    }

    /// Cuando `period ⊂ month`, una transacción dentro del período también
    /// suma en mes (buckets independientes, no excluyentes).
    @Test func calculate_periodSubsetOfMonth_transactionCountsInBoth() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        let txInWeek = makeTransaction(amount: -120, date: date(2026, 4, 25), account: account, category: food)
        let txOutsideWeek = makeTransaction(amount: -80, date: date(2026, 4, 5), account: account, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [txInWeek, txOutsideWeek],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: lastWeekInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        // Mes incluye ambas (200), período solo la del 25 (120).
        #expect(result.monthExpense == 200)
        #expect(result.periodExpense == 120)
    }

    // MARK: - Guards y exclusiones

    /// Balance adjustments NO suman en ningún bucket.
    @Test func calculate_excludesBalanceAdjustments() {
        let account = makeAccount()
        let food = makeCategory(name: "Food")

        let normal = makeTransaction(amount: -200, date: date(2026, 4, 5), account: account, category: food)
        let adjustment = makeTransaction(
            amount: -9999, date: date(2026, 4, 5), account: account, category: food,
            balanceAdjustmentType: "manual"
        )

        let result = HeroBucketsCalculator.calculate(
            transactions: [normal, adjustment],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.monthExpense == 200)
        #expect(result.periodExpense == 200)
    }

    /// Transacciones huérfanas (sin cuenta) se excluyen siempre.
    @Test func calculate_excludesTransactionsWithoutAccount() {
        let food = makeCategory(name: "Food")
        let orphan = makeTransaction(amount: -300, date: date(2026, 4, 5), account: nil, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [orphan],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: []
        )

        #expect(result.monthExpense == 0)
        #expect(result.periodExpense == 0)
    }

    /// Mes anterior solo cuenta egresos (`prevExpense`) — los ingresos del
    /// mes anterior no se exponen porque el Hero solo usa el delta de gasto
    /// para el trend "vs mes anterior".
    @Test func calculate_prevMonthOnlyTracksExpense() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)
        let food = makeCategory(name: "Food")

        let prevIncome = makeTransaction(amount: 9999, date: date(2026, 3, 15), account: account, category: salary)
        let prevExpense = makeTransaction(amount: -500, date: date(2026, 3, 15), account: account, category: food)

        let result = HeroBucketsCalculator.calculate(
            transactions: [prevIncome, prevExpense],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.prevExpense == 500)
        #expect(result.prevHasAnyTx == true)
    }

    /// `prevHasAnyTx` se activa con cualquier tx en mes anterior (income o
    /// expense), no solo egresos — diferencia entre "no había nada" y
    /// "había ingresos pero cero gastos".
    @Test func calculate_prevHasAnyTx_trueWhenIncomeOnly() {
        let account = makeAccount()
        let salary = makeCategory(name: "Salary", isIncome: true)

        let prevIncomeOnly = makeTransaction(amount: 1000, date: date(2026, 3, 15), account: account, category: salary)

        let result = HeroBucketsCalculator.calculate(
            transactions: [prevIncomeOnly],
            monthInterval: aprilInterval,
            prevInterval: marchInterval,
            periodInterval: aprilInterval,
            eligibleAccountIDs: [account.persistentModelID]
        )

        #expect(result.prevExpense == 0)
        #expect(result.prevHasAnyTx == true)
    }
}
