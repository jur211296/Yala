//
//  MainTabSelectionLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for MainTabSelectionLogic.decide(requested:config:).
//  Sin SwiftData, sin UI, sin singletons. Cubre tabs visibles, ocultos,
//  cases especiales (.more / .search), config groupInvite y config malformada.
//

import Foundation
import Testing

@testable import Yala

struct MainTabSelectionLogicTests {

    // MARK: - Tab visible en activeTabs (asignación directa, sin delay)

    @Test func decide_visibleTab_directAssignment_noDelay() {
        let config = TabBarConfiguration(activeTabs: [.panel, .statistics, .planning])
        let decision = MainTabSelectionLogic.decide(requested: .statistics, config: config)
        #expect(decision.selectedTab == .statistics)
        #expect(decision.temporaryTab == nil)
        #expect(decision.requiresDelay == false)
    }

    @Test func decide_panelAlwaysVisible() {
        let config = TabBarConfiguration.default
        let decision = MainTabSelectionLogic.decide(requested: .panel, config: config)
        #expect(decision.selectedTab == .panel)
        #expect(decision.temporaryTab == nil)
        #expect(decision.requiresDelay == false)
    }

    // MARK: - Tab oculto (setea temporaryTab + delay)

    @Test func decide_hiddenTab_setsTemporaryAndRequiresDelay() {
        let config = TabBarConfiguration(activeTabs: [.panel, .records, .reports])
        let decision = MainTabSelectionLogic.decide(requested: .statistics, config: config)
        #expect(decision.selectedTab == .statistics)
        #expect(decision.temporaryTab == .statistics)
        #expect(decision.requiresDelay == true)
    }

    @Test func decide_hiddenPlanning_setsTemporaryAndRequiresDelay() {
        let config = TabBarConfiguration(activeTabs: [.panel, .statistics, .records])
        let decision = MainTabSelectionLogic.decide(requested: .planning, config: config)
        #expect(decision.selectedTab == .planning)
        #expect(decision.temporaryTab == .planning)
        #expect(decision.requiresDelay == true)
    }

    // MARK: - .more y .search (no son configurables, asignación directa)

    @Test func decide_more_returnsDirectAssignment() {
        let config = TabBarConfiguration.default
        let decision = MainTabSelectionLogic.decide(requested: .more, config: config)
        #expect(decision.selectedTab == .more)
        #expect(decision.temporaryTab == nil)
        #expect(decision.requiresDelay == false)
    }

    @Test func decide_search_returnsDirectAssignment() {
        let config = TabBarConfiguration.default
        let decision = MainTabSelectionLogic.decide(requested: .search, config: config)
        #expect(decision.selectedTab == .search)
        #expect(decision.temporaryTab == nil)
        #expect(decision.requiresDelay == false)
    }

    // MARK: - Config groupInvite (solo .groups activo)

    @Test func decide_groupInviteConfig_groupsDirect() {
        let config = TabBarConfiguration.groupInvite
        let decision = MainTabSelectionLogic.decide(requested: .groups, config: config)
        #expect(decision.selectedTab == .groups)
        #expect(decision.temporaryTab == nil)
        #expect(decision.requiresDelay == false)
    }

    @Test func decide_groupInviteConfig_statisticsRequiresTemporary() {
        // El helper, sin guard de modo, sí marca delay para tabs no permitidos
        // en groupInvite. El guard real (no-op para tabs prohibidos) vive en
        // SessionState.selectMainTab — este test verifica que el helper se
        // mantiene puro y delega la decisión política al caller.
        let config = TabBarConfiguration.groupInvite
        let decision = MainTabSelectionLogic.decide(requested: .statistics, config: config)
        #expect(decision.selectedTab == .statistics)
        #expect(decision.temporaryTab == .statistics)
        #expect(decision.requiresDelay == true)
    }

    // MARK: - Config malformada (fromJSON inválido cae a default)

    @Test func decide_emptyConfig_fallsBackToDefault() {
        // fromJSON con string vacío retorna .default = [.panel, .statistics, .planning]
        let config = TabBarConfiguration.fromJSON("")
        let statisticsDecision = MainTabSelectionLogic.decide(requested: .statistics, config: config)
        #expect(statisticsDecision.requiresDelay == false)
        let recordsDecision = MainTabSelectionLogic.decide(requested: .records, config: config)
        #expect(recordsDecision.requiresDelay == true)
        #expect(recordsDecision.temporaryTab == .records)
    }
}
