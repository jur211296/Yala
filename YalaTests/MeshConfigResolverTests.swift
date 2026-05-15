//
//  MeshConfigResolverTests.swift
//  YalaTests
//
//  Pure-logic tests para MeshConfigResolver.config(for:).
//  Sin SwiftData, sin UI. Cubre los 4 themes translucent + fallback nil para
//  themes sin material.
//

import Foundation
import Testing

@testable import Yala

struct MeshConfigResolverTests {

    @Test func config_liquidGlass_usesLiquidGlassFlag() {
        let result = MeshConfigResolver.config(for: .liquidGlass)
        #expect(result?.variant == .indigo)
        #expect(result?.isLiquidGlass == true)
    }

    @Test func config_translucent_returnsIndigoNonLiquid() {
        let result = MeshConfigResolver.config(for: .translucent)
        #expect(result?.variant == .indigo)
        #expect(result?.isLiquidGlass == false)
    }

    @Test func config_translucentRosa_returnsRosaNonLiquid() {
        let result = MeshConfigResolver.config(for: .translucentRosa)
        #expect(result?.variant == .rosa)
        #expect(result?.isLiquidGlass == false)
    }

    @Test func config_translucentTeal_returnsTealNonLiquid() {
        let result = MeshConfigResolver.config(for: .translucentTeal)
        #expect(result?.variant == .teal)
        #expect(result?.isLiquidGlass == false)
    }

    @Test func config_light_returnsNil() {
        // Light theme tiene hasGradient=true pero usesMaterial=false → fuera de rama mesh.
        let result = MeshConfigResolver.config(for: .light)
        #expect(result == nil)
    }

    @Test func config_dark_returnsNil() {
        // Dark theme sin material ni gradient → fuera de rama mesh.
        let result = MeshConfigResolver.config(for: .dark)
        #expect(result == nil)
    }
}
