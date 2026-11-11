//
//  ArchivedAccountKeepsHistoryTests.swift
//  YalaTests
//
//  Archivar saca la cuenta del saldo y conserva su historial (opción A del 2026-10-08, adelantada a 2.3 en la decisión 6
//  del 2026-11-09; card «Archivar una cuenta: decidir si oculta su historial…»). Las dos preguntas viven en
//  `AccountScopeLogic`, y aquí se fija que cada pantalla haga la que le toca.
//
//  El fixture es DISCRIMINANTE: trae las cuatro combinaciones de los dos flags, cada una con su importe, y así la regla
//  vieja da otra cifra en cada aserción.
//  - «Activa»: suma y se ve.
//  - «Archivada» (como la deja el downgrade, o archivar antes del 2026-10-03): con la regla vieja SUMABA al saldo.
//  - «Archivada y excluida» (como la dejaba archivar desde el formulario hasta esta decisión, también en la 2.1): con la
//    regla vieja su historial DESAPARECÍA de Registros y de Estadísticas.
//  - «Excluida» (activa, a mano): ni suma ni se ve, antes y ahora.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Archivar · las dos reglas puras")
struct AccountScopeLogicTests {
    @Test("Saldo: solo la activa sin excluir; historial: todas menos la activa excluida")
    func truthTable() {
        let cases: [(excluded: Bool, archived: Bool, sums: Bool, history: Bool)] = [
            (false, false, true, true),
            (false, true, false, true),
            (true, true, false, true),
            (true, false, false, false),
        ]
        for c in cases {
            #expect(
                AccountScopeLogic.sumsInBalance(isExcludedFromStatistics: c.excluded, isArchived: c.archived) == c.sums,
                "sumsInBalance(excluida: \(c.excluded), archivada: \(c.archived))"
            )
            #expect(
                AccountScopeLogic.keepsHistory(isExcludedFromStatistics: c.excluded, isArchived: c.archived) == c.history,
                "keepsHistory(excluida: \(c.excluded), archivada: \(c.archived))"
            )
        }
        // La cuenta sistema de Grupos que la app archiva (duplicada) conserva sus movimientos y sigue sumando.
        #expect(AccountScopeLogic.sumsInBalance(isExcludedFromStatistics: false, isArchived: true, isSystemAccount: true))
        #expect(!AccountScopeLogic.sumsInBalance(isExcludedFromStatistics: true, isArchived: true, isSystemAccount: true))
    }
}

@MainActor
@Suite("Archivar · conserva el historial y sale del saldo en cada pantalla", .serialized)
struct ArchivedAccountKeepsHistoryTests {

    // Gastos: activa 100 · archivada 40 · archivada y excluida 20 · excluida 7 (no se ve).
    private let expectedExpense: Double = 160
    // Ingreso: el sueldo de la activa.
    private let expectedIncome: Double = 1_000
    // Saldo: solo la activa (1.000 − 100). Con la regla vieja, 900 − 40 + 500 (saldo inicial de la archivada).
    private let expectedBalance: Double = 900

    private struct Fixture {
        let active: Account
        let archived: Account
        let archivedExcluded: Account
        let excluded: Account
        let categories: [YalaCategory]
        let txs: [TransactionItem]
        var accounts: [Account] { [active, archived, archivedExcluded, excluded] }
    }

