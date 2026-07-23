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
    private let third = "CCCCCCCC-0000-0000-0000-000000000003"

    // MARK: - expenseDecision (legado — sin lastEditedByMemberID)

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

    // MARK: - expenseDecision (autoexclusión del eco por AUTOR — lastEditedByMemberID)

    @Test func expense_iEditedGastoPaidByOther_skips() {
        // EL BUG REPORTADO: edito un gasto pagado por otro. El eco vuelve; como YO soy el autor,
        // no debe notificarme (antes: paidBy=other≠me → notificaba "other actualizó").
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other,
            lastEditedByMemberID: me, myShareAmount: 25) == .skip)
    }

    @Test func expense_iCreatedGastoPaidByOther_skips() {
        // Registro "other pagó" (soy el creador, other el pagador). Autor=yo → no me llega el eco.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other,
            lastEditedByMemberID: me, myShareAmount: 25) == .skip)
    }

    @Test func expense_thirdEditedGastoPaidByOther_notifies() {
        // Un tercero editó un gasto pagado por otro; yo participo → notify (autor≠yo, pagador≠yo).
        // La atribución "third actualizó" la resuelve expenseAttributionMemberID, no esta decisión.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: other,
            lastEditedByMemberID: third, myShareAmount: 25) == .notify(share: 25))
    }

    @Test func expense_otherEditedGastoPaidByMe_skips() {
        // Alguien editó un gasto que pagué yo → SILENCIO (comportamiento legado preservado; el 2º guard
        // `paidByMemberID == me` gana). Fuera de scope cambiarlo a notificar.
        #expect(GroupNotificationRecipientLogic.expenseDecision(
            currentMemberID: me, paidByMemberID: me,
            lastEditedByMemberID: other, myShareAmount: 25) == .skip)
    }

    // MARK: - expenseAttributionMemberID

    @Test func attribution_usesEditorWhenPresent() {
        #expect(GroupNotificationRecipientLogic.expenseAttributionMemberID(
            lastEditedByMemberID: other, paidByMemberID: me) == other)
    }

    @Test func attribution_fallsBackToPayerWhenNil() {
        #expect(GroupNotificationRecipientLogic.expenseAttributionMemberID(
            lastEditedByMemberID: nil, paidByMemberID: me) == me)
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

    // MARK: - shouldNotifySettlement (autoexclusión del eco Caso D — recordedByMemberID)

    @Test func settlement_iRecordedIt_skips() {
        // Registro "other me pagó" (soy el receptor Y quien lo registró). El eco no debe notificarme.
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: me, recordedByMemberID: me) == false)
    }

    @Test func settlement_otherRecorded_iAmReceiver_notifies() {
        // other registró "other me pagó" (Caso C desde su lado): yo (receptor) SÍ debo enterarme.
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: me, recordedByMemberID: other) == true)
    }

    @Test func settlement_legacyNilRecorder_iAmReceiver_notifies() {
        // Liquidación pre-campo (recorder nil) → solo el filtro por receptor (comportamiento legado).
        #expect(GroupNotificationRecipientLogic.shouldNotifySettlement(
            currentMemberID: me, toMemberID: me, recordedByMemberID: nil) == true)
    }
}
