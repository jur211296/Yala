//
//  CombinedFiltersScreenParityTests.swift
//  YalaTests
//
//  Ticket `stats-filter-segment-tap-should-ask-include-or-exclude` (opción B de Jürgen del 2026-10-12): con «Solo X» y
//  «Sin Y» a la vez en el filtro de sesión, Registros, Estadísticas y el Panel tienen que dar las mismas cifras. Antes
//  había un solo modo global y la combinación no podía existir; ahora cada pantalla compone las dos listas, y si una
//  leyera solo una de ellas su cifra se separaría de las otras.
//
//  El fixture es DISCRIMINANTE: con lo oculto ignorado el gasto sube 140 (Uber 80 + la fila con «Viaje» 60); con lo
//  oculto tratado como «solo esto» cae casi a cero; y trae las filas que separan las reglas de ingreso/gasto
//  (`ingreso-gasto.md`): un movimiento sin categoría de cada signo y uno de signo contrario a su categoría.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Filtros combinados · misma cifra en Registros, Estadísticas y Panel", .serialized)
struct CombinedFiltersScreenParityTests {

    /// 1.000 − 50 (en contra, en categoría de ingreso) + 100 (sin categoría, positivo).
    private let expectedIncome: Double = 1_050
    /// 200 + 300 (cuenta B, incluida) + 40 (sin categoría, negativo) + 25 (Taxi sin etiqueta) − 30 (devolución).
    /// Fuera: Uber (subcategoría oculta, 80), Taxi con «Viaje» (etiqueta oculta, 60) y la cuenta fuera de estadísticas.
    private let expectedExpense: Double = 535

    private struct Fixture {
        let a: Account
        let b: Account
        let outOfStats: Account
        let categories: [YalaCategory]
        let uber: Subcategory
        let viaje: Yala.Tag
        let txs: [TransactionItem]
    }

