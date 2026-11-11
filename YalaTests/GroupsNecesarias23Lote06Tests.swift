//
//  GroupsNecesarias23Lote06Tests.swift
//  YalaTests
//
//  Mejoras necesarias 2.3 · lote 06 (Grupos: saldos que se contradicen y lectura con VoiceOver). La lógica pura de los
//  cinco puntos; lo que se ve lo fija `GroupsNecesarias23Lote06UITests`.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupsNecesarias23Lote06Tests {

    private let me = "me"
    private typealias Logic = GroupBalancesPresentationLogic

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    // MARK: - 1 · La frase de la cifra

    /// «Menos pagos» apagado: debes S/ 40 a Ana y Beto te debe S/ 30. El neto (debes S/ 10) es la cifra; la frase no
    /// puede decir «Nadie te debe nada».
    @Test func crossDebts_whenYouOweAndAreOwedInTheSameCurrency_sayBoth() throws {
        let debts = [debt(me, "ana", 40), debt("beto", me, 30), debt("beto", "ana", 40)]
        let summary = try #require(Logic.summary(debts: debts, currentUserMemberID: me))
        #expect(summary.kind == .iOwe)
        let cross = Logic.crossDebts(debts: debts, currentUserMemberID: me)
        #expect(cross == .init(owedToMe: [.init(currencyCode: "PEN", amount: 30)],
                               iOwe: [.init(currencyCode: "PEN", amount: 40)]))
        #expect(Logic.summarySentence(summary: summary, cross: cross)
                == .both(owedToMe: [.init(currencyCode: "PEN", amount: 30)],
                         iOwe: [.init(currencyCode: "PEN", amount: 40)]))
    }

    /// Lo mismo cuando el neto es cero: «Estás a mano» de cifra, pero la frase dice que debes S/ 40 y te deben S/ 40.
    @Test func crossDebts_withNetZero_stillSayBoth() throws {
        let debts = [debt(me, "ana", 40), debt("beto", me, 40)]
        let summary = try #require(Logic.summary(debts: debts, currentUserMemberID: me))
        #expect(summary.kind == .settled)
        let cross = Logic.crossDebts(debts: debts, currentUserMemberID: me)
        #expect(Logic.summarySentence(summary: summary, cross: cross)
                == .both(owedToMe: [.init(currencyCode: "PEN", amount: 40)],
                         iOwe: [.init(currencyCode: "PEN", amount: 40)]))
    }

    /// Y el rótulo de encima tampoco puede decir «Estás a mano» sobre «Tú pagas a Ana»: neto cero con deudas cruzadas
    /// tiene su propio rótulo. Sin cruce, «a mano» sigue siendo verdad, y los otros dos lados no cambian.
    @Test func caption_withNetZero_andCrossDebts_isNotAllSquare() throws {
        let crossed = [debt(me, "ana", 40), debt("beto", me, 40)]
        let summary = try #require(Logic.summary(debts: crossed, currentUserMemberID: me))
        let cross = Logic.crossDebts(debts: crossed, currentUserMemberID: me)
        #expect(Logic.groupCaption(summary: summary, cross: cross) == .evenWithDebts)

        let none = try #require(Logic.summary(debts: [], currentUserMemberID: me))
        #expect(Logic.groupCaption(summary: none, cross: nil) == .settled)

        let owing = [debt(me, "ana", 40), debt("beto", me, 30)]
        let owingSummary = try #require(Logic.summary(debts: owing, currentUserMemberID: me))
        #expect(Logic.groupCaption(summary: owingSummary,
                                   cross: Logic.crossDebts(debts: owing, currentUserMemberID: me)) == .iOwe)
        let owed = [debt("beto", me, 30)]
        let owedSummary = try #require(Logic.summary(debts: owed, currentUserMemberID: me))
        #expect(Logic.groupCaption(summary: owedSummary, cross: nil) == .owedToMe)
        #expect(L10n.GroupsNecesarias06.summaryEvenCaption != L10n.UXL13.summarySettled)
        #expect(L10n.GroupsNecesarias06.summaryEvenCaption != "groups.n23l06.summaryEvenCaption")
    }

    /// «Menos pagos» encendido: nunca debes y te deben en la misma moneda, así que la frase es la de siempre.
    @Test func simplifiedDebts_keepTheUsualSentence() throws {
        let simplified = DebtSimplificationService.simplify(
            debts: [debt(me, "ana", 40), debt("beto", me, 30), debt("beto", "ana", 40)])
        let summary = try #require(Logic.summary(debts: simplified, currentUserMemberID: me))
        #expect(Logic.crossDebts(debts: simplified, currentUserMemberID: me) == nil)
        #expect(Logic.summarySentence(summary: summary, cross: nil) == .iOweOnly)
    }

    /// Control: una moneda a favor y otra en contra no es cruce (no hay nada que el neto esconda), y la frase de siempre
    /// ya lo dice («Y tú debes $ 10.00.»).
    @Test func differentCurrencies_areNotACross() throws {
        let debts = [debt("ana", me, 30), debt(me, "beto", 10, "USD")]
        let summary = try #require(Logic.summary(debts: debts, currentUserMemberID: me))
        #expect(Logic.crossDebts(debts: debts, currentUserMemberID: me) == nil)
        #expect(Logic.summarySentence(summary: summary, cross: nil)
                == .alsoOwe([.init(currencyCode: "USD", amount: 10)]))
    }

    @Test func usualSentences_withoutCross() throws {
        let owed = try #require(Logic.summary(debts: [debt("ana", me, 30)], currentUserMemberID: me))
        #expect(Logic.summarySentence(summary: owed, cross: nil) == .owedToMeOnly)
        let settled = try #require(Logic.summary(debts: [debt("ana", "beto", 30)], currentUserMemberID: me))
        #expect(Logic.summarySentence(summary: settled, cross: nil) == .settled)
        #expect(Logic.crossDebts(debts: [debt("ana", me, 30)], currentUserMemberID: nil) == nil)
    }

    // MARK: - 2 y 4 · Quién paga a quién, contado desde ti

    @Test func pairRole_fromYou_toYou_andBetweenOthers() {
        #expect(Logic.pairRole(fromMemberID: me, toMemberID: "ana", currentUserMemberID: me) == .youPay)
        #expect(Logic.pairRole(fromMemberID: "beto", toMemberID: me, currentUserMemberID: me) == .paysYou)
        #expect(Logic.pairRole(fromMemberID: "beto", toMemberID: "ana", currentUserMemberID: me) == .others)
        #expect(Logic.pairRole(fromMemberID: "beto", toMemberID: me, currentUserMemberID: nil) == .others)
    }

    /// Los textos de VoiceOver de una deuda que te pagan y de un pago, en español. El idioma se fija aquí: sin él, el
    /// texto sale en el idioma del simulador, y en el runner del CI (`en_US`) es «Beto pays you», no «te paga».
    @Test(.appLanguageStateIsolated) func spokenTexts_readFromYou() {
        LanguageManager.overrideLanguage = "es"
        #expect(L10n.GroupsNecesarias06.debtA11yToMe(from: "Beto", amounts: "S/ 30.00").contains("te paga"))
        #expect(!L10n.GroupsNecesarias06.debtA11yToMe(from: "Beto", amounts: "S/ 30.00").contains("Tú"))
        #expect(!L10n.GroupsNecesarias06.paysYou.isEmpty)
        #expect(L10n.GroupsNecesarias06.settlementToMe(from: "Beto", amount: "S/ 10.00", date: "10 nov 2026",
                                                       status: "Confirmada").hasPrefix("Beto"))
    }

    // MARK: - 3 · «¿Quién puso más?»: tu fila dice «Tú»

    @Test func whoPaidMost_yourRowSaysYou() {
        let names = ["lucia": "Lucía", "ana": "Ana"]
        #expect(GroupStatsViewModel.memberDisplayName(memberID: "lucia", currentUserMemberID: "lucia", names: names)
                == L10n.UXL13.you)
        #expect(GroupStatsViewModel.memberDisplayName(memberID: "ana", currentUserMemberID: "lucia", names: names) == "Ana")
        // Sin usuario resuelto, el nombre de siempre.
        #expect(GroupStatsViewModel.memberDisplayName(memberID: "lucia", currentUserMemberID: nil, names: names) == "Lucía")
    }

    // MARK: - 5 · Un grupo sin nada apuntado no está «al día»

    @Test func emptyBalances_withoutEntries_sayNoExpenses_andSettledGroupsStaySettled() {
        #expect(Logic.emptyState(hasExpenses: false, hasSettlements: false) == .noEntries)
        #expect(Logic.emptyState(hasExpenses: true, hasSettlements: false) == .settled)
        #expect(Logic.emptyState(hasExpenses: false, hasSettlements: true) == .settled)
    }
}
