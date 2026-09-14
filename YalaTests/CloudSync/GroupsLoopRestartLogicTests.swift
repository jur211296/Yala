//
//  GroupsLoopRestartLogicTests.swift
//  YalaTests / CloudSync
//
//  Tabla del gate puro `GroupsLoopRestartLogic.shouldStart` — decisión de (re)arranque del loop propio del
//  canal Grupos→backend (`GroupsSyncClient.startIfEligible`).
//

import Testing

@testable import Yala

@Suite("GroupsLoopRestartLogic · tabla de (re)arranque")
struct GroupsLoopRestartLogicTests {

    /// Estado "todo verde" (flag ON, sesión viva, no stopped, loop muerto): SÍ arranca.
    @Test func allGreen_starts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false) == true)
    }

    /// Flag OFF (producción hoy) → JAMÁS arranca (byte-identidad DARK del re-arranque mid-session).
    @Test func flagOff_neverStarts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: false, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: false) == false)
    }

    /// Sin sesión → no arranca (no hay a quién sincronizar).
    @Test func noSession_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: false, stoppedUntilRelaunch: false,
            loopAlive: false) == false)
    }

    /// `stoppedUntilRelaunch` armado → no re-arranca en este proceso, ni al foreground. Desde el
    /// 2026-09-13 ningún 403 lo arma (ver `GroupsSyncClient.stoppedUntilRelaunch`); la tabla se conserva
    /// porque es la que pararía un veredicto de cuenta futuro.
    @Test func stoppedUntilRelaunch_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: true,
            loopAlive: false) == false)
    }

    /// Loop ya vivo → single-instance, no duplicar.
    @Test func loopAlive_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, stoppedUntilRelaunch: false,
            loopAlive: true) == false)
    }
}
