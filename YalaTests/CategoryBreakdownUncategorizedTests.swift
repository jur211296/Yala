//
//  CategoryBreakdownUncategorizedTests.swift
//  YalaTests
//
//  **Cada desglose por categoría suma el total del período, con un trozo «Sin categoría».**
//
//  Decisión A de Jürgen (2026-10-23, ticket `category-breakdowns-leave-out-uncategorized-movements`): con 200 en
//  Comida y 40 sin categoría el gasto del mes dice 240, y la tarta, los rankings, el Sankey, la distribución por
//  necesidad y las categorías del widget de inicio sumaban 200. Ahora el movimiento sin categoría entra, del lado que
//  dice su signo (la regla de los totales, `TransactionClassificationLogic`), como «Sin categoría» con el gris neutro.
//
//  El fixture es DISCRIMINANTE: trae un ingreso sin categoría (+100) que NO puede entrar en ningún desglose de gastos
//  —con «sin categoría = gasto» la tarta sumaría 340— y un ingreso con categoría, para que el lado de ingresos del
//  Sankey tenga algo con lo que distinguirse. Con la regla vieja («sin categoría no existe») todo daría 200.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Desgloses por categoría · el trozo «Sin categoría» suma el total")
@MainActor
struct CategoryBreakdownUncategorizedTests {

    // MARK: - Fixture

