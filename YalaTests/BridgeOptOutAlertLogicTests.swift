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
        // Caso D: viene de sync remoto, no hay form para acoplar alert.
        #expect(BridgeOptOutAlertLogic.shouldShowAlert(
            case: .caseD, bridgeEffectivelyEnabled: false
        ) == false)
    }
}