    private func fixture(_ context: ModelContext) throws -> Fixture {
        let active = makeTestAccount(context: context, name: "Activa", currencyCode: "PEN")
        let archived = makeTestAccount(context: context, name: "Archivada", currencyCode: "PEN")
        archived.isArchived = true
        let archivedExcluded = makeTestAccount(context: context, name: "Archivada y excluida", currencyCode: "PEN")
        archivedExcluded.isArchived = true
        archivedExcluded.excludeFromStatistics = true
        let excluded = makeTestAccount(context: context, name: "Excluida", currencyCode: "PEN")
        excluded.excludeFromStatistics = true
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let mercado = makeTestSubcategory(context: context, name: "Mercado", category: comida)
        let date = aMomentAgoToday()

        func tx(_ amount: Double, _ account: Account, _ category: YalaCategory?, _ sub: Subcategory? = nil,
                adjustment: String? = nil) -> TransactionItem {
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: "PEN", note: "", category: category, subcategory: sub,
                account: account, amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
            )
            item.balanceAdjustmentType = adjustment
            context.insert(item)
            return item
        }
        let txs = [
            tx(1_000, active, sueldo),
            tx(-100, active, comida, mercado),
            tx(500, archived, nil, adjustment: InitialBalanceService.typeInitialBalance),
            tx(-40, archived, comida, mercado),
            tx(-20, archivedExcluded, comida, mercado),
            tx(-7, excluded, comida, mercado),
        ]
        try context.save()
        return Fixture(
            active: active, archived: archived, archivedExcluded: archivedExcluded, excluded: excluded,
            categories: [sueldo, comida], txs: txs
        )
    }

    /// El filtro de sesión y el estado global que leen las pantallas, limpios y restaurados.
    private func withCleanSession(_ body: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (session.selectedAccountIDs, session.excludedFilterSets, session.selectedPeriod,
                     session.selectedTrendMetric, session.isExpensesOnlyMode)
        let feedKey = AppPreferences.Keys.includeGroupTransactionsInFeed
        let previousFeed = UserDefaults.standard.object(forKey: feedKey)
        UserDefaults.standard.set(true, forKey: feedKey)
        session.clearFilters()
        session.selectedPeriod = .allTime
        session.selectedTrendMetric = .expense
        session.isExpensesOnlyMode = false
        defer {
            session.clearFilters()
            session.selectedAccountIDs = saved.0
            session.excludedFilterSets = saved.1
            session.selectedPeriod = saved.2
            session.selectedTrendMetric = saved.3
            session.isExpensesOnlyMode = saved.4
            if let previousFeed {
                UserDefaults.standard.set(previousFeed, forKey: feedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: feedKey)
            }
        }
        try body()
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.001 }

    @Test("Registros y Estadísticas siguen contando lo gastado con una cuenta archivada, también si quedó excluida")
    func archivedAccounts_keepTheirHistory() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        let converter = MockCurrencyConverter()
        withCleanSession {
            let records = RecordsViewModel()
            records.applyFilters(
                transactions: f.txs, accounts: f.accounts, categories: f.categories, tags: [], context: context,
                currencyCode: "PEN", converter: converter
            )
            #expect(close(records.recordsSummary.expense, expectedExpense), "Registros gasto: \(records.recordsSummary.expense)")
            #expect(close(records.recordsSummary.income, expectedIncome), "Registros ingreso: \(records.recordsSummary.income)")
            let shown = Set(records.groupedRecords.flatMap(\.records).compactMap { $0.account?.name })
            #expect(shown.contains("Archivada y excluida"), "Registros no enseña la archivada que quedó excluida: \(shown)")
            #expect(!shown.contains("Excluida"), "Registros enseña la cuenta activa excluida: \(shown)")

            let stats = StatisticsViewModel(context: StatisticsContext(initialMetric: .expense, period: .allTime))
            stats.calculateTrendData(accounts: f.accounts, transactions: f.txs, allTags: [], defaultCurrencyCode: "PEN")
            #expect(close(stats.totalExpense, expectedExpense), "Estadísticas gasto: \(stats.totalExpense)")

            var criteria = stats.filterCriteria(withTagCatalog: [])
            criteria.dateInterval = DetailPeriod.allTime.dateInterval()
            let filtered = FilterService.filterForTrends(
                transactions: f.txs, accounts: f.accounts, criteria: criteria, includeBridgedGroupTx: true
            )
            let names = Set(filtered.compactMap { $0.account?.name })
            #expect(names == ["Activa", "Archivada", "Archivada y excluida"], "filterForTrends: \(names)")
        }
    }

    @Test("El saldo del Panel, el de Distribución y el «en N cuentas» dejan fuera toda cuenta archivada")
    func archivedAccounts_leaveTheBalance() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        try withCleanSession {
            let live = LiveBalanceCalculator.liveBalance(
                accounts: f.accounts, transactions: f.txs, preferredCurrencyCode: "PEN", converter: MockCurrencyConverter()
            )
            #expect(close(live, expectedBalance), "Saldo vivo: \(live)")

            let panel = PanelViewModel()
            let big = panel.displayedBalanceInDefaultCurrency(
                accounts: f.accounts, transactions: f.txs, defaultCurrencyCode: "PEN"
            )
            let panelValue = NSDecimalNumber(decimal: big.convertedTotal).doubleValue
            #expect(close(panelValue, expectedBalance), "Panel: \(panelValue)")

            let stats = StatisticsViewModel(context: StatisticsContext(initialMetric: .expense, period: .allTime))
            let kpi = stats.balanceKPI(
                accounts: f.accounts, transactions: f.txs, allTags: [], defaultCurrencyCode: "PEN",
                converter: MockCurrencyConverter()
            )
            #expect(close(kpi.value, expectedBalance), "Distribución: \(kpi.value)")

            let countable = PanelTotalAccountsLogic.countableAccounts(f.accounts).map(\.name)
            #expect(countable == ["Activa"], "«en N cuentas»: \(countable)")
            #expect(PanelBalanceScopeLogic.accounts(
                eligible: f.accounts, includeGroups: true, selectedAccountIDs: []
            ).map(\.name) == ["Activa"])

            let archivedRow = try #require(f.txs.first { $0.account?.name == "Archivada" })
            #expect(!LiveBalanceCalculator.entersBalance(archivedRow), "Una fila de una cuenta archivada entra en un saldo.")
        }
    }

    @Test("Archivar desde el formulario no enciende «Excluir de las estadísticas»")
    func archivingFromTheForm_leavesExcludeAlone() {
        let account = Account(name: "Visa", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill",
                              type: "credit_card")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.isArchived = true
        vm.setArchived(true)
        #expect(vm.excludeFromStatistics == false)
        #expect(vm.showsArchiveKeepsHistoryNotice == true)
        vm.isArchived = false
        vm.setArchived(false)
        #expect(vm.showsArchiveKeepsHistoryNotice == false)
    }

    @Test("Archivar la tarjeta archiva sus líneas sin excluirlas")
    func archivingTheCardLines_leavesExcludeAlone() throws {
        let context = try makeTestContext()
        let visa = makeTestAccount(context: context, name: "Visa", currencyCode: "PEN")
        let line = makeTestAccount(context: context, name: "Visa USD", currencyCode: "USD")
        line.parentAccountID = visa.shortcutID
        try context.save()
        let archived = AccountLineService.archiveLines(of: visa, among: [visa, line])
        #expect(archived == 1)
        #expect(line.isArchived == true)
        #expect(line.excludeFromStatistics == false)
    }
}
