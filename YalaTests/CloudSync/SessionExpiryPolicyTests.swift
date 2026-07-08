//
//  SessionExpiryPolicyTests.swift
//  YalaTests
//
//  Pure-logic tests for `SessionExpiryPolicy` (Modo Nube §f.3/§f.5, S11). No network — the full
//  truth table of (pending × canRenewSession) with the boundary at pending == 0/1.
//

import Foundation
import Testing

@testable import Yala

@Suite("Session Expiry Policy")
struct SessionExpiryPolicyTests {

    // MARK: - .ok cases

    @Test func noPending_isOk_evenWhenCannotRenew() {
        // Nothing waiting to upload → losing the session is not (yet) an actionable block.
        #expect(SessionExpiryPolicy.decide(pending: 0, canRenewSession: false) == .ok)
    }

    @Test func canRenew_isAlwaysOk() {
        #expect(SessionExpiryPolicy.decide(pending: 0, canRenewSession: true) == .ok)
        #expect(SessionExpiryPolicy.decide(pending: 5, canRenewSession: true) == .ok)
        #expect(SessionExpiryPolicy.decide(pending: 9_999, canRenewSession: true) == .ok)
    }

    // MARK: - .blockedNeedsSignIn cases

    @Test func pendingAndCannotRenew_isBlocked_carryingTheCount() {
        #expect(
            SessionExpiryPolicy.decide(pending: 1, canRenewSession: false) == .blockedNeedsSignIn(pending: 1)
        )
        #expect(
            SessionExpiryPolicy.decide(pending: 42, canRenewSession: false) == .blockedNeedsSignIn(pending: 42)
        )
    }

    @Test func boundary_atOnePending() {
        // pending == 0 → ok; pending == 1 → blocked (the guard is strictly > 0).
        #expect(SessionExpiryPolicy.decide(pending: 0, canRenewSession: false) == .ok)
        #expect(SessionExpiryPolicy.decide(pending: 1, canRenewSession: false) == .blockedNeedsSignIn(pending: 1))
    }

    @Test func defensive_negativePending_isOk() {
        // A nonsensical negative count is not an actionable block (defensive; > 0 guard).
        #expect(SessionExpiryPolicy.decide(pending: -3, canRenewSession: false) == .ok)
    }
}
