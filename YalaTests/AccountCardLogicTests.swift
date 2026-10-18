//
//  AccountCardLogicTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 2: lo que las pantallas preguntan a `AccountCardLogic` — agrupar en tarjetas,
//  el orden que se guarda al reordenar, qué líneas archiva la cascada, qué divisas se pueden añadir, qué cuentas se
//  ofrecen para vincular y por qué no, quién tiene recordatorio y el total «≈». Sin SwiftData: nodos a mano.
//

import Foundation
import Testing

@testable import Yala

struct AccountCardLogicTests {

    private let card = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    private let usd = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
    private let eur = UUID(uuidString: "30000000-0000-4000-8000-000000000003")!
    private let savings = UUID(uuidString: "40000000-0000-4000-8000-000000000004")!
    private let dollars = UUID(uuidString: "50000000-0000-4000-8000-000000000005")!
    private let otherCard = UUID(uuidString: "60000000-0000-4000-8000-000000000006")!
    private let otherLine = UUID(uuidString: "70000000-0000-4000-8000-000000000007")!

    private func node(_ id: UUID, _ currency: String, parent: UUID? = nil,
                      archived: Bool = false, system: Bool = false) -> AccountLineNode {
        AccountLineNode(id: id, parentID: parent, currencyCode: currency, isArchived: archived, isSystem: system)
    }

    /// Tarjeta PEN con líneas USD y EUR, una suelta en PEN y otra en USD.
    private var standardNodes: [AccountLineNode] {
        [node(card, "PEN"), node(usd, "USD", parent: card), node(eur, "EUR", parent: card),
         node(savings, "PEN"), node(dollars, "USD")]
    }

    private func cards(_ shown: [AccountLineNode], all: [AccountLineNode]) -> [AccountCard<AccountLineNode>] {
        AccountCardLogic.cards(shown, roles: AccountLineLogic.resolve(all), id: \.id, currencyCode: \.currencyCode)
    }

    // MARK: - Agrupar

    @Test func cards_linesGoInsideTheirCard_inCurrencyOrder_andCardsKeepTheirOrder() {
        // La línea USD va delante de la principal en la lista: el orden de las tarjetas lo da la cabeza.
        let shown = [standardNodes[1], standardNodes[3], standardNodes[0], standardNodes[2], standardNodes[4]]
        let result = cards(shown, all: standardNodes)
        #expect(result.map(\.head.id) == [savings, card, dollars])
        #expect(result[1].lines.map(\.id) == [eur, usd])
        #expect(result[0].lines.isEmpty)
    }

    @Test func cards_lineWhosePrincipalIsNotShown_isItsOwnCard() {
        // Solo se muestran las líneas (p. ej. una lista que no incluye la principal): no desaparecen.
        let result = cards([standardNodes[1]], all: standardNodes)
        #expect(result.map(\.head.id) == [usd])
    }

    @Test func cards_brokenLine_isItsOwnCard() {
        // Misma divisa que la principal: el enlace no vale y la cuenta se ve suelta.
        let nodes = [node(card, "PEN"), node(usd, "PEN", parent: card)]
        let result = cards(nodes, all: nodes)
        #expect(result.map(\.head.id) == [card, usd])
        #expect(result.allSatisfy { $0.lines.isEmpty })
    }

    @Test func cards_lineOfAnArchivedPrincipal_isItsOwnCard() {
        let all = [node(card, "PEN", archived: true), node(usd, "USD", parent: card)]
        let result = cards([all[1]], all: all)
        #expect(result.map(\.head.id) == [usd])
    }

    @Test func sortOrderNames_putsEachLineRightAfterItsCard() {
        let shown = [standardNodes[3], standardNodes[0], standardNodes[1], standardNodes[2], standardNodes[4]]
        var result = cards(shown, all: standardNodes)
        // Reordenar mueve la tarjeta entera: la tarjeta pasa al final.
        result.append(result.remove(at: 1))
        let names = AccountCardLogic.sortOrderNames(result) { $0.id.uuidString }
        #expect(names == [savings, dollars, card, eur, usd].map(\.uuidString))
    }

    // MARK: - Recordatorio

    @Test func ownsCardSettings_onlyNotForAValidLine() {
        let roles = AccountLineLogic.resolve(standardNodes)
        #expect(AccountCardLogic.ownsCardSettings(roles[card]))
        #expect(!AccountCardLogic.ownsCardSettings(roles[usd]))
        #expect(AccountCardLogic.ownsCardSettings(roles[savings]))
        let broken = AccountLineLogic.resolve([node(usd, "USD", parent: otherCard)])
        #expect(AccountCardLogic.ownsCardSettings(broken[usd]), "una línea huérfana se ve suelta y tiene los suyos")
    }

    // MARK: - Añadir y vincular

