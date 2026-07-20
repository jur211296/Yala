//
//  TabBarConfigurationSecondaryTests.swift
//  YalaTests
//
//  Filtro del tab Grupos en sesión secundaria (M1 Inc 5): el CKSyncEngine de grupos está atado
//  al Apple ID del OS (el dueño) — la invitada jamás debe ver ese tab.
//  + D1 (retención): reducción a solo-Grupos vía `reduceToGroupsOnly` (usageFocus == .groupsOnly).
//

import Foundation
import Testing

@testable import Yala

@Suite("TabBarConfiguration · filtro de Grupos en secundaria (M1) + reduce D1")
struct TabBarConfigurationSecondaryTests {

    @Test func secondary_filtersGroups_keepsRest() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups, .records, .statistics])
        let config = TabBarConfiguration.forMode(
            .completed, stored: stored, secondarySessionActive: true, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .records, .statistics])
    }

    @Test func secondary_withoutGroups_isUntouched() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .records])
        let config = TabBarConfiguration.forMode(
            .full, stored: stored, secondarySessionActive: true, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .records])
    }

    @Test func notSecondary_legacyIntact_includingGroups() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups])
        let config = TabBarConfiguration.forMode(
            .completed, stored: stored, secondarySessionActive: false, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .groups])
    }

    @Test func groupInviteMode_secondary_alsoFilters() {
        // Combinación imposible por diseño (group-invite es un onboarding del iCloud del dueño),
        // pero el filtro es uniforme: jamás `.groups` con descriptor activo Y el canal backend APAGADO.
        let config = TabBarConfiguration.forMode(
            .groupInvite, stored: .default, secondarySessionActive: true, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(!config.activeTabs.contains(.groups))
    }

    @Test func groupInviteMode_notSecondary_keepsFixedConfig() {
        let config = TabBarConfiguration.forMode(
            .groupInvite, stored: .default, secondarySessionActive: false, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.groups])
    }

    // MARK: - D8 (G5-C): con el canal backend ENCENDIDO, la secundaria VE el tab Grupos

    @Test func secondary_flagOn_keepsGroups() {
        // Con el flag ON la invitada ve sus PROPIOS grupos (canal backend, store `-Secondary`) → no se filtra.
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups, .records])
        let config = TabBarConfiguration.forMode(
            .completed, stored: stored, secondarySessionActive: true, groupsBackendEnabled: true,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .groups, .records])
    }

    @Test func groupInviteMode_secondary_flagOn_keepsGroups() {
        let config = TabBarConfiguration.forMode(
            .groupInvite, stored: .default, secondarySessionActive: true, groupsBackendEnabled: true,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs.contains(.groups))
    }

    @Test func notSecondary_flagOn_legacyIntact() {
        // No-secundaria: el flag no altera nada (la matriz personal permanece).
        let stored = TabBarConfiguration(activeTabs: [.panel, .groups])
        let config = TabBarConfiguration.forMode(
            .completed, stored: stored, secondarySessionActive: false, groupsBackendEnabled: true,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .groups])
    }

    // MARK: - D1 (retención): reduceToGroupsOnly fuerza [.groups] sin tocar onboardingMode

    @Test func reduceToGroupsOnly_full_forcesGroupsOnly() {
        // Un usuario `.full` (con datos personales) que eligió «Solo mis grupos» → solo [.groups].
        let stored = TabBarConfiguration(activeTabs: [.panel, .statistics, .planning])
        let config = TabBarConfiguration.forMode(
            .full, stored: stored, secondarySessionActive: false, groupsBackendEnabled: false,
            reduceToGroupsOnly: true)
        #expect(config.activeTabs == [.groups])
    }

    @Test func reduceToGroupsOnly_completed_forcesGroupsOnly() {
        let stored = TabBarConfiguration(activeTabs: [.panel, .records, .reports])
        let config = TabBarConfiguration.forMode(
            .completed, stored: stored, secondarySessionActive: false, groupsBackendEnabled: false,
            reduceToGroupsOnly: true)
        #expect(config.activeTabs == [.groups])
    }

    @Test func reduceToGroupsOnly_false_full_keepsStored() {
        // Byte-idéntico: sin reduce, un `.full` conserva su config custom.
        let stored = TabBarConfiguration(activeTabs: [.panel, .statistics, .planning])
        let config = TabBarConfiguration.forMode(
            .full, stored: stored, secondarySessionActive: false, groupsBackendEnabled: false,
            reduceToGroupsOnly: false)
        #expect(config.activeTabs == [.panel, .statistics, .planning])
    }
}
