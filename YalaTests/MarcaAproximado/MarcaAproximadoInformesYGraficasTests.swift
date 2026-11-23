//
//  MarcaAproximadoInformesYGraficasTests.swift
//  YalaTests
//
//  La misma marca «≈» que el Panel en tres sitios que la perdían (encargo del 2026-11-23):
//  - `financial-report-amounts-unmarked`: «Te quedó» de Informes y las filas de su tabla.
//  - `fx-historical-balance-curve-unmarked`: el saldo de un período CERRADO (último punto de la curva).
//  - `pie-header-total-unmarked`: el total de las tartas de Distribución y del Panel.
//
//  Los casos discriminan: con el código de antes (sin señal, o con la suma de magnitudes como denominador de una
//  resta) dan otro veredicto. Sin `ModelContext`: `@Model` sueltos, como `ApproximateMarkPanelCoherenceTests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Marca «≈» en Informes, curva de saldo cerrada y total de las tartas")
struct MarcaAproximadoInformesYGraficasTests {

    private let calendar = Calendar.current
    private let stale = MockCurrencyConverter(fixedRate: 3.75, quality: .carriedForward(fromDateKey: "2026-04-09"))
    private let exact = MockCurrencyConverter(fixedRate: 3.75, quality: .exact)

    private func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: d, hour: 12)) ?? Date()
    }

    private var april: DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1)) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private struct Escenario {
        let account: Account
        let food: YalaCategory
        let salary: YalaCategory
        let txs: [TransactionItem]
    }

    /// 10.000 PEN de ingreso exacto y un gasto en dólares guardado con una tasa que no era la del día.
    private func escenario(usdSpent: Double, provisional: Bool = true) -> Escenario {
        let account = Account(
            name: "Main", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank"
        )
        let salary = YalaCategory(name: "Salary", colorHex: "#00FF00", isIncome: true)
        let food = YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let income = TransactionItem(
            date: day(2), amount: 10_000, currencyCode: "PEN", note: "", category: salary,
            account: account, tags: [], amountInPreferredCurrency: 10_000
        )
        income.preferredCurrencyCode = "PEN"
        let spent = TransactionItem(
            date: day(3), amount: -usdSpent, currencyCode: "USD", note: "", category: food,
            account: account, tags: [], amountInPreferredCurrency: -usdSpent * 3.75
        )
        spent.preferredCurrencyCode = "PEN"
        spent.isExchangeRateProvisional = provisional
        return Escenario(account: account, food: food, salary: salary, txs: [income, spent])
    }

    // MARK: - Informes: «Te quedó»

    @Test("«Te quedó» lleva «≈» cuando el gasto con tasa dudosa pesa, y no cuando no")
    func netFlow_marksOnlyWhenTheDoubtfulPartWeighs() {
        let grande = escenario(usdSpent: 2_000)  // 7.500 dudosos sobre un neto de 2.500
        let pequeno = escenario(usdSpent: 100)   // 375 sobre 9.625: 3,9 %
        #expect(FinancialReportViewModel.netFlow(
            of: grande.txs, currencyCode: "PEN", adjustment: .none, converter: stale
        ).isApproximate)
        #expect(!FinancialReportViewModel.netFlow(
            of: pequeno.txs, currencyCode: "PEN", adjustment: .none, converter: stale
        ).isApproximate)
    }

    /// El neto es una RESTA: el denominador es el número mostrado. 130 USD → 487,5 sobre el neto de 9.512,5 es un
    /// 5,12 % y marca; sobre la suma de magnitudes (10.487,5) sería un 4,65 % y no marcaría.
    @Test("El denominador de «Te quedó» es el neto que se ve, no la suma de magnitudes")
    func netFlow_denominatorIsTheShownNet() {
        let caso = escenario(usdSpent: 130)
        let net = FinancialReportViewModel.netFlow(
            of: caso.txs, currencyCode: "PEN", adjustment: .none, converter: stale
        )
        #expect(abs(net.value - 9_512.5) < 0.001, "premisa: el neto no cambia, solo su marca")
        #expect(net.isApproximate)
    }

    @Test("Sin tasas dudosas, «Te quedó» no lleva «≈»")
    func netFlow_exact_noMark() {
        let caso = escenario(usdSpent: 2_000, provisional: false)
        #expect(!FinancialReportViewModel.netFlow(
            of: caso.txs, currencyCode: "PEN", adjustment: .none, converter: exact
        ).isApproximate)
    }

    // MARK: - Informes: filas de la tabla

    @Test("La fila de la categoría con la tasa dudosa lleva «≈»; la exacta no")
    func pivotRows_markTheRowThatCarriesTheDoubt() throws {
        let caso = escenario(usdSpent: 2_000)
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: caso.txs, previousTransactions: [], hierarchy: [.categoria],
            preferredCurrency: "PEN", allTags: [], converter: stale
        )
        let food = try #require(nodes.first { $0.label == "Food" })
        let salary = try #require(nodes.first { $0.label == "Salary" })
        #expect(food.isApproximate)
        #expect(!salary.isApproximate)
        #expect(abs(food.amount - (-7_500)) < 0.001, "ningún importe cambia: solo su marca")
    }

    @Test("La fila del período anterior lleva su propia marca")
    func pivotRows_previousSideHasItsOwnMark() throws {
        let actual = escenario(usdSpent: 2_000, provisional: false)
        let anterior = escenario(usdSpent: 2_000, provisional: true)
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: actual.txs, previousTransactions: anterior.txs, hierarchy: [.tipo],
            preferredCurrency: "PEN", allTags: [], converter: stale
        )
        let gastos = try #require(nodes.first { !$0.isIncome })
        #expect(!gastos.isApproximate)
        #expect(gastos.previousIsApproximate)
    }

    @Test("Agrupado por divisa la fila suma en nativo y no lleva «≈»: ahí no hubo conversión")
    func pivotRows_nativeCurrencyRows_noMark() {
        let caso = escenario(usdSpent: 2_000)
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: caso.txs, previousTransactions: [], hierarchy: [.divisa],
            preferredCurrency: "PEN", allTags: [], converter: stale
        )
        #expect(!nodes.isEmpty)
        #expect(nodes.allSatisfy { !$0.isApproximate })
    }

    // MARK: - Tartas

    @Test("El total de la tarta de gastos lleva «≈» cuando el gasto dudoso pesa en el gasto")
    func pieTotal_marksOnTheExpenseSide() {
        // Solo cuenta el lado de la tarta (gastos): el ingreso exacto de 10.000 no diluye la marca.
        let caso = escenario(usdSpent: 100)
        #expect(PieTotalApproximateMark.marks(
            transactions: caso.txs, interval: april, currencyCode: "PEN", natures: nil,
            slices: .categories, adjustment: .none, converter: stale
        ))
        #expect(!PieTotalApproximateMark.marks(
            transactions: caso.txs, interval: april, currencyCode: "PEN", natures: [.income],
            slices: .categories, adjustment: .none, converter: stale
        ), "la tarta de ingresos no incluye el gasto dudoso")
    }

    @Test("El total de la tarta no lleva «≈» si la parte dudosa no llega al 5 % del gasto")
    func pieTotal_smallDoubt_noMark() {
        let caso = escenario(usdSpent: 100)
        let gastoExacto = TransactionItem(
            date: day(4), amount: -10_000, currencyCode: "PEN", note: "", category: caso.food,
            account: caso.account, tags: [], amountInPreferredCurrency: -10_000
        )
        gastoExacto.preferredCurrencyCode = "PEN"
        #expect(!PieTotalApproximateMark.marks(
            transactions: caso.txs + [gastoExacto], interval: april, currencyCode: "PEN", natures: nil,
            slices: .categories, adjustment: .none, converter: stale
        ))
    }

    @Test("La tarta de subcategorías mide solo la categoría filtrada")
    func pieTotal_includesFilter() {
        let caso = escenario(usdSpent: 2_000)
        let salaryID = caso.salary.persistentModelID
        #expect(!PieTotalApproximateMark.marks(
            transactions: caso.txs, interval: april, currencyCode: "PEN", natures: [.income, .expense],
            slices: .subcategories, adjustment: .none, converter: stale,
            includes: { $0.category?.persistentModelID == salaryID }
        ))
    }

    @Test("La tarta de etiquetas no cuenta movimientos sin etiqueta")
    func pieTotal_tags_skipsUntagged() {
        let caso = escenario(usdSpent: 2_000)
        #expect(!PieTotalApproximateMark.marks(
            transactions: caso.txs, interval: april, currencyCode: "PEN", natures: nil,
            slices: .tags, adjustment: .none, converter: stale
        ))
    }

    /// El total de la tarta es `Σ|neto de cada trozo|`: un reembolso resta dentro de su categoría. 50 USD dudosos
    /// (187,5) en Food; en Travel, 10.000 de gasto y 9.800 de devolución, exactos ⇒ la tarta pinta 387,5 y lo dudoso es
    /// el 48 %. Con la suma de magnitudes de cada movimiento (19.987,5) sería el 0,9 % y no marcaría.
    @Test("Un reembolso no diluye la marca de la tarta: el denominador es el total que se pinta")
    func pieTotal_refundDoesNotDiluteTheMark() {
        let caso = escenario(usdSpent: 50)
        let travel = YalaCategory(name: "Travel", colorHex: "#0000FF", isIncome: false)
        let gasto = TransactionItem(
            date: day(5), amount: -10_000, currencyCode: "PEN", note: "", category: travel,
            account: caso.account, tags: [], amountInPreferredCurrency: -10_000
        )
        gasto.preferredCurrencyCode = "PEN"
        let devolucion = TransactionItem(
            date: day(6), amount: 9_800, currencyCode: "PEN", note: "", category: travel,
            account: caso.account, tags: [], amountInPreferredCurrency: 9_800
        )
        devolucion.preferredCurrencyCode = "PEN"
        let txs = caso.txs + [gasto, devolucion]
        let summaries = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: txs, interval: april, currencyCode: "PEN", converter: stale
        )
        #expect(abs(summaries.reduce(0) { $0 + $1.amount } - 387.5) < 0.001, "premisa: la tarta pinta 387,5")
        #expect(PieTotalApproximateMark.marks(
            transactions: txs, interval: april, currencyCode: "PEN", natures: nil,
            slices: .categories, adjustment: .none, converter: stale
        ))
        #expect(PieTotalApproximateMark.marks(
            transactions: txs, interval: april, currencyCode: "PEN", natures: nil,
            slices: .subcategories, adjustment: .none, converter: stale
        ))
    }

    // MARK: - Curva de saldo: período cerrado

    /// Una cuenta en dólares con su saldo. El mes pasado se valora al cierre con la tasa de ese día; este mes, con la
    /// regla del saldo vivo. La incertidumbre es la misma (la tasa es la misma), así que la marca no puede depender del
    /// período: es el AC del ticket.
    private func saldoEnDolares() -> (Account, [TransactionItem]) {
        let account = Account(
            name: "Dólares", currencyCode: "USD", colorHex: "#6366F1", iconName: "dollarsign", type: "bank"
        )
        let now = Date()
        let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let lastMonthDay = calendar.date(byAdding: .day, value: -20, to: startOfThisMonth) ?? now
        let deposito = TransactionItem(
            date: lastMonthDay, amount: 1_000, currencyCode: "USD", note: "", category: nil,
            account: account, tags: [], amountInPreferredCurrency: 3_750
        )
        deposito.preferredCurrencyCode = "PEN"
        let hoy = TransactionItem(
            date: calendar.startOfDay(for: now), amount: 10, currencyCode: "USD", note: "", category: nil,
            account: account, tags: [], amountInPreferredCurrency: 37.5
        )
        hoy.preferredCurrencyCode = "PEN"
        return (account, [deposito, hoy])
    }

    private func intervals() -> (lastMonth: DateInterval, thisMonth: DateInterval) {
        let now = Date()
        let thisStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let lastStart = calendar.date(byAdding: .month, value: -1, to: thisStart) ?? thisStart
        let lastEnd = calendar.date(byAdding: .second, value: -1, to: thisStart) ?? thisStart
        let todayEnd = calendar.date(
            byAdding: .second, value: -1,
            to: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        ) ?? now
        return (DateInterval(start: lastStart, end: lastEnd), DateInterval(start: thisStart, end: todayEnd))
    }

    @Test("El saldo de un mes cerrado lleva «≈» igual que el del mes en curso, con la misma tasa dudosa")
    func closedPeriodBalance_marksLikeTheOpenOne() {
        let (account, txs) = saldoEnDolares()
        let (lastMonth, thisMonth) = intervals()
        let cerrado = BalanceKPICalculator.result(
            transactions: txs, accounts: [account], interval: lastMonth, period: .lastMonth,
            currencyCode: "PEN", converter: stale
        )
        let abierto = BalanceKPICalculator.result(
            transactions: txs, accounts: [account], interval: thisMonth, period: .thisMonth,
            currencyCode: "PEN", converter: stale
        )
        #expect(cerrado.hasDataInPeriod, "premisa: el caso recorre la rama del período cerrado con datos")
        #expect(abs(cerrado.value - 3_750) < 0.001)
        #expect(abierto.isApproximate, "premisa: el saldo vivo ya marcaba")
        #expect(cerrado.isApproximate, "hasta el 2026-11-23 valía false fijo y la marca se apagaba en «Mes pasado»")
    }

    @Test("Con la tasa del día, el saldo de un mes cerrado no lleva «≈»")
    func closedPeriodBalance_exact_noMark() {
        let (account, txs) = saldoEnDolares()
        let (lastMonth, _) = intervals()
        let cerrado = BalanceKPICalculator.result(
            transactions: txs, accounts: [account], interval: lastMonth, period: .lastMonth,
            currencyCode: "PEN", converter: exact
        )
        #expect(!cerrado.isApproximate)
    }

    /// El saldo es una resta: el denominador es el saldo mostrado. −100 USD dudosos (375) y +7.375 PEN ⇒ se ven 7.000 y
    /// lo dudoso es el 5,36 %; con la suma de lo convertido por divisa (7.750) sería el 4,84 % y no marcaría.
    @Test("El denominador del saldo cerrado es el saldo que se ve, no la suma por divisa")
    func closedPeriodBalance_denominatorIsTheShownBalance() {
        let dolares = Account(
            name: "USD", currencyCode: "USD", colorHex: "#6366F1", iconName: "dollarsign", type: "bank"
        )
        let soles = Account(
            name: "PEN", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank"
        )
        let (lastMonth, _) = intervals()
        let dia = calendar.date(byAdding: .day, value: 5, to: lastMonth.start) ?? lastMonth.start
        let gastoUSD = TransactionItem(
            date: dia, amount: -100, currencyCode: "USD", note: "", category: nil,
            account: dolares, tags: [], amountInPreferredCurrency: -375
        )
        gastoUSD.preferredCurrencyCode = "PEN"
        let ingresoPEN = TransactionItem(
            date: dia, amount: 7_375, currencyCode: "PEN", note: "", category: nil,
            account: soles, tags: [], amountInPreferredCurrency: 7_375
        )
        ingresoPEN.preferredCurrencyCode = "PEN"
        let result = TrendDataProcessor.processTrendData(
            transactions: [gastoUSD, ingresoPEN], accounts: [dolares, soles], metric: .balance, period: .lastMonth,
            grouping: .day, interval: lastMonth, currencyCode: "PEN", adjustment: .none, liveBalanceOverride: nil,
            converter: stale
        )
        #expect(abs(result.finalBalance - 7_000) < 0.001, "premisa: se ven 7.000")
        #expect(result.finalBalanceIsApproximate)
    }

    @Test("La curva expone la marca del cierre en `finalBalanceIsApproximate`")
    func trendProcessor_exposesTheClosingMark() {
        let (account, txs) = saldoEnDolares()
        let (lastMonth, _) = intervals()
        let result = TrendDataProcessor.processTrendData(
            transactions: txs, accounts: [account], metric: .balance, period: .lastMonth, grouping: .day,
            interval: lastMonth, currencyCode: "PEN", adjustment: .none, liveBalanceOverride: nil, converter: stale
        )
        #expect(result.liveAnchor == nil, "premisa: período cerrado, sin anchor")
        #expect(result.finalBalanceIsApproximate)
    }
}

