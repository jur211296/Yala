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
            hasCompletedOnboarding: true, isBootstrapInitialized: true))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: true, isBootstrapInitialized: true) == nil)
    }

    @Test func bootstrapPending_defers() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: true, isBootstrapInitialized: false))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: true, isBootstrapInitialized: false) == "bootstrapPending")
    }

    @Test func onboardingIncomplete_defers() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: false, isBootstrapInitialized: true))
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: false, isBootstrapInitialized: true) == "onboardingIncomplete")
    }

    @Test func bootstrapBeatsOnboarding_inReason() {
        #expect(NotificationGateLogic.deferralReason(
            hasCompletedOnboarding: false, isBootstrapInitialized: false) == "bootstrapPending")
    }

    @Test func allFalse_defersBootstrap() {
        #expect(!NotificationGateLogic.shouldEnqueueNow(
            hasCompletedOnboarding: false, isBootstrapInitialized: false))
    }
}
