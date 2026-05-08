//
//  GroupCardDisplayLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para `GroupCardDisplayLogic.displayMode`. Sin SwiftData
//  ni ModelContext — verifica solo la decisión basada en `SplitMemberStatus`.
//

import Foundation
import Testing

@testable import Yala

struct GroupCardDisplayLogicTests {

    @Test func displayMode_returnsPendingApproval_whenStatusIsPendingApproval() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .pendingApproval) == .pendingApproval)
    }

    @Test func displayMode_returnsRejected_whenStatusIsRejected() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .rejected) == .rejected)
    }

    @Test func displayMode_returnsActive_whenStatusIsActive() {
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .active) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsNil() {
        // Caso: current user no tiene SplitMember en el grupo (ej. owner pre-A0).
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: nil) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsLeft() {
        // Caso edge: defensa-en-profundidad. El filtro upstream debería evitar
        // mostrar cards de members .left, pero si llegan, no bloquear navegación.
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .left) == .active)
    }

    @Test func displayMode_returnsActive_whenStatusIsRemoved() {
        // Caso edge: similar a .left.
        #expect(GroupCardDisplayLogic.displayMode(memberStatus: .removed) == .active)
    }
}