    private func fixture(_ context: ModelContext) throws -> Fixture {
        let a = makeTestAccount(context: context, name: "A", currencyCode: "PEN")
        let b = makeTestAccount(context: context, name: "B", currencyCode: "PEN")
        let outOfStats = makeTestAccount(context: context, name: "Fuera", currencyCode: "PEN")
        outOfStats.excludeFromStatistics = true
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let transporte = makeTestCategory(context: context, name: "Transporte", isIncome: false)
        let mercado = makeTestSubcategory(context: context, name: "Mercado", category: comida)
        let uber = makeTestSubcategory(context: context, name: "Uber", category: comida, need: .optional)
        let taxi = makeTestSubcategory(context: context, name: "Taxi", category: transporte)
        let viaje = makeTestTag(context: context, name: "Viaje")
        let date = Date.now.addingTimeInterval(-3_600)

        func tx(
            _ amount: Double, _ account: Account, _ category: YalaCategory?, _ sub: Subcategory? = nil,
            tag: Yala.Tag? = nil
        ) -> TransactionItem {
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: category, subcategory: sub,
                account: account, tags: tag.map { [$0] } ?? [], amountInPreferredCurrency: amount,
                preferredCurrencyCode: "PEN", tagIDs: tag?.id.uuidString
            )
            context.insert(item)
            return item
        }
        let txs = [
            tx(1_000, a, sueldo),
            tx(-50, a, sueldo),
            tx(-200, a, comida, mercado),
            tx(-80, a, comida, uber),            // subcategoría oculta
            tx(30, a, comida, mercado),          // devolución
            tx(-300, b, comida, mercado),
            tx(100, a, nil),
            tx(-40, a, nil),
            tx(-60, a, transporte, taxi, tag: viaje),   // etiqueta oculta
            tx(-25, a, transporte, taxi),
            tx(-999, outOfStats, comida, mercado),      // fuera de estadísticas
        ]
        try context.save()
        return Fixture(
            a: a, b: b, outOfStats: outOfStats, categories: [sueldo, comida, transporte], uber: uber, viaje: viaje,
            txs: txs
        )
    }

    /// Filtro de sesión y estado global del que leen las tres pantallas, fijado y restaurado.
    private func withSession(_ apply: (SessionState) -> Void, _ body: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (
            session.selectedAccountIDs, session.selectedCategoryIDs, session.selectedSubcategoryIDs,
            session.selectedNeeds, session.selectedTransactionNatures, session.selectedTags,
            session.selectedCurrencies, session.amountCondition, session.searchText, session.excludedFilterSets,
            session.selectedPeriod, session.selectedTrendMetric
        )
        let feedKey = AppPreferences.Keys.includeGroupTransactionsInFeed
        let previousFeed = UserDefaults.standard.object(forKey: feedKey)
        UserDefaults.standard.set(true, forKey: feedKey)
        session.clearFilters()
        session.selectedPeriod = .allTime
        session.selectedTrendMetric = .expense
        apply(session)
        defer {
            session.clearFilters()
            session.selectedAccountIDs = saved.0
            session.selectedCategoryIDs = saved.1
            session.selectedSubcategoryIDs = saved.2
            session.selectedNeeds = saved.3
            session.selectedTransactionNatures = saved.4
            session.selectedTags = saved.5
            session.selectedCurrencies = saved.6
            session.amountCondition = saved.7
            session.searchText = saved.8
            session.excludedFilterSets = saved.9
            session.selectedPeriod = saved.10
            session.selectedTrendMetric = saved.11
            if let previousFeed {
                UserDefaults.standard.set(previousFeed, forKey: feedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: feedKey)
            }
        }
        try body()
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    @Test("«Solo A y B» + «Sin Uber» + «Sin Viaje»: Registros, Estadísticas y el Panel dan 1.050 / 535")
    func includedAndExcluded_sameTotalsOnEveryScreen() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        let accounts = [f.a, f.b, f.outOfStats]
        let converter = MockCurrencyConverter()

        try withSession({ session in
            session.selectedAccountIDs = [f.a.persistentModelID, f.b.persistentModelID]
            session.hide(.subcategory(f.uber.persistentModelID))
            session.hide(.tag(f.viaje.persistentModelID))
        }) {
            // Registros.
            let records = RecordsViewModel()
            records.applyFilters(
                transactions: f.txs, accounts: accounts, categories: f.categories, tags: [f.viaje], context: context,
                currencyCode: "PEN", converter: converter
            )
            #expect(close(records.recordsSummary.income, expectedIncome), "Registros ingreso: \(records.recordsSummary.income)")
            #expect(close(records.recordsSummary.expense, expectedExpense), "Registros gasto: \(records.recordsSummary.expense)")

            // Estadísticas (Tendencias): el KPI de la tarjeta.
            let stats = StatisticsViewModel(context: StatisticsContext(initialMetric: .expense, period: .allTime))
            stats.calculateTrendData(
                accounts: accounts, transactions: f.txs, allTags: [f.viaje], defaultCurrencyCode: "PEN"
            )
            #expect(close(stats.totalIncome, expectedIncome), "Estadísticas ingreso: \(stats.totalIncome)")
            #expect(close(stats.totalExpense, expectedExpense), "Estadísticas gasto: \(stats.totalExpense)")

            // Estadísticas, por el camino de los criterios del protocolo (el que usan Tendencias y el Informe).
            var criteria = stats.filterCriteria(withTagCatalog: [f.viaje])
            criteria.dateInterval = DetailPeriod.allTime.dateInterval()
            let statsFiltered = FilterService.filterForTrends(
                transactions: f.txs, accounts: accounts, criteria: criteria, includeBridgedGroupTx: true
            )
            let totals = StatisticsViewModel.periodTotals(
                filtered: statsFiltered, currencyCode: "PEN", adjustment: .none, converter: converter
            )
            #expect(close(totals.income, expectedIncome), "criterios ingreso: \(totals.income)")
            #expect(close(totals.expense, expectedExpense), "criterios gasto: \(totals.expense)")

            // Panel: sus criterios propios (`buildFilterCriteria`) sobre las cuentas que el Panel da por elegibles, con
            // el mismo cálculo que su widget de Flujo de caja.
            let panel = PanelViewModel()
            var panelCriteria = panel.buildFilterCriteria(dateInterval: DetailPeriod.allTime.dateInterval())
            // El Panel rellena las etiquetas con su catálogo cargado; aquí no hay carga, se le da el mismo.
            panelCriteria.populateTagUUIDs(fromCatalog: [f.viaje])
            let eligible = Set(accounts.filter {
                !$0.excludeFromStatistics
                    && EntityFilter(included: panel.selectedAccountIDs, excluded: panel.excludedAccountIDs)
                        .matches($0.persistentModelID)
            }.map(\.persistentModelID))
            let panelFiltered = f.txs.filter { tx in
                guard let id = tx.account?.persistentModelID, eligible.contains(id) else { return false }
                return FilterService.matchesCriteria(tx, criteria: panelCriteria)
            }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: panelFiltered, interval: DetailPeriod.allTime.dateInterval(), grouping: .month,
                currencyCode: "PEN", converter: converter
            )
            #expect(close(cashFlow.totalIncome, expectedIncome), "Panel ingreso: \(cashFlow.totalIncome)")
            #expect(close(cashFlow.totalExpense, expectedExpense), "Panel gasto: \(cashFlow.totalExpense)")
        }
    }

    /// Lo oculto de una dimensión no recorta otra: «Sin Uber» deja Mercado, y «Solo Comida» + «Sin Uber» es Comida sin
    /// Uber (el caso de la maqueta de Jürgen).
    @Test("«Solo Comida» + «Sin Uber»: Comida sin Uber en Registros y Estadísticas")
    func onlyCategory_withoutOneOfItsSubcategories() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        let accounts = [f.a, f.b, f.outOfStats]
        let comida = try #require(f.categories.first { $0.name == "Comida" })
        let converter = MockCurrencyConverter()
        // Comida en cuentas contables: −200 −80 +30 −300 = 550 de gasto; sin Uber, 470.
        let expected: Double = 470

        try withSession({ session in
            session.selectedCategoryIDs = [comida.persistentModelID]
            session.hide(.subcategory(f.uber.persistentModelID))
        }) {
            let records = RecordsViewModel()
            records.applyFilters(
                transactions: f.txs, accounts: accounts, categories: f.categories, tags: [f.viaje], context: context,
                currencyCode: "PEN", converter: converter
            )
            #expect(close(records.recordsSummary.expense, expected), "Registros: \(records.recordsSummary.expense)")
            #expect(close(records.recordsSummary.income, 0), "Registros ingreso: \(records.recordsSummary.income)")

            let stats = StatisticsViewModel(context: StatisticsContext(initialMetric: .expense, period: .allTime))
            stats.calculateTrendData(
                accounts: accounts, transactions: f.txs, allTags: [f.viaje], defaultCurrencyCode: "PEN"
            )
            #expect(close(stats.totalExpense, expected), "Estadísticas: \(stats.totalExpense)")
        }
    }

    /// El saldo: «Sin B» en el Panel (todas las cuentas + el filtro) y en el KPI de Distribución (las elegibles) da lo
    /// mismo, y es el saldo de A entero. Lo de una cuenta oculta no se cuela, y «Sin Uber» o «Sin Viaje» no restan nada:
    /// hasta el 2026-10-25 el KPI de Distribución sí los aplicaba (675 − 80 − 60 = 535).
    @Test("«Sin B» + «Sin Uber» + «Sin Viaje»: el saldo del Panel y el KPI de Distribución dicen lo mismo")
    func hiddenAccount_balanceParity() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        let accounts = [f.a, f.b, f.outOfStats]
        // A: 1.000 − 50 − 200 − 80 + 30 + 100 − 40 − 60 − 25.
        let expectedA: Double = 675

        try withSession({ session in
            session.hide(.account(f.b.persistentModelID))
            // Lo oculto de otras dimensiones no mueve un saldo (decisión del 2026-10-22): ni en el Panel ni en Distribución.
            session.hide(.subcategory(f.uber.persistentModelID))
            session.hide(.tag(f.viaje.persistentModelID))
        }) {
            let panel = PanelViewModel()
            let big = panel.displayedBalanceInDefaultCurrency(
                accounts: accounts, transactions: f.txs, defaultCurrencyCode: "PEN"
            )
            let panelValue = NSDecimalNumber(decimal: big.convertedTotal).doubleValue

            let stats = StatisticsViewModel(context: StatisticsContext(initialMetric: .expense, period: .allTime))
            let kpi = stats.balanceKPI(
                accounts: accounts, transactions: f.txs, allTags: [f.viaje], defaultCurrencyCode: "PEN",
                converter: MockCurrencyConverter()
            )
            #expect(close(panelValue, expectedA), "Panel: \(panelValue)")
            #expect(close(kpi.value, expectedA), "Distribución: \(kpi.value)")
        }
    }
}
