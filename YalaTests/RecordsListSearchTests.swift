//
//  RecordsListSearchTests.swift
//  YalaTests
//
//  «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1): el campo de la lista busca también por importe y
//  respeta el período y los filtros. Dos suites: la regla pura (`RecordsListSearchLogic`, sin contexto) y el camino real
//  de la pantalla (`RecordsViewModel.applyFilters`), que es lo que decide qué filas se ven y qué suma la cabecera.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Buscar en Registros · la regla")
struct RecordsListSearchLogicTests {

    private func amount(_ text: String) -> RecordsListSearchLogic.AmountQuery? {
        RecordsListSearchLogic.amount(from: text)
    }

    @Test("Un importe se lee con punto o coma, con moneda y con miles")
    func readsAmountsAsTheyAreWritten() {
        #expect(amount("45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("45,90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("45,9") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("S/ 45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("US$45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("-45.90") == .init(cents: 4590, hasDecimals: true))
        #expect(amount("1.234,50") == .init(cents: 123_450, hasDecimals: true))
        #expect(amount("1,234.50") == .init(cents: 123_450, hasDecimals: true))
        #expect(amount("1.234") == .init(cents: 123_400, hasDecimals: false))
        #expect(amount("45") == .init(cents: 4500, hasDecimals: false))
    }

    @Test("Una palabra no es un importe, aunque lleve una cifra")
    func wordsAreNotAmounts() {
        #expect(amount("almuerzo") == nil)
        #expect(amount("Bus 12") == nil)
        #expect(amount("") == nil)
        #expect(amount("S/") == nil)
    }

    @Test("Con decimales casa al céntimo, sin signo; sin decimales, toda la parte entera")
    func amountMatchingRule() throws {
        let exact = try #require(amount("45.90"))
        #expect(exact.matches(-45.90))
        #expect(exact.matches(45.9))
        #expect(!exact.matches(-45.00))
        #expect(!exact.matches(-145.90))

        let whole = try #require(amount("45"))
        #expect(whole.matches(-45.00))
        #expect(whole.matches(-45.90))
        #expect(!whole.matches(-46.00))
        #expect(!whole.matches(-4.50))
    }

    @Test("El texto busca en nota, categoría, subcategoría, cuenta y etiquetas, sin mayúsculas ni tildes")
    func textMatchesEveryField() {
        let fields = RecordsListSearchLogic.Fields(
            note: "Almuerzo de trabajo", category: "Alimentación", subcategory: "Restaurantes",
            account: "Cuenta Principal", tags: ["Viaje a Cusco"], signedAmount: -45.90
        )
        func finds(_ text: String) -> Bool {
            RecordsListSearchLogic.matches(fields, query: RecordsListSearchLogic.query(text))
        }
        #expect(finds("almuerzo"))
        #expect(finds("ALIMENTACION"))
        #expect(finds("restaurantes"))
        #expect(finds("principal"))
        #expect(finds("cusco"))
        #expect(finds("45,90"))
        #expect(finds("  almuerzo  "), "Los espacios a los lados no cuentan.")
        #expect(finds(""), "Sin nada escrito, todo casa.")
        #expect(!finds("taxi"))
        #expect(!finds("12.00"))
    }
}

@MainActor
@Suite("Buscar en Registros · la pantalla", .serialized)
struct RecordsListSearchScreenTests {

    /// `applyFilters` lee de `SessionState.shared` el período y los filtros: se fijan y se restauran (molde de
    /// `RecordsSummaryApproximateMarkTests.conPeriodoCompleto`).
    private func conSesion(periodo: DetailPeriod, _ cuerpo: () throws -> Void) rethrows {
        let session = SessionState.shared
        let periodoAntes = session.selectedPeriod
        let soloGastos = session.isExpensesOnlyMode
        let cuentas = session.selectedAccountIDs
        let texto = session.searchText
        let excluidos = session.excludedFilterSets
        session.isExpensesOnlyMode = false
        session.clearFilters()
        session.selectedPeriod = periodo
        defer {
            session.isExpensesOnlyMode = soloGastos
            session.clearFilters()
            session.selectedAccountIDs = cuentas
            session.searchText = texto
            session.excludedFilterSets = excluidos
            session.selectedPeriod = periodoAntes
        }
        try cuerpo()
    }

    private func makeTx(
        _ amount: Double, note: String, date: Date, account: Account, category: YalaCategory,
        tags: [Yala.Tag] = [], context: ModelContext
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date, amount: amount, currencyCode: account.currencyCode, note: note,
            category: category, account: account, tags: tags, amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = account.currencyCode
        context.insert(tx)
        return tx
    }

