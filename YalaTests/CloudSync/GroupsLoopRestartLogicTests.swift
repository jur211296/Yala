//
//  GroupsLoopRestartLogicTests.swift
//  YalaTests / CloudSync
//
//  Tabla del gate puro `GroupsLoopRestartLogic.shouldStart` — decisión de (re)arranque del loop propio del
//  canal Grupos→backend (`GroupsSyncClient.startIfEligible`), incl. la celda D8 de mount-mismatch que hace
//  seguro el call mid-session (foreground / post-sign-in, H-2026-07-18-4).
//

import Testing

@testable import Yala

@Suite("GroupsLoopRestartLogic · tabla de (re)arranque")
struct GroupsLoopRestartLogicTests {

    /// Estado "todo verde" (flag ON, sesión viva, no stopped, loop muerto, sin secundaria): SÍ arranca.
    @Test func allGreen_starts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: false, secondaryMounted: false) == true)
    }

    /// Flag OFF (producción hoy) → JAMÁS arranca (byte-identidad DARK del re-arranque mid-session).
    @Test func flagOff_neverStarts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: false, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: false, secondaryMounted: false) == false)
    }

    /// Sin sesión → no arranca (no hay a quién sincronizar).
    @Test func noSession_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: false, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: false, secondaryMounted: false) == false)
    }

    /// `stoppedUntilRelaunch` armado (403 previo) → no re-arranca en este proceso, ni al foreground.
    @Test func stoppedUntilRelaunch_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: true,
            loopAlive: false, secondaryActive: false, secondaryMounted: false) == false)
    }

    /// Loop ya vivo → single-instance, no duplicar.
    @Test func loopAlive_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: true, secondaryActive: false, secondaryMounted: false) == false)
    }

    /// CELDA D8: secundaria ACTIVA pero su store NO montado (ventana de entrada, store del DUEÑO montado) →
    /// bloquea (un re-arranque drenaría/rehydrataría la History del dueño a la cuenta entrante).
    @Test func mountMismatch_blocks() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: true, secondaryMounted: false) == false)
    }

    /// Secundaria ACTIVA con su store YA montado (estado coherente) → NO es mismatch → arranca.
    @Test func secondaryActiveAndMounted_starts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: true, secondaryMounted: true) == true)
    }

    /// `secondaryMounted == true` con secundaria INACTIVA (device del dueño normal) → no es mismatch.
    @Test func notSecondary_mountedFlagIrrelevant_starts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false, secondaryActive: false, secondaryMounted: true) == true)
    }
}
