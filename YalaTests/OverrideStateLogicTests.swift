//
//  OverrideStateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `OverrideStateLogic.compute`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — override UI state")
struct OverrideStateLogicTests {

    @Test
    func notActiveMember_hidesSection() {
        // pending/rejected/removed → sección oculta entera (D8).
        for override in [Bool?.none, .some(true), .some(false)] {
            for global in [true, false] {
                #expect(OverrideStateLogic.compute(
                    global: global, override: override, memberIsActive: false
                ) == .hiddenSection)
            }
        }
    }

    @Test
    func activeMember_globalOff_returnsDisabledOff() {
        // Override ignorado: global OFF → toggle disabled, no puede activarse per-grupo.
        for override in [Bool?.none, .some(true), .some(false)] {
            #expect(OverrideStateLogic.compute(
                global: false, override: override, memberIsActive: true
            ) == .disabledOff)
        }
    }

    @Test
    func activeMember_globalOn_overrideNil_returnsInheriting() {
        #expect(OverrideStateLogic.compute(
            global: true, override: nil, memberIsActive: true
        ) == .enabledOnInheriting)
    }

    @Test
    func activeMember_globalOn_overrideTrue_returnsLocal() {
        #expect(OverrideStateLogic.compute(
            global: true, override: true, memberIsActive: true
        ) == .enabledOnLocal)
    }

    @Test
    func activeMember_globalOn_overrideFalse_returnsLocalOff() {
        #expect(OverrideStateLogic.compute(
            global: true, override: false, memberIsActive: true
        ) == .enabledOffLocal)
    }
}
