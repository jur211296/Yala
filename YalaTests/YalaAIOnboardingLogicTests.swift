//
//  YalaAIOnboardingLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para YalaAIOnboardingLogic. Sin SwiftData ni UI.
//  Cubre la matriz consent × onboardingShown (4 combinaciones).
//

import Foundation
import Testing

@testable import Yala

struct YalaAIOnboardingLogicTests {

    @Test func nextScreen_noConsent_returnsConsent() {
        let result = YalaAIOnboardingLogic.nextScreen(
            consentAccepted: false,
            onboardingShown: false
        )
        #expect(result == .consent)
    }

    @Test func nextScreen_noConsent_evenIfOnboardingShown_returnsConsent() {
        // Caso edge: si user revoca consent post-onboarding, vuelve a alert.
        let result = YalaAIOnboardingLogic.nextScreen(
            consentAccepted: false,
            onboardingShown: true
        )
        #expect(result == .consent)
    }

    @Test func nextScreen_consentButNoOnboarding_returnsOnboarding() {
        let result = YalaAIOnboardingLogic.nextScreen(
            consentAccepted: true,
            onboardingShown: false
        )
        #expect(result == .onboarding)
    }

    @Test func nextScreen_consentAndOnboardingShown_returnsChat() {
        let result = YalaAIOnboardingLogic.nextScreen(
            consentAccepted: true,
            onboardingShown: true
        )
        #expect(result == .chat)
    }
}
