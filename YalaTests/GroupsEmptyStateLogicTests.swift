//
//  GroupsEmptyStateLogicTests.swift
//  YalaTests
//
//  Tabla 2×2 del empty state del tab Grupos (H-2026-07-18-7). Pure-logic sin SwiftData/CloudKit/UI.
//

import Testing

@testable import Yala

@Suite("GroupsEmptyStateLogic · empty state del tab Grupos")
struct GroupsEmptyStateLogicTests {

    typealias Kind = GroupsEmptyStateLogic.Kind

    // MARK: - Flag OFF → SIEMPRE standard (byte-idéntico, sin importar sesión)

    @Test func flagOff_noSession_standard() {
        #expect(GroupsEmptyStateLogic.decide(flagOn: false, hasSession: false) == .standard)
    }

    @Test func flagOff_session_standard() {
        #expect(GroupsEmptyStateLogic.decide(flagOn: false, hasSession: true) == .standard)
    }

    // MARK: - Flag ON → sin sesión = re-entrada; con sesión = standard

    @Test func flagOn_session_standard() {
        #expect(GroupsEmptyStateLogic.decide(flagOn: true, hasSession: true) == .standard)
    }

    @Test func flagOn_noSession_signInToView() {
        #expect(GroupsEmptyStateLogic.decide(flagOn: true, hasSession: false) == .signInToView)
    }
}
