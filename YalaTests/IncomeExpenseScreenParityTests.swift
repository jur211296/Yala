//
//  IncomeExpenseScreenParityTests.swift
//  YalaTests
//
//  Ticket `records-standalone-amount-discrepancy` (card vl1q): el mismo mes daba ingresos y gastos distintos según la
//  pantalla en cuanto un movimiento no tenía categoría o su signo contradecía su categoría. Desde el 2026-10-23 todas
//  deciden ingreso o gasto con `TransactionClassificationLogic` (decisión de Jürgen del 2026-09-06: sin categoría, el
//  signo) y suman con signo.
//
//  El fixture es DISCRIMINANTE para las tres reglas viejas: con «sin categoría = gasto» (hero, widgets, Informe) el
//  ingreso sin categoría pasa al gasto; con «sin categoría no existe» (Flujo de caja, Observaciones, presupuestos) los
//  dos sin categoría desaparecen; y con la suma de magnitudes (hero, widgets) las dos filas de signo contrario a su
//  categoría suben su lado en vez de bajarlo. Cada regla vieja da una cifra distinta de 1.050 / 210.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Ingresos y gastos · misma cifra en todas las pantallas", .serialized)
struct IncomeExpenseScreenParityTests {

    /// 1.000 − 50 (en contra, en categoría de ingreso) + 100 (sin categoría, positivo).
    private let expectedIncome: Double = 1_050
    /// 200 − 30 (devolución en categoría de gasto) + 40 (sin categoría, negativo).
    private let expectedExpense: Double = 210

    private struct Fixture {
        let account: Account
        let txs: [TransactionItem]
        let salary: TransactionItem
        let incomeAgainst: TransactionItem
        let food: TransactionItem
        let refund: TransactionItem
        let uncategorizedIn: TransactionItem
        let uncategorizedOut: TransactionItem
    }

    private func fixture(_ context: ModelContext, date: Date) throws -> Fixture {
        let account = makeTestAccount(context: context, name: "Main", currencyCode: "PEN")
        let incomeCat = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let expenseCat = makeTestCategory(context: context, name: "Comida", isIncome: false)
        func tx(_ amount: Double, _ category: YalaCategory?) -> TransactionItem {
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            context.insert(item)
            return item
        }
        let salary = tx(1_000, incomeCat)
        let incomeAgainst = tx(-50, incomeCat)
        let food = tx(-200, expenseCat)
        let refund = tx(30, expenseCat)
        let uncategorizedIn = tx(100, nil)
        let uncategorizedOut = tx(-40, nil)
        try context.save()
        return Fixture(
            account: account,
            txs: [salary, incomeAgainst, food, refund, uncategorizedIn, uncategorizedOut],
            salary: salary, incomeAgainst: incomeAgainst, food: food, refund: refund,
            uncategorizedIn: uncategorizedIn, uncategorizedOut: uncategorizedOut
        )
    }

