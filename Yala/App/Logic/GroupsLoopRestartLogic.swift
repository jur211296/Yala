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
    /// - `stoppedUntilRelaunch` — un 403 previo (cuenta no disponible) armó el stop de proceso (A5): no
    ///   re-arrancar en este proceso ni al foreground ni tras un sign-in.
    /// - `loopAlive` — el loop ya vive (`loopTask != nil`): single-instance, no duplicar.
    /// - `secondaryActive` / `secondaryMounted` — GUARD D8 (mount-mismatch): en la VENTANA DE ENTRADA de
    ///   la sesión secundaria (descriptor persistido pero el store del DUEÑO aún montado) un re-arranque
    ///   drenaría/rehydrataría la History del dueño a la cuenta entrante. Bloquea si
    ///   `secondaryActive && !secondaryMounted` (idéntico a `CloudSyncRuntime.canRunDomain`). El estado
    ///   coherente (secundaria activa Y su store montado) NO bloquea.
    static func shouldStart(
        flagOn: Bool,
        hasSession: Bool,
        stoppedUntilRelaunch: Bool,
        loopAlive: Bool,
        secondaryActive: Bool,
        secondaryMounted: Bool
    ) -> Bool {
        guard flagOn, hasSession else { return false }
        guard !stoppedUntilRelaunch else { return false }
        guard !loopAlive else { return false }
        if secondaryActive && !secondaryMounted { return false }  // D8 mount-mismatch
        return true
    }
}
