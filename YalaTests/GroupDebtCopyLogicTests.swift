//
//  GroupDebtCopyLogicTests.swift
//  YalaTests
//
//  L19-4, L19-10 y L19-11 · los avisos de administrar un grupo dicen cuánto y a quién.
//

import Foundation
import Testing
@testable import Yala

@Suite("L19 · Frases de deuda con cifra")
@MainActor
struct GroupDebtCopyLogicTests {

    private let names = ["me": "Tú", "ana": "Ana", "beto": "Beto"]
    private func name(_ id: String) -> String { names[id] ?? id }
    private func money(_ value: Double, _ currency: String) -> String { "\(currency) \(String(format: "%.2f", value))" }

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    private func balance(_ id: String, _ display: String, _ net: Double, _ currency: String = "PEN") -> MemberBalance {
        MemberBalance(memberID: id, displayName: display, totalPaid: 0, totalOwes: 0, netBalance: net, currencyCode: currency)
    }

    // MARK: - Relaciones de persona a persona

    /// Quitar a Ana, que te debe: «Ana te debe PEN 80.00.»
    @Test func subjectOwesMe_saysItFromMyPointOfView() {
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: "ana", debts: [debt("ana", "me", 80)], currentMemberID: "me", name: name, money: money)
        #expect(sentences == [L10n.UXL19.owesYou("Ana", "PEN 80.00")])
    }

    /// Salir debiendo a Ana: «Debes PEN 270.00 a Ana.»
    @Test func iOwe_namesTheCounterpart() {
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: "me", debts: [debt("me", "ana", 270)], currentMemberID: "me", name: name, money: money)
        #expect(sentences == [L10n.UXL19.youOwe("Ana", "PEN 270.00")])
    }

    /// Lo que Ana debe a un tercero se cuenta con los dos nombres.
    @Test func betweenOthers_namesBoth() {
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: "ana", debts: [debt("ana", "beto", 30)], currentMemberID: "me", name: name, money: money)
        #expect(sentences == [L10n.UXL19.owesOther("Ana", "PEN 30.00", "Beto")])
    }

    /// Una frase por pareja, con las divisas juntas.
    @Test func relationSentences_groupThePairsCurrencies() {
        let debts = [debt("beto", "me", 40, "USD"), debt("beto", "me", 110), debt("beto", "ana", 30)]
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: "beto", debts: debts, currentMemberID: "me", name: name, money: money)
        #expect(sentences == [L10n.UXL19.owesYou("Beto", "PEN 110.00 + USD 40.00"),
                              L10n.UXL19.owesOther("Beto", "PEN 30.00", "Ana")])
    }

    /// Solo las deudas en las que participa la persona: la de Beto conmigo no entra al hablar de Ana.
    @Test func onlyTheSubjectsDebts() {
        let debts = [debt("beto", "me", 10), debt("me", "ana", 5, "USD")]
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: "ana", debts: debts, currentMemberID: "me", name: name, money: money)
        #expect(sentences == [L10n.UXL19.youOwe("Ana", "USD 5.00")])
        #expect(GroupDebtCopyLogic.debts(involving: "ana", in: debts).count == 1)
    }

    // MARK: - El bloqueo de eliminar

    /// Quién debe y cuánto, primero quien mira, y cada persona con sus divisas juntas.
    @Test func debtorsSentence_listsWhoOwes_meFirst_currenciesTogether() {
        let debts = [
            debt("beto", "ana", 30, "USD"),
            debt("me", "ana", 20, "PEN"),
            debt("beto", "ana", 30, "PEN"),
        ]
        let sentence = GroupDebtCopyLogic.debtorsSentence(debts: debts, currentMemberID: "me", name: name, money: money)
        let me = L10n.UXL19.youOweNet("PEN 20.00")
        let beto = L10n.UXL19.memberOwes("Beto", "PEN 30.00 + USD 30.00")
        #expect(sentence == GroupDebtCopyLogic.joined([me, beto]) + ".")
        #expect(sentence?.contains("Ana") == false, "Ana no debe: le deben")
    }

    /// Dos deudas de la misma persona en la misma divisa se suman.
    @Test func debtorsSentence_sumsTheSamePersonAndCurrency() {
        let debts = [debt("beto", "ana", 10), debt("beto", "me", 5)]
        let sentence = GroupDebtCopyLogic.debtorsSentence(debts: debts, currentMemberID: "me", name: name, money: money)
        #expect(sentence == L10n.UXL19.memberOwes("Beto", "PEN 15.00") + ".")
    }

    @Test func debtorsSentence_withoutDebts_isNil() {
        #expect(GroupDebtCopyLogic.debtorsSentence(debts: [], currentMemberID: "me", name: name, money: money) == nil)
    }
}
