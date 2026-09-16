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

    /// Estado "todo verde" (flag ON, sesión viva, loop muerto): SÍ arranca.
    @Test func allGreen_starts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, loopAlive: false) == true)
    }

    /// Flag OFF (producción hoy) → JAMÁS arranca (byte-identidad DARK del re-arranque mid-session).
    @Test func flagOff_neverStarts() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: false, hasSession: true, loopAlive: false) == false)
    }

    /// Sin sesión → no arranca (no hay a quién sincronizar).
    @Test func noSession_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: false, loopAlive: false) == false)
    }

    /// Loop ya vivo → single-instance, no duplicar.
    @Test func loopAlive_doesNotStart() {
        #expect(GroupsLoopRestartLogic.shouldStart(
            flagOn: true, hasSession: true, loopAlive: true) == false)
    }

    // MARK: - Despertar el loop vivo (2026-09-16)

    /// Loop vivo con flag y sesión → SÍ se despierta. Es el caso del ticket: volver a primer plano con el
    /// loop durmiendo su backoff.
    @Test func loopAlive_wakes() {
        #expect(GroupsLoopRestartLogic.shouldWake(
            flagOn: true, hasSession: true, loopAlive: true) == true)
    }

    /// Sin loop no hay sueño que cortar: despertar es `false` y el (re)arranque es cosa de `shouldStart`.
    @Test func loopDead_doesNotWake() {
        #expect(GroupsLoopRestartLogic.shouldWake(
            flagOn: true, hasSession: true, loopAlive: false) == false)
    }

    /// Flag OFF —hoy eso significa el kill-switch remoto del canal, no el compilado— → JAMÁS despierta,
    /// igual que jamás arranca.
    @Test func flagOff_neverWakes() {
        #expect(GroupsLoopRestartLogic.shouldWake(
            flagOn: false, hasSession: true, loopAlive: true) == false)
    }

    /// Sin sesión → no despierta (no hay a quién sincronizar, y el loop vivo se va a parar solo en su
    /// próximo `sessionCheck`).
    @Test func noSession_doesNotWake() {
        #expect(GroupsLoopRestartLogic.shouldWake(
            flagOn: true, hasSession: false, loopAlive: true) == false)
    }

    /// Las dos decisiones son MUTUAMENTE EXCLUYENTES en las ocho combinaciones, y su unión es exactamente
    /// «flag ON y sesión viva». Lo que sostiene esto es el `else` de `startIfEligible`: si las dos pudieran
    /// ser ciertas a la vez, ese camino arrancaría un loop Y despertaría otro.
    @Test func startAndWake_areDisjoint_andCoverTheGate() {
        for flagOn in [true, false] {
            for hasSession in [true, false] {
                for loopAlive in [true, false] {
                    let start = GroupsLoopRestartLogic.shouldStart(
                        flagOn: flagOn, hasSession: hasSession, loopAlive: loopAlive)
                    let wake = GroupsLoopRestartLogic.shouldWake(
                        flagOn: flagOn, hasSession: hasSession, loopAlive: loopAlive)
                    #expect(!(start && wake), "arrancar y despertar a la vez: \(flagOn)/\(hasSession)/\(loopAlive)")
                    #expect((start || wake) == (flagOn && hasSession),
                            "el gate compuesto no cuadra: \(flagOn)/\(hasSession)/\(loopAlive)")
                }
            }
        }
    }
}
