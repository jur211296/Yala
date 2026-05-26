//
//  NotificationGateLogicTests.swift
//  YalaTests
//

import Testing
@testable import Yala

@Suite("NotificationGateLogic")
struct NotificationGateLogicTests {

    @Test func allClean_enqueueNow() {
        #expect(NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: true, isLocked: false, isBootstrapInitialized: true))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: true, isLocked: false, isBootstrapInitialized: true) == nil)
    }

    @Test func bootstrapPending_defers() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: true, isLocked: false, isBootstrapInitialized: false))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: true, isLocked: false, isBootstrapInitialized: false) == "bootstrapPending")
    }

    @Test func onboardingIncomplete_defers() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: false, isLocked: false, isBootstrapInitialized: true))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: false, isLocked: false, isBootstrapInitialized: true) == "onboardingIncomplete")
    }

    @Test func locked_defers() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: true, isLocked: true, isBootstrapInitialized: true))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: true, isLocked: true, isBootstrapInitialized: true) == "biometricLocked")
    }

    @Test func bootstrapBeatsOnboarding_inReason() {
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: false, isLocked: true, isBootstrapInitialized: false) == "bootstrapPending")
    }

    @Test func onboardingBeatsLock_inReason() {
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: false, isLocked: true, isBootstrapInitialized: true) == "onboardingIncomplete")
    }

    @Test func allFalse_defersBootstrap() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: false, isLocked: true, isBootstrapInitialized: false))
    }
}