    /// Estado global del que depende `RecordsViewModel.applyFilters`, fijado y restaurado.
    private func withRecordsState(period: DetailPeriod, _ body: () throws -> Void) rethrows {
        let previousPeriod = SessionState.shared.selectedPeriod
        let key = AppPreferences.Keys.includeGroupTransactionsInFeed
        let previousInclude = UserDefaults.standard.object(forKey: key)
        SessionState.shared.selectedPeriod = period
        UserDefaults.standard.set(true, forKey: key)
        defer {
            SessionState.shared.selectedPeriod = previousPeriod
            if let previousInclude {
                UserDefaults.standard.set(previousInclude, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        try body()
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    /// Las seis superficies que pintan «ingresos» y «gastos» de un período, sobre los mismos movimientos, en tres
    /// períodos (el criterio del ticket).
    @Test(
        "Registros, hero del Panel, Flujo de caja, Tendencias, widgets e Informe dan la misma cifra",
        arguments: [DetailPeriod.thisMonth, .last7Days, .thisYear]
    )
    func everyScreenAgrees(period: DetailPeriod) throws {
        try withRecordsState(period: period) {
            let context = try makeTestContext()
            let now = Date.now
            let f = try fixture(context, date: now.addingTimeInterval(-60))
            let interval = period.dateInterval(now: now)
            let converter = MockCurrencyConverter()

            // Registros (cabecero de la pantalla y de la pestaña de Estadísticas).
            let records = RecordsViewModel()
            records.applyFilters(
                transactions: f.txs, accounts: [f.account], categories: [], tags: [], context: context,
                currencyCode: "PEN", converter: converter
            )
            let r = records.recordsSummary
            #expect(close(r.income, expectedIncome), "Registros ingreso: \(r.income)")
            #expect(close(r.expense, expectedExpense), "Registros gasto: \(r.expense)")

            // Hero del Panel.
            let month = DetailPeriod.thisMonth.dateInterval(now: now)
            let prev = DetailPeriod.lastMonth.dateInterval(now: now)
            let hero = HeroBucketsCalculator.calculate(
                transactions: f.txs, monthInterval: month, prevInterval: prev, periodInterval: interval,
                eligibleAccountIDs: [f.account.persistentModelID], currencyCode: "PEN", converter: converter
            )
            #expect(close(hero.periodIncome, expectedIncome), "hero ingreso: \(hero.periodIncome)")
            #expect(close(hero.periodExpense, expectedExpense), "hero gasto: \(hero.periodExpense)")
            #expect(close(hero.monthIncome, expectedIncome), "hero mes ingreso: \(hero.monthIncome)")
            #expect(close(hero.monthExpense, expectedExpense), "hero mes gasto: \(hero.monthExpense)")

            // Widget Flujo de caja (y el resumen de Observaciones, que lo lee).
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: f.txs, interval: interval, grouping: .day, currencyCode: "PEN", converter: converter
            )
            #expect(close(cashFlow.totalIncome, expectedIncome), "Flujo de caja ingreso: \(cashFlow.totalIncome)")
            #expect(close(cashFlow.totalExpense, expectedExpense), "Flujo de caja gasto: \(cashFlow.totalExpense)")

            // Tendencias.
            let trend = TrendDataProcessor.processTrendData(
                transactions: f.txs, accounts: [f.account], metric: .expense, period: period, grouping: .day,
                interval: interval, currencyCode: "PEN", converter: converter
            )
            #expect(close(trend.totalIncome, expectedIncome), "Tendencias ingreso: \(trend.totalIncome)")
            #expect(close(trend.totalExpense, expectedExpense), "Tendencias gasto: \(trend.totalExpense)")

            // Widgets de pantalla de inicio.
            let widget = WidgetDataCache.buildPeriodSummary(
                transactions: f.txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
                converter: converter
            )
            #expect(close(widget.totalIncome, expectedIncome), "widget ingreso: \(widget.totalIncome)")
            #expect(close(widget.totalExpense, expectedExpense), "widget gasto: \(widget.totalExpense)")

            // Informe, dimensión «Tipo»: el nodo de ingresos y el de gastos (con signo, como suma la tabla).
            let byType = PivotTableCalculator.buildTree(
                currentTransactions: f.txs, previousTransactions: [], hierarchy: [.tipo], preferredCurrency: "PEN",
                allTags: [], converter: converter
            )
            let pivotIncome = byType.filter(\.isIncome).reduce(0) { $0 + $1.amount }
            let pivotExpense = -byType.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
            #expect(close(pivotIncome, expectedIncome), "Informe ingreso: \(pivotIncome)")
            #expect(close(pivotExpense, expectedExpense), "Informe gasto: \(pivotExpense)")
        }
    }

    /// El mismo Informe no mueve un movimiento sin categoría de lado al cambiar de dimensión: hasta el 2026-10-23
    /// «Tipo» lo daba por ingreso y «Categoría», «Subcategoría» y «Cuenta» por gasto.
    @Test(
        "En el Informe, todas las dimensiones reparten ingreso y gasto igual",
        arguments: [ReportGroupingDimension.tipo, .categoria, .subcategoria, .cuenta]
    )
    func pivotDimensionsAgree(dimension: ReportGroupingDimension) throws {
        let context = try makeTestContext()
        let f = try fixture(context, date: Date.now.addingTimeInterval(-60))
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: f.txs, previousTransactions: [], hierarchy: [dimension], preferredCurrency: "PEN",
            allTags: [], converter: MockCurrencyConverter()
        )
        let income = nodes.filter(\.isIncome).reduce(0) { $0 + $1.amount }
        let expense = -nodes.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        #expect(close(income, expectedIncome), "\(dimension) ingreso: \(income)")
        #expect(close(expense, expectedExpense), "\(dimension) gasto: \(expense)")
    }

    /// Los chips «Ingresos» y «Gastos» reparten TODOS los movimientos: ninguno desaparece al filtrar (antes el sin
    /// categoría no pasaba ninguno de los dos), y cada uno cae del lado que cuentan los totales.
    @Test("Los filtros Ingresos y Gastos no esconden el movimiento sin categoría")
    func natureFiltersPartitionEveryMovement() throws {
        let context = try makeTestContext()
        let f = try fixture(context, date: Date.now.addingTimeInterval(-60))
        func matching(_ nature: TransactionNature) -> Set<PersistentIdentifier> {
            var criteria = FilterCriteria()
            criteria.selectedTransactionNatures = [nature]
            return Set(f.txs.filter { FilterService.matchesCriteria($0, criteria: criteria) }.map(\.persistentModelID))
        }
        let income = matching(.income)
        let expense = matching(.expense)
        #expect(income == Set([f.salary, f.incomeAgainst, f.uncategorizedIn].map(\.persistentModelID)))
        #expect(expense == Set([f.food, f.refund, f.uncategorizedOut].map(\.persistentModelID)))
        #expect(income.isDisjoint(with: expense))
        #expect(income.count + expense.count == f.txs.count)
    }

    /// Reclasificar redistribuye entre ingreso y gasto sin tocar el neto: `ingresos − gastos` es la suma de los
    /// importes, también para el hero, que antes sumaba magnitudes y se apartaba del neto.
    @Test("Ingresos − gastos es la suma de los importes en todas las pantallas")
    func netIsTheSumOfAmounts() throws {
        let context = try makeTestContext()
        let now = Date.now
        let f = try fixture(context, date: now.addingTimeInterval(-60))
        let net = f.txs.reduce(0) { $0 + $1.amount }
        #expect(close(net, expectedIncome - expectedExpense))
        let interval = DetailPeriod.thisMonth.dateInterval(now: now)
        let converter = MockCurrencyConverter()
        let hero = HeroBucketsCalculator.calculate(
            transactions: f.txs, monthInterval: interval, prevInterval: DetailPeriod.lastMonth.dateInterval(now: now),
            periodInterval: interval, eligibleAccountIDs: [f.account.persistentModelID], currencyCode: "PEN",
            converter: converter
        )
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: f.txs, interval: interval, grouping: .day, currencyCode: "PEN", converter: converter
        )
        let widget = WidgetDataCache.buildPeriodSummary(
            transactions: f.txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            converter: converter
        )
        #expect(close(hero.periodIncome - hero.periodExpense, net))
        #expect(close(cashFlow.netFlow, net))
        #expect(close(widget.netCashFlow, net))
    }

    /// La regla con datos sueltos (`isIncome(categoryIsIncome:signedAmount:)`) es la misma que la del movimiento: la
    /// usan el gasto por cuenta, los candidatos de un pago y el detalle.
    @Test("La regla con datos sueltos coincide con la del movimiento")
    func looseDataRuleMatchesTheTransactionRule() throws {
        let context = try makeTestContext()
        let f = try fixture(context, date: Date.now.addingTimeInterval(-60))
        for tx in f.txs {
            #expect(
                TransactionClassificationLogic.isIncome(tx)
                    == TransactionClassificationLogic.isIncome(
                        categoryIsIncome: tx.category?.isIncome, signedAmount: tx.amount
                    )
            )
        }
        // El cero cuenta como ingreso (el helper ya lo decía; el Informe decía gasto con `> 0`).
        #expect(TransactionClassificationLogic.isIncome(categoryIsIncome: nil, signedAmount: 0))
        // Gasto por cuenta: el sin categoría negativo cuenta y el positivo no.
        #expect(AccountSpendingLogic.spending(amount: -40, adjustmentType: nil, categoryIsIncome: nil) == 40)
        #expect(AccountSpendingLogic.spending(amount: 100, adjustmentType: nil, categoryIsIncome: nil) == nil)
    }
    // MARK: - Lo que dejó de poder leerse de la cifra (review del 2026-10-23)

