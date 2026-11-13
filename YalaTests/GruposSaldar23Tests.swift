//
//  GruposSaldar23Tests.swift
//  YalaTests
//
//  Decisión 37 de la revisión 2.3 (Grupos: saldar como en Splitwise, C1 + C2 + C3). Lógica pura de
//  `SettlementSaldar23Logic`; el cableado en pantalla lo fija `GruposSaldar23UITests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Grupos 2.3 · saldar como en Splitwise")
@MainActor
struct GruposSaldar23Tests {

    private let me = "me"
    private let ana = "ana"
    private let beto = "beto"

    // MARK: - C1 · Quién confirma

    @Test func lo_que_apunta_un_tercero_queda_por_confirmar() {
        #expect(SettlementSaldar23Logic.confirmsOnRecord(recorderMemberID: me, fromMemberID: beto, toMemberID: ana) == false)
        #expect(SettlementSaldar23Logic.recorderRole(recorderMemberID: me, fromMemberID: beto, toMemberID: ana) == .thirdParty)
    }

    @Test func lo_que_apuntan_quien_paga_o_quien_recibe_nace_confirmado() {
        #expect(SettlementSaldar23Logic.confirmsOnRecord(recorderMemberID: me, fromMemberID: me, toMemberID: ana))
        #expect(SettlementSaldar23Logic.confirmsOnRecord(recorderMemberID: me, fromMemberID: ana, toMemberID: me))
        #expect(SettlementSaldar23Logic.recorderRole(recorderMemberID: me, fromMemberID: ana, toMemberID: me) == .receiver)
        // Sin miembro resuelto, como antes.
        #expect(SettlementSaldar23Logic.confirmsOnRecord(recorderMemberID: nil, fromMemberID: beto, toMemberID: ana))
    }

    @Test func saldar_va_en_todas_las_deudas_si_se_sabe_quien_eres() {
        #expect(SettlementSaldar23Logic.offersSettle(involvesMe: false, currentUserMemberID: me, receiverCanConfirm: true))
        #expect(SettlementSaldar23Logic.offersSettle(involvesMe: true, currentUserMemberID: me, receiverCanConfirm: false))
        #expect(SettlementSaldar23Logic.offersSettle(involvesMe: false, currentUserMemberID: nil, receiverCanConfirm: true) == false)
    }

    /// Quien recibe salió del grupo o espera aprobación: no podría confirmarlo y el pago quedaría pendiente para siempre.
    @Test func entre_otros_no_se_ofrece_si_quien_recibe_no_puede_confirmar() {
        #expect(SettlementSaldar23Logic.offersSettle(involvesMe: false, currentUserMemberID: me, receiverCanConfirm: false) == false)
    }

    @Test func la_lista_dice_quien_lo_apunto_solo_si_fue_un_tercero() {
        #expect(SettlementSaldar23Logic.recordedByThirdParty(fromMemberID: beto, toMemberID: ana, recordedByMemberID: me))
        #expect(SettlementSaldar23Logic.recordedByThirdParty(fromMemberID: beto, toMemberID: ana, recordedByMemberID: beto) == false)
        #expect(SettlementSaldar23Logic.recordedByThirdParty(fromMemberID: beto, toMemberID: ana, recordedByMemberID: ana) == false)
        #expect(SettlementSaldar23Logic.recordedByThirdParty(fromMemberID: beto, toMemberID: ana, recordedByMemberID: nil) == false)
    }

    // MARK: - C2 · Todo o una parte

