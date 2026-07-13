//
//  SecondarySessionStoreTests.swift
//  YalaTests / CloudSync
//
//  Descriptor de la sesión secundaria (M1 multi-cuenta) — round-trips, 1 slot, arm del wipe y
//  marker de purga de entrada. UserDefaults aislado (regla del repo). El override de test se
//  ejercita en su propia suite `.serialized` (estado estático compartido).
//

import Foundation
import Testing

@testable import Yala

@Suite("SecondarySessionStore · descriptor + arm + purga (M1)")
struct SecondarySessionStoreTests {

    @Test func inactive_byDefault() {
        let defaults = makeIsolatedDefaults(prefix: "sss.default")
        #expect(SecondarySessionStore.isActive(defaults) == false)
        #expect(SecondarySessionStore.activeUserID(defaults) == nil)
        #expect(SecondarySessionStore.isWipeArmed(defaults) == false)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults) == false)
    }

    @Test func activate_roundTrips_andClears() {
        let defaults = makeIsolatedDefaults(prefix: "sss.rt")
        SecondarySessionStore.activate(userID: "user-a", defaults)
        #expect(SecondarySessionStore.isActive(defaults))
        #expect(SecondarySessionStore.activeUserID(defaults) == "user-a")
        SecondarySessionStore.clear(defaults)
        #expect(SecondarySessionStore.isActive(defaults) == false)
        #expect(SecondarySessionStore.activeUserID(defaults) == nil)
    }

    @Test func activate_emptyUserID_isIgnored() {
        let defaults = makeIsolatedDefaults(prefix: "sss.empty")
        SecondarySessionStore.activate(userID: "", defaults)
        #expect(SecondarySessionStore.isActive(defaults) == false)
    }

    @Test func activate_overwrites_singleSlot() {
        let defaults = makeIsolatedDefaults(prefix: "sss.slot")
        SecondarySessionStore.activate(userID: "user-a", defaults)
        SecondarySessionStore.activate(userID: "user-b", defaults)
        #expect(SecondarySessionStore.activeUserID(defaults) == "user-b")
    }

    @Test func wipeArm_roundTrips() {
        let defaults = makeIsolatedDefaults(prefix: "sss.arm")
        SecondarySessionStore.armWipe(defaults)
        #expect(SecondarySessionStore.isWipeArmed(defaults))
        SecondarySessionStore.clearWipeArm(defaults)
        #expect(SecondarySessionStore.isWipeArmed(defaults) == false)
    }

    @Test func entryPurgeMark_roundTrips() {
        let defaults = makeIsolatedDefaults(prefix: "sss.purge")
        SecondarySessionStore.markEntryPurgeDone(defaults)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults))
        SecondarySessionStore.clearEntryPurgeMark(defaults)
        #expect(SecondarySessionStore.isEntryPurgeDone(defaults) == false)
    }
}

@Suite("SecondarySessionStore · override de test", .serialized)
struct SecondarySessionStoreOverrideTests {

    @Test func override_forcesIsActive_bothWays_andResets() {
        let defaults = makeIsolatedDefaults(prefix: "sss.override")
        defer { SecondarySessionStore._testSetActiveOverride(nil) }

        SecondarySessionStore._testSetActiveOverride(true)
        #expect(SecondarySessionStore.isActive(defaults))

        SecondarySessionStore._testSetActiveOverride(false)
        SecondarySessionStore.activate(userID: "user-a", defaults)
        #expect(SecondarySessionStore.isActive(defaults) == false)

        SecondarySessionStore._testSetActiveOverride(nil)
        #expect(SecondarySessionStore.isActive(defaults))
    }
}
