//
//  ForceUpdateGateTests.swift
//  YalaTests
//
//  Wiring @Observable del gate de forzado: recompute mapea (umbral, build) → isUpdateRequired
//  vía la lógica pura. Usa el seam inyectable (sin `.standard`/Bundle).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("ForceUpdateGate — recompute wiring")
struct ForceUpdateGateTests {

    @Test func recompute_setsRequired_whenBuildBelowMin() {
        let gate = ForceUpdateGate()
        gate.recompute(minSupportedBuild: 100, currentBuild: 99)
        #expect(gate.isUpdateRequired)
    }

    @Test func recompute_clearsRequired_whenBuildAtOrAbove() {
        let gate = ForceUpdateGate()
        gate.recompute(minSupportedBuild: 100, currentBuild: 99)
        #expect(gate.isUpdateRequired)
        gate.recompute(minSupportedBuild: 100, currentBuild: 100)
        #expect(!gate.isUpdateRequired)
    }

    @Test func recompute_failOpen_whenNoThreshold() {
        let gate = ForceUpdateGate()
        gate.recompute(minSupportedBuild: nil, currentBuild: 1)
        #expect(!gate.isUpdateRequired)
        gate.recompute(minSupportedBuild: 0, currentBuild: 1)
        #expect(!gate.isUpdateRequired)
    }
}