    @Test func todo_deja_a_mano_y_una_parte_dice_lo_que_queda() {
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 40, paying: 40) == .settles)
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 40, paying: 15) == .leaves(25))
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 40, paying: 0) == nil)
    }

    @Test func pagar_de_mas_se_avisa_con_la_diferencia() {
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 80, paying: 100) == .overpays(20))
    }

    /// 100 / 3 se enseña «33.33»: pagar lo que se ve deja a mano, no «queda S/ 0.00».
    @Test func la_deuda_con_mas_decimales_que_los_que_se_ven_queda_a_mano() {
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 100.0 / 3.0, paying: 33.33) == .settles)
        #expect(SettlementSaldar23Logic.amountOutcome(owed: 0.004, paying: 0.01, matchesShownDebt: true) == .settles)
    }

    @Test func escribir_otro_importe_con_todo_pasa_a_una_parte() {
        #expect(SettlementSaldar23Logic.scopeAfterTyping(.all, matchesShownDebt: false) == .part)
        #expect(SettlementSaldar23Logic.scopeAfterTyping(.all, matchesShownDebt: true) == .all)
        #expect(SettlementSaldar23Logic.scopeAfterTyping(.part, matchesShownDebt: true) == .part)
    }

    // MARK: - C3 · El aviso al guardar

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    private func name(_ id: String) -> String { id == me ? "Tú" : id.capitalized }
    private func format(_ debts: [Debt]) -> String { debts.map { "\($0.currencyCode) \($0.amount)" }.joined(separator: " + ") }

    @Test func el_resto_de_la_pareja_sale_de_las_deudas_recalculadas() {
        let debts = [debt(me, ana, 20), debt(beto, ana, 30), debt(ana, me, 5, "USD")]
        let rest = SettlementSaldar23Logic.pairRemainder(debts: debts, fromMemberID: me, toMemberID: ana)
        #expect(rest.payerOwes == [debt(me, ana, 20)])
        #expect(rest.receiverOwes == [debt(ana, me, 5, "USD")])
        #expect(SettlementSaldar23Logic.pairRemainder(debts: [debt(beto, ana, 30)], fromMemberID: me, toMemberID: ana).isSettled)
    }

    @Test func pagar_todo_dice_que_quedan_a_mano() {
        let text = SettlementSaldar23Logic.savedNotice(
            fromMemberID: me, toMemberID: ana, currentUserMemberID: me, isConfirmed: true, amount: "S/ 40.00",
            remainder: .init(payerOwes: [], receiverOwes: []), name: name, format: format)
        #expect(text == L10n.GruposSaldar23.noticeYouPaid(amount: "S/ 40.00", to: "Ana") + " "
                + L10n.GruposSaldar23.noticeSettled)
    }

    @Test func pagar_una_parte_dice_lo_que_aun_debes() {
        let text = SettlementSaldar23Logic.savedNotice(
            fromMemberID: me, toMemberID: ana, currentUserMemberID: me, isConfirmed: true, amount: "S/ 20.00",
            remainder: .init(payerOwes: [debt(me, ana, 20)], receiverOwes: []), name: name, format: format)
        #expect(text == L10n.GruposSaldar23.noticeYouPaid(amount: "S/ 20.00", to: "Ana") + " "
                + L10n.GruposSaldar23.noticeNowYouOwe(amounts: "PEN 20.0", to: "Ana"))
    }

    @Test func cobrar_de_mas_dice_que_ahora_debes_tu() {
        let text = SettlementSaldar23Logic.savedNotice(
            fromMemberID: ana, toMemberID: me, currentUserMemberID: me, isConfirmed: true, amount: "S/ 100.00",
            remainder: .init(payerOwes: [], receiverOwes: [debt(me, ana, 20)]), name: name, format: format)
        #expect(text == L10n.GruposSaldar23.noticePaidYou(from: "Ana", amount: "S/ 100.00") + " "
                + L10n.GruposSaldar23.noticeNowYouOwe(amounts: "PEN 20.0", to: "Ana"))
    }

    /// Lo apuntado por un tercero no mueve el saldo: el aviso dice a quién le toca confirmarlo, no «a mano».
    @Test func lo_apuntado_entre_otros_dice_quien_falta_que_confirme() {
        let text = SettlementSaldar23Logic.savedNotice(
            fromMemberID: beto, toMemberID: ana, currentUserMemberID: me, isConfirmed: false, amount: "S/ 30.00",
            remainder: .init(payerOwes: [debt(beto, ana, 30)], receiverOwes: []), name: name, format: format)
        #expect(text == L10n.GruposSaldar23.noticeOthersPaid(from: "Beto", amount: "S/ 30.00", to: "Ana") + " "
                + L10n.GruposSaldar23.noticeWaitingFor("Ana"))
    }
}
