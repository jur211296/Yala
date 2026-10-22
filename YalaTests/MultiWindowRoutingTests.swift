//
//  MultiWindowRoutingTests.swift
//  YalaTests
//
//  Fase 4 del carril adaptativo: a qué ventana va cada intent, qué enseña una ventana seguidora y quién lanzó el
//  cierre de sesión.
//

import Foundation
import Testing

@testable import Yala

// MARK: - A qué ventana va lo que llega

struct SceneRoutingLogicTests {

    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    @Test func routingTarget_focusedAlive_wins() {
        #expect(SceneRoutingLogic.routingTarget(focused: b, alive: [a, b]) == b)
    }

    @Test func routingTarget_focusedClosed_fallsBackToLeader() {
        #expect(SceneRoutingLogic.routingTarget(focused: c, alive: [a, b]) == a)
    }

    @Test func routingTarget_noWindows_isNil() {
        #expect(SceneRoutingLogic.routingTarget(focused: a, alive: []) == nil)
    }

    @Test func effectiveTarget_sealedAlive_keepsItsWindow_evenIfAnotherIsFocused() {
        // El enlace llegó a B; luego el usuario tocó A. El intent sigue yendo a B.
        #expect(SceneRoutingLogic.effectiveTarget(sealed: b, focused: a, alive: [a, b]) == b)
    }

    @Test func effectiveTarget_sealedClosed_goesToTheFocusedOne() {
        #expect(SceneRoutingLogic.effectiveTarget(sealed: c, focused: b, alive: [a, b]) == b)
    }

    @Test func effectiveTarget_unsealed_goesToTheFocusedOne() {
        #expect(SceneRoutingLogic.effectiveTarget(sealed: nil, focused: b, alive: [a, b]) == b)
    }

    @Test func canDrain_onlyTheEffectiveWindow() {
        #expect(SceneRoutingLogic.canDrain(sealed: b, consumerScene: b, focused: a, alive: [a, b]))
        #expect(!SceneRoutingLogic.canDrain(sealed: b, consumerScene: a, focused: a, alive: [a, b]))
    }

    @Test func canDrain_consumerWithoutWindow_drainsEverything() {
        // Los unit tests del router no montan ventanas: su comportamiento es el de antes de la fase 4.
        #expect(SceneRoutingLogic.canDrain(sealed: b, consumerScene: nil, focused: a, alive: [a, b]))
    }

    @Test func canDrain_noWindowsAlive_drains() {
        #expect(SceneRoutingLogic.canDrain(sealed: b, consumerScene: a, focused: nil, alive: []))
    }
}

// MARK: - El router sella y drena por ventana

@MainActor
struct AppRouterPerWindowTests {

    /// Dos ventanas de mentira dadas de alta DETRÁS de las que ya haya (el host de tests monta la suya, que sigue
    /// siendo la líder). Se dan de baja al final para no dejar el registro cambiado.
    private func withTwoWindows(_ body: (SceneNavigation, SceneNavigation) -> Void) {
        let registry = SceneRegistry.shared
        let previousFocus = registry.focusedID
        let first = SceneNavigation()
        let second = SceneNavigation()
        registry.register(first)
        registry.register(second)
        AppRouter.shared._testReset()
        body(first, second)
        registry.unregister(first.id)
        registry.unregister(second.id)
        if let previousFocus { registry.noteFocused(previousFocus) }
        AppRouter.shared._testReset()
    }

    @Test func enqueue_sealsTheFocusedWindow_andOnlyItDrains() {
        withTwoWindows { first, second in
            let router = AppRouter.shared
            SceneRegistry.shared.noteFocused(second.id)
            router.enqueue(.presentInboxSheet)
            #expect(router._testTargets == [second.id])

            router.markReady(.panel, in: first.id)
            router.markReady(.panel, in: second.id)
            #expect(router.drainNext(for: .panel, in: first.id) == nil)
            #expect(router.peekNext(for: .panel, in: first.id) == nil)
            #expect(router.drainNext(for: .panel, in: second.id)?.id == "inboxSheet")
        }
    }

    @Test func focusMovingAfterEnqueue_doesNotStealTheIntent() {
        withTwoWindows { first, second in
            let router = AppRouter.shared
            SceneRegistry.shared.noteFocused(second.id)
            router.enqueue(.presentInboxSheet)
            SceneRegistry.shared.noteFocused(first.id)

            router.markReady(.panel, in: first.id)
            router.markReady(.panel, in: second.id)
            #expect(router.drainNext(for: .panel, in: first.id) == nil)
            #expect(router.drainNext(for: .panel, in: second.id) != nil)
        }
    }

