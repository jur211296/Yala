//
//  SharedImageRecoveryGateTests.swift
//  YalaTests
//

import Testing
@testable import Yala

@Suite("SharedImageRecoveryGate")
struct SharedImageRecoveryGateTests {

    @Test func allReady_reEmits() {
        #expect(SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: true))
    }

    @Test func noPendingImage_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: false, isInitialized: true, hasCompletedOnboarding: true))
    }

    @Test func notInitialized_doesNotReEmit() {
        // El caso del bug: pre-`isInitialized` el submit se diferiría y el intent
        // no-serializable se descartaría → NO re-emitir, esperar a la ventana ready.
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: false, hasCompletedOnboarding: true))
    }

    @Test func onboardingIncomplete_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: false))
    }
}
