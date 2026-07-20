//
//  ShellModeLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para ShellModeLogic.effective(onboardingMode:usageFocus:) — el
//  derivador ÚNICO del modo de la shell (D1, retención «Seguir con mis grupos»).
//  Tabla exhaustiva OnboardingMode × UsageFocus. Sin SwiftData, sin UI, sin singletons.
//

import Foundation
import Testing

@testable import Yala

struct ShellModeLogicTests {

    // MARK: - usageFocus == .full → byte-idéntico a isGroupInviteMode

    @Test func full_full_isFull() {
        #expect(ShellModeLogic.effective(onboardingMode: .full, usageFocus: .full) == .full)
    }

    @Test func completed_full_isFull() {
        #expect(ShellModeLogic.effective(onboardingMode: .completed, usageFocus: .full) == .full)
    }

    @Test func groupInvite_full_isGroupsFocused() {
        // groupInvite reduce SIEMPRE (byte-idéntico a isGroupInviteMode con usageFocus=.full).
        #expect(ShellModeLogic.effective(onboardingMode: .groupInvite, usageFocus: .full) == .groupsFocused)
    }

    // MARK: - usageFocus == .groupsOnly → siempre reduce, sin importar onboardingMode

    @Test func full_groupsOnly_isGroupsFocused() {
        // El caso D1: un usuario full que eligió «Solo mis grupos».
        #expect(ShellModeLogic.effective(onboardingMode: .full, usageFocus: .groupsOnly) == .groupsFocused)
    }

    @Test func completed_groupsOnly_isGroupsFocused() {
        #expect(ShellModeLogic.effective(onboardingMode: .completed, usageFocus: .groupsOnly) == .groupsFocused)
    }

    @Test func groupInvite_groupsOnly_isGroupsFocused() {
        #expect(ShellModeLogic.effective(onboardingMode: .groupInvite, usageFocus: .groupsOnly) == .groupsFocused)
    }

    // MARK: - Barrido de tabla completo (6 celdas)

    @Test func fullTable() {
        let cases: [(OnboardingMode, UsageFocus, ShellMode)] = [
            (.full, .full, .full),
            (.completed, .full, .full),
            (.groupInvite, .full, .groupsFocused),
            (.full, .groupsOnly, .groupsFocused),
            (.completed, .groupsOnly, .groupsFocused),
            (.groupInvite, .groupsOnly, .groupsFocused),
        ]
        for (mode, focus, expected) in cases {
            #expect(
                ShellModeLogic.effective(onboardingMode: mode, usageFocus: focus) == expected,
                "onboardingMode=\(mode) usageFocus=\(focus) → esperado \(expected)")
        }
    }
}
