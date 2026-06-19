//
//  RemoteWipeSignalDeciderTests.swift
//  YalaTests
//
//  Pure-logic tests para RemoteWipeSignalDecider. Sin SwiftData ni UI.
//  Cubre los 3 cases de la matriz de decisión + idempotencia.
//

import Foundation
import Testing

@testable import Yala

struct RemoteWipeSignalDeciderTests {

    // MARK: - Fresh-install guard (bug #6 fix)

    @Test func decide_freshInstall_doesNotProcess() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: true
        )
        #expect(decision.shouldProcess == false)
    }

    @Test func decide_freshInstall_marksSignalsAsProcessedForIdempotency() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: true
        )
        #expect(decision.shouldMarkSignalsAsProcessed == true)
    }

    @Test func decide_freshInstallNoRemoteSignal_doesNotMark() {
        // KV-Store limpio (Apple ID nunca tuvo Yala) — no hay nada que marcar.
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: false,
            isWipingData: false,
            hasRemoteWipeTimestamp: false
        )
        #expect(decision.shouldProcess == false)
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    // MARK: - Returning user (no regresión cross-device wipe)

    @Test func decide_returningUser_processes() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: false,
            hasRemoteWipeTimestamp: true
        )
        #expect(decision.shouldProcess == true)
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }

    // MARK: - Self-wipe guard (no auto-react al propio signal)

    @Test func decide_isWipingData_doesNotProcess() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: true,
            hasRemoteWipeTimestamp: true
        )
        #expect(decision.shouldProcess == false)
    }

    @Test func decide_isWipingData_doesNotMark() {
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: true,
            isWipingData: true,
            hasRemoteWipeTimestamp: true
        )
        #expect(decision.shouldMarkSignalsAsProcessed == false)
    }
}
