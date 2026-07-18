//
//  RelaunchNetLogicTests.swift
//  YalaTests
//
//  Tabla de la decisión pura de las redes de relaunch terminal (fix carrera de anchors
//  2026-07-14): verify loop de presentación efectiva + exit-on-background.
//

import SwiftUI
import Testing

@testable import Yala

@Suite("Relaunch net — veredicto del verify loop (presentación efectiva)")
struct RelaunchNetVerdictTests {

    @Test
    func notArmed_standsDown_regardlessOfEverything() {
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: false, attempt: 0) == .standDown)
        // Desarmado gana incluso con cover vivo o intentos agotados.
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: true, attempt: 0) == .standDown)
        #expect(RelaunchNetLogic.verdict(armed: false, coverDidAppear: false, attempt: 99) == .standDown)
    }

    @Test
    func coverAppeared_isSatisfied_evenBeyondCap() {
        #expect(RelaunchNetLogic.verdict(armed: true, coverDidAppear: true, attempt: 0) == .satisfied)
        // El cover vivo gana SIEMPRE — jamás togglar (dismiss/re-present) un cover real,
        // ni aunque el contador haya rebasado el cap por cualquier vía.
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: true, attempt: RelaunchNetLogic.maxAttempts + 3
        ) == .satisfied)
    }

    @Test
    func noCover_underCap_retries() {
        #expect(RelaunchNetLogic.verdict(armed: true, coverDidAppear: false, attempt: 0) == .retry)
        // Frontera: el último intento permitido es attempt == maxAttempts - 1.
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts - 1
        ) == .retry)
    }

    @Test
    func noCover_atCap_exhausts() {
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts
        ) == .exhausted)
        #expect(RelaunchNetLogic.verdict(
            armed: true, coverDidAppear: false, attempt: RelaunchNetLogic.maxAttempts + 1
        ) == .exhausted)
    }
}

@Suite("Relaunch net — exit(0) en background (decisión owner UX 2026-07-14)")
struct RelaunchExitOnBackgroundTests {

    @Test
    func background_withSignOutAwaitingRelaunch_exits() {
        #expect(RelaunchNetLogic.shouldExitOnBackground(
            scenePhase: .background, signOutPhase: .awaitingRelaunch,
            secondaryEntryArmedUnmounted: false
        ))
    }

    @Test
    func background_withSecondaryEntryArmed_exits() {
        #expect(RelaunchNetLogic.shouldExitOnBackground(
            scenePhase: .background, signOutPhase: .idle,
            secondaryEntryArmedUnmounted: true
        ))
    }

    @Test
    func background_withoutRelaunchPending_neverExits() {
        for phase: CloudSessionSignOut.Phase in [.idle, .working, .blocked(pendingCount: 3, reason: .transient)] {
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: .background, signOutPhase: phase,
                secondaryEntryArmedUnmounted: false
            ))
        }
    }

    @Test
    func inactiveOrActive_neverExits_evenArmed() {
        // .inactive cubre app switcher / notification center — matar el proceso ahí
        // aparentaría crash con la app a la vista.
        for scene: ScenePhase in [.inactive, .active] {
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .awaitingRelaunch,
                secondaryEntryArmedUnmounted: false
            ))
            #expect(!RelaunchNetLogic.shouldExitOnBackground(
                scenePhase: scene, signOutPhase: .idle,
                secondaryEntryArmedUnmounted: true
            ))
        }
    }
}
