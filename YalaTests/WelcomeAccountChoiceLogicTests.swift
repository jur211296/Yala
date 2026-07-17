//
//  WelcomeAccountChoiceLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Welcome chooser 2 niveles — opciones visibles y bypass")
struct WelcomeAccountChoiceLogicTests {

    // MARK: - "Soy nuevo"

    @Test
    func newOptions_bornCloudDisabled_onlyPrivate() {
        // Born-cloud DIFERIDO: aun con backend configurado, sin el enable no aparece.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: false
        ) == [.privateAccount])
    }

    @Test
    func newOptions_bornCloudEnabled_requiresConfiguredAndNotUITest() {
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true
        ) == [.privateAccount, .cloudAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: false, isUITest: false, bornCloudEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: true, bornCloudEnabled: true
        ) == [.privateAccount])
    }

    // MARK: - "Ya tengo cuenta"

    @Test
    func existingOptions_configured_showsAllThree() {
        // Sesión 2 Google: Apple y Google comparten el MISMO gate (configured && !uitest).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false
        ) == [.restoreICloud, .cloudSignIn, .googleSignIn])
    }

    @Test
    func existingOptions_notConfigured_onlyRestore() {
        // Prod DARK hoy: el botón SIWA jamás aparece sin backend configurado.
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: false, isUITest: false
        ) == [.restoreICloud])
    }

    @Test
    func existingOptions_uitest_onlyRestore() {
        // Bypass uitest intacto (el opt-in `-uitest-cloud-chooser` pasa isUITest=false en
        // el callsite — la lógica pura no cambia).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: true
        ) == [.restoreICloud])
    }

    // MARK: - Bypass

    @Test
    func bypass_singleOption_returnsIt() {
        #expect(WelcomeAccountChoiceLogic.bypass(
            [WelcomeAccountChoiceLogic.ExistingOption.restoreICloud]
        ) == .restoreICloud)
    }

    @Test
    func bypass_multipleOptions_returnsNil() {
        #expect(WelcomeAccountChoiceLogic.bypass(
            [WelcomeAccountChoiceLogic.ExistingOption.restoreICloud, .cloudSignIn]
        ) == nil)
    }
}
