//
//  GroupSplitLinesSummaryLogicTests.swift
//  YalaTests
//
//  Grupos B · la línea resumen bajo «Tu parte»: «Debes S/ 510.00 a Pía · Sip sube S/ 500.00» (maqueta `opcion-b.html`).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("Grupos B · línea resumen de «Partir»")
struct GroupSplitLinesSummaryLogicTests {
    private let sip = UUID()
    private let bcp = UUID()
    private var names: [UUID: String] { [sip: "Sip", bcp: "BCP"] }

    @Test("El caso de Pía: debes tu parte a quien pagó y Sip sube lo de la recarga")
    func piaCase() {
        let lines: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 500, destinationAccountID: sip),
            .expense(amount: 10, subcategoryID: UUID()),
        ]
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: true, payerName: "Pía", share: 510, lines: lines, accountNames: names)
        #expect(parts == [.owe(amount: 510, to: "Pía"), .raises(account: "Sip", amount: 500)])
    }

    @Test("Sin recargas solo queda lo que debes")
    func onlyExpenses_onlyTheDebt() {
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: true, payerName: "Pía", share: 510,
            lines: [.expense(amount: 510, subcategoryID: nil)], accountNames: names)
        #expect(parts == [.owe(amount: 510, to: "Pía")])
    }

    @Test("Si pagaste tú no debes nada: solo las cuentas que suben")
    func paidByMe_noDebt() {
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: false, payerName: "Pía", share: 510,
            lines: [.transfer(amount: 500, destinationAccountID: sip), .expense(amount: 10, subcategoryID: nil)],
            accountNames: names)
        #expect(parts == [.raises(account: "Sip", amount: 500)])
    }

    @Test("Si pagaste tú y no hay recargas, no hay línea")
    func paidByMe_noTransfers_empty() {
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: false, payerName: nil, share: 100,
            lines: [.expense(amount: 100, subcategoryID: nil)], accountNames: names)
        #expect(parts.isEmpty)
    }

    @Test("Dos recargas a la misma cuenta se suman, en el orden de la primera")
    func transfersToTheSameAccount_add() {
        let lines: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 100, destinationAccountID: bcp),
            .transfer(amount: 200, destinationAccountID: sip),
            .transfer(amount: 50, destinationAccountID: bcp),
        ]
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: true, payerName: "Pía", share: 350, lines: lines, accountNames: names)
        #expect(parts == [
            .owe(amount: 350, to: "Pía"),
            .raises(account: "BCP", amount: 150),
            .raises(account: "Sip", amount: 200),
        ])
    }

    @Test("Una recarga sin cuenta elegida, o a una cuenta que ya no está, no sale")
    func transfersWithoutAccount_skipped() {
        let lines: [GroupSplitLinesRecipe.Line] = [
            .transfer(amount: 100, destinationAccountID: nil),
            .transfer(amount: 200, destinationAccountID: UUID()),
        ]
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: true, payerName: "Pía", share: 300, lines: lines, accountNames: names)
        #expect(parts == [.owe(amount: 300, to: "Pía")])
    }

    @Test("Sin el nombre de quien pagó no se dice a quién debes")
    func noPayerName_noDebtPart() {
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: true, payerName: "", share: 300,
            lines: [.transfer(amount: 300, destinationAccountID: sip)], accountNames: names)
        #expect(parts == [.raises(account: "Sip", amount: 300)])
    }
}
