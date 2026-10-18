//
//  AccountLineLogicTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 1: las reglas puras de `AccountLineLogic`, un caso por regla del ticket
//  `multi-currency-accounts-1-model-and-sync` (misma divisa, divisa de la principal, segundo nivel, ciclo,
//  autoenlace, huérfana, tipo de cuenta) más el desempate entre dos teléfonos y el reenlace tras regenerar un
//  `shortcutID`. Sin SwiftData: nodos a mano.
//

import Foundation
import Testing

@testable import Yala

struct AccountLineLogicTests {

    // UUIDs fijos con orden conocido por `uuidString` (el desempate es el menor).
    private let card = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    private let usdA = UUID(uuidString: "20000000-0000-4000-8000-00000000000A")!
    private let usdB = UUID(uuidString: "30000000-0000-4000-8000-00000000000B")!
    private let eur = UUID(uuidString: "40000000-0000-4000-8000-000000000004")!
    private let other = UUID(uuidString: "50000000-0000-4000-8000-000000000005")!

    private func node(_ id: UUID, _ currency: String, parent: UUID? = nil,
                      archived: Bool = false, system: Bool = false) -> AccountLineNode {
        AccountLineNode(id: id, parentID: parent, currencyCode: currency, isArchived: archived, isSystem: system)
    }

    // MARK: - Tarjeta válida

    @Test func validCard_principalAndLine() {
        let roles = AccountLineLogic.resolve([node(card, "PEN"), node(usdA, "USD", parent: card)])
        #expect(roles[card] == .principal(lineIDs: [usdA]))
        #expect(roles[usdA] == .line(principalID: card))
    }

    @Test func accountWithoutLinks_isStandalone() {
        let roles = AccountLineLogic.resolve([node(card, "PEN"), node(other, "USD")])
        #expect(roles[card] == .standalone)
        #expect(roles[other] == .standalone)
    }

    @Test func twoCurrencies_twoLines() {
        let roles = AccountLineLogic.resolve([
            node(card, "PEN"), node(usdA, "USD", parent: card), node(eur, "EUR", parent: card),
        ])
        #expect(roles[card] == .principal(lineIDs: [usdA, eur]))
        #expect(roles[eur] == .line(principalID: card))
    }

    // MARK: - Regla: dos líneas en la misma divisa

    @Test func sameCurrencyTwice_lowestIDKeepsTheSlot_otherIsStandalone() {
        let roles = AccountLineLogic.resolve([
            node(card, "PEN"), node(usdB, "USD", parent: card), node(usdA, "USD", parent: card),
        ])
        #expect(roles[usdA] == .line(principalID: card))
        #expect(roles[usdB] == .brokenLine(.duplicateCurrency(keptLineID: usdA)))
        #expect(roles[card] == .principal(lineIDs: [usdA]))
    }

