//
//  AccountCardReportTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 4 (ticket `multi-currency-accounts-4-reports-and-export`): la tabla de informes y
//  el flujo de caja por cuenta, «Por tarjeta» y «Por línea», y la columna de tarjeta del CSV. Lógica pura, sin
//  SwiftData: las cuentas y los movimientos no se insertan en ningún contexto.
//
//  El escenario es el del seed `tarjeta-dos-lineas`: «Visa QA» en soles con su línea en dólares y una cuenta suelta en
//  dólares. Divisa preferida PEN; los importes convertidos van guardados como en producción (3,70 PEN por dólar).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct AccountCardReportTests {

    // MARK: - Escenario

    private struct Scenario {
        let card: Account
        let line: Account
        let dollars: Account
        let food: YalaCategory
        let salary: YalaCategory
        var accounts: [Account] { [card, line, dollars] }
        var cards: AccountCardIndex { AccountCardIndex(accounts: accounts) }
    }

    private func scenario() -> Scenario {
        let card = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        let line = Account(name: "Visa QA · USD", currencyCode: "USD", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        line.parentAccountID = card.shortcutID
        let dollars = Account(name: "Dólares QA", currencyCode: "USD", colorHex: "#FF7F11", iconName: "dollarsign.circle.fill", type: "savings")
        return Scenario(
            card: card, line: line, dollars: dollars,
            food: YalaCategory(name: "Comida", colorHex: "#000000", isIncome: false),
            salary: YalaCategory(name: "Sueldo", colorHex: "#000000", isIncome: true))
    }

    private let day = Date(timeIntervalSince1970: 1_790_000_000)  // 2026-09-21

    private func tx(
        _ amount: Double, _ currency: String, inPEN: Double, _ account: Account, _ category: YalaCategory,
        daysAgo: Int = 0
    ) -> TransactionItem {
        let item = TransactionItem(
            date: day.addingTimeInterval(TimeInterval(-daysAgo * 86_400)), amount: amount, currencyCode: currency,
            note: "", category: category, account: account, amountInPreferredCurrency: inPEN)
        item.preferredCurrencyCode = "PEN"
        return item
    }

    /// Los tres gastos del seed: −1.250 PEN en la tarjeta, −80 USD en su línea (−296 PEN) y −45 USD sueltos (−166,50 PEN).
    private func expenses(_ s: Scenario) -> [TransactionItem] {
        [
            tx(-1_250, "PEN", inPEN: -1_250, s.card, s.food),
            tx(-80, "USD", inPEN: -296, s.line, s.food),
            tx(-45, "USD", inPEN: -166.5, s.dollars, s.food),
        ]
    }

    private func node(_ nodes: [PivotNode], _ label: String) throws -> PivotNode {
        try #require(nodes.first { $0.label == label }, "no hay fila «\(label)»: \(nodes.map(\.label))")
    }

    // MARK: - Índice de tarjetas

    @Test("El índice sabe de qué tarjeta es cada cuenta; una cuenta sin líneas no está")
    func index_resolvesHeadsAndLines() {
        let s = scenario()
        let cards = s.cards
        #expect(cards.hasCards)
        #expect(cards.card(of: s.card) === s.card)
        #expect(cards.card(of: s.line) === s.card)
        #expect(cards.card(of: s.dollars) == nil)
        #expect(cards.isLine(s.line))
        #expect(!cards.isLine(s.card))
        #expect(cards.cardNamesByMember == [s.card.shortcutID: "Visa QA", s.line.shortcutID: "Visa QA"])
    }

    @Test("Una línea en la divisa de su principal es una cuenta suelta: no forma tarjeta")
    func index_brokenLineIsStandalone() {
        let s = scenario()
        let samePEN = Account(name: "Visa QA · PEN", currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard", type: "creditCard")
        samePEN.parentAccountID = s.card.shortcutID
        let cards = AccountCardIndex(accounts: [s.card, samePEN])
        #expect(!cards.hasCards)
        #expect(cards.card(of: samePEN) == nil)
    }

    // MARK: - Tabla de informes

    @Test("Por tarjeta: una fila con la tarjeta entera en soles y «≈»; la cuenta suelta, en su divisa")
    func pivot_byCard_oneRowConverted() throws {
        let s = scenario()
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: expenses(s), previousTransactions: [], hierarchy: [.cuenta],
            preferredCurrency: "PEN", allTags: [], accountGrouping: .byCard, cards: s.cards)

        #expect(nodes.count == 2)
        let card = try node(nodes, "Visa QA")
        #expect(card.amount == -1_546)
        #expect(card.currencyCode == "PEN")
        #expect(card.isApproximate)
        #expect(card.colorHex == "#3D36B3")
        let dollars = try node(nodes, "Dólares QA")
        #expect(dollars.amount == -45)
        #expect(dollars.currencyCode == "USD")
        #expect(!dollars.isApproximate)
    }

    @Test("Por línea: cada línea en su divisa, sin sumar en crudo ni «≈»")
    func pivot_byLine_eachLineInItsCurrency() throws {
        let s = scenario()
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: expenses(s), previousTransactions: [], hierarchy: [.cuenta],
            preferredCurrency: "PEN", allTags: [], accountGrouping: .byLine, cards: s.cards)

        #expect(nodes.count == 3)
        let card = try node(nodes, "Visa QA")
        #expect(card.amount == -1_250)
        #expect(card.currencyCode == "PEN")
        let line = try node(nodes, "Visa QA · USD")
        #expect(line.amount == -80)
        #expect(line.currencyCode == "USD")
        #expect(nodes.allSatisfy { !$0.isApproximate })
    }

    @Test("Sin índice de tarjetas (cualquier llamador de antes) la tabla sale como antes")
    func pivot_withoutCards_isUnchanged() {
        let s = scenario()
        let txs = expenses(s)
        let before = PivotTableCalculator.buildTree(
            currentTransactions: txs, previousTransactions: [], hierarchy: [.cuenta], preferredCurrency: "PEN", allTags: [])
        let byLine = PivotTableCalculator.buildTree(
            currentTransactions: txs, previousTransactions: [], hierarchy: [.cuenta], preferredCurrency: "PEN", allTags: [],
            accountGrouping: .byLine, cards: s.cards)
        #expect(before.map(\.label).sorted() == byLine.map(\.label).sorted())
        #expect(before.map(\.amount).sorted() == byLine.map(\.amount).sorted())
        // Y «Por tarjeta» sin tarjetas tampoco cambia nada.
        let byCardNoCards = PivotTableCalculator.buildTree(
            currentTransactions: txs, previousTransactions: [], hierarchy: [.cuenta], preferredCurrency: "PEN", allTags: [],
            accountGrouping: .byCard, cards: .empty)
        #expect(byCardNoCards.map(\.amount).sorted() == before.map(\.amount).sorted())
    }

    @Test("Una tarjeta cuyos movimientos están todos en la divisa preferida no lleva «≈»")
    func pivot_byCard_withoutConversion_isExact() throws {
        let s = scenario()
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: [tx(-1_250, "PEN", inPEN: -1_250, s.card, s.food)], previousTransactions: [],
            hierarchy: [.cuenta], preferredCurrency: "PEN", allTags: [], accountGrouping: .byCard, cards: s.cards)
        let card = try node(nodes, "Visa QA")
        #expect(card.amount == -1_250)
        #expect(!card.isApproximate)
    }

    @Test("Tipo › Cuenta: la tarjeta sale convertida dentro de Gastos, y el período anterior lleva su propio «≈»")
    func pivot_byCard_nestedAndPrevious() throws {
        let s = scenario()
        let previous = [tx(-20, "USD", inPEN: -74, s.line, s.food, daysAgo: 31)]
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: [tx(-1_250, "PEN", inPEN: -1_250, s.card, s.food)], previousTransactions: previous,
            hierarchy: [.tipo, .cuenta], preferredCurrency: "PEN", allTags: [], accountGrouping: .byCard, cards: s.cards)
        let expenses = try #require(nodes.first { !$0.isIncome })
        let card = try node(expenses.children, "Visa QA")
        #expect(card.amount == -1_250)
        #expect(card.previousAmount == -74)
        #expect(!card.isApproximate)
        #expect(card.previousIsApproximate)
    }

    @Test("Divisa › Cuenta: bajo el nodo USD la tarjeta suma en dólares, sin convertir ni «≈» (review del 2026-10-18)")
    func pivot_byCard_underACurrencyNode_staysInThatCurrency() throws {
        let s = scenario()
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: expenses(s), previousTransactions: [], hierarchy: [.divisa, .cuenta],
            preferredCurrency: "PEN", allTags: [], accountGrouping: .byCard, cards: s.cards)
        let usd = try node(nodes, "USD")
        let card = try node(usd.children, "Visa QA")
        #expect(card.amount == -80)
        #expect(card.currencyCode == "USD")
        #expect(!card.isApproximate)
        let pen = try node(nodes, "PEN")
        #expect(try node(pen.children, "Visa QA").amount == -1_250)
    }

    @Test("Una tarjeta con movimientos en una sola divisa suma en esa divisa, como cualquier cuenta")
    func pivot_byCard_singleCurrencyRow_staysNative() throws {
        let s = scenario()
        let nodes = PivotTableCalculator.buildTree(
            currentTransactions: [tx(-80, "USD", inPEN: -296, s.line, s.food)], previousTransactions: [],
            hierarchy: [.cuenta], preferredCurrency: "PEN", allTags: [], accountGrouping: .byCard, cards: s.cards)
        let card = try node(nodes, "Visa QA")
        #expect(card.amount == -80)
        #expect(card.currencyCode == "USD")
        #expect(!card.isApproximate)
    }

    // MARK: - Resumen del asistente de exportación

    @Test("El resumen cuenta lo que enseña el filtro: la tarjeta una vez y sin las cuentas de Grupos")
    func exportSummary_countsShownAccounts() {
        let s = scenario()
        let groups = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#888888", iconName: "person.2.fill", type: "bank")
        groups.isSystemAccount = true
        #expect(ExportAccountCount.shown(s.accounts + [groups]) == 2)
        #expect(ExportAccountCount.shown([s.card, s.line]) == 1)
        #expect(ExportAccountCount.shown([groups]) == 1)
    }

    // MARK: - Flujo de caja por cuenta

    private func cashFlow(_ s: Scenario, _ txs: [TransactionItem], _ grouping: AccountCardGrouping) -> [UUID: CashFlowSummary] {
        let interval = DateInterval(start: day.addingTimeInterval(-40 * 86_400), end: day.addingTimeInterval(86_400))
        return AccountCardReportLogic.cashFlowByAccount(
            transactions: txs, accounts: s.accounts, cards: s.cards, grouping: grouping, preferredCurrency: "PEN",
            id: \.shortcutID
        ) { accountTransactions, currency in
            CashFlowCalculator.calculateCashFlow(
                transactions: accountTransactions, interval: interval, grouping: .day, currencyCode: currency)
        }
    }

    @Test("Flujo de caja por tarjeta: las dos divisas convertidas, sin que la segunda se funda en la primera")
    func cashFlow_byCard_convertsBothLines() throws {
        let s = scenario()
        let byAccount = cashFlow(s, expenses(s), .byCard)

        #expect(Set(byAccount.keys) == [s.card.shortcutID, s.dollars.shortcutID])
        let card = try #require(byAccount[s.card.shortcutID])
        #expect(card.currencyCode == "PEN")
        #expect(card.totalExpense == 1_546)  // y no 1.250 + 80 = 1.330
        #expect(card.expenseAmountsAreApproximate)
        #expect(card.amountsAreApproximate)
        #expect(!card.incomeAmountsAreApproximate)
        let dollars = try #require(byAccount[s.dollars.shortcutID])
        #expect(dollars.currencyCode == "USD")
        #expect(dollars.totalExpense == 45)
        #expect(!dollars.amountsAreApproximate)
    }

    @Test("Flujo de caja por línea: cada cuenta en su divisa, como antes")
    func cashFlow_byLine_eachInItsCurrency() throws {
        let s = scenario()
        let byAccount = cashFlow(s, expenses(s), .byLine)

        #expect(byAccount.count == 3)
        let card = try #require(byAccount[s.card.shortcutID])
        #expect(card.currencyCode == "PEN")
        #expect(card.totalExpense == 1_250)
        let line = try #require(byAccount[s.line.shortcutID])
        #expect(line.currencyCode == "USD")
        #expect(line.totalExpense == 80)
        #expect(byAccount.values.allSatisfy { !$0.amountsAreApproximate })
    }

    @Test("Solo el lado que convirtió algo lleva «≈»")
    func cashFlow_byCard_marksOnlyTheConvertedSide() throws {
        let s = scenario()
        let txs = [
            tx(3_000, "PEN", inPEN: 3_000, s.card, s.salary),
            tx(-80, "USD", inPEN: -296, s.line, s.food),
        ]
        let card = try #require(cashFlow(s, txs, .byCard)[s.card.shortcutID])
        #expect(!card.incomeAmountsAreApproximate)
        #expect(card.expenseAmountsAreApproximate)
        #expect(card.netFlow == 3_000 - 296)
    }

    // MARK: - Export CSV

    private func csv(_ txs: [TransactionItem], columns: Set<ExportColumn>, cardNames: [UUID: String]) -> [String] {
        let data = TransactionsExportService.makeCSVData(
            transactions: txs, columns: ExportColumns(activeColumns: columns), cardNames: cardNames)
        let text = String(decoding: data.dropFirst(3), as: UTF8.self)  // sin el BOM
        return text.components(separatedBy: "\n")
    }

    @Test("CSV: la columna `card` va detrás de `account`, con la tarjeta en sus líneas y vacía en una cuenta suelta")
    func csv_cardColumn() {
        let s = scenario()
        let lines = csv(expenses(s), columns: [.amount, .account, .card], cardNames: s.cards.cardNamesByMember)
        #expect(lines == [
            "amount,account,card",
            "-1250.00,Visa QA,Visa QA",
            "-80.00,Visa QA · USD,Visa QA",
            "-45.00,Dólares QA,",
        ])
    }

    @Test("XLSX: la misma columna, con los mismos valores")
    func xlsx_cardColumn() {
        let s = scenario()
        let (headers, rows) = TransactionsExportService.makeExportData(
            transactions: expenses(s), columns: ExportColumns(activeColumns: [.account, .card]),
            cardNames: s.cards.cardNamesByMember)
        #expect(headers == ["account", "card"])
        #expect(rows == [["Visa QA", "Visa QA"], ["Visa QA · USD", "Visa QA"], ["Dólares QA", ""]])
    }

    @Test("Sin tarjetas el fichero es el de siempre: la columna no sale por defecto ni se ofrece")
    func exportColumns_cardOnlyWithCards() {
        #expect(!ExportColumns.default.activeColumns.contains(.card))
        #expect(ExportColumns.default.activeColumns == Set(ExportColumn.allCases).subtracting([.card]))
        #expect(!ExportColumns.offeredOrder(hasAccountCards: false).contains(.card))
        let offered = ExportColumns.offeredOrder(hasAccountCards: true)
        let accountIndex = offered.firstIndex(of: .account)
        #expect(accountIndex.map { offered[$0 + 1] } == .card)
        #expect(ExportColumn.card.csvHeaderTitle == "card")
    }

    @Test("Con la columna apagada, la cabecera que el import acepta no cambia")
    func csv_importCompatibleHeaderIsUnchanged() {
        let s = scenario()
        let header = csv(
            expenses(s), columns: [.date, .amount, .currency, .category, .subcategory, .tags, .note],
            cardNames: s.cards.cardNamesByMember
        ).first
        #expect(header == "date,amount,currency,category,subcategory,tags,note")
    }
}
