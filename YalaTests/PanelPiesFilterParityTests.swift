//
//  PanelPiesFilterParityTests.swift
//  YalaTests
//
//  Tickets `panel-pies-amount-filter-uses-signed-amount` y `panel-pies-ignore-hidden-currency-and-compare-signed-amount`:
//  con un filtro de moneda y de monto, las tartas y tops del Panel dejan pasar los MISMOS registros que Registros. Hasta
//  el 2026-10-28 el Panel comparaba el monto con signo y «Mayor a 100» vaciaba las tartas de gasto. «Ocultar» una moneda
//  ya lo respetaba desde c5e2c1a89 (incluidos y excluidos); aquí se fija.
//
//  El fixture es DISCRIMINANTE: un gasto y un ingreso por encima y por debajo del umbral en cada moneda. Con el monto con
//  signo, «Mayor a 100» deja solo los ingresos; con «Ocultar PEN» leído como «solo PEN», salen los PEN.
//
//  Y el borde 2 de `combined-filters-edge-cases-after-option-b` (un oculto que se borra sale del filtro), que pide
//  contexto para tener ids reales: va en esta misma suite (`.serialized` no ordena entre suites del mismo fichero).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Tartas del Panel ↔ Registros: moneda y monto", .serialized)
struct PanelPiesFilterParityTests {

    private struct Fixture {
        let accounts: [Account]
        let categories: [YalaCategory]
        let txs: [TransactionItem]
    }

    private func fixture(_ context: ModelContext) throws -> Fixture {
        let pen = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let usd = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        let comida = makeTestCategory(context: context, name: "Comida", isIncome: false)
        let sueldo = makeTestCategory(context: context, name: "Sueldo", isIncome: true)
        let mercado = makeTestSubcategory(context: context, name: "Mercado", category: comida)
        let date = Date.now.addingTimeInterval(-3_600)

        func tx(_ amount: Double, _ account: Account, _ category: YalaCategory, _ sub: Subcategory? = nil) -> TransactionItem {
            let item = TransactionItem(
                date: date, amount: amount, currencyCode: account.currencyCode, note: "", category: category,
                subcategory: sub, account: account, amountInPreferredCurrency: amount,
                preferredCurrencyCode: account.currencyCode
            )
            context.insert(item)
            return item
        }
        let txs = [
            tx(-150, pen, comida, mercado),
            tx(-50, pen, comida, mercado),
            tx(150, pen, sueldo),
            tx(-150, usd, comida, mercado),
            tx(-50, usd, comida, mercado),
            tx(150, usd, sueldo),
        ]
        try context.save()
        return Fixture(accounts: [pen, usd], categories: [comida, sueldo], txs: txs)
    }

    private func withSession(_ apply: (SessionState) -> Void, _ body: () throws -> Void) rethrows {
        let session = SessionState.shared
        let saved = (
            session.selectedCurrencies, session.amountCondition, session.excludedFilterSets, session.selectedPeriod,
            session.selectedTransactionNatures, session.isExpensesOnlyMode
        )
        let savedIncluded = (
            session.selectedAccountIDs, session.selectedCategoryIDs, session.selectedSubcategoryIDs,
            session.selectedNeeds, session.selectedTags, session.searchText, session.selectedBudgetID
        )
        let feedKey = AppPreferences.Keys.includeGroupTransactionsInFeed
        let previousFeed = UserDefaults.standard.object(forKey: feedKey)
        UserDefaults.standard.set(true, forKey: feedKey)
        session.clearFilters()
        session.selectedPeriod = .allTime
        session.isExpensesOnlyMode = false
        apply(session)
        defer {
            session.clearFilters()
            session.selectedCurrencies = saved.0
            session.amountCondition = saved.1
            session.excludedFilterSets = saved.2
            session.selectedPeriod = saved.3
            session.selectedTransactionNatures = saved.4
            session.isExpensesOnlyMode = saved.5
            session.selectedAccountIDs = savedIncluded.0
            session.selectedCategoryIDs = savedIncluded.1
            session.selectedSubcategoryIDs = savedIncluded.2
            session.selectedNeeds = savedIncluded.3
            session.selectedTags = savedIncluded.4
            session.searchText = savedIncluded.5
            session.selectedBudgetID = savedIncluded.6
            if let previousFeed {
                UserDefaults.standard.set(previousFeed, forKey: feedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: feedKey)
            }
        }
        try body()
    }

