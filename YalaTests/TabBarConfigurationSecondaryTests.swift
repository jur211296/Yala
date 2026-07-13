//
//  TabBarConfigurationSecondaryTests.swift
//  YalaTests
//
//  Filtro del tab Grupos en sesión secundaria (M1 Inc 5): el CKSyncEngine de grupos está atado
//  al Apple ID del OS (el dueño) — la invitada jamás debe ver ese tab.
//

import Foundation
import Testing

@testable import Yala

@Suite("TabBarConfiguration · filtro de Grupos en secundaria (M1)")
struct TabBarConfigurationSecondaryTests {

    @Test func secondary_filtersGroups_keepsRest() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups, .records, .statistics])
        let config = TabBarConfiguration.forMode(.completed, stored: stored, secondarySessionActive: true)
        #expect(config.activeTabs == [.panel, .records, .statistics])
    }

    @Test func secondary_withoutGroups_isUntouched() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .records])
        let config = TabBarConfiguration.forMode(.full, stored: stored, secondarySessionActive: true)
        #expect(config.activeTabs == [.panel, .records])
    }

    @Test func notSecondary_legacyIntact_includingGroups() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups])
        let config = TabBarConfiguration.forMode(.completed, stored: stored, secondarySessionActive: false)
        #expect(config.activeTabs == [.panel, .groups])
    }

    @Test func groupInviteMode_secondary_alsoFilters() {
        // Combinación imposible por diseño (group-invite es un onboarding del iCloud del dueño),
        // pero el filtro es uniforme: jamás `.groups` con descriptor activo.
        let config = TabBarConfiguration.forMode(
            .groupInvite, stored: .default, secondarySessionActive: true)
        #expect(!config.activeTabs.contains(.groups))
    }

    @Test func groupInviteMode_notSecondary_keepsFixedConfig() {
        let config = TabBarConfiguration.forMode(
            .groupInvite, stored: .default, secondarySessionActive: false)
        #expect(config.activeTabs == [.groups])
    }
}
