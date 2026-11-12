//
//  AccountCardRouteTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 3: la función de la decisión 6 de Jürgen (se elige la tarjeta y la divisa del importe
//  decide la línea) y las dos reglas de selección que la acompañan — el filtro de sesión que arrastra las líneas de la
//  tarjeta elegida, y el presupuesto que cuenta sus gastos. Sin SwiftData: nodos a mano.
//

import Foundation
import Testing

@testable import Yala

struct AccountCardRouteTests {

    private let card = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    private let usd = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
    private let eur = UUID(uuidString: "30000000-0000-4000-8000-000000000003")!
    private let savings = UUID(uuidString: "40000000-0000-4000-8000-000000000004")!
    private let dollars = UUID(uuidString: "50000000-0000-4000-8000-000000000005")!
    private let archivedLine = UUID(uuidString: "60000000-0000-4000-8000-000000000006")!

    private func node(_ id: UUID, _ currency: String, parent: UUID? = nil,
                      archived: Bool = false, system: Bool = false) -> AccountLineNode {
        AccountLineNode(id: id, parentID: parent, currencyCode: currency, isArchived: archived, isSystem: system)
    }

    /// Tarjeta PEN con líneas USD y EUR, una suelta en PEN y otra en USD.
    private var nodes: [AccountLineNode] {
        [node(card, "PEN"), node(usd, "USD", parent: card), node(eur, "EUR", parent: card),
         node(savings, "PEN"), node(dollars, "USD")]
    }

    // MARK: - route