    /// Lo que deja pasar cada pantalla, como «moneda importe».
    private func label(_ tx: TransactionItem) -> String { "\(tx.currencyCode) \(Int(tx.amount))" }

    private func compare(_ f: Fixture, _ context: ModelContext) -> (pies: [String], records: [String]) {
        let panel = PanelViewModel()
        let pies = panel.buildPieContextTransactions(
            from: f.txs,
            eligibleAccountIDs: Set(f.accounts.map(\.persistentModelID)),
            effectiveInterval: DetailPeriod.allTime.dateInterval()
        )
        let records = RecordsViewModel()
        records.applyFilters(
            transactions: f.txs, accounts: f.accounts, categories: f.categories, tags: [], context: context,
            currencyCode: "PEN", converter: MockCurrencyConverter()
        )
        let shown = records.groupedRecords.flatMap(\.records)
        return (pies.map(label).sorted(), shown.map(label).sorted())
    }

    @Test("«Mayor a 100»: las tartas cuentan los gastos de 150 que Registros cuenta")
    func moreThan100_sameRecordsInPiesAndRecords() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        try withSession({ $0.amountCondition = .greaterThan(100) }) {
            let (pies, records) = compare(f, context)
            #expect(pies == ["PEN -150", "PEN 150", "USD -150", "USD 150"])
            #expect(pies == records)
        }
    }

    @Test("«Menor a 100»: los gastos de 150 salen de las tartas, como de Registros")
    func lessThan100_sameRecordsInPiesAndRecords() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        try withSession({ $0.amountCondition = .lessThan(100) }) {
            let (pies, records) = compare(f, context)
            #expect(pies == ["PEN -50", "USD -50"])
            #expect(pies == records)
        }
    }

    @Test("«Ocultar PEN» + «Mayor a 100»: solo lo de USD por encima de 100, en las dos")
    func hidePENAndMoreThan100_sameRecordsInPiesAndRecords() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        try withSession({ session in
            session.hide(.currency(.pen))
            session.amountCondition = .greaterThan(100)
        }) {
            let (pies, records) = compare(f, context)
            #expect(pies == ["USD -150", "USD 150"])
            #expect(pies == records)
        }
    }

    @Test("«Solo PEN» + «Mayor a 100»: solo lo de PEN por encima de 100, en las dos")
    func onlyPENAndMoreThan100_sameRecordsInPiesAndRecords() throws {
        let context = try makeTestContext()
        let f = try fixture(context)
        try withSession({ session in
            session.selectedCurrencies = [.pen]
            session.amountCondition = .greaterThan(100)
        }) {
            let (pies, records) = compare(f, context)
            #expect(pies == ["PEN -150", "PEN 150"])
            #expect(pies == records)
        }
    }

    /// Borde 2: una categoría, subcategoría o etiqueta oculta que se borra sale del filtro. Sin esto la barra del Panel
    /// salía sin cápsulas y sin ✕: `hasExcludedFilters` contaba el id y nadie lo pintaba.
    @Test("Borrar un valor oculto lo saca del filtro, y solo a él")
    func deletingAHiddenValue_forgetsIt() throws {
        let context = try makeTestContext()
        let comida = makeTestCategory(context: context, name: "Comida")
        let transporte = makeTestCategory(context: context, name: "Transporte")
        let mercado = makeTestSubcategory(context: context, name: "Mercado", category: comida)
        let taxi = makeTestSubcategory(context: context, name: "Taxi", category: transporte)
        let viaje = makeTestTag(context: context, name: "Viaje")
        let casa = makeTestTag(context: context, name: "Casa")
        try context.save()
        let session = SessionState()
        session.hide(.category(comida.persistentModelID))
        session.hide(.subcategory(taxi.persistentModelID))
        session.hide(.tag(viaje.persistentModelID))
        session.selectedTags = [casa.persistentModelID]

        let service = EntityDeletionService.shared
        service.setContext(context)
        defer { service.setContext(nil) }
        // El servicio escribe la sesión compartida: se mira ahí y se restaura.
        let shared = SessionState.shared
        let savedExcluded = shared.excludedFilterSets
        let savedTags = shared.selectedTags
        defer {
            shared.excludedFilterSets = savedExcluded
            shared.selectedTags = savedTags
        }
        shared.excludedFilterSets = session.excludedFilterSets
        shared.selectedTags = session.selectedTags
        #expect(shared.hasExcludedFilters)

        try service.deleteTag(viaje)
        #expect(shared.excludedTags.isEmpty)
        #expect(shared.selectedTags == [casa.persistentModelID], "la etiqueta vista sola no se toca")

        try service.deleteSubcategory(taxi)
        #expect(shared.excludedSubcategoryIDs.isEmpty)

        try service.deleteCategory(comida, withSubcategories: [mercado])
        #expect(shared.excludedCategoryIDs.isEmpty)
        #expect(!shared.hasExcludedFilters)
    }

    /// Exportar en «Ocultar»: las monedas a la vista son las de las cuentas que NO se ocultan. La primera versión del
    /// arreglo miraba las de las marcadas, que en ese modo son las ocultas (review del lote, 2026-10-28).
    @Test("Exportar «Ocultar»: la moneda del monto sale de las cuentas que se exportan")
    func exportHideMode_currencyComesFromTheAccountsLeftInView() throws {
        let context = try makeTestContext()
        let pen = makeTestAccount(context: context, name: "Soles", currencyCode: "PEN")
        let usd = makeTestAccount(context: context, name: "Dólares", currencyCode: "USD")
        _ = makeTestAccount(context: context, name: "Euros", currencyCode: "EUR")
        try context.save()
        let viewModel = ExportFiltersStepViewModel()
        viewModel.setContext(context)

        // Ocultas Soles y Dólares: se exporta solo Euros.
        let hidden: Set<PersistentIdentifier> = [pen.persistentModelID, usd.persistentModelID]
        let left = viewModel.currenciesLeftInView(hiding: hidden)
        #expect(left == [.eur])
        #expect(Set(viewModel.availableCurrencies(selectedAccounts: hidden)) == [.pen, .usd], "control: las de lo oculto")
        // Con PEN marcada (oculta) la moneda del monto es EUR, nunca USD ni PEN.
        #expect(ExportRecordsLogic.amountCurrency(marked: [.pen], available: left, isExcludeMode: true) == .eur)
        // Sin nada oculto por cuentas, las tres a la vista: sin una sola moneda, el monto no se usa.
        let none = viewModel.currenciesLeftInView(hiding: [])
        #expect(ExportRecordsLogic.amountCurrency(marked: [], available: none, isExcludeMode: true) == nil)
    }

    /// Y la pieza pura: quita de las dos listas lo borrado, y nada más.
    @Test("forgetDeletedFilterValues: las dos listas, solo lo borrado")
    func forgetDeletedFilterValues_table() throws {
        let context = try makeTestContext()
        let a = makeTestCategory(context: context, name: "A")
        let b = makeTestCategory(context: context, name: "B")
        let sub = makeTestSubcategory(context: context, name: "S", category: a)
        try context.save()
        let session = SessionState()
        session.selectedCategoryIDs = [a.persistentModelID]
        session.excludedCategoryIDs = [b.persistentModelID]
        session.selectedSubcategoryIDs = [sub.persistentModelID]

        session.forgetDeletedFilterValues(categories: [b.persistentModelID])
        #expect(session.selectedCategoryIDs == [a.persistentModelID])
        #expect(session.excludedCategoryIDs.isEmpty)

        session.forgetDeletedFilterValues(categories: [a.persistentModelID], subcategories: [sub.persistentModelID])
        #expect(session.selectedCategoryIDs.isEmpty)
        #expect(session.selectedSubcategoryIDs.isEmpty)
    }
}