    @Test func sameCurrencyTwice_isDeterministicForAnyInputOrder() {
        let nodes = [node(card, "PEN"), node(usdB, "USD", parent: card), node(usdA, "USD", parent: card)]
        let expected = AccountLineLogic.resolve(nodes)
        for permutation in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]] {
            #expect(AccountLineLogic.resolve(permutation.map { nodes[$0] }) == expected)
        }
    }

    @Test func linkRejection_currencyAlreadyLinked() {
        let nodes = [node(card, "PEN"), node(usdA, "USD", parent: card), node(usdB, "USD")]
        #expect(AccountLineLogic.linkRejection(lineID: usdB, principalID: card, among: nodes)
                == .currencyAlreadyLinked(existingLineID: usdA))
    }

    @Test func archivedLine_doesNotHoldTheSlot() {
        let nodes = [node(card, "PEN"), node(usdA, "USD", parent: card, archived: true), node(usdB, "USD")]
        #expect(AccountLineLogic.linkRejection(lineID: usdB, principalID: card, among: nodes) == nil)
        let linked = [node(card, "PEN"), node(usdA, "USD", parent: card, archived: true), node(usdB, "USD", parent: card)]
        let roles = AccountLineLogic.resolve(linked)
        #expect(roles[usdB] == .line(principalID: card), "la archivada no compite por la divisa")
        #expect(roles[usdA] == .line(principalID: card), "sigue siendo una línea (archivada) de la tarjeta")
    }

    // MARK: - Regla: línea en la divisa de la principal

    @Test func lineInPrincipalCurrency_isBroken_andRejected() {
        let roles = AccountLineLogic.resolve([node(card, "PEN"), node(other, "PEN", parent: card)])
        #expect(roles[other] == .brokenLine(.sameCurrencyAsPrincipal))
        #expect(roles[card] == .standalone)
        #expect(AccountLineLogic.linkRejection(lineID: other, principalID: card,
                                               among: [node(card, "PEN"), node(other, "PEN")])
                == .sameCurrencyAsPrincipal)
    }

    // MARK: - Regla: un solo nivel

    @Test func secondLevel_isBroken() {
        // card ← usdA ← eur: la principal de `eur` es a su vez una línea.
        let roles = AccountLineLogic.resolve([
            node(card, "PEN"), node(usdA, "USD", parent: card), node(eur, "EUR", parent: usdA),
        ])
        #expect(roles[usdA] == .line(principalID: card))
        #expect(roles[eur] == .brokenLine(.principalIsLine))
    }

    @Test func linkRejection_principalIsLine() {
        let nodes = [node(card, "PEN"), node(usdA, "USD", parent: card), node(eur, "EUR")]
        #expect(AccountLineLogic.linkRejection(lineID: eur, principalID: usdA, among: nodes) == .principalIsLine)
    }

    @Test func linkRejection_lineHasLines() {
        // `card` ya es principal de `usdA`: no puede pasar a ser línea de `other`.
        let nodes = [node(card, "PEN"), node(usdA, "USD", parent: card), node(other, "EUR")]
        #expect(AccountLineLogic.linkRejection(lineID: card, principalID: other, among: nodes) == .lineHasLines)
    }

    // MARK: - Regla: ciclo y autoenlace

    @Test func cycle_bothBroken_andRejected() {
        let roles = AccountLineLogic.resolve([node(card, "PEN", parent: usdA), node(usdA, "USD", parent: card)])
        #expect(roles[card] == .brokenLine(.principalIsLine))
        #expect(roles[usdA] == .brokenLine(.principalIsLine))
        let nodes = [node(card, "PEN"), node(usdA, "USD", parent: card)]
        #expect(AccountLineLogic.linkRejection(lineID: card, principalID: usdA, among: nodes) == .cycle)
    }

    @Test func selfLink_isBroken_andRejected() {
        let roles = AccountLineLogic.resolve([node(card, "PEN", parent: card)])
        #expect(roles[card] == .brokenLine(.selfLink))
        #expect(AccountLineLogic.linkRejection(lineID: card, principalID: card, among: [node(card, "PEN")])
                == .selfLink)
    }

    // MARK: - Regla: huérfana → suelta, y deja de serlo al llegar su principal

    @Test func orphan_isStandaloneUntilItsPrincipalArrives() {
        let alone = AccountLineLogic.resolve([node(usdA, "USD", parent: card)])
        #expect(alone[usdA] == .brokenLine(.orphan))
        #expect(alone[usdA]?.isLine == false)
        let arrived = AccountLineLogic.resolve([node(usdA, "USD", parent: card), node(card, "PEN")])
        #expect(arrived[usdA] == .line(principalID: card))
    }

    @Test func archivedPrincipal_leavesItsLinesStandalone() {
        let roles = AccountLineLogic.resolve([node(card, "PEN", archived: true), node(usdA, "USD", parent: card)])
        #expect(roles[usdA] == .brokenLine(.principalArchived))
    }

    @Test func systemAccounts_neverLink() {
        let asLine = AccountLineLogic.resolve([node(card, "PEN"), node(usdA, "USD", parent: card, system: true)])
        #expect(asLine[usdA] == .brokenLine(.systemAccount))
        let asPrincipal = AccountLineLogic.resolve([node(card, "PEN", system: true), node(usdA, "USD", parent: card)])
        #expect(asPrincipal[usdA] == .brokenLine(.systemAccount))
        #expect(AccountLineLogic.linkRejection(lineID: usdA, principalID: card,
                                               among: [node(card, "PEN", system: true), node(usdA, "USD")])
                == .systemAccount)
    }

    @Test func collapsedIdentity_isAmbiguous_neverALine() {
        let roles = AccountLineLogic.resolve([
            node(card, "PEN"), node(card, "EUR"), node(usdA, "USD", parent: card),
        ])
        #expect(roles[usdA] == .brokenLine(.ambiguousIdentity))
        #expect(AccountLineLogic.linkRejection(lineID: usdA, principalID: card,
                                               among: [node(card, "PEN"), node(card, "EUR"), node(usdA, "USD")])
                == .ambiguousIdentity)
    }

    @Test func linkRejection_validCase_isNil() {
        #expect(AccountLineLogic.linkRejection(lineID: usdA, principalID: card,
                                               among: [node(card, "PEN"), node(usdA, "USD")]) == nil)
    }

    // MARK: - Desduplicar es leer: dos teléfonos, la misma ranura

    @Test func duplicates_twoPhonesSeeTheSameWinner_whateverEachReceivedFirst() {
        let phone1 = [node(card, "PEN"), node(usdB, "USD", parent: card), node(usdA, "USD", parent: card)]
        let phone2 = [node(usdA, "USD", parent: card), node(card, "PEN"), node(usdB, "USD", parent: card)]
        #expect(AccountLineLogic.resolve(phone1)[usdA] == .line(principalID: card))
        #expect(AccountLineLogic.resolve(phone2)[usdA] == .line(principalID: card))
        // Un teléfono que solo ve una de las dos la lee como línea: no hay escritura que lo contradiga después.
        #expect(AccountLineLogic.resolve([node(card, "PEN"), node(usdB, "USD", parent: card)])[usdB]
                == .line(principalID: card))
    }

    @Test func duplicates_orphansAndOtherBrokenLinksAreNotDuplicates() {
        let samePEN = UUID(uuidString: "60000000-0000-4000-8000-000000000006")!
        let roles = AccountLineLogic.resolve([
            node(card, "PEN"), node(usdA, "USD", parent: card),
            node(eur, "EUR", parent: other),          // huérfana
            node(samePEN, "PEN", parent: card),       // divisa de la principal
        ])
        #expect(roles[eur] == .brokenLine(.orphan))
        #expect(roles[samePEN] == .brokenLine(.sameCurrencyAsPrincipal))
        #expect(roles[usdA] == .line(principalID: card))
    }

    // MARK: - Reenlace tras regenerar un `shortcutID`

    @Test func relink_singleCandidate_relinksToTheNewID() {
        let old = card
        let newPrincipal = UUID()
        let newOther = UUID()
        // Dos cuentas compartían `old`: la principal en PEN y otra en USD (misma divisa que la línea → no candidata).
        let regenerated = [
            RegeneratedAccountIdentity(oldID: old, newID: newPrincipal, parentID: nil, currencyCode: "PEN", isSystem: false),
            RegeneratedAccountIdentity(oldID: old, newID: newOther, parentID: nil, currencyCode: "USD", isSystem: false),
        ]
        let targets = AccountLineLogic.relinkTargets(lines: [0: node(usdA, "USD", parent: old)], regenerated: regenerated)
        #expect(targets == [0: newPrincipal])
    }

    @Test func relink_twoCandidates_leavesTheLineOrphanInsteadOfGuessing() {
        let old = card
        let regenerated = [
            RegeneratedAccountIdentity(oldID: old, newID: UUID(), parentID: nil, currencyCode: "PEN", isSystem: false),
            RegeneratedAccountIdentity(oldID: old, newID: UUID(), parentID: nil, currencyCode: "EUR", isSystem: false),
        ]
        let targets = AccountLineLogic.relinkTargets(lines: [0: node(usdA, "USD", parent: old)], regenerated: regenerated)
        #expect(targets.isEmpty)
    }

    @Test func relink_ignoresSystemAndLineCandidates_andTheLineItself() {
        let old = card
        let lineNew = UUID()
        let principalNew = UUID()
        let regenerated = [
            RegeneratedAccountIdentity(oldID: old, newID: principalNew, parentID: nil, currencyCode: "PEN", isSystem: false),
            RegeneratedAccountIdentity(oldID: old, newID: UUID(), parentID: nil, currencyCode: "EUR", isSystem: true),
            RegeneratedAccountIdentity(oldID: old, newID: UUID(), parentID: other, currencyCode: "EUR", isSystem: false),
            // La propia línea también colapsó al mismo valor: no puede elegirse a sí misma.
            RegeneratedAccountIdentity(oldID: old, newID: lineNew, parentID: old, currencyCode: "USD", isSystem: false),
        ]
        let targets = AccountLineLogic.relinkTargets(lines: [0: node(lineNew, "USD", parent: old)], regenerated: regenerated)
        #expect(targets == [0: principalNew])
    }

    @Test func relink_lineNotPointingAtARegeneratedValue_isUntouched() {
        let regenerated = [
            RegeneratedAccountIdentity(oldID: other, newID: UUID(), parentID: nil, currencyCode: "PEN", isSystem: false),
        ]
        #expect(AccountLineLogic.relinkTargets(lines: [0: node(usdA, "USD", parent: card)], regenerated: regenerated).isEmpty)
    }
}
