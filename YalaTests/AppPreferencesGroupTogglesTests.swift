//
//  AppPreferencesGroupTogglesTests.swift
//  YalaTests
//
//  F4 — A0-Bridge: tests para 3 nuevas keys de visibilidad de grupos:
//  - includeGroupTransactionsInFeed
//  - includeGroupsInPanelTotal
//  - includeGroupTransactionsInStats
//

import Foundation
import Testing

@testable import Yala

@Suite("F4 — Group visibility toggles")
struct AppPreferencesGroupTogglesTests {

    @MainActor @Test
    func includeGroupTransactionsInFeed_defaultsTrue_whenKeyAbsent() {
        let defaults = makeIsolatedDefaults(prefix: "f4.feed")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupTransactionsInFeed == true)
    }

    @MainActor @Test
    func includeGroupTransactionsInFeed_persistsToggleOff() {
        let defaults = makeIsolatedDefaults(prefix: "f4.feed.off")
        let prefs = AppPreferences(defaults: defaults)
        prefs.includeGroupTransactionsInFeed = false
        #expect(defaults.bool(forKey: AppPreferences.Keys.includeGroupTransactionsInFeed) == false)
    }

    @MainActor @Test
    func includeGroupTransactionsInFeed_loadsFromExistingDefaults() {
        let defaults = makeIsolatedDefaults(prefix: "f4.feed.load")
        defaults.set(false, forKey: AppPreferences.Keys.includeGroupTransactionsInFeed)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupTransactionsInFeed == false)
    }

    @MainActor @Test
    func includeGroupsInPanelTotal_defaultsTrue_whenKeyAbsent() {
        let defaults = makeIsolatedDefaults(prefix: "f4.panel")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupsInPanelTotal == true)
    }

    @MainActor @Test
    func includeGroupsInPanelTotal_persistsToggleOff() {
        let defaults = makeIsolatedDefaults(prefix: "f4.panel.off")
        let prefs = AppPreferences(defaults: defaults)
        prefs.includeGroupsInPanelTotal = false
        #expect(defaults.bool(forKey: AppPreferences.Keys.includeGroupsInPanelTotal) == false)
    }

    @MainActor @Test
    func includeGroupsInPanelTotal_loadsFromExistingDefaults() {
        let defaults = makeIsolatedDefaults(prefix: "f4.panel.load")
        defaults.set(false, forKey: AppPreferences.Keys.includeGroupsInPanelTotal)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupsInPanelTotal == false)
    }

    @MainActor @Test
    func includeGroupTransactionsInStats_defaultsTrue_whenKeyAbsent() {
        let defaults = makeIsolatedDefaults(prefix: "f4.stats")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupTransactionsInStats == true)
    }

    @MainActor @Test
    func includeGroupTransactionsInStats_persistsToggleOff() {
        let defaults = makeIsolatedDefaults(prefix: "f4.stats.off")
        let prefs = AppPreferences(defaults: defaults)
        prefs.includeGroupTransactionsInStats = false
        #expect(defaults.bool(forKey: AppPreferences.Keys.includeGroupTransactionsInStats) == false)
    }

    @MainActor @Test
    func includeGroupTransactionsInStats_loadsFromExistingDefaults() {
        let defaults = makeIsolatedDefaults(prefix: "f4.stats.load")
        defaults.set(false, forKey: AppPreferences.Keys.includeGroupTransactionsInStats)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.includeGroupTransactionsInStats == false)
    }

    @MainActor @Test
    func threeKeys_areDistinct() {
        #expect(AppPreferences.Keys.includeGroupTransactionsInFeed
                != AppPreferences.Keys.includeGroupsInPanelTotal)
        #expect(AppPreferences.Keys.includeGroupTransactionsInFeed
                != AppPreferences.Keys.includeGroupTransactionsInStats)
        #expect(AppPreferences.Keys.includeGroupsInPanelTotal
                != AppPreferences.Keys.includeGroupTransactionsInStats)
    }

    @MainActor @Test
    func roundTrip_allThreeToggles_independently() {
        let defaults = makeIsolatedDefaults(prefix: "f4.roundtrip")
        let prefs = AppPreferences(defaults: defaults)

        prefs.includeGroupTransactionsInFeed = false
        prefs.includeGroupsInPanelTotal = true
        prefs.includeGroupTransactionsInStats = false

        // Re-instantiate from same defaults to verify persistence
        let reloaded = AppPreferences(defaults: defaults)
        #expect(reloaded.includeGroupTransactionsInFeed == false)
        #expect(reloaded.includeGroupsInPanelTotal == true)
        #expect(reloaded.includeGroupTransactionsInStats == false)
    }

    // MARK: - Bridge opt-out global toggle (new in opt-out feature)

    @MainActor @Test
    func bridgeGroupExpensesToPersonalAccounts_defaultsTrue_whenKeyAbsent() {
        let defaults = makeIsolatedDefaults(prefix: "bridge.optout.default")
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.bridgeGroupExpensesToPersonalAccounts == true)
    }

    @MainActor @Test
    func bridgeGroupExpensesToPersonalAccounts_persistsToggleOff() {
        let defaults = makeIsolatedDefaults(prefix: "bridge.optout.off")
        let prefs = AppPreferences(defaults: defaults)
        prefs.bridgeGroupExpensesToPersonalAccounts = false
        #expect(defaults.bool(forKey: AppPreferences.Keys.bridgeGroupExpensesToPersonalAccounts) == false)
    }

    @MainActor @Test
    func bridgeGroupExpensesToPersonalAccounts_loadsFromExistingDefaults() {
        let defaults = makeIsolatedDefaults(prefix: "bridge.optout.load")
        defaults.set(false, forKey: AppPreferences.Keys.bridgeGroupExpensesToPersonalAccounts)
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.bridgeGroupExpensesToPersonalAccounts == false)
    }
}
