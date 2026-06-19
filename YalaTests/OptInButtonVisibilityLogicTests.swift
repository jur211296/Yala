//
//  OptInButtonVisibilityLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — opt-in button visibility (D1)")
struct OptInButtonVisibilityLogicTests {

    @Test
    func notPayer_neverShows() {
        #expect(OptInButtonVisibilityLogic.shouldShow(
            isCurrentUserPayer: false, hasRealBridgedTransaction: false
        ) == false)
        #expect(OptInButtonVisibilityLogic.shouldShow(
            isCurrentUserPayer: false, hasRealBridgedTransaction: true
        ) == false)
    }

    @Test
    func payer_withExistingTx_doesNotShow() {
        #expect(OptInButtonVisibilityLogic.shouldShow(
            isCurrentUserPayer: true, hasRealBridgedTransaction: true
        ) == false)
    }

    @Test
    func payer_withoutExistingTx_shows() {
        #expect(OptInButtonVisibilityLogic.shouldShow(
            isCurrentUserPayer: true, hasRealBridgedTransaction: false
        ) == true)
    }
}