    @Test func canHaveLines_userAccountAliveAndWithoutOwnLink() {
        #expect(AccountCardLogic.canHaveLines(node(card, "PEN")))
        #expect(!AccountCardLogic.canHaveLines(node(usd, "USD", parent: card)))
        #expect(!AccountCardLogic.canHaveLines(node(card, "PEN", archived: true)))
        #expect(!AccountCardLogic.canHaveLines(node(card, "PEN", system: true)))
    }

    @Test func addableCurrencies_excludeThePrincipalsAndItsLiveLines() {
        let available = ["PEN", "USD", "EUR", "MXN"]
        #expect(AccountCardLogic.addableCurrencies(principalID: card, nodes: standardNodes, available: available)
                == ["MXN"])
        // Una línea archivada sigue ocupando su divisa: otra nueva dejaría dos en la ranura al desarchivarla.
        let withArchived = [node(card, "PEN"), node(usd, "USD", parent: card, archived: true)]
        #expect(AccountCardLogic.addableCurrencies(principalID: card, nodes: withArchived, available: available)
                == ["EUR", "MXN"])
    }

    @Test func linkCandidates_explainEachRejection_andPutTheValidOnesFirst() {
        let nodes = [node(card, "PEN"), node(usd, "USD", parent: card),
                     node(savings, "PEN"), node(dollars, "USD"),
                     node(otherCard, "EUR"), node(otherLine, "MXN", parent: otherCard),
                     node(eur, "GBP", archived: true)]
        let candidates = AccountCardLogic.linkCandidates(principalID: card, nodes: nodes)
        // Fuera: la propia tarjeta, su línea y la archivada. Dentro: las demás, válidas primero.
        #expect(candidates.map(\.id) == [otherLine, savings, dollars, otherCard])
        #expect(candidates[0].rejection == nil, "una línea de otra tarjeta se puede mover a esta")
        #expect(candidates[1].rejection == .sameCurrencyAsPrincipal)
        #expect(candidates[2].rejection == .currencyAlreadyLinked(existingLineID: usd))
        #expect(candidates[3].rejection == .lineHasLines)
    }

    @Test func currencyCollidesWithLine_onlyWithALiveLine() {
        #expect(AccountCardLogic.currencyCollidesWithLine(principalID: card, currencyCode: "USD", nodes: standardNodes))
        #expect(!AccountCardLogic.currencyCollidesWithLine(principalID: card, currencyCode: "MXN", nodes: standardNodes))
        let archived = [node(card, "PEN"), node(usd, "USD", parent: card, archived: true)]
        #expect(!AccountCardLogic.currencyCollidesWithLine(principalID: card, currencyCode: "USD", nodes: archived))
    }

    @Test func lineName_cardAndCurrency_numberedWhenTaken() {
        #expect(AccountCardLogic.lineName(cardName: "Visa", currencyCode: "USD", taken: ["Visa"]) == "Visa · USD")
        #expect(AccountCardLogic.lineName(cardName: "Visa", currencyCode: "USD", taken: ["visa · usd"])
                == "Visa · USD 2")
        #expect(AccountCardLogic.lineName(cardName: "Visa", currencyCode: "USD", taken: ["Visa · USD", "Visa · USD 2"])
                == "Visa · USD 3")
    }

    // MARK: - Archivar

    @Test func linesToArchive_theLiveLines_evenWithThePrincipalAlreadyArchived() {
        let live = Set(AccountCardLogic.linesToArchive(principalID: card, nodes: standardNodes))
        #expect(live == [usd, eur])
        // Quien llama ya escribió `isArchived` en la principal: la cascada tiene que encontrarlas igual.
        var archivedFirst = standardNodes
        archivedFirst[0] = node(card, "PEN", archived: true)
        #expect(Set(AccountCardLogic.linesToArchive(principalID: card, nodes: archivedFirst)) == [usd, eur])
        // Una línea ya archivada no se vuelve a tocar, y una suelta tampoco.
        var oneArchived = standardNodes
        oneArchived[1] = node(usd, "USD", parent: card, archived: true)
        #expect(AccountCardLogic.linesToArchive(principalID: card, nodes: oneArchived) == [eur])
        #expect(AccountCardLogic.linesToArchive(principalID: savings, nodes: standardNodes).isEmpty)
    }

    // MARK: - Total

    @Test func total_convertsOnlyForeignLines_andSaysSo() {
        let amounts = [AccountCardLogic.LineAmount(value: -1_250, currencyCode: "PEN"),
                       AccountCardLogic.LineAmount(value: -80, currencyCode: "USD")]
        let result = AccountCardLogic.total(amounts, in: "PEN") { value, code in
            #expect(code == "USD")
            return value * 3.7
        }
        #expect(abs(result.value - (-1_546)) < 0.0001)
        #expect(result.isConverted)

        let same = AccountCardLogic.total([amounts[0]], in: "PEN") { _, _ in
            Issue.record("no debía convertir")
            return 0
        }
        #expect(same.value == -1_250)
        #expect(!same.isConverted)
    }
}