    @Test func sealedWindowCloses_intentMovesToTheFocusedOne() {
        withTwoWindows { first, second in
            let router = AppRouter.shared
            SceneRegistry.shared.noteFocused(second.id)
            router.enqueue(.presentInboxSheet)
            SceneRegistry.shared.noteFocused(first.id)
            SceneRegistry.shared.unregister(second.id)

            router.markReady(.panel, in: first.id)
            #expect(router.drainNext(for: .panel, in: first.id)?.id == "inboxSheet")
        }
    }

    @Test func closingAWindow_retiresItsReadiness() {
        withTwoWindows { first, second in
            let router = AppRouter.shared
            router.markReady(.panel, in: second.id)
            #expect(router.readyConsumers.contains(.panel))
            SceneRegistry.shared.unregister(second.id)
            #expect(!router.readyConsumers.contains(.panel))
            _ = first
        }
    }

    @Test func contentViewIntents_areNotSealed_andGoToTheLeaderOnly() {
        withTwoWindows { first, second in
            let router = AppRouter.shared
            SceneRegistry.shared.noteFocused(second.id)
            router.enqueue(.iCloudMismatch)
            #expect(router._testTargets == [nil])

            // Ninguna de las dos es la líder (lo es la ventana del host): no drenan aunque estén al frente.
            router.markReady(.contentView, in: first.id)
            router.markReady(.contentView, in: second.id)
            #expect(router.drainNext(for: .contentView, in: second.id) == nil)
            #expect(router.drainNext(for: .contentView, in: first.id) == nil)
            if let leader = SceneRegistry.shared.leaderID {
                router.markReady(.contentView, in: leader)
                #expect(router.drainNext(for: .contentView, in: leader)?.id == "iCloudMismatch")
            }
        }
    }
}

// MARK: - Qué enseña una ventana seguidora

struct FollowerWindowGateLogicTests {

    private func state(
        leaderBlocker: String? = nil,
        hasLeader: Bool = true,
        isWipingData: Bool = false,
        busyBySignOut: Bool = false,
        signOutAwaitingRelaunch: Bool = false,
        forceUpdateRequired: Bool = false,
        hasCompletedOnboarding: Bool = true
    ) -> FollowerWindowGateLogic.State {
        FollowerWindowGateLogic.state(
            leaderBlocker: leaderBlocker,
            hasLeader: hasLeader,
            isWipingData: isWipingData,
            busyBySignOut: busyBySignOut,
            signOutAwaitingRelaunch: signOutAwaitingRelaunch,
            forceUpdateRequired: forceUpdateRequired,
            hasCompletedOnboarding: hasCompletedOnboarding)
    }

    @Test func freeLeader_operates() {
        #expect(state() == .operating)
    }

    @Test func leaderSheets_doNotStopTheFollower() {
        for blocker in ["activeInboxAlert", "proTrialOffer", "whatsNew", "groupsConsent", "groupsSignIn",
                        "inviteError", "mainTabModal", "syncSettingsSheet"] {
            #expect(state(leaderBlocker: blocker) == .operating, "\(blocker)")
        }
    }

    /// Los dos que pueden borrar el corpus desde su hoja sin pasar por `isWipingData`.
    @Test func leaderSheetsThatWipe_stopTheFollower() {
        #expect(state(leaderBlocker: "lateICloudNotice") == .needsLeader)
        #expect(state(leaderBlocker: "fullModeActivation") == .needsLeader)
    }

    @Test func leaderQuestions_sendTheUserToTheLeader() {
        for blocker in FollowerWindowGateLogic.attentionBlockers {
            #expect(state(leaderBlocker: blocker) == .needsLeader, "\(blocker)")
        }
    }

    @Test func leaderStarting_isBusy() {
        #expect(state(leaderBlocker: "splash") == .busy)
        #expect(state(leaderBlocker: "bootstrapPending") == .busy)
        #expect(state(hasLeader: false) == .busy)
    }

    @Test func signOutRelaunch_isTerminalEverywhere_evenOverALeaderQuestion() {
        #expect(state(leaderBlocker: "welcomeFlow", signOutAwaitingRelaunch: true) == .signOutRelaunch)
    }

