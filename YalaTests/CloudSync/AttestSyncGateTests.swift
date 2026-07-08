//
//  AttestSyncGateTests.swift
//  YalaTests
//
//  Pure-logic tests for `AttestSyncGate` (Modo Nube §f.5, E2E-S10). No network, no DeviceCheck —
//  covers the transient/terminal classification across every `AppAttestError` shape (from the REAL
//  `AppAttestError` enum) with `retryCount` at the boundary, plus the onboarding upfront gate.
//

import Foundation
import Testing

@testable import Yala

@Suite("Attest Sync Gate")
struct AttestSyncGateTests {

    private let dummyNetworkError = NSError(domain: "test", code: -1)

    // MARK: - Always transient (regardless of retryCount)

    @Test(arguments: [0, 1, 5, 99])
    func network_isAlwaysTransient(retry: Int) {
        #expect(AttestSyncGate.classify(error: .network(dummyNetworkError), retryCount: retry) == .transient)
    }

    @Test(arguments: [0, 1, 5, 99])
    func server_isAlwaysTransient(retry: Int) {
        #expect(AttestSyncGate.classify(error: .server("http_503"), retryCount: retry) == .transient)
    }

    @Test(arguments: [0, 1, 5, 99])
    func unknownKey_isAlwaysTransient(retry: Int) {
        // Triggers a re-register in AppAttestClient — not a "device can't attest" verdict.
        #expect(AttestSyncGate.classify(error: .unknownKey, retryCount: retry) == .transient)
    }

    // MARK: - .unavailable: transient until it persists past N

    @Test func unavailable_belowThreshold_isTransient() {
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 0) == .transient)
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 2) == .transient) // maxRetries-1
    }

    @Test func unavailable_atOrAboveThreshold_isTerminal() {
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 3) == .terminal) // == maxRetries
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 10) == .terminal)
    }

    @Test func unavailable_respectsCustomMaxRetries() {
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 0, maxRetries: 0) == .terminal)
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 4, maxRetries: 5) == .transient)
        #expect(AttestSyncGate.classify(error: .unavailable, retryCount: 5, maxRetries: 5) == .terminal)
    }

    // MARK: - Onboarding upfront gate (block cloud-only when attest is terminally unsupported)

    @Test func offerCloudOnly_onlyWhenAttestSupported() {
        #expect(AttestSyncGate.shouldOfferCloudOnly(isAttestSupported: true) == true)
        #expect(AttestSyncGate.shouldOfferCloudOnly(isAttestSupported: false) == false)
    }
}