// MARK: - Cableado (source-scan)

@Suite("Marca «≈» en Informes y tartas: cableado (source-scan)")
struct MarcaAproximadoCableadoTests {

    private static func code(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func count(_ needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    @Test("El header de las tartas pinta el total con su marca")
    func pieHeaderPassesTheMark() throws {
        let src = try Self.code("Yala/App/Views/Panel/PieChartVariationHeader.swift")
        #expect(src.contains("value: totalAmount,\n                        currencyCode: currencyCode,\n                        font: DS.Typography.headline,\n                        isEstimate: isApproximate"))
    }

    @Test("Los tres widgets de tarta pasan la marca al header y a la cifra sin comparativa")
    func pieWidgetsPassTheMark() throws {
        for name in ["Categories", "Subcategories", "Tags"] {
            let src = try Self.code("Yala/App/Views/Panel/\(name)PieWidget.swift")
            #expect(src.contains("isApproximate: totalIsApproximate") || src.contains("isApproximate: filteredTotalIsApproximate"), "\(name)")
            #expect(src.contains("filteredTotalIsApproximate"), "\(name)")
        }
    }

    @Test("Distribución y el Panel entregan la marca a las tres tartas")
    func hostsPassTheMark() throws {
        let stats = try Self.code("Yala/App/Views/Statistics/CategoriesTabView.swift")
        #expect(stats.contains("totalIsApproximate: categoryPieIsApproximate"))
        #expect(stats.contains("totalIsApproximate: subcategoryPieIsApproximate"))
        #expect(stats.contains("totalIsApproximate: tagPieIsApproximate"))
        let panel = try Self.code("Yala/App/Views/Panel/PanelWidgetSection.swift")
        #expect(panel.contains("totalIsApproximate: viewModel.categoriesTotalIsApproximate"))
        #expect(panel.contains("totalIsApproximate: viewModel.subcategoriesTotalIsApproximate"))
        #expect(panel.contains("totalIsApproximate: viewModel.tagsTotalIsApproximate"))
    }

    @Test("Informes pasa la marca a «Te quedó» y a la frase del período anterior")
    func reportNetPassesTheMark() throws {
        let view = try Self.code("Yala/App/Views/Reports/FinancialReportView.swift")
        #expect(view.contains("currentIsApproximate: viewModel.netFlowCurrentIsApproximate"))
        #expect(view.contains("previousIsApproximate: viewModel.netFlowPreviousIsApproximate"))
        let summary = try Self.code("Yala/App/Views/Reports/NetFlowSummaryView.swift")
        #expect(summary.contains("isEstimate: currentIsApproximate"))
        #expect(summary.contains("isEstimate: previousIsApproximate"))
    }

    @Test("El saldo de fin del Panel y el KPI de Tendencias leen la marca del cierre")
    func closedBalanceSurfacesReadTheMark() throws {
        let carousel = try Self.code("Yala/App/Views/Panel/TrendsCarouselWidget.swift")
        #expect(Self.count("isEstimate: viewModel.trendFinalBalanceIsApproximate", in: carousel) == 3)
        #expect(carousel.contains("amount(summary.endValue, viewModel.trendFinalBalanceIsApproximate)"),
                "la etiqueta de VoiceOver de la fila lleva la misma marca que el número")
        let trends = try Self.code("Yala/App/Views/Statistics/TrendsTabView.swift")
        #expect(trends.contains("isEstimate: currentKPIIsApproximate"))
        #expect(trends.contains("trendsViewModel.trendFinalBalanceIsApproximate"))
    }
}