    @Test func forceUpdate_beatsEverything() {
        #expect(state(isWipingData: true, signOutAwaitingRelaunch: true, forceUpdateRequired: true) == .forceUpdate)
    }

    @Test func wiping_isBusy() {
        #expect(state(isWipingData: true) == .busy)
    }

    @Test func busyBySignOut_isBusy() {
        #expect(state(busyBySignOut: true) == .busy)
    }

    @Test func onboardingNotDone_sendsTheUserToTheLeader() {
        #expect(state(hasCompletedOnboarding: false) == .needsLeader)
    }

    @Test func blockerNames_holdTheRouterExceptWhenOperating() {
        #expect(FollowerWindowGateLogic.State.operating.blockerName == nil)
        for other: FollowerWindowGateLogic.State in [.busy, .signOutRelaunch, .forceUpdate, .needsLeader] {
            #expect(other.blockerName != nil)
        }
    }
}

// MARK: - Quién lanzó el cierre de sesión

struct SignOutDriverLogicTests {

    private let a = UUID()
    private let b = UUID()

    @Test func enteringWorking_theFocusedWindowIsTheDriver() {
        #expect(SignOutDriverLogic.driver(previous: nil, oldPhase: .idle, newPhase: .working, focused: a) == a)
    }

    @Test func whileWorking_theDriverHolds_evenIfFocusMoves() {
        #expect(SignOutDriverLogic.driver(previous: a, oldPhase: .working, newPhase: .working, focused: b) == a)
    }

    @Test func leavingWorking_forgetsIt() {
        #expect(SignOutDriverLogic.driver(previous: a, oldPhase: .working, newPhase: .awaitingRelaunch, focused: a) == nil)
        #expect(SignOutDriverLogic.driver(previous: a, oldPhase: .working, newPhase: .idle, focused: a) == nil)
    }

    @Test func busy_everyWindowButTheDriver() {
        #expect(!SignOutDriverLogic.windowIsBusy(windowID: a, driverID: a, aliveCount: 2, signOutWorking: true))
        #expect(SignOutDriverLogic.windowIsBusy(windowID: b, driverID: a, aliveCount: 2, signOutWorking: true))
        #expect(!SignOutDriverLogic.windowIsBusy(windowID: b, driverID: a, aliveCount: 2, signOutWorking: false))
    }

    /// La que lo lanzó se cerró: la que queda, aunque esté sola, no vuelve a operar a mitad del cierre.
    @Test func driverClosed_theRemainingWindowStaysBusy() {
        #expect(SignOutDriverLogic.windowIsBusy(windowID: b, driverID: a, aliveCount: 1, signOutWorking: true))
    }

    /// El iPhone de siempre: una ventana, sin dato de quién lo lanzó, nunca se le desmonta nada.
    @Test func singleWindowWithoutDriver_isNeverBusy() {
        #expect(!SignOutDriverLogic.windowIsBusy(windowID: a, driverID: nil, aliveCount: 1, signOutWorking: true))
        #expect(SignOutDriverLogic.windowIsBusy(windowID: a, driverID: nil, aliveCount: 2, signOutWorking: true))
    }
}

// MARK: - Qué trae la líder al frente

struct BringsLeaderForwardTests {

    /// Lo que pide el usuario con un toque en otra ventana y solo enseña la líder.
    @Test func userRequestedShellFlows_bringTheLeaderForward() {
        let flows: [RouterIntent] = [
            .presentGroupsConsent(pendingJoin: "z"), .presentGroupsSignIn(pendingJoin: "z"),
            .presentFullModeActivation, .presentGroupsOrganizerStep,
        ]
        for intent in flows {
            #expect(intent.bringsLeaderForward, "\(intent.id)")
            #expect(intent.handler == .contentView, "\(intent.id)")
        }
    }

    /// Los avisos de fondo no le quitan la ventana al usuario.
    @Test func backgroundNotices_doNotStealTheWindow() {
        let notices: [RouterIntent] = [
            .presentTrialOffer, .presentWhatsNew(features: [], version: "1"), .remoteOnboardingCompleted,
            .showGroupSyncError("x"), .iCloudMismatch, .presentRemoteWipeNotice, .presentInboxSheet,
        ]
        for intent in notices {
            #expect(!intent.bringsLeaderForward, "\(intent.id)")
        }
    }
}