    private func notes(_ vm: RecordsViewModel) -> [String] {
        vm.groupedRecords.flatMap(\.records).compactMap(\.note).sorted()
    }

    @Test("Por importe encuentra el registro dentro del período, no el de hace dos meses")
    func amountSearchRespectsThePeriod() throws {
        try conSesion(periodo: .thisMonth) {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context, name: "Cuenta Principal")
            let comida = makeTestCategory(context: context, name: "Alimentación")
            let hoy = aMomentAgoToday()
            let haceDosMeses = try #require(Calendar.current.date(byAdding: .month, value: -2, to: hoy))
            let txs = [
                makeTx(-45.90, note: "Almuerzo de trabajo", date: hoy, account: account, category: comida,
                       context: context),
                makeTx(-12.00, note: "Bus", date: hoy, account: account, category: comida, context: context),
                makeTx(-45.90, note: "Almuerzo viejo", date: haceDosMeses, account: account, category: comida,
                       context: context),
            ]
            try context.save()

            let vm = RecordsViewModel()
            vm.listSearchText = "45,90"
            vm.applyFilters(transactions: txs, accounts: [account], categories: [comida], tags: [], context: context,
                            currencyCode: "PEN")

            #expect(notes(vm) == ["Almuerzo de trabajo"], "Sale el de este mes y solo ese; el Bus no casa.")
            #expect(abs(vm.recordsSummary.expense - 45.90) < 0.001, "La cabecera suma lo que la lista enseña.")
            #expect(SessionState.shared.searchText.isEmpty,
                    "La búsqueda es de Registros: no escribe el «Nota contiene» que filtra el Panel y Estadísticas.")
        }
    }

    @Test("Respeta el filtro de cuenta y busca por etiqueta")
    func searchRespectsTheAccountFilter_andFindsTags() throws {
        try conSesion(periodo: .allTime) {
            let context = try makeTestContext()
            let principal = makeTestAccount(context: context, name: "Cuenta Principal")
            let ahorros = makeTestAccount(context: context, name: "Ahorros")
            let comida = makeTestCategory(context: context, name: "Alimentación")
            let viaje = makeTestTag(context: context, name: "Viaje a Cusco")
            let hoy = aMomentAgoToday()
            let txs = [
                makeTx(-30, note: "Cena", date: hoy, account: principal, category: comida, tags: [viaje],
                       context: context),
                makeTx(-30, note: "Hotel", date: hoy, account: ahorros, category: comida, tags: [viaje],
                       context: context),
                makeTx(-30, note: "Taxi", date: hoy, account: principal, category: comida, context: context),
            ]
            try context.save()
            SessionState.shared.selectedAccountIDs = [principal.persistentModelID]

            let vm = RecordsViewModel()
            vm.listSearchText = "cusco"
            vm.applyFilters(transactions: txs, accounts: [principal, ahorros], categories: [comida], tags: [viaje],
                            context: context, currencyCode: "PEN")

            #expect(notes(vm) == ["Cena"], "La etiqueta casa en las dos cuentas, pero el filtro deja solo Principal.")
        }
    }

    @Test("Sin nada escrito la lista es la de siempre, y sin resultados queda vacía")
    func emptyAndNoMatch() throws {
        try conSesion(periodo: .allTime) {
            let context = try makeTestContext()
            let account = makeTestAccount(context: context)
            let comida = makeTestCategory(context: context, name: "Alimentación")
            let hoy = aMomentAgoToday()
            let txs = [
                makeTx(-10, note: "Pan", date: hoy, account: account, category: comida, context: context),
                makeTx(-20, note: "Leche", date: hoy, account: account, category: comida, context: context),
            ]
            try context.save()

            let vm = RecordsViewModel()
            vm.applyFilters(transactions: txs, accounts: [account], categories: [comida], tags: [], context: context,
                            currencyCode: "PEN")
            #expect(notes(vm) == ["Leche", "Pan"])
            #expect(!vm.isSearchingList)

            vm.listSearchText = "café"
            vm.applyFilters(transactions: txs, accounts: [account], categories: [comida], tags: [], context: context,
                            currencyCode: "PEN")
            #expect(vm.groupedRecords.isEmpty)
            #expect(vm.isSearchingList, "El vacío dice «Sin resultados», no «Sin registros».")
        }
    }
}
