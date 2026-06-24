//
//  GroupsBetaGateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupsBetaGateLogic`: validación del código beta
//  (con trim defensivo) y la decisión de mostrar el gate (bloqueo estricto
//  con exención solo para invitados por enlace).
//
//  Sin SwiftUI, sin SwiftData, sin singletons, sin `makeTestContext()` — evita
//  flake R8 conocido.
//

import Foundation
import Testing

@testable import Yala

struct GroupsBetaGateLogicTests {

    // MARK: - isValidCode

    @Test func isValidCode_exactCodeReturnsTrue() {
        #expect(GroupsBetaGateLogic.isValidCode("1050") == true)
    }

    @Test func isValidCode_surroundingWhitespaceReturnsTrue() {
        #expect(GroupsBetaGateLogic.isValidCode("  1050 ") == true)
    }

    @Test func isValidCode_emptyReturnsFalse() {
        #expect(GroupsBetaGateLogic.isValidCode("") == false)
    }

    @Test func isValidCode_wrongDigitsReturnsFalse() {
        #expect(GroupsBetaGateLogic.isValidCode("1051") == false)
    }

    @Test func isValidCode_nonNumericReturnsFalse() {
        #expect(GroupsBetaGateLogic.isValidCode("abcd") == false)
    }

    @Test func isValidCode_partialReturnsFalse() {
        #expect(GroupsBetaGateLogic.isValidCode("105") == false)
    }

    // MARK: - shouldShowGate

    @Test func shouldShowGate_lockedNonInviteReturnsTrue() {
        #expect(GroupsBetaGateLogic.shouldShowGate(isUnlocked: false, isGroupInviteMode: false) == true)
    }

    @Test func shouldShowGate_unlockedReturnsFalse() {
        #expect(GroupsBetaGateLogic.shouldShowGate(isUnlocked: true, isGroupInviteMode: false) == false)
    }

    /// Invitado por enlace: exento del gate aunque no haya ingresado el código.
    @Test func shouldShowGate_groupInviteExemptReturnsFalse() {
        #expect(GroupsBetaGateLogic.shouldShowGate(isUnlocked: false, isGroupInviteMode: true) == false)
    }

    @Test func shouldShowGate_unlockedAndInviteReturnsFalse() {
        #expect(GroupsBetaGateLogic.shouldShowGate(isUnlocked: true, isGroupInviteMode: true) == false)
    }
}
