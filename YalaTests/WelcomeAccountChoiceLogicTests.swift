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
        // Born-cloud DIFERIDO: aun con backend configurado + remotos ON, sin el enable no aparece.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: false,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_bornCloudEnabled_requiresConfiguredAndNotUITest() {
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount, .cloudAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: false, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: true, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
    }

    @Test
    func newOptions_remoteFlags_bothRequired() {
        // DIFERIDOS #34: la card born-cloud exige el flag padre Y el sub-flag §j.1 —
        // el escalón born-cloud es POSTERIOR al del flag padre en el rollout.
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: false, remoteOnboardingChoiceEnabled: true
        ) == [.privateAccount])
        #expect(WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: true, isUITest: false, bornCloudEnabled: true,
            remoteCloudEnabled: true, remoteOnboardingChoiceEnabled: false
        ) == [.privateAccount])
    }

    // MARK: - "Ya tengo cuenta"

    @Test
    func existingOptions_configured_showsAllThree() {
        // Sesión 2 Google: Apple y Google comparten el MISMO gate (configured && !uitest && remoto).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false, remoteCloudEnabled: true
        ) == [.restoreICloud, .cloudSignIn, .googleSignIn])
    }

    @Test
    func existingOptions_notConfigured_onlyRestore() {
        // Prod DARK hoy: el botón SIWA jamás aparece sin backend configurado.
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: false, isUITest: false, remoteCloudEnabled: true
        ) == [.restoreICloud])
    }

    @Test
    func existingOptions_uitest_onlyRestore() {
        // Bypass uitest intacto (el opt-in `-uitest-cloud-chooser` pasa isUITest=false en
        // el callsite — la lógica pura no cambia).
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: true, remoteCloudEnabled: true
        ) == [.restoreICloud])
    }

    @Test
    func existingOptions_remoteKillSwitch_onlyRestore() {
        // DIFERIDOS #34: kill-switch OFF oculta las cards nube → bypass a restore (= prod DARK).
        // Residual ratificado: un usuario nube que reinstala bajo el kill no re-entra hasta
        // re-encendido.
        #expect(WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: true, isUITest: false, remoteCloudEnabled: false
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
