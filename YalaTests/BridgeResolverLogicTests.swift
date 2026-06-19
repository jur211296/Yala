//
//  BridgeResolverLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgeResolverLogic.computeEffective(global:override:)`
//  y `computeOrphanZoneIDs`. Sin SwiftData/ModelContext (regla R8).
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — resolver logic")
struct BridgeResolverLogicTests {

    // MARK: - computeEffective

    @Test
    func effective_isFalse_whenGlobalFalse_overrideNil() {
        #expect(BridgeResolverLogic.computeEffective(global: false, override: nil) == false)
    }

    @Test
    func effective_isFalse_whenGlobalFalse_overrideTrue() {
        // Override solo restringe — no puede habilitar contra global=OFF.
        #expect(BridgeResolverLogic.computeEffective(global: false, override: true) == false)
    }

    @Test
    func effective_isFalse_whenGlobalFalse_overrideFalse() {
        #expect(BridgeResolverLogic.computeEffective(global: false, override: false) == false)
    }

    @Test
    func effective_isTrue_whenGlobalTrue_overrideNil() {
        // Default ON cuando no hay override.
        #expect(BridgeResolverLogic.computeEffective(global: true, override: nil) == true)
    }

    @Test
    func effective_isTrue_whenGlobalTrue_overrideTrue() {
        // Override explícito ON cuando global ON — redundante con nil pero válido.
        #expect(BridgeResolverLogic.computeEffective(global: true, override: true) == true)
    }

    @Test
    func effective_isFalse_whenGlobalTrue_overrideFalse() {
        // Override OFF excluye este grupo del bridge aunque global esté ON.
        #expect(BridgeResolverLogic.computeEffective(global: true, override: false) == false)
    }

    // MARK: - computeOrphanZoneIDs

    @Test
    func orphans_returnsEmpty_whenAllActiveMatch() {
        let result = BridgeResolverLogic.computeOrphanZoneIDs(
            allPreferenceZoneIDs: ["zone-1", "zone-2"],
            activeZoneIDs: ["zone-1", "zone-2", "zone-3"]
        )
        #expect(result.isEmpty)
    }

    @Test
    func orphans_returnsAbandonedZones() {
        let result = BridgeResolverLogic.computeOrphanZoneIDs(
            allPreferenceZoneIDs: ["zone-1", "zone-2", "zone-3"],
            activeZoneIDs: ["zone-2"]
        )
        #expect(result == Set(["zone-1", "zone-3"]))
    }

    @Test
    func orphans_returnsEmpty_whenPreferenceEmpty() {
        let result = BridgeResolverLogic.computeOrphanZoneIDs(
            allPreferenceZoneIDs: Set<String>(),
            activeZoneIDs: ["zone-1"]
        )
        #expect(result.isEmpty)
    }
}
