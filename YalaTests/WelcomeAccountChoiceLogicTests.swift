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
    func existingOptions_configured_showsBoth() {
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false
        ) == [.restoreICloud, .cloudSignIn])
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
