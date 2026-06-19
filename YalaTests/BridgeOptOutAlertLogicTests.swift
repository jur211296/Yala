//
//  BridgeOptOutAlertLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgeOptOutAlertLogic.shouldShowAlert`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — alert decision")
struct BridgeOptOutAlertLogicTests {

    @Test
    func bridgeOn_neverShowsAlert() {
        for kase in [BridgeOptOutAlertLogic.BridgeCase.caseA, .caseB, .caseC, .caseD] {
            #expect(BridgeOptOutAlertLogic.shouldShowAlert(
                case: kase, bridgeEffectivelyEnabled: true
            ) == false)
        }
    }

    @Test
    func bridgeOff_caseA_showsAlert() {
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: .caseA, bridgeEffectivelyEnabled: false
        ) == true)
    }

    @Test
    func bridgeOff_caseC_showsAlert() {
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: .caseC, bridgeEffectivelyEnabled: false
        ) == true)
    }

    @Test
    func bridgeOff_caseB_doesNotShowAlert() {
        // Caso B: otro pagó, no involucra TX personal real.
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: .caseB, bridgeEffectivelyEnabled: false
        ) == false)
    }

    @Test
    func bridgeOff_caseD_doesNotShowAlert() {
        // Caso D: el bridge ya crea el draft auto, el alert lo duplicaría.
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: .caseD, bridgeEffectivelyEnabled: false
        ) == false)
    }

    // MARK: - settlementCase mapping

    @Test
    func settlementCase_currentUserIsFrom_isCaseC() {
        #expect(BridgeOptOutAlertLogic.settlementCase(
            currentUserMemberID: "me", fromMemberID: "me", toMemberID: "beto"
        ) == .caseC)
    }

    @Test
    func settlementCase_currentUserIsTo_isCaseD() {
        // Escenario del bug: "Beto paga a Tú" → no debe disparar alert opt-in.
        #expect(BridgeOptOutAlertLogic.settlementCase(
            currentUserMemberID: "me", fromMemberID: "beto", toMemberID: "me"
        ) == .caseD)
    }

    @Test
    func settlementCase_currentUserNotInvolved_isNil() {
        #expect(BridgeOptOutAlertLogic.settlementCase(
            currentUserMemberID: "me", fromMemberID: "ana", toMemberID: "beto"
        ) == nil)
    }

    @Test
    func settlementCase_nilCurrentUser_isNil() {
        #expect(BridgeOptOutAlertLogic.settlementCase(
            currentUserMemberID: nil, fromMemberID: "ana", toMemberID: "beto"
        ) == nil)
    }

    // El Caso D entrante via form local NO muestra alert (regresión B-S2-f):
    // settlementCase → .caseD, y shouldShowAlert(.caseD, OFF) → false.
    @Test
    func settlementCaseD_withBridgeOff_compositeDoesNotShowAlert() {
        let kase = BridgeOptOutAlertLogic.settlementCase(
            currentUserMemberID: "me", fromMemberID: "beto", toMemberID: "me"
        )
        #expect(kase == .caseD)
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: kase!, bridgeEffectivelyEnabled: false
        ) == false)
    }
}
