//
//  GroupsOnboardingLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupsOnboardingLogic.shouldShow`:
//  verifica el AND-gating de los 3 blockers (flag persistida, modo `.groupInvite`,
//  deeplink a grupo específico pendiente).
//
//  Sin SwiftUI, sin SwiftData, sin singletons, sin `makeTestContext()` — evita
//  flake R8 conocido.
//

import Foundation
import Testing

@testable import Yala

@Suite(.serialized)
struct GroupsOnboardingLogicTests {

    @Test func shouldShow_freshUserNoBlockersReturnsTrue() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: false,
            onboardingMode: .full,
            hasPendingGroupDeeplink: false
        )
        #expect(result == true)
    }

    @Test func shouldShow_alreadyShownReturnsFalse() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: true,
            onboardingMode: .full,
            hasPendingGroupDeeplink: false
        )
        #expect(result == false)
    }

    @Test func shouldShow_groupInviteModeReturnsFalse() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: false,
            onboardingMode: .groupInvite,
            hasPendingGroupDeeplink: false
        )
        #expect(result == false)
    }

    @Test func shouldShow_pendingGroupDeeplinkReturnsFalse() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: false,
            onboardingMode: .full,
            hasPendingGroupDeeplink: true
        )
        #expect(result == false)
    }

    /// Regression: ambos blockers presentes simultáneamente. Confirma AND-gating
    /// sin race entre evaluaciones (cualquier blocker bloquea independientemente).
    @Test func shouldShow_groupInviteModeWithDeeplinkReturnsFalse() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: false,
            onboardingMode: .groupInvite,
            hasPendingGroupDeeplink: true
        )
        #expect(result == false)
    }

    /// Mode `.completed` (post fullActivation) NO bloquea — el user ya activó
    /// el modo full y debe ver el onboarding informativo del tab Grupos.
    @Test func shouldShow_completedModeReturnsTrue() {
        let result = GroupsOnboardingLogic.shouldShow(
            hasShownOnboarding: false,
            onboardingMode: .completed,
            hasPendingGroupDeeplink: false
        )
        #expect(result == true)
    }
}
