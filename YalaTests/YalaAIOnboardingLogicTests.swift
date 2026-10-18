//
//  YalaAIOnboardingLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para YalaAIOnboardingLogic. Sin SwiftData ni UI.
//  Cubre la matriz consent × onboardingShown (4 combinaciones).
//
//  UX 2.2 · L14-2: la presentación va PRIMERO y pide el permiso en su último paso. La alerta solo sale a quien ya vio
//  la presentación y retiró el permiso.
//

import Foundation
import Testing

@testable import Yala

struct YalaAIOnboardingLogicTests {

    /// La primera vez no sale ningún aviso antes de saber qué es Yala IA: la presentación lo pide al final.
    @Test func nextScreen_firstTime_returnsOnboarding_notConsent() {
        let result = YalaAIOnboardingLogic.nextScreen(
            consentAccepted: false,
            onboardingShown: false
        )
        #expect(result == .onboarding)
    }

    @Test func nextScreen_onboardingShownButConsentRevoked_returnsConsent() {
        // Retiró el permiso en Privacidad y datos IA después de la presentación: solo se le vuelve a pedir el permiso.
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
