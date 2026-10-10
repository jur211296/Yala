//
//  StatsAggregatorsPreferredCurrencyTests.swift
//  YalaTests
//
//  Ticket `stats-aggregators-sum-stored-amounts-from-other-preferred-currencies`: el flujo de
//  Distribución, el gasto por etiqueta, la tabla dinámica de Informes y el hero sumaban el
//  `amountInPreferredCurrency` guardado sin mirar EN QUÉ divisa principal se guardó. Tras cambiar de
//  divisa principal, las filas sin recalcular mezclaban dos escalas con el símbolo de la vigente.
//
//  Los cuatro resuelven ahora cada fila con `CashFlowCalculator.resolvedAmount`, la regla que ya
//  usan el Panel y Registros. Cada superficie lleva las dos direcciones:
//  El neto de Informes va con la tabla dinámica (está encima de ella y sumaría distinto), y la
//  tarjeta de Tendencias —total, curva y su KPI en Estadísticas— con el hero del Panel, que
//  comparte pantalla con ella.
//  - **mezcla**: una fila en soles y otra guardada cuando la principal era USD ⇒ la de USD se
//    reconvierte (con el código viejo el total sale con las dos escalas sumadas);
//  - **una sola divisa**: todo guardado en la principal ⇒ el converter no interviene. La tasa del
//    doble es absurda a propósito: cualquier reconversión de más se ve en el total.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Totales de Estadísticas e Informes · divisas principales mezcladas", .serialized)
struct StatsAggregatorsPreferredCurrencyTests {

    /// 1 USD = 3,7 PEN en el doble.
    private let tasaUSD: Decimal = 3.7
    /// Tasa que ninguna fila debería usar en el caso de una sola divisa.
    private let tasaAbsurda: Decimal = 1_000

