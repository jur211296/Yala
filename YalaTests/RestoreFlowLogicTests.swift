//
//  RestoreFlowLogicTests.swift
//  YalaTests
//
//  Pure-logic del flujo de restore desde iCloud: gate del wipe (RestoreOfferGate),
//  destino post-restore por onboardingMode (RestoreRouter) y fases de la pantalla
//  de progreso (OnboardingRestoreProgress). Sin contexto ni singletons.
//

import Foundation
import Testing

@testable import Yala

struct RestoreOfferGateTests {

    @Test func returningSignal_onboardingNoWipe_true() {
        #expect(RestoreOfferGate.hasReturningSignal(lastOnboarding: 100, lastWipe: 0))
    }

    @Test func returningSignal_wipeAfterOnboarding_false() {
        // Hizo wipe después del onboarding → respeta el wipe, no ofrecer.
        #expect(!RestoreOfferGate.hasReturningSignal(lastOnboarding: 100, lastWipe: 200))
    }

    @Test func returningSignal_onboardingAfterWipe_true() {
        // Wipe y luego re-onboardeó en otro device → vuelve a ofrecer.
        #expect(RestoreOfferGate.hasReturningSignal(lastOnboarding: 300, lastWipe: 200))
    }

    @Test func returningSignal_neverOnboarded_false() {
        #expect(!RestoreOfferGate.hasReturningSignal(lastOnboarding: 0, lastWipe: 0))
    }

    @Test func shouldOffer_noData_false() {
        #expect(!RestoreOfferGate.shouldOfferRestore(hasData: false, lastOnboarding: 100, lastWipe: 0))
    }

    @Test func shouldOffer_dataAndReturning_true() {
        #expect(RestoreOfferGate.shouldOfferRestore(hasData: true, lastOnboarding: 100, lastWipe: 0))
    }

    @Test func shouldOffer_dataButWiped_false() {
        #expect(!RestoreOfferGate.shouldOfferRestore(hasData: true, lastOnboarding: 100, lastWipe: 200))
    }

    @Test func wasWiped_wipeRecent_true() {
        #expect(RestoreOfferGate.wasWiped(lastOnboarding: 100, lastWipe: 200))
    }

    @Test func wasWiped_onboardingRecent_false() {
        #expect(!RestoreOfferGate.wasWiped(lastOnboarding: 300, lastWipe: 200))
    }

    @Test func wasWiped_neverWiped_false() {
        #expect(!RestoreOfferGate.wasWiped(lastOnboarding: 100, lastWipe: 0))
    }
}

struct RestoreRouterTests {

    @Test func groupInvite_goesToGroupsOnly() {
        #expect(RestoreRouter.decide(onboardingMode: .groupInvite, isFullyPrefilled: false) == .groupsOnly)
    }

    @Test func groupInvite_ignoresPrefill() {
        // groupInvite manda aunque esté fully prefilled.
        #expect(RestoreRouter.decide(onboardingMode: .groupInvite, isFullyPrefilled: true) == .groupsOnly)
    }

    @Test func full_fullyPrefilled_directToApp() {
        #expect(RestoreRouter.decide(onboardingMode: .full, isFullyPrefilled: true) == .directToApp)
    }

    @Test func full_notPrefilled_onboarding() {
        // Caso Pia (si fuera .full sin cuentas) → onboarding rama B.
        #expect(RestoreRouter.decide(onboardingMode: .full, isFullyPrefilled: false) == .onboarding)
    }

    @Test func completed_fullyPrefilled_directToApp() {
        #expect(RestoreRouter.decide(onboardingMode: .completed, isFullyPrefilled: true) == .directToApp)
    }
}

struct OnboardingRestoreProgressTests {

    @Test func phase_noFirstImport_connecting() {
        #expect(OnboardingRestoreProgress.phase(hasCompletedFirstImport: false, isQuiescent: false, timedOut: false) == .connecting)
    }

    @Test func phase_firstImportNotQuiescent_importing() {
        #expect(OnboardingRestoreProgress.phase(hasCompletedFirstImport: true, isQuiescent: false, timedOut: false) == .importing)
    }

    @Test func phase_settled_completed() {
        #expect(OnboardingRestoreProgress.phase(hasCompletedFirstImport: true, isQuiescent: true, timedOut: false) == .completed)
    }

    @Test func phase_timeoutBeforeSettled_partial() {
        #expect(OnboardingRestoreProgress.phase(hasCompletedFirstImport: true, isQuiescent: false, timedOut: true) == .partial)
    }

    @Test func phase_settledWinsOverTimeout() {
        // Si ya está asentado, no es parcial aunque el timeout haya disparado.
        #expect(OnboardingRestoreProgress.phase(hasCompletedFirstImport: true, isQuiescent: true, timedOut: true) == .completed)
    }

    @Test func isTerminal_completedAndPartial() {
        #expect(OnboardingRestoreProgress.isTerminal(.completed))
        #expect(OnboardingRestoreProgress.isTerminal(.partial))
        #expect(!OnboardingRestoreProgress.isTerminal(.connecting))
        #expect(!OnboardingRestoreProgress.isTerminal(.importing))
    }

    @Test func fraction_increasesWithProgress() {
        #expect(OnboardingRestoreProgress.fraction(for: .connecting) < OnboardingRestoreProgress.fraction(for: .importing))
        #expect(OnboardingRestoreProgress.fraction(for: .importing) < OnboardingRestoreProgress.fraction(for: .completed))
        #expect(OnboardingRestoreProgress.fraction(for: .completed) == 1.0)
    }
}