    private let food = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let salary = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)

    private func tx(_ amount: Double, _ category: YalaCategory?, subcategory: Subcategory? = nil) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(),
            amount: amount,
            currencyCode: "USD",
            note: "",
            category: category,
            subcategory: subcategory,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    /// 200 en Comida, 40 de gasto sin categoría, 100 de ingreso sin categoría y 1.000 de sueldo.
    private var fixture: [TransactionItem] {
        [tx(-200, food), tx(-40, nil), tx(100, nil), tx(1000, salary)]
    }

    private var interval: DateInterval {
        let now = Date()
        return DateInterval(start: now.addingTimeInterval(-86_400 * 30), end: now.addingTimeInterval(60))
    }

    /// El gasto del período con la regla de los totales: el número contra el que tiene que cuadrar cada desglose.
    private func periodExpense(_ txs: [TransactionItem]) -> Double {
        CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day, currencyCode: "USD",
            converter: MockCurrencyConverter()
        ).totalExpense
    }

    // MARK: - Tarta y ranking de categorías

    @Test("Tarta y ranking: Comida 200 + Sin categoría 40 = 240, el gasto del período")
    func topCategories_includeUncategorizedSlice() throws {
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: fixture, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(periodExpense(fixture) == 240)
        #expect(result.reduce(0) { $0 + $1.amount } == 240)
        #expect(result.count == 2)
        let uncategorized = try #require(result.first { $0.isUncategorized })
        #expect(uncategorized.amount == 40)
        #expect(uncategorized.name == L10n.Report.uncategorized)
        #expect(uncategorized.colorHex == AppConstants.uncategorizedColorHex)
        #expect(uncategorized.id == nil)
        #expect(abs(uncategorized.percentage - 40.0 / 240.0 * 100) < 0.0001)
        #expect(result.first?.name == "Comida")
    }

    @Test("Con el filtro de ingresos, el ingreso sin categoría es su trozo y el gasto no entra")
    func topCategories_incomeSide_takesThePositiveUncategorized() throws {
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: fixture, interval: interval, currencyCode: "USD",
            transactionNatures: [.income], converter: MockCurrencyConverter()
        )

        #expect(result.reduce(0) { $0 + $1.amount } == 1100)
        let uncategorized = try #require(result.first { $0.isUncategorized })
        #expect(uncategorized.amount == 100)
    }

    @Test("Una devolución en Comida resta, y la tarta sigue cuadrando con el total")
    func topCategories_refundStillMatchesThePeriodTotal() {
        let txs = fixture + [tx(30, food)]
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: txs, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(periodExpense(txs) == 210)
        #expect(result.reduce(0) { $0 + $1.amount } == 210)
    }

    @Test("El trozo «Sin categoría» no se puede elegir como filtro")
    func uncategorizedSlice_isNeverSelected() throws {
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: fixture, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )
        let comida = try #require(result.first { !$0.isUncategorized })
        let uncategorized = try #require(result.first { $0.isUncategorized })
        let selected: Set<PersistentIdentifier> = [try #require(comida.id)]

        #expect(comida.isSelected(in: selected))
        #expect(!uncategorized.isSelected(in: selected))
    }

    @Test("Con Ingresos y Gastos a la vez, el trozo suma lo de cada lado: el +100 y el −40 no se restan")
    func topCategories_bothSides_doNotNetEachOther() throws {
        let both = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: fixture, interval: interval, currencyCode: "USD",
            transactionNatures: [.income, .expense], converter: MockCurrencyConverter()
        )
        let subcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: fixture, interval: interval, currencyCode: "USD",
            transactionNatures: [.income, .expense], converter: MockCurrencyConverter()
        )

        #expect(try #require(both.first { $0.isUncategorized }).amount == 140)
        #expect(try #require(subcategories.first { $0.isUncategorized }).amount == 140)
    }

    @Test("A igual importe, «Sin categoría» va detrás de la categoría")
    func topCategories_tie_putsUncategorizedLast() {
        let result = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx(-40, nil), tx(-40, food)], interval: interval, currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.map(\.isUncategorized) == [false, true])
    }

    // MARK: - Ranking de subcategorías

    @Test("Ranking de subcategorías: una fila «Sin categoría» y la suma es 240")
    func topSubcategories_includeUncategorizedRow() throws {
        let groceries = Subcategory(name: "Mercado", colorHex: "#00FF00", category: food)
        let txs = [tx(-200, food, subcategory: groceries), tx(-40, nil), tx(100, nil), tx(1000, salary)]

        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: txs, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.reduce(0) { $0 + $1.amount } == 240)
        let uncategorized = try #require(result.first { $0.category == nil })
        #expect(uncategorized.amount == 40)
        #expect(uncategorized.subcategoryName == L10n.Report.uncategorized)
        #expect(uncategorized.colorHex == AppConstants.uncategorizedColorHex)
        #expect(uncategorized.persistentID == nil)
    }

    @Test("Un movimiento sin categoría con una subcategoría colgando va a la MISMA fila «Sin categoría» que los demás")
    func topSubcategories_danglingSubcategory_isUncategorized() throws {
        let groceries = Subcategory(name: "Mercado", colorHex: "#00FF00", category: food)
        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: [tx(-40, nil, subcategory: groceries), tx(-40, nil)], interval: interval, currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result.count == 1)
        #expect(result.first?.isUncategorized == true)
        #expect(result.first?.amount == 80)
        #expect(result.first?.subcategory == nil)
        #expect(result.first?.iconName == AppConstants.uncategorizedIconName)
    }

    @Test("Con una categoría elegida, «Sin categoría» no aparece en sus subcategorías")
    func topSubcategories_categoryFilter_leavesUncategorizedOut() {
        let result = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: fixture, interval: interval, currencyCode: "USD",
            categoryFilter: food.persistentModelID, converter: MockCurrencyConverter()
        )

        #expect(result.allSatisfy { $0.category != nil })
        #expect(result.reduce(0) { $0 + $1.amount } == 200)
    }

    // MARK: - Sankey

    @Test("Sankey: nodo «Sin categoría» de 40 en gastos y de 100 en ingresos")
    func sankey_includesUncategorizedNodes() throws {
        let result = SankeyFlowCalculator.compute(
            transactions: fixture, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )

        #expect(result.totalExpense == 240)
        #expect(result.totalIncome == 1100)
        let expenseNode = try #require(result.nodes.first { $0.id == SankeyFlowCalculator.expenseUncategorizedID })
        #expect(expenseNode.amount == 40)
        #expect(expenseNode.column == .expenseCategory)
        #expect(expenseNode.name == L10n.Report.uncategorized)
        #expect(expenseNode.colorHex == AppConstants.uncategorizedColorHex)
        #expect(expenseNode.isTappable == false)
        #expect(expenseNode.persistentID == nil)
        let categoryColumn = result.nodes.filter { $0.column == .expenseCategory }
        #expect(categoryColumn.reduce(0) { $0 + $1.amount } == 240)
        // «Gastos» reparte los 240 entre las categorías, el nodo sin categoría incluido.
        let link = try #require(result.links.first { $0.targetID == SankeyFlowCalculator.expenseUncategorizedID })
        #expect(link.amount == 40)

        let incomeNode = try #require(result.nodes.first { $0.id == SankeyFlowCalculator.incomeUncategorizedID })
        #expect(incomeNode.amount == 100)
        #expect(incomeNode.column == .income)
    }

    // MARK: - Distribución por necesidad

    @Test("Necesidad: el gasto sin categoría cae en «Sin clasificar» y la gráfica suma 240")
    func needTrend_uncategorizedIsUnclassified() throws {
        let groceries = Subcategory(
            name: "Mercado", colorHex: "#00FF00", natureRawValue: SubcategoryNeed.essential.rawValue, category: food
        )
        let txs = [tx(-200, food, subcategory: groceries), tx(-40, nil), tx(100, nil), tx(1000, salary)]

        let points = NeedTrendHelper.calculateTrend(
            transactions: txs, grouping: .month, interval: interval, preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        let point = try #require(points.first)
        #expect(points.count == 1)
        #expect(point.essential == 200)
        #expect(point.unclassified == 40)
        #expect(point.essential + point.priority + point.optional + point.unclassified == 240)
    }

    @Test("Necesidad: un gasto sin categoría con una subcategoría esencial colgando sigue siendo «Sin clasificar»")
    func needTrend_danglingSubcategory_isUnclassified() throws {
        let groceries = Subcategory(
            name: "Mercado", colorHex: "#00FF00", natureRawValue: SubcategoryNeed.essential.rawValue, category: food
        )
        let points = NeedTrendHelper.calculateTrend(
            transactions: [tx(-40, nil, subcategory: groceries)], grouping: .month, interval: interval,
            preferredCurrency: .usd, converter: MockCurrencyConverter()
        )

        let point = try #require(points.first)
        #expect(point.unclassified == 40)
        #expect(point.essential == 0)
    }

    @Test("Observaciones: el gasto sin categoría entra en el reparto por necesidad, con lo sin clasificar (en Opcional)")
    func insightsNeedDistribution_countsUncategorized() {
        let groceries = Subcategory(
            name: "Mercado", colorHex: "#00FF00", natureRawValue: SubcategoryNeed.essential.rawValue, category: food
        )
        let txs = [tx(-200, food, subcategory: groceries), tx(-40, nil, subcategory: groceries), tx(100, nil), tx(1000, salary)]
        let distribution = InsightsCalculator.calculateNeedDistribution(
            txs, currencyCode: "USD", adjustment: .none, converter: MockCurrencyConverter()
        )

        #expect(abs(distribution.total) == 240)
        #expect(abs(distribution.essential) == 200)
        #expect(abs(distribution.optional) == 40)
    }

    // MARK: - Período anterior

    @Test("El corte del período anterior cuenta el día del último gasto sin categoría")
    func previousPeriodCut_countsUncategorized() throws {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let month = DateInterval(start: start.addingTimeInterval(-86_400 * 20), end: start.addingTimeInterval(86_400))
        let early = tx(-200, food)
        early.date = start.addingTimeInterval(-86_400 * 15)
        let late = tx(-40, nil)
        late.date = start.addingTimeInterval(-86_400 * 2)

        let dates = DistributionPreviousPeriodCalculator.currentDates(from: [early, late], in: month, natures: nil)

        #expect(try #require(dates.max()) == late.date)
    }

    // MARK: - Widget de inicio

    @Test("Widget de inicio: «Sin categoría» con 40 y el desglose suma el gasto del período")
    func widgetTopCategories_includeUncategorized() throws {
        let top = WidgetDataCache.buildTopCategories(
            transactions: fixture, totalExpense: 240, limit: 20, currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(top.reduce(0) { $0 + $1.amount } == 240)
        let uncategorized = try #require(top.first { $0.id == WidgetDataCache.uncategorizedWidgetKey })
        #expect(uncategorized.amount == 40)
        #expect(uncategorized.name == L10n.Report.uncategorized)
        #expect(uncategorized.colorHex == AppConstants.uncategorizedColorHex)
        #expect(uncategorized.iconName == AppConstants.uncategorizedIconName)
    }

    @Test("Widget de inicio: una categoría que se llama «Sin categoría» no se funde con el trozo")
    func widgetTopCategories_aCategoryNamedLikeTheSliceStaysApart() {
        let lookalike = YalaCategory(name: L10n.Report.uncategorized, colorHex: "#123456", isIncome: false)
        let top = WidgetDataCache.buildTopCategories(
            transactions: [tx(-10, lookalike), tx(-40, nil)], totalExpense: 50, limit: 20, currencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(top.count == 2)
    }

    // MARK: - Lo que NOMBRA la mayor categoría

    @Test("Observaciones no nombra «Sin categoría» como la mayor categoría ni subcategoría")
    func quickStats_topCategory_skipsUncategorized() throws {
        let groceries = Subcategory(name: "Mercado", colorHex: "#00FF00", category: food)
        let txs = [tx(-200, food, subcategory: groceries), tx(-400, nil)]
        let categories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: txs, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )
        let subcategories = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: txs, interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )
        let stats = QuickStats(
            dailyAverage: 0, topCategories: categories, topSubcategories: subcategories,
            highestExpense: nil, highestAvgWeekday: nil, subscriptionsTotal: 0
        )

        #expect(categories.first?.isUncategorized == true)
        #expect(subcategories.first?.isUncategorized == true)
        #expect(stats.topCategory?.name == "Comida")
        #expect(stats.topSubcategory?.subcategoryName == "Mercado")
    }

    @Test("La regla de la categoría dominante nombra la primera categoría real")
    func ruleTopCategory_skipsUncategorized() throws {
        let categories = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: [tx(-500, nil), tx(-450, food), tx(-50, YalaCategory(name: "Cine", colorHex: "#0000FF", isIncome: false))],
            interval: interval, currencyCode: "USD", converter: MockCurrencyConverter()
        )
        let insights = InsightsCalculator.generateRuleBasedInsights(
            periodSummary: PeriodSummary(
                totalExpense: 1000, totalIncome: 2000, netBalance: 1000, transactionCount: 3, expenseVariation: nil,
                incomeVariation: nil, balanceVariation: nil, dailyAverageCount: 1, dailyAverageExpense: 33,
                dailyAverageVariation: nil, previousPeriodLabel: "", incomeAmountsAreApproximate: false,
                expenseAmountsAreApproximate: false, amountsAreApproximate: false
            ),
            quickStats: QuickStats(
                dailyAverage: 33, topCategories: categories, topSubcategories: [], highestExpense: nil,
                highestAvgWeekday: nil, subscriptionsTotal: 0
            ),
            commitments: Commitments(
                pendingPaymentsCount: 0, pendingPaymentsAmount: 0, activeSubscriptionsCount: 0,
                activeSubscriptionsMonthly: 0, activeRecurringCount: 0, activeRecurringMonthly: 0, budgetsAtRisk: []
            ),
            needDistribution: NeedDistribution(essential: 500, priority: 300, optional: 200, total: 1000),
            yearOverYear: nil,
            topCategories: categories,
            prevCashFlow: CashFlowSummary(
                totalIncome: 2000, totalExpense: 1000, netFlow: 1000, chartData: [], currencyCode: "USD",
                incomeAmountsAreApproximate: false, expenseAmountsAreApproximate: false, amountsAreApproximate: false
            ),
            currencyCode: "USD"
        )

        let rule = try #require(insights.first { $0.id == "top_category_dominant" })
        let text = String(rule.text.characters)
        #expect(text.contains("Comida"))
        #expect(!text.contains(L10n.Report.uncategorized))
    }
}

