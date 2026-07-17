//
//  StoreKitManagerAppGroupTests.swift
//  YalaTests
//
//  Regresión del bug "SiriNatural pro_required para usuarios Pro": StoreKitManager
//  escribía `isProUser` al suite hardcodeado "group.com.yala.shared" (no-entitled →
//  plist local al sandbox) mientras QuickExpenseIntent lee el App Group canónico.
//  Roto desde b1e724a0 (el flow review corrigió el lector pero no el escritor).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite(.serialized)
struct StoreKitManagerAppGroupTests {

    /// El write de syncToAppGroup DEBE aterrizar en el par (suite, key) exacto que
    /// lee el gate Pro de QuickExpenseIntent. Antes del fix este test fallaba: el
    /// suite canónico jamás recibía la key.
    @Test func syncToAppGroup_escribeEnElSuiteCanonicoQueLeeElIntent() {
        let suite = UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)
        let previous = suite?.object(forKey: AppPreferences.Keys.isProUser)
        suite?.removeObject(forKey: AppPreferences.Keys.isProUser)
        defer {
            if let previous {
                suite?.set(previous, forKey: AppPreferences.Keys.isProUser)
            } else {
                suite?.removeObject(forKey: AppPreferences.Keys.isProUser)
            }
        }

        StoreKitManager.shared.syncToAppGroup()

        #expect(suite?.object(forKey: AppPreferences.Keys.isProUser) != nil)
    }

    /// Guard del drift que causó el bug: los dos resolvers del App Group (el que usa
    /// el escritor y el que usa el lector) deben seguir resolviendo al mismo suite.
    @Test func appGroupResolvers_coinciden() {
        #expect(SharedContainerService.appGroupIdentifier == WidgetURLHelper.appGroupIdentifier)
    }
}
