//
//  OnboardingTelemetryEventBuilder.swift
//  Yala
//
//  Pure-logic helper para construir parameters dicts de telemetría del flow
//  Onboarding. Aislado de ModelContext/env/UI state para testabilidad con
//  Swift Testing sin `makeTestContext()` (R8 flake risk).
//
//  El step se pasa como String (lowercased rawValue) en lugar de un enum
//  para desacoplar del private `OnboardingView.Step`.
//

import Foundation

enum OnboardingTelemetryEventBuilder {

    /// Parameters para `.onboardingStarted` (mount inicial del flow).
    static func paramsForStarted(
        mode: OnboardingFlowMode,
        prefilled: Bool
    ) -> [String: String] {
        [
            "mode": mode.rawValue,
            "prefilled": String(prefilled)
        ]
    }

    /// Parameters para `.onboardingStepViewed` (cada visit a un step,
    /// incluido el primer mount Step 1).
    static func paramsForStepViewed(
        step: String,
        stepIndex: Int,
        totalSteps: Int,
        mode: OnboardingFlowMode
    ) -> [String: String] {
        [
            "step": step,
            "stepIndex": String(stepIndex),
            "totalSteps": String(totalSteps),
            "mode": mode.rawValue
        ]
    }

    /// Parameters para `.onboardingCancelled` (X cancel total / back desde Step 1).
    static func paramsForCancelled(
        atStep: String,
        mode: OnboardingFlowMode
    ) -> [String: String] {
        [
            "atStep": atStep,
            "mode": mode.rawValue
        ]
    }

    /// Parameters para `.onboardingBackTapped` (chevron toolbar / back capsule).
    static func paramsForBackTapped(
        fromStep: String,
        mode: OnboardingFlowMode
    ) -> [String: String] {
        [
            "fromStep": fromStep,
            "mode": mode.rawValue
        ]
    }
}
