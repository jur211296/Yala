//
//  GroupsOnboardingCloseOutcomeTests.swift
//  YalaTests
//
//  Card imbk: la X de la bienvenida de Grupos aplaza una vez y la segunda la da por vista (Jürgen, 2026-11-06, B).
//

import Foundation
import Testing

@testable import Yala

@Suite("La X de la bienvenida de Grupos aplaza una vez")
@MainActor
struct GroupsOnboardingCloseOutcomeTests {

    @Test("La primera X aplaza")
    func firstClose_postpones() {
        #expect(GroupsOnboardingLogic.closeOutcome(alreadyPostponed: false) == .postponeOnce)
    }

    @Test("La segunda X la da por vista")
    func secondClose_marksSeen() {
        #expect(GroupsOnboardingLogic.closeOutcome(alreadyPostponed: true) == .markSeen)
    }

    @Test("La marca de aplazado se guarda en su clave y se vuelve a leer")
    func postponedMark_roundTrips() {
        let defaults = makeIsolatedDefaults()
        let prefs = AppPreferences(defaults: defaults)
        #expect(prefs.groupsOnboardingPostponedOnce == false)
        prefs.groupsOnboardingPostponedOnce = true
        #expect(defaults.bool(forKey: AppPreferences.Keys.groupsOnboardingPostponedOnce))
        #expect(AppPreferences(defaults: defaults).groupsOnboardingPostponedOnce)
    }
}
