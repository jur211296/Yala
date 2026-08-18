//
//  UITestHooksTests.swift
//  YalaTests
//
//  Pure-logic del parsing de launch arguments de UI testing (regla R8: sin contexto).
//

import Testing
@testable import Yala

@Suite struct UITestHooksTests {
    @Test func parseSeedProfile_present_returnsValue() {
        #expect(UITestHooks.parseSeedProfile(from: ["app", "-uitest", "-uitest-seed", "pesado"]) == "pesado")
    }

    @Test func parseSeedProfile_realistaAnywhere() {
        #expect(UITestHooks.parseSeedProfile(from: ["-uitest-seed", "realista", "-uitest"]) == "realista")
    }

    @Test func parseSeedProfile_absent_returnsNil() {
        #expect(UITestHooks.parseSeedProfile(from: ["app", "-uitest"]) == nil)
    }

    @Test func parseSeedProfile_flagAtEnd_returnsNil() {
        #expect(UITestHooks.parseSeedProfile(from: ["app", "-uitest-seed"]) == nil)
    }

    @Test func parseSeedProfile_followedByAnotherFlag_returnsNil() {
        #expect(UITestHooks.parseSeedProfile(from: ["app", "-uitest-seed", "-uitest-pro"]) == nil)
    }

    @Test func parseSeedProfile_deadPointer() {
        #expect(UITestHooks.parseSeedProfile(from: ["app", "-uitest", "-uitest-seed", "dead-pointer"]) == "dead-pointer")
    }

    // MARK: - parseValue (genérico — usado por -uitest-deeplink)

    @Test func parseValue_deeplinkPresent_returnsValue() {
        #expect(UITestHooks.parseValue(after: "-uitest-deeplink", from: ["app", "-uitest", "-uitest-deeplink", "groups"]) == "groups")
    }

    @Test func parseValue_deeplinkAbsent_returnsNil() {
        #expect(UITestHooks.parseValue(after: "-uitest-deeplink", from: ["app", "-uitest"]) == nil)
    }

    @Test func parseValue_deeplinkFlagAtEnd_returnsNil() {
        #expect(UITestHooks.parseValue(after: "-uitest-deeplink", from: ["app", "-uitest-deeplink"]) == nil)
    }

    @Test func parseValue_deeplinkFollowedByFlag_returnsNil() {
        #expect(UITestHooks.parseValue(after: "-uitest-deeplink", from: ["app", "-uitest-deeplink", "-uitest-pro"]) == nil)
    }
}