    private let calendar = Calendar.current

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
    }

    private var abril: DateInterval {
        let start = day(2026, 4, 1)
        let startOfApril = calendar.startOfDay(for: start)
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfApril) ?? start
        return DateInterval(start: startOfApril, end: end)
    }

    private var marzo: DateInterval {
        let startOfMarch = calendar.startOfDay(for: day(2026, 3, 1))
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMarch) ?? startOfMarch
        return DateInterval(start: startOfMarch, end: end)
    }

    private let cuenta = Account(
        name: "Principal", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "bank"
    )
    private let comida = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
    private let sueldo = YalaCategory(name: "Sueldo", colorHex: "#00FF00", isIncome: true)
    private let viaje = YalaTag(name: "Viaje", colorHex: "#0000FF")

    /// Una fila con su monto nativo y el monto que se guardó cuando la principal era `guardadaEn`.
    private func tx(
        nativo: Double, divisa: String, guardado: Double, guardadaEn: String,
        category: YalaCategory, date: Date? = nil, provisional: Bool = false
    ) -> TransactionItem {
        TransactionItem(
            date: date ?? day(2026, 4, 10), amount: nativo, currencyCode: divisa, note: "",
            category: category, account: cuenta, tags: [viaje],
            amountInPreferredCurrency: guardado, preferredCurrencyCode: guardadaEn,
            isExchangeRateProvisional: provisional
        )
    }

    /// Principal PEN: un gasto y un ingreso ya en soles, y otro par guardado cuando la principal era
    /// USD y sin recalcular. Gasto correcto: 100 + 50 × 3,7 = 285 (el viejo: 150). Ingreso correcto:
    /// 1.000 + 200 × 3,7 = 1.740 (el viejo: 1.200).
    private func mezcla(date: Date? = nil) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -50, guardadaEn: "USD", category: comida, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 200, guardadaEn: "USD", category: sueldo, date: date),
        ]
    }

    /// Las mismas filas de USD, ya recalculadas a soles: todo guardado en la principal.
    private func unaSolaDivisa(date: Date? = nil) -> [TransactionItem] {
        [
            tx(nativo: -100, divisa: "PEN", guardado: -100, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 1_000, divisa: "PEN", guardado: 1_000, guardadaEn: "PEN", category: sueldo, date: date),
            tx(nativo: -50, divisa: "USD", guardado: -185, guardadaEn: "PEN", category: comida, date: date),
            tx(nativo: 200, divisa: "USD", guardado: 740, guardadaEn: "PEN", category: sueldo, date: date),
        ]
    }

    private func cerca(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    // MARK: - Distribución (Sankey)

    @Test("Distribución: las filas guardadas en otra divisa se reconvierten antes de sumar")
    func sankey_mixedPreferredCurrencies_convertsBeforeSumming() {
        let data = SankeyFlowCalculator.compute(
            transactions: mezcla(), interval: abril, currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        #expect(cerca(data.totalExpense, 285), "gasto: \(data.totalExpense)")
        #expect(cerca(data.totalIncome, 1_740), "ingreso: \(data.totalIncome)")
    }

    @Test("Distribución: con todo en la principal, lee el monto guardado")
    func sankey_singlePreferredCurrency_readsStoredAmounts() {
        let data = SankeyFlowCalculator.compute(
            transactions: unaSolaDivisa(), interval: abril, currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasaAbsurda)
        )
        #expect(cerca(data.totalExpense, 285), "gasto: \(data.totalExpense)")
        #expect(cerca(data.totalIncome, 1_740), "ingreso: \(data.totalIncome)")
    }

    // MARK: - Gasto por etiqueta

    @Test("Etiquetas: las filas guardadas en otra divisa se reconvierten antes de sumar")
    func tags_mixedPreferredCurrencies_convertsBeforeSumming() throws {
        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: mezcla(), interval: abril, currencyCode: "PEN",
            allTags: [viaje], converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        let fila = try #require(result.first)
        #expect(cerca(fila.amount, 285), "gasto de «Viaje»: \(fila.amount)")
    }

    @Test("Etiquetas: con todo en la principal, lee el monto guardado")
    func tags_singlePreferredCurrency_readsStoredAmounts() throws {
        let result = TagSpendingCalculator.calculateTopSpending(
            transactions: unaSolaDivisa(), interval: abril, currencyCode: "PEN",
            allTags: [viaje], converter: MockCurrencyConverter(fixedRate: tasaAbsurda)
        )
        let fila = try #require(result.first)
        #expect(cerca(fila.amount, 285), "gasto de «Viaje»: \(fila.amount)")
    }

    // MARK: - Tabla dinámica de Informes (período actual y anterior)

    private func nodos(_ actual: [TransactionItem], _ anterior: [TransactionItem], tasa: Decimal) -> [PivotNode] {
        PivotTableCalculator.buildTree(
            currentTransactions: actual, previousTransactions: anterior,
            hierarchy: [.tipo], preferredCurrency: "PEN", allTags: [viaje],
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    @Test("Tabla dinámica: las dos columnas reconvierten las filas guardadas en otra divisa")
    func pivot_mixedPreferredCurrencies_convertsBothPeriods() throws {
        let result = nodos(mezcla(), mezcla(date: day(2026, 3, 10)), tasa: tasaUSD)
        let gasto = try #require(result.first { !$0.isIncome })
        let ingreso = try #require(result.first { $0.isIncome })
        #expect(cerca(gasto.amount, -285), "gasto actual: \(gasto.amount)")
        #expect(cerca(ingreso.amount, 1_740), "ingreso actual: \(ingreso.amount)")
        let gastoAnterior = try #require(gasto.previousAmount)
        let ingresoAnterior = try #require(ingreso.previousAmount)
        #expect(cerca(gastoAnterior, -285), "gasto anterior: \(gastoAnterior)")
        #expect(cerca(ingresoAnterior, 1_740), "ingreso anterior: \(ingresoAnterior)")
    }

    @Test("Tabla dinámica: con todo en la principal, lee el monto guardado")
    func pivot_singlePreferredCurrency_readsStoredAmounts() throws {
        let result = nodos(unaSolaDivisa(), unaSolaDivisa(date: day(2026, 3, 10)), tasa: tasaAbsurda)
        let gasto = try #require(result.first { !$0.isIncome })
        #expect(cerca(gasto.amount, -285), "gasto actual: \(gasto.amount)")
        let gastoAnterior = try #require(gasto.previousAmount)
        #expect(cerca(gastoAnterior, -285), "gasto anterior: \(gastoAnterior)")
    }

    // MARK: - Hero del Panel

    private func hero(_ txs: [TransactionItem], converter: CurrencyConverting) -> HeroBucketsCalculator.Buckets {
        HeroBucketsCalculator.calculate(
            transactions: txs, monthInterval: abril, prevInterval: marzo, periodInterval: abril,
            eligibleAccountIDs: [cuenta.persistentModelID], currencyCode: "PEN", converter: converter
        )
    }

    @Test("Hero: las filas guardadas en otra divisa se reconvierten antes de sumar")
    func hero_mixedPreferredCurrencies_convertsBeforeSumming() {
        let b = hero(mezcla(), converter: MockCurrencyConverter(fixedRate: tasaUSD))
        #expect(cerca(b.periodExpense, 285), "gasto del período: \(b.periodExpense)")
        #expect(cerca(b.periodIncome, 1_740), "ingreso del período: \(b.periodIncome)")
        #expect(cerca(b.monthExpense, 285), "gasto del mes: \(b.monthExpense)")
        #expect(cerca(b.monthIncome, 1_740), "ingreso del mes: \(b.monthIncome)")
        // Con tasa exacta, la reconversión no marca.
        #expect(!b.periodExpenseApproximate)
        #expect(!b.periodIncomeApproximate)
    }

    @Test("Hero: el mes anterior también reconvierte")
    func hero_previousMonth_convertsBeforeSumming() {
        let b = hero(mezcla(date: day(2026, 3, 10)), converter: MockCurrencyConverter(fixedRate: tasaUSD))
        #expect(cerca(b.prevExpense, 285), "gasto del mes anterior: \(b.prevExpense)")
    }

    /// La marca sale de la conversión que de verdad se hizo: si la tasa con que se reconvierte la fila
    /// de USD no es la de su día, el número lleva «≈». Las filas en soles no pasan por el converter.
    @Test("Hero: una reconversión con tasa no exacta marca el lado al que pesa")
    func hero_inexactReconversion_marks() {
        let b = hero(mezcla(), converter: MockCurrencyConverter(
            fixedRate: tasaUSD, quality: .carriedForward(fromDateKey: "2026-04-09")
        ))
        #expect(b.periodExpenseApproximate, "185 de 285 salen de una tasa que no era la del día")
        #expect(b.periodIncomeApproximate, "740 de 1.740 salen de una tasa que no era la del día")
    }

    @Test("Hero: con todo en la principal, lee el monto guardado y no marca")
    func hero_singlePreferredCurrency_readsStoredAmounts() {
        let b = hero(unaSolaDivisa(), converter: MockCurrencyConverter(
            fixedRate: tasaAbsurda, quality: .carriedForward(fromDateKey: "2026-04-09")
        ))
        #expect(cerca(b.periodExpense, 285), "gasto del período: \(b.periodExpense)")
        #expect(cerca(b.periodIncome, 1_740), "ingreso del período: \(b.periodIncome)")
        #expect(!b.periodExpenseApproximate)
        #expect(!b.periodIncomeApproximate)
    }

    // MARK: - Neto de Informes (encima de la tabla dinámica)

    /// Filtros de sesión de los que lee `calculateReport`, fijados y restaurados.
    private func conFiltrosLimpios(_ cuerpo: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (session.selectedAccountIDs, session.selectedCategoryIDs, session.selectedSubcategoryIDs,
                     session.selectedNeeds, session.selectedTransactionNatures, session.selectedTags,
                     session.selectedCurrencies, session.amountCondition, session.searchText, session.isExcludeMode)
        defer {
            session.selectedAccountIDs = saved.0
            session.selectedCategoryIDs = saved.1
            session.selectedSubcategoryIDs = saved.2
            session.selectedNeeds = saved.3
            session.selectedTransactionNatures = saved.4
            session.selectedTags = saved.5
            session.selectedCurrencies = saved.6
            session.amountCondition = saved.7
            session.searchText = saved.8
            session.isExcludeMode = saved.9
        }
        try cuerpo()
    }

    private func informe(_ txs: [TransactionItem], tasa: Decimal) -> FinancialReportViewModel {
        let vm = FinancialReportViewModel()
        vm.clearFilters()
        vm.calculateReport(
            transactions: txs, accounts: [cuenta], preferredCurrency: "PEN", allTags: [viaje],
            now: day(2026, 5, 15), period: .lastMonth, comparisonMode: .month, expensesOnly: false,
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
        return vm
    }

    @Test("Informes: el neto reconvierte las filas guardadas en otra divisa, como su tabla")
    func report_mixedPreferredCurrencies_netFlowConvertsBothPeriods() throws {
        try conFiltrosLimpios {
            let vm = informe(mezcla() + mezcla(date: day(2026, 3, 10)), tasa: tasaUSD)
            // 1.740 − 285 = 1.455 (el viejo: 1.200 − 150 = 1.050).
            #expect(cerca(vm.netFlowCurrent, 1_455), "neto actual: \(vm.netFlowCurrent)")
            let anterior = try #require(vm.netFlowPrevious)
            #expect(cerca(anterior, 1_455), "neto anterior: \(anterior)")
            let sumaDeLaTabla = vm.rootNodes.reduce(0) { $0 + $1.amount }
            #expect(cerca(vm.netFlowCurrent, sumaDeLaTabla), "neto \(vm.netFlowCurrent) ≠ tabla \(sumaDeLaTabla)")
        }
    }

    @Test("Informes: con todo en la principal, el neto lee el monto guardado")
    func report_singlePreferredCurrency_readsStoredAmounts() throws {
        try conFiltrosLimpios {
            let vm = informe(unaSolaDivisa() + unaSolaDivisa(date: day(2026, 3, 10)), tasa: tasaAbsurda)
            #expect(cerca(vm.netFlowCurrent, 1_455), "neto actual: \(vm.netFlowCurrent)")
            let anterior = try #require(vm.netFlowPrevious)
            #expect(cerca(anterior, 1_455), "neto anterior: \(anterior)")
        }
    }

    // MARK: - Tarjeta de Tendencias (Panel y Estadísticas): total y curva

    /// Comparte pantalla con el hero del Panel: si uno reconvierte y el otro no, el Panel enseña dos
    /// números para el mismo dinero.
    private func tendencia(_ txs: [TransactionItem], metrica: TrendType, tasa: Decimal)
        -> TrendDataProcessor.TrendProcessingResult
    {
        TrendDataProcessor.processTrendData(
            transactions: txs, accounts: [cuenta], metric: metrica, period: .lastMonth,
            grouping: .day, interval: abril, currencyCode: "PEN",
            converter: MockCurrencyConverter(fixedRate: tasa)
        )
    }

    @Test("Tendencias: el total y la curva reconvierten las filas guardadas en otra divisa")
    func trend_mixedPreferredCurrencies_convertsTotalsAndCurve() throws {
        let gasto = tendencia(mezcla(), metrica: .expense, tasa: tasaUSD)
        #expect(cerca(gasto.totalExpense, 285), "gasto: \(gasto.totalExpense)")
        #expect(cerca(gasto.totalIncome, 1_740), "ingreso: \(gasto.totalIncome)")
        let finCurvaGasto = try #require(gasto.rawPoints.last?.value)
        #expect(cerca(finCurvaGasto, 285), "curva de gasto: \(finCurvaGasto)")
        let ingreso = tendencia(mezcla(), metrica: .income, tasa: tasaUSD)
        let finCurvaIngreso = try #require(ingreso.rawPoints.last?.value)
        #expect(cerca(finCurvaIngreso, 1_740), "curva de ingreso: \(finCurvaIngreso)")
    }

    @Test("Tendencias: con todo en la principal, el total y la curva leen el monto guardado")
    func trend_singlePreferredCurrency_readsStoredAmounts() throws {
        let gasto = tendencia(unaSolaDivisa(), metrica: .expense, tasa: tasaAbsurda)
        #expect(cerca(gasto.totalExpense, 285), "gasto: \(gasto.totalExpense)")
        #expect(cerca(gasto.totalIncome, 1_740), "ingreso: \(gasto.totalIncome)")
        let finCurvaGasto = try #require(gasto.rawPoints.last?.value)
        #expect(cerca(finCurvaGasto, 285), "curva de gasto: \(finCurvaGasto)")
        let ingreso = tendencia(unaSolaDivisa(), metrica: .income, tasa: tasaAbsurda)
        let finCurvaIngreso = try #require(ingreso.rawPoints.last?.value)
        #expect(cerca(finCurvaIngreso, 1_740), "curva de ingreso: \(finCurvaIngreso)")
    }

    @Test("Estadísticas: el KPI de la tarjeta de Tendencias reconvierte como su curva")
    func statisticsKPI_mixedPreferredCurrencies_convertsBeforeSumming() {
        let t = StatisticsViewModel.periodTotals(
            filtered: mezcla(), currencyCode: "PEN", adjustment: .none,
            converter: MockCurrencyConverter(fixedRate: tasaUSD)
        )
        #expect(cerca(t.expense, 285), "gasto: \(t.expense)")
        #expect(cerca(t.income, 1_740), "ingreso: \(t.income)")
    }

    @Test("Estadísticas: con todo en la principal, el KPI lee el monto guardado")
    func statisticsKPI_singlePreferredCurrency_readsStoredAmounts() {
        let t = StatisticsViewModel.periodTotals(
            filtered: unaSolaDivisa(), currencyCode: "PEN", adjustment: .none,
            converter: MockCurrencyConverter(fixedRate: tasaAbsurda)
        )
        #expect(cerca(t.expense, 285), "gasto: \(t.expense)")
        #expect(cerca(t.income, 1_740), "ingreso: \(t.income)")
    }
}