    @Test func route_currencyMatchesALine_goesToThatLine() {
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: "USD", nodes: nodes)
            == .init(accountID: usd, isFallback: false))
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: "EUR", nodes: nodes)
            == .init(accountID: eur, isFallback: false))
    }

    @Test func route_currencyMatchesThePrincipal_staysOnThePrincipal() {
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: "PEN", nodes: nodes)
            == .init(accountID: card, isFallback: false))
    }

    @Test func route_noMemberInThatCurrency_goesToThePrincipal_flagged_andCreatesNothing() {
        let before = nodes
        let route = AccountCardLogic.route(chosenID: card, currencyCode: "JPY", nodes: before)
        #expect(route == .init(accountID: card, isFallback: true))
        // Pura: no hay forma de crear nada, pero el resultado tiene que ser una cuenta que YA existe.
        #expect(before.contains { $0.id == route?.accountID })
    }

    @Test func route_accountWithoutLines_isUnchanged() {
        #expect(AccountCardLogic.route(chosenID: savings, currencyCode: "PEN", nodes: nodes)
            == .init(accountID: savings, isFallback: false))
        // En otra divisa sigue en la misma cuenta; el aviso de divisa es el de siempre.
        #expect(AccountCardLogic.route(chosenID: dollars, currencyCode: "PEN", nodes: nodes)
            == .init(accountID: dollars, isFallback: true))
    }

    @Test func route_fromALine_routesAcrossTheWholeCard() {
        #expect(AccountCardLogic.route(chosenID: usd, currencyCode: "PEN", nodes: nodes)?.accountID == card)
        #expect(AccountCardLogic.route(chosenID: usd, currencyCode: "EUR", nodes: nodes)?.accountID == eur)
    }

    @Test func route_skipsAnArchivedLine() {
        let withArchived = [node(card, "PEN"), node(archivedLine, "USD", parent: card, archived: true)]
        // La única línea USD está archivada: la tarjeta no tiene miembros vivos además de la principal.
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: "USD", nodes: withArchived)
            == .init(accountID: card, isFallback: true))
    }

    @Test func route_brokenLine_readsAsStandalone() {
        // Misma divisa que la principal: `resolve` la lee suelta, y enruta como cuenta sin líneas.
        let broken = [node(card, "PEN"), node(usd, "PEN", parent: card)]
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: "PEN", nodes: broken)?.accountID == card)
        #expect(AccountCardLogic.route(chosenID: usd, currencyCode: "PEN", nodes: broken)?.accountID == usd)
    }

    @Test func route_currencyIsCaseInsensitive_andUnknownAccountIsNil() {
        #expect(AccountCardLogic.route(chosenID: card, currencyCode: " usd ", nodes: nodes)?.accountID == usd)
        #expect(AccountCardLogic.route(chosenID: UUID(), currencyCode: "USD", nodes: nodes) == nil)
    }

    @Test func liveMembers_headFirst_thenLinesByCurrency() {
        #expect(AccountCardLogic.liveMembers(of: usd, nodes: nodes).map(\.id) == [card, eur, usd])
        #expect(AccountCardLogic.liveMembers(of: savings, nodes: nodes).map(\.id) == [savings])
    }

    // MARK: - Importación

    @Test func importAssignments_fillsTheOtherCurrencies_withTheCardLines_withoutOverwriting() {
        let filled = AccountCardLogic.importAssignments(
            chosenID: card, currencies: ["EUR", "JPY", "PEN", "USD"], assigned: ["PEN", "EUR"], nodes: nodes)
        // EUR ya estaba elegida (no se pisa), JPY no la tiene la tarjeta (no cae a la principal).
        #expect(filled == ["USD": usd])
    }

    @Test func importAssignments_standaloneAccount_fillsNothing() {
        #expect(AccountCardLogic.importAssignments(
            chosenID: dollars, currencies: ["PEN", "USD"], assigned: ["USD"], nodes: nodes).isEmpty)
    }

    // MARK: - Filtro de sesión

    private var linesByHead: [UUID: Set<UUID>] {
        AccountCardLogic.linesByHead(nodes, node: { $0 }, id: \.id)
    }

    /// Una línea archivada sigue siendo de la tarjeta: archivar no decide la suma, así que su gasto sigue en el presupuesto de
    /// la tarjeta y sus movimientos en el filtro. Las cuentas sin líneas no aparecen.
    @Test func linesByHead_includesArchivedLines_andOnlyCardsWithLines() {
        let withArchived = nodes + [node(archivedLine, "JPY", parent: card, archived: true)]
        #expect(AccountCardLogic.linesByHead(withArchived, node: { $0 }, id: \.id) == [card: [usd, eur, archivedLine]])
    }

    @Test func normalizedSelection_choosingTheCard_addsItsLines() {
        #expect(AccountCardLogic.normalizedSelection(old: [], new: [card], linesByHead: linesByHead)
            == [card, usd, eur])
        #expect(AccountCardLogic.normalizedSelection(old: [savings], new: [savings, card], linesByHead: linesByHead)
            == [savings, card, usd, eur])
    }

    @Test func normalizedSelection_removingTheCard_removesItsLines() {
        #expect(AccountCardLogic.normalizedSelection(
            old: [card, usd, eur, savings], new: [usd, eur, savings], linesByHead: linesByHead) == [savings])
    }

    @Test func normalizedSelection_aLoneLine_isRespected() {
        // Un presupuesto de antes del enlace apuntaba solo a la cuenta en dólares, que hoy es línea.
        #expect(AccountCardLogic.normalizedSelection(old: [], new: [usd], linesByHead: linesByHead) == [usd])
    }

    @Test func normalizedSelection_withTheCardKept_itsLinesStay() {
        #expect(AccountCardLogic.normalizedSelection(
            old: [card, usd, eur], new: [card, eur], linesByHead: linesByHead) == [card, usd, eur])
    }

    @Test func shownSelection_countsTheCardOnce_andKeepsALoneLine() {
        #expect(AccountCardLogic.shownSelection([card, usd, eur, savings], linesByHead: linesByHead) == [card, savings])
        #expect(AccountCardLogic.shownSelection([usd], linesByHead: linesByHead) == [usd])
    }

    // MARK: - Presupuesto

    @Test func includingLines_aBudgetOnTheCard_countsItsLines() {
        #expect(AccountCardLogic.includingLines([card], linesByHead: linesByHead) == [card, usd, eur])
        #expect(AccountCardLogic.includingLines([savings, usd], linesByHead: linesByHead) == [savings, usd])
    }
}
