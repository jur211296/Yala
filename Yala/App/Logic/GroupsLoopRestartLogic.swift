//
//  GroupsLoopRestartLogic.swift
//  Yala
//
//  Pure-logic gate for (re)starting the OWN cadence loop of the Groups→backend sync channel
//  (`GroupsSyncClient.startIfEligible`). Extracted so the restart decision — INCLUDING the D8
//  mount-mismatch guard that makes MID-SESSION calls safe (foreground resume / post-sign-in, the
//  H-2026-07-18-4 fix) — is a single testable table instead of scattered guards. Molde: `SplitSyncStartGate`
//  (pure, nonisolated, exhaustive table).
//
//  Scope: this decides ONLY whether the channel's OWN loop should (re)start now. The piggyback mode (when
//  the PERSONAL runtime cadences, the group cycle rides as step 5.6 of `CloudSyncRuntime.performCycle`) is
//  NOT modeled here — its early-return lives in `startIfEligible` after this returns `true` with
//  `loopAlive == false`. The boot-net rehydrate of the App Group mirror also runs behind a `true` here.
//

import Foundation

nonisolated enum GroupsLoopRestartLogic {

    /// ¿Debe `startIfEligible` (re)arrancar el loop propio del canal AHORA?
    ///
    /// - `flagOn` — `CloudSyncFlags.groupsBackendEnabled`. Con el flag OFF (producción hoy) SIEMPRE
    ///   `false` → byte-identidad DARK: el re-arranque en foreground / post-sign-in es un no-op.
    /// - `hasSession` — hay sesión viva (`sessionCheck()`). Sin sesión no hay a quién sincronizar.
    /// - `stoppedUntilRelaunch` — un `.accountUnavailable` previo armó el stop de proceso (A5): no
    ///   re-arrancar en este proceso ni al foreground ni tras un sign-in. Desde el 2026-09-13 **el canal de
    ///   Grupos no tiene ningún productor alcanzable para ese sello**: el 403 del kill nunca lo armó (es
    ///   re-arrancable a propósito), el 403 de infraestructura pasó a ser transitorio, y el 409 que queda
    ///   en el código no lo emite `/groups/push`. Ver `GroupsSyncClient.stoppedUntilRelaunch`; el parámetro
    ///   se conserva porque esta tabla es la que pararía un veredicto de cuenta futuro.
    /// - `loopAlive` — el loop ya vive (`loopTask != nil`): single-instance, no duplicar.
    static func shouldStart(
        flagOn: Bool,
        hasSession: Bool,
        stoppedUntilRelaunch: Bool,
        loopAlive: Bool
    ) -> Bool {
        guard flagOn, hasSession else { return false }
        guard !stoppedUntilRelaunch else { return false }
        guard !loopAlive else { return false }
        return true
    }
}
