//
//  DailySpendingCalculatorTests.swift
//  YalaTests
//
//  Unit tests for DailySpendingCalculator (daily expense aggregation for the
//  Records calendar). Pure logic, no ModelContext.
//

import Foundation
import Testing

@testable import Yala

struct DailySpendingCalculatorTests {
    private let calendar = Calendar.current

    private func startOfDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!)
    }

    private func makeAccount(excludeFromStatistics: Bool = false) -> Account {
        Account(
            name: "Main", currencyCode: "USD", colorHex: "#6366F1",
            iconName: "creditcard", type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
    }

    private func makeCategory(name: String, isIncome: Bool) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    /// `preferred` es el monto en divisa preferida.
    ///
    /// OJO con `category: nil` (el default): la regla canónica cae al signo del monto SOLO
    /// cuando no hay categoría, así que un test sin categoría no distingue la clasificación
    /// buena de la clasificación por signo puro. Para ejercitar la regla, pasa `category`.
    private func makeTx(
        preferred: Double,
        account: Account?,
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(),
            amount: preferred,
            currencyCode: "USD",
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: preferred,
            preferredCurrencyCode: "USD"
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    // MARK: - Tests

    @Test func empty_returnsZeroMax() {
        let result = DailySpendingCalculator.compute(groups: [])
        #expect(result.spendingByDay.isEmpty)
        #expect(result.maxSpending == 0)
    }

    @Test func sumsExpensesPerDay() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -100, account: acc),
            makeTx(preferred: -50, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 150)
        #expect(result.maxSpending == 150)
    }

    @Test func ignoresIncome() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: 500, account: acc),
            makeTx(preferred: -80, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 80)
    }

    @Test func ignoresTransfersAndAdjustments() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -100, account: acc, balanceAdjustmentType: TransactionItem.adjustmentTypeTransfer),
            makeTx(preferred: -40, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 40)
    }

    @Test func ignoresExcludedAccounts() {
        let excluded = makeAccount(excludeFromStatistics: true)
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: -100, account: excluded)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == nil)
        #expect(result.maxSpending == 0)
    }

    @Test func ignoresRecordsWithoutAccount() {
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: -100, account: nil)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay.isEmpty)
    }

    @Test func maxAcrossDays() {
        let acc = makeAccount()
        let d1 = startOfDay(2026, 1, 5)
        let d2 = startOfDay(2026, 1, 6)
        let groups = [
            (date: d1, records: [makeTx(preferred: -100, account: acc)]),
            (date: d2, records: [makeTx(preferred: -250, account: acc)]),
        ]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[d1] == 100)
        #expect(result.spendingByDay[d2] == 250)
        #expect(result.maxSpending == 250)
    }

    @Test func incomeOnlyDay_notInResult() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: 300, account: acc)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == nil)
        #expect(result.maxSpending == 0)
    }

    // MARK: - Clasificación por categoría (regla canónica)
    //
    // Los 8 tests de arriba construyen transacciones SIN categoría, donde la regla canónica
    // cae al signo por diseño: pasarían igual con la clasificación por signo puro que tenía
    // este calculador hasta el 2026-09-02. Los cuatro de abajo sí discriminan — cada uno
    // falla contra aquella versión.

    /// Le devuelven un cobro: importe positivo con categoría de GASTO. Es un reembolso, así que
    /// debe RESTAR del día. La clasificación por signo lo ignoraba (dejaba el día en 500).
    @Test func expenseCategoryWithPositiveAmount_reducesDay() {
        let acc = makeAccount()
        let food = makeCategory(name: "Restaurantes", isIncome: false)
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -500, account: acc, category: food),
            makeTx(preferred: 200, account: acc, category: food),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 300)
        #expect(result.maxSpending == 300)
    }

    /// Le devuelven un ingreso: importe negativo con categoría de INGRESO. No es un gasto, así
    /// que el día no debe contarlo. La clasificación por signo lo sumaba como gasto de 100.
    @Test func incomeCategoryWithNegativeAmount_notCountedAsExpense() {
        let acc = makeAccount()
        let salary = makeCategory(name: "Salario", isIncome: true)
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: -100, account: acc, category: salary)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == nil)
        #expect(result.maxSpending == 0)
    }

    /// Las cuatro filas del fixture `-uitest-seed-desync` (`DevSeedTransactions.createDesyncFixtures`),
    /// todas el mismo día. El chip del hero da 300 por la regla canónica; este calculador debe dar
    /// lo mismo. Con la clasificación por signo daba 600, que es exactamente el desajuste que el
    /// usuario veía entre el resumen y la celda del calendario.
    @Test func desyncFixtureDay_matchesHeroSummary() {
        let acc = makeAccount()
        let salary = makeCategory(name: "Salario", isIncome: true)
        let food = makeCategory(name: "Restaurantes", isIncome: false)
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: 600, account: acc, category: salary),
            makeTx(preferred: -100, account: acc, category: salary),
            makeTx(preferred: -500, account: acc, category: food),
            makeTx(preferred: 200, account: acc, category: food),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 300)
    }

    /// Sin categoría, el fallback por signo sigue vivo — es parte de la regla canónica, no un
    /// resto de la versión anterior. Fija ese contrato para que un refactor no se lo lleve.
    @Test func nilCategory_stillFallsBackToSign() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -100, account: acc),
            makeTx(preferred: 40, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 100)
    }
}