    /// Gasto de 1.000 exacto, su devolución de 960 exacta y 40 con tasa dudosa: el gasto que se pinta es 80 en todas.
    /// La marca «≈» divide la parte dudosa entre las MAGNITUDES del lado (2.000, un 2 %), como el Flujo de caja; dividir
    /// entre el gasto con signo (80, un 50 %) marcaba el hero y los widgets y no el Flujo de caja.
    @Test("La marca «≈» del gasto es la misma en el hero, el Flujo de caja y los widgets")
    func approximateMarkAgreesAcrossScreens() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Main", currencyCode: "PEN")
        let food = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let date = Date.now.addingTimeInterval(-60)
        func tx(_ amount: Double, provisional: Bool) -> TransactionItem {
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: food, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN", isExchangeRateProvisional: provisional
            )
            context.insert(item)
            return item
        }
        let txs = [tx(-1_000, provisional: false), tx(960, provisional: false), tx(-40, provisional: true)]
        let interval = DetailPeriod.thisMonth.dateInterval(now: Date.now)
        let converter = MockCurrencyConverter()

        let hero = HeroBucketsCalculator.calculate(
            transactions: txs, monthInterval: interval, prevInterval: DetailPeriod.lastMonth.dateInterval(now: Date.now),
            periodInterval: interval, eligibleAccountIDs: [account.persistentModelID], currencyCode: "PEN",
            converter: converter
        )
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: txs, interval: interval, grouping: .day, currencyCode: "PEN", converter: converter
        )
        let widget = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            converter: converter
        )
        #expect(close(hero.periodExpense, 80) && close(cashFlow.totalExpense, 80) && close(widget.totalExpense, 80))
        #expect(cashFlow.expenseAmountsAreApproximate == false)
        #expect(hero.periodExpenseApproximate == cashFlow.expenseAmountsAreApproximate)
        #expect(widget.expenseIsApproximate == cashFlow.expenseAmountsAreApproximate)
    }

    /// Con una devolución, el gasto con signo queda por debajo de lo que suman las categorías en magnitud: los
    /// porcentajes del widget se calculan sobre las magnitudes y no pasan de 100 %.
    @Test("Los porcentajes de categorías del widget suman como mucho 100 %")
    func widgetCategoryPercentagesStayWithin100() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Main", currencyCode: "PEN")
        let food = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let clothes = makeTestCategory(context: context, name: "Ropa", isIncome: false)
        let date = Date.now.addingTimeInterval(-60)
        let txs = [(-100.0, food), (-50, clothes), (50, clothes)].map { amount, category in
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: category, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            context.insert(item)
            return item
        }
        let interval = DetailPeriod.thisMonth.dateInterval(now: Date.now)
        let widget = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            converter: MockCurrencyConverter()
        )
        #expect(close(widget.totalExpense, 100))
        let total = widget.topCategories.reduce(0) { $0 + $1.percentage }
        #expect(total <= 100.0001, "suman \(total) %")
    }

    /// Un gasto y su devolución dejan ingresos 0 y gastos 0 con movimientos: el hero no dice «Sin movimientos».
    @Test("El hero sabe que hubo movimientos aunque las cifras se anulen")
    func heroKnowsThereWereMovements() throws {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Main", currencyCode: "PEN")
        let food = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let date = Date.now.addingTimeInterval(-60)
        let txs = [-50.0, 50].map { amount in
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: food, account: account,
                amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            context.insert(item)
            return item
        }
        let interval = DetailPeriod.thisMonth.dateInterval(now: Date.now)
        let hero = HeroBucketsCalculator.calculate(
            transactions: txs, monthInterval: interval, prevInterval: DetailPeriod.lastMonth.dateInterval(now: Date.now),
            periodInterval: interval, eligibleAccountIDs: [account.persistentModelID], currencyCode: "PEN",
            converter: MockCurrencyConverter()
        )
        #expect(hero.periodIncome == 0 && hero.periodExpense == 0)
        #expect(hero.periodHasAnyTx)
        var data = PanelHeroPeriodData(income: hero.periodIncome, expense: hero.periodExpense)
        data.periodHadMovements = hero.periodHasAnyTx
        #expect(!data.hasNoMovements)
        #expect(PanelHeroPeriodData().hasNoMovements)
    }
}
