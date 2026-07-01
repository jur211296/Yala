//
//  GroupNotificationRecipientLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para GroupNotificationRecipientLogic (filtro de destinatarios
//  de notificaciones de grupo). Sin SwiftData/ModelContext — verifica solo la
//  decisión a partir de los IDs y el share ya resueltos.
//

import Foundation
import Testing

@testable import Yala

struct GroupNotificationRecipientLogicTests {

    private let me = "AAAAAAAA-0000-0000-0000-000000000001"
    private let other = "BBBBBBBB-0000-0000-0000-000000000002"

    // MARK: - expenseDecision

    @Test func expense_iAmPayer_skips() {
        // No me notifico de un gasto que yo mismo pagué (incluye 2º device mismo iCloud).
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: me, myShareAmount: 25) == .skip)
    }

    @Test func expense_iParticipate_notifiesWithMyShare() {
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other, myShareAmount: 25) == .notify(share: 25))
    }

    @Test func expense_iDontParticipate_skips() {
        // Otro pagó y no tengo share → el gasto no me concierne.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other, myShareAmount: nil) == .skip)
    }

    @Test func expense_unknownIdentity_skips() {
        // No sé quién soy en el grupo → conservador, no notificar.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: nil, paidByMemberID: other, myShareAmount: 25) == .skip)
    }

    @Test func expense_zeroShare_skips() {
        // Un share de 0 → no me concierne financieramente; "te toca S/0" sería ruido.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other, myShareAmount: 0) == .skip)
    }

    // MARK: - shouldNotifySettlement

    @Test func settlement_iAmReceiver_notifies() {
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: me) == true)
    }

    @Test func settlement_iAmNotReceiver_skips() {
        // Ana le pagó a otro: yo (tercero del grupo) no recibo "te pagó".
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: other) == false)
    }

    @Test func settlement_unknownIdentity_skips() {
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: nil, toMemberID: me) == false)
    }
}
