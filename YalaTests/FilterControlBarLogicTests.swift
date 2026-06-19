//
//  FilterControlBarLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para FilterControlBarLogic. Cubre las 2 decisiones del
//  helper: shouldRenderPanelSection y shouldShowInlinePeriodSelector.
//

import Foundation
import Testing

@testable import Yala

struct FilterControlBarLogicTests {

    // MARK: - shouldRenderPanelSection

    @Test func panelSection_legacy_zeroChips_doesNotRender() {
        let result = FilterControlBarLogic.shouldRenderPanelSection(panelStyle: false, activeFilterCount: 0)
        #expect(result == false)
    }

    @Test func panelSection_legacy_withChips_doesNotRender() {
        let result = FilterControlBarLogic.shouldRenderPanelSection(panelStyle: false, activeFilterCount: 5)
        #expect(result == false)
    }

    @Test func panelSection_panel_zeroChips_doesNotRender() {
        let result = FilterControlBarLogic.shouldRenderPanelSection(panelStyle: true, activeFilterCount: 0)
        #expect(result == false)
    }

    @Test func panelSection_panel_oneChip_renders() {
        let result = FilterControlBarLogic.shouldRenderPanelSection(panelStyle: true, activeFilterCount: 1)
        #expect(result == true)
    }

    @Test func panelSection_panel_manyChips_renders() {
        let result = FilterControlBarLogic.shouldRenderPanelSection(panelStyle: true, activeFilterCount: 5)
        #expect(result == true)
    }

    // MARK: - shouldShowInlinePeriodSelector

    @Test func inlinePeriodSelector_legacy_shows() {
        let result = FilterControlBarLogic.shouldShowInlinePeriodSelector(panelStyle: false)
        #expect(result == true)
    }

    @Test func inlinePeriodSelector_panel_hides() {
        let result = FilterControlBarLogic.shouldShowInlinePeriodSelector(panelStyle: true)
        #expect(result == false)
    }
}
