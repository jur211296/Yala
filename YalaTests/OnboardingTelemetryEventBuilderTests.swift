//
//  OnboardingTelemetryEventBuilderTests.swift
//  YalaTests
//
//  Cubre la construcción de parameters dicts del flow Onboarding instrumentado
//  en F6. Pure-logic — sin ModelContext, sin makeTestContext (R8 flake risk).
//

import Foundation
import Testing

@testable import Yala

struct OnboardingTelemetryEventBuilderTests {

    // MARK: - paramsForStarted

    @Test func paramsForStarted_initial_noPrefill() {
        let params = OnboardingTelemetryEventBuilder.paramsForStarted(
            mode: .initial,
            prefilled: false
        )
        #expect(params == ["mode": "initial", "prefilled": "false"])
    }

    @Test func paramsForStarted_fullActivation_withPrefill() {
        let params = OnboardingTelemetryEventBuilder.paramsForStarted(
            mode: .fullActivation,
            prefilled: true
        )
        #expect(params == ["mode": "fullActivation", "prefilled": "true"])
    }

    // MARK: - paramsForStepViewed

    @Test func paramsForStepViewed_firstStep_initial() {
        let params = OnboardingTelemetryEventBuilder.paramsForStepViewed(
            step: "name",
            stepIndex: 0,
            totalSteps: 8,
            mode: .initial
        )
        #expect(params == [
            "step": "name",
            "stepIndex": "0",
            "totalSteps": "8",
            "mode": "initial"
        ])
    }

    @Test func paramsForStepViewed_lastStep_fullActivation() {
        let params = OnboardingTelemetryEventBuilder.paramsForStepViewed(
            step: "confirmation",
            stepIndex: 4,
            totalSteps: 5,
            mode: .fullActivation
        )
        #expect(params == [
            "step": "confirmation",
            "stepIndex": "4",
            "totalSteps": "5",
            "mode": "fullActivation"
        ])
    }

    // MARK: - paramsForCancelled

    @Test func paramsForCancelled_atName_initial() {
        let params = OnboardingTelemetryEventBuilder.paramsForCancelled(
            atStep: "name",
            mode: .initial
        )
        #expect(params == ["atStep": "name", "mode": "initial"])
    }

    @Test func paramsForCancelled_atBalance_fullActivation() {
        let params = OnboardingTelemetryEventBuilder.paramsForCancelled(
            atStep: "balance",
            mode: .fullActivation
        )
        #expect(params == ["atStep": "balance", "mode": "fullActivation"])
    }

    // MARK: - paramsForBackTapped

    @Test func paramsForBackTapped_fromCurrencyName_initial() {
        let params = OnboardingTelemetryEventBuilder.paramsForBackTapped(
            fromStep: "currencyName",
            mode: .initial
        )
        #expect(params == ["fromStep": "currencyName", "mode": "initial"])
    }
}
