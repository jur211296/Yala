//
//  ForceUpdateDecisionLogicTests.swift
//  YalaTests
//
//  Decisión pura del forzado min-version (fail-open). Tabla build local vs umbral del server.
//

import Foundation
import Testing

@testable import Yala

@Suite("ForceUpdateDecisionLogic — min-version (tabla, fail-open)")
struct ForceUpdateDecisionLogicTests {

    @Test func required_whenBuildBelowMin() {
        #expect(ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 99, minSupportedBuild: 100))
        #expect(ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 1, minSupportedBuild: 999999))
    }

    @Test func notRequired_whenBuildAtOrAboveMin() {
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 100, minSupportedBuild: 100))
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 101, minSupportedBuild: 100))
    }

    @Test func failOpen_whenDisabledOrUnknown() {
        // min nil/0/negativo = desactivado (o sin config) → jamás bloquear.
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 1, minSupportedBuild: nil))
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 1, minSupportedBuild: 0))
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: 1, minSupportedBuild: -5))
        // build local no determinable → jamás bloquear.
        #expect(!ForceUpdateDecisionLogic.isUpdateRequired(currentBuild: nil, minSupportedBuild: 100))
    }
}
