//
//  YalaIAUncategorizedClassificationTests.swift
//  YalaTests
//
//  Yala IA decide ingreso o gasto con la regla de la app (`TransactionClassificationLogic`): la categoría manda y, sin
//  categoría, el signo (ticket `yala-ia-classifies-uncategorized-movements-as-expense`). Hasta el 2026-10-29 el contexto
//  del chat filtraba con `category?.isIncome == false` / `!= true` / `== true`: un gasto sin categoría contaba en el
//  bucket «uncategorized» pero no en categorías, comercios, necesidades, historial ni en la línea base de anomalías, y
//  un ingreso sin categoría se sumaba a los gastos sin categoría y no aparecía como ingreso.
//
//  Cada caso lleva un movimiento sin categoría DE CADA SIGNO: con uno solo, «`!= true`» y la regla de la app dan lo
//  mismo y el test no distingue nada (`ingreso-gasto.md`, «Los tests que lo fijan»). Sin `ModelContext`: `@Model`
//  sueltos, como `FullFinancialContextBuilderTests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Yala IA · un movimiento sin categoría es ingreso o gasto por su signo", .serialized)
@MainActor
struct YalaIAUncategorizedClassificationTests {

    // 20 de septiembre a mediodía: el mes en curso es septiembre y el pasado, agosto.
    private let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 9; c.day = 20; c.hour = 12
        return Calendar.current.date(from: c) ?? .now
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = month; c.day = day; c.hour = 12
        return Calendar.current.date(from: c) ?? .now
    }

    private func tx(_ amount: Double, _ date: Date, category: YalaCategory? = nil, note: String? = nil) -> TransactionItem {
        let t = TransactionItem(
            date: date, amount: amount, currencyCode: "USD", note: note, category: category,
            amountInPreferredCurrency: amount
        )
        t.preferredCurrencyCode = "USD"
        return t
    }

    private let expenseNote = "Kiosko Central"
    private let incomeNote = "Venta de garaje"

    /// Septiembre: un gasto esencial con categoría, un gasto sin categoría y un ingreso sin categoría. Agosto: uno de
    /// cada signo sin categoría.
    private func corpus() -> [TransactionItem] {
        let food = YalaCategory(name: "Food", colorHex: "#000", isIncome: false)
        let groceries = Subcategory(
            name: "Groceries", colorHex: nil, natureRawValue: SubcategoryNeed.essential.rawValue,
            iconName: "cart.fill", category: food
        )
        let essential = tx(-30, day(9, 5), category: food)
        essential.subcategory = groceries
        return [
            essential,
            tx(-40, day(9, 6), note: expenseNote),
            tx(70, day(9, 7), note: incomeNote),
            tx(-25, day(8, 10), note: expenseNote),
            tx(50, day(8, 11), note: incomeNote),
        ]
    }

    private func build(_ txs: [TransactionItem]) -> FullFinancialContext {
        FullFinancialContextBuilder().buildFromArrays(
            transactions: txs, budgets: [], accounts: [], tags: [], scheduledPayments: [],
            currencyCode: "USD", currencyDisplay: "$", converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es", country: "PE", includeAnomalies: false, now: now
        )
    }

    // MARK: - Contexto del chat

    @Test("Gastos por categoría: el gasto sin categoría está en «Other», el ingreso sin categoría no")
    func expenseCategories() throws {
        let ctx = build(corpus())
        let other = try #require(ctx.categories.first { $0.name == "Other" })
        #expect(other.totalCurrentMonth == 40)
        #expect(other.totalLastMonth == 25)
        #expect(other.txCountCurrentMonth == 1)
    }

    @Test("Ingresos por categoría: el ingreso sin categoría está en «Other»")
    func incomeCategories() throws {
        let ctx = build(corpus())
        let other = try #require(ctx.incomeCategories.first { $0.name == "Other" })
        #expect(other.totalCurrentMonth == 70)
        #expect(other.totalLastMonth == 50)
    }

    @Test("El bucket «uncategorized» cuenta solo el gasto sin categoría")
    func uncategorizedBucket() {
        let ctx = build(corpus())
        #expect(ctx.uncategorized.txCountCurrentMonth == 1)
        #expect(ctx.uncategorized.totalCurrentMonth == 40)
    }

    @Test("Comercios: entra el del gasto sin categoría, no el del ingreso")
    func merchants() {
        let ctx = build(corpus())
        let names = Set(ctx.merchantsTop20.map(\.name))
        #expect(names.contains(MerchantCanonicalizer.canonicalize(expenseNote)))
        #expect(!names.contains(MerchantCanonicalizer.canonicalize(incomeNote)))
    }

    @Test("Necesidades del mes: el gasto sin categoría cae en «sin clasificar» y el ingreso no suma")
    func needs() {
        let needs = build(corpus()).patterns.needsBreakdownCurrentMonth
        #expect(needs.essential == 30)
        #expect(needs.unclassified == 40)
        #expect(needs.total == 70)
    }

    @Test("Historial: agosto lleva el gasto sin categoría en sus categorías y el ingreso en sus ingresos")
    func monthlyHistory() throws {
        let august = try #require(build(corpus()).monthlyHistory.first { $0.month == "2026-08" })
        #expect(august.topExpenseCategories.first { $0.name == "Other" }?.total == 25)
        #expect(august.topIncomeSubcategories.first { $0.name == "Other" }?.total == 50)
    }

    // MARK: - Anomalías

    @Test("Anomalías: la línea base de «Other» cuenta los gastos sin categoría y no los ingresos")
    func anomalyBaseline() {
        let interval = DateInterval(start: day(9, 1), end: now)
        var all = (1...5).map { tx(-20, day(8, $0 * 2)) }
        // Un ingreso sin categoría en la línea base: si contara, la media de «Other» sería 100 y 200 no la doblaría.
        all.append(tx(500, day(8, 15)))
        let big = tx(-200, day(9, 10), note: "Compra grande")
        all.append(big)

        let hits = AnomalyDetectionCalculator.detect(
            allTransactions: all, periodTransactions: [big], interval: interval,
            currencyCode: "USD", converter: MockCurrencyConverter(fixedRate: 1.0)
        )
        #expect(hits.count == 1)
        #expect(hits.first?.category == "Other")
        #expect(hits.first?.avgForCategory == 20)
    }

    // MARK: - Sugerencias del chat

    @Test("Sugerencias: el ingreso sin categoría suma a ingresos y el gasto sin categoría a gastos y comercios")
    func suggestionsMonthSums() {
        let sums = ChatSuggestionsLLMService.monthSums(
            [tx(-40, day(9, 6), note: expenseNote), tx(70, day(9, 7), note: incomeNote)],
            tagCatalog: [:], currencyCode: "USD", adjustment: .none, includeGroupTransactions: true,
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )
        #expect(sums.totalIncome == 70)
        #expect(sums.totalExpense == 40)
        #expect(sums.merchants[MerchantCanonicalizer.canonicalize(expenseNote)] == 40)
        #expect(sums.merchants[MerchantCanonicalizer.canonicalize(incomeNote)] == nil)
    }
}