// MARK: - La copia de la extensión

/// `YalaTests` no compila `YalaWidgets`, así que el recálculo de la extensión (al cambiar de período en el widget) solo
/// se puede fijar leyendo su fuente: el bloque del trozo y sus tres constantes, que tienen que ser las de la app.
@Suite("Widget · la extensión pinta el mismo trozo «Sin categoría» que la app")
struct WidgetExtensionUncategorizedParityTests {

    private static func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    private static func normalized(_ text: String) -> String {
        text.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
            .joined(separator: " ")
    }

    @Test("Las constantes de la extensión son las de la app")
    func constantsMatchTheApp() throws {
        let reader = try Self.source("YalaWidgets/Services/WidgetDataService.swift")
        #expect(reader.contains(#"static let uncategorizedKey = "\u{1}uncategorized""#))
        #expect(WidgetDataCache.uncategorizedWidgetKey == "\u{1}uncategorized")
        #expect(reader.contains(#"static let uncategorizedIconName = "\#(AppConstants.uncategorizedIconName)""#))
        #expect(reader.contains(#"static let uncategorizedColorHex = "\#(AppConstants.uncategorizedColorHex)""#))
    }

    @Test("El gasto sin categoría va al trozo con su texto, en vez de saltarse")
    func uncategorizedBlockIsWired() throws {
        let body = Self.normalized(try Self.source("YalaWidgets/Services/WidgetDataService.swift"))
        let expected = Self.normalized("""
            for tx in transactions where !tx.isIncome {
                let amount = abs(tx.amountInPreferredCurrency)
                guard let categoryName = tx.categoryName else {
                    let key = uncategorizedKey
                    if var existing = categoryTotals[key] {
                        existing.amount += amount
                        categoryTotals[key] = existing
                    } else {
                        categoryTotals[key] = (
                            name: String(localized: "widget.ui.uncategorized", bundle: .main),
                            icon: uncategorizedIconName,
                            color: uncategorizedColorHex,
                            amount: amount
                        )
                    }
                    continue
                }
            """)
        #expect(body.contains(expected))
    }

    @Test("El texto del widget es la traducción del Informe en cada idioma")
    func widgetStringMatchesTheReportInEveryLocale() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let widgetResources = root.appendingPathComponent("YalaWidgets/Resources")
        let locales = try FileManager.default.contentsOfDirectory(atPath: widgetResources.path)
            .filter { $0.hasSuffix(".lproj") }
        #expect(locales.count == 16)
        for locale in locales {
            let widget = try Self.source("YalaWidgets/Resources/\(locale)/Localizable.strings")
            let app = try Self.source("Yala/Resources/\(locale)/Localizable.strings")
            let widgetValue = Self.value(of: "widget.ui.uncategorized", in: widget)
            let appValue = Self.value(of: "report.uncategorized", in: app)
            #expect(widgetValue != nil, "\(locale) no trae widget.ui.uncategorized")
            #expect(widgetValue == appValue, "\(locale): \(widgetValue ?? "-") ≠ \(appValue ?? "-")")
        }
    }

    private static func value(of key: String, in strings: String) -> String? {
        for line in strings.split(separator: "\n") where line.hasPrefix("\"\(key)\"") {
            guard let equals = line.range(of: "= ") else { continue }
            return String(line[equals.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"; "))
        }
        return nil
    }
}
