//
//  AccountCardReportLogic.swift
//  Yala
//
//  Tarjeta con varias divisas, entrega 4 (ticket `multi-currency-accounts-4-reports-and-export`): lo que los informes,
//  el flujo de caja, el export y el contexto de Yala IA necesitan para enseñar una tarjeta entera en vez de partida en
//  sus líneas. Qué es cada cuenta lo sigue decidiendo `AccountLineLogic.resolve` (vía `AccountCardLogic.linesByHead`);
//  aquí solo se responde «¿de qué tarjeta es esta cuenta?» y cómo se marca un total convertido.
//

import Foundation

/// Cómo se ve una tarjeta con varias divisas en una pantalla que agrupa por cuenta (Paso 0 de la entrega 4, D1-D2).
enum AccountCardGrouping: String, CaseIterable, Identifiable, Sendable {
    /// Una fila por tarjeta, con sus líneas convertidas a la divisa preferida y «≈».
    case byCard
    /// Una fila por línea, cada una en su divisa: lo de antes de la entrega 4.
    case byLine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .byCard: return L10n.AccountCardGrouping.byCard
        case .byLine: return L10n.AccountCardGrouping.byLine
        }
    }
}

/// A qué tarjeta pertenece cada cuenta. Solo aparecen las tarjetas con alguna línea (archivadas incluidas, como en
/// `AccountCardLogic.linesByHead`): una cuenta sin líneas no está aquí y sigue siendo ella misma.
struct AccountCardIndex {
    /// La cabeza de cada cuenta que es parte de una tarjeta con líneas, por `shortcutID` (la cabeza también apunta a sí
    /// misma).
    private let headByMember: [UUID: Account]

    static let empty = AccountCardIndex(headByMember: [:])

    /// `accounts` tiene que traer TODAS las cuentas, archivadas incluidas: una principal que falte deja sus líneas
    /// sueltas (falla visible, como en el resto de la app).
    init(accounts: [Account]) {
        let linesByHead = AccountCardLogic.linesByHead(accounts, node: { AccountLineNode($0) }, id: { $0.shortcutID })
        var byID: [UUID: Account] = [:]
        for account in accounts where byID[account.shortcutID] == nil { byID[account.shortcutID] = account }
        var map: [UUID: Account] = [:]
        for (headID, lines) in linesByHead {
            guard let head = byID[headID] else { continue }
            map[headID] = head
            for line in lines { map[line] = head }
        }
        self.init(headByMember: map)
    }

    private init(headByMember: [UUID: Account]) {
        self.headByMember = headByMember
    }

    /// Si hay alguna tarjeta con líneas. Sin ninguna, las pantallas no enseñan el selector «Por tarjeta · Por línea».
    var hasCards: Bool { !headByMember.isEmpty }

    /// La tarjeta (su cuenta principal) de `account`, o `nil` si la cuenta no tiene líneas ni es línea de nada.
    func card(of account: Account?) -> Account? {
        guard let account else { return nil }
        return headByMember[account.shortcutID]
    }

    /// `true` si `account` es una LÍNEA de una tarjeta (no la principal).
    func isLine(_ account: Account) -> Bool {
        guard let head = headByMember[account.shortcutID] else { return false }
        return head.shortcutID != account.shortcutID
    }

    /// El nombre de la tarjeta para la columna `card` del export, por `shortcutID` de cada miembro.
    var cardNamesByMember: [UUID: String] {
        headByMember.mapValues(\.name)
    }
}

enum AccountCardReportLogic {

    /// `true` si sumar estos movimientos en `target` convierte alguno: la marca «≈» de un total de tarjeta, con el mismo
    /// significado que en el Panel (`AccountCardLogic.total`, `isConverted`).
    static func convertsAny(_ currencyCodes: some Sequence<String>, to target: String) -> Bool {
        let normalizedTarget = normalized(target)
        return currencyCodes.contains { normalized($0) != normalizedTarget }
    }

    /// El resumen de flujo de caja de una tarjeta con su «≈» por lado: un lado está convertido si alguno de sus
    /// movimientos estaba en otra divisa. Se suma a lo que ya marcaba el calculador por la calidad de las tasas.
    /// Mismo criterio de lado que `CashFlowCalculator` (categoría de ingreso o no; sin categoría no cuenta).
    static func markingConversions(
        _ summary: CashFlowSummary,
        transactions: [TransactionItem]
    ) -> CashFlowSummary {
        var incomeConverted = false
        var expenseConverted = false
        for tx in transactions {
            guard let category = tx.category, tx.balanceAdjustmentType == nil else { continue }
            guard convertsAny([tx.currencyCode], to: summary.currencyCode) else { continue }
            if category.isIncome { incomeConverted = true } else { expenseConverted = true }
        }
        guard incomeConverted || expenseConverted else { return summary }
        return CashFlowSummary(
            totalIncome: summary.totalIncome,
            totalExpense: summary.totalExpense,
            netFlow: summary.netFlow,
            chartData: summary.chartData,
            currencyCode: summary.currencyCode,
            incomeAmountsAreApproximate: summary.incomeAmountsAreApproximate || incomeConverted,
            expenseAmountsAreApproximate: summary.expenseAmountsAreApproximate || expenseConverted,
            amountsAreApproximate: summary.amountsAreApproximate || incomeConverted || expenseConverted
        )
    }

    /// El flujo de caja de cada cuenta de `accounts`, en su divisa (`summarize(movimientos, divisa)`). Con `.byCard` y
    /// alguna tarjeta, la tarjeta sale una vez —con el id de su principal— sumando sus líneas en `preferredCurrency` y con
    /// «≈» en el lado que convirtió algo; sus líneas no salen solas. Las cuentas sin líneas, igual que antes.
    static func cashFlowByAccount<ID: Hashable>(
        transactions: [TransactionItem],
        accounts: [Account],
        cards: AccountCardIndex,
        grouping: AccountCardGrouping,
        preferredCurrency: String,
        id: (Account) -> ID,
        summarize: ([TransactionItem], String) -> CashFlowSummary
    ) -> [ID: CashFlowSummary] {
        let byCard = grouping == .byCard && cards.hasCards
        let grouped = Dictionary(grouping: transactions) { tx -> ID? in
            if byCard, let card = cards.card(of: tx.account) { return id(card) }
            return tx.account.map(id)
        }
        var result: [ID: CashFlowSummary] = [:]
        for account in accounts {
            if byCard && cards.isLine(account) { continue }
            let isCard = byCard && cards.card(of: account) != nil
            let accountTransactions = grouped[id(account)] ?? []
            let summary = summarize(accountTransactions, isCard ? preferredCurrency : account.currencyCode)
            result[id(account)] = isCard ? markingConversions(summary, transactions: accountTransactions) : summary
        }
        return result
    }

    private static func normalized(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespaces).uppercased()
    }
}

/// Cuántas cuentas dice el resumen del asistente de exportación: las que enseña el filtro. Una línea de tarjeta no es otra
/// cuenta, y las de Grupos no tienen chip salvo que no haya ninguna propia (`ExportFiltersStepViewModel.offeredAccounts`).
enum ExportAccountCount {
    static func shown(_ accounts: [Account]) -> Int {
        let cards = AccountCardIndex(accounts: accounts)
        let visible = accounts.filter { !cards.isLine($0) }
        let own = visible.filter { !$0.isSystemAccount }
        return own.isEmpty ? visible.count : own.count
    }
}
