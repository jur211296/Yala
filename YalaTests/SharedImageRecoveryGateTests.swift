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
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: true, isLocked: false))
    }

    @Test func noPendingImage_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: false, isInitialized: true, hasCompletedOnboarding: true, isLocked: false))
    }

    @Test func notInitialized_doesNotReEmit() {
        // El caso del bug: pre-`isInitialized` el submit se diferiría y el intent
        // no-serializable se descartaría → NO re-emitir, esperar a la ventana ready.
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: false, hasCompletedOnboarding: true, isLocked: false))
    }

    @Test func onboardingIncomplete_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: false, isLocked: false))
    }

    @Test func locked_doesNotReEmit() {
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: true, isInitialized: true, hasCompletedOnboarding: true, isLocked: true))
    }

    @Test func noPendingImage_beatsAllReady() {
        // Sin imagen no re-emite aunque todo lo demás esté ready.
        #expect(!SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: false, isInitialized: true, hasCompletedOnboarding: true, isLocked: true))
    }
}
